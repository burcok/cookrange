import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_config_model.dart';
import '../utils/deep_merge.dart';
import '../utils/stable_hash.dart';
import 'ai/ai_service.dart';
import 'log_service.dart';

/// Loads + caches the remote, admin-editable [AppConfig] — sourced from
/// THREE Firestore documents, not one, per the config-migration plan's
/// audience-split design (see `functions/config_schema.json`'s header):
///
///   - `app_config/critical` — kill-switches, maintenance, version,
///     announcement, rollout. Watched with a REALTIME LISTENER: a
///     maintenance-mode flip is documented (docs/DEVOPS.md) as an incident
///     lever, and a lever whose latency is "next cold start" is not one.
///   - `app_config/client` — AI model/timeout/quota, endpoints, and other
///     settings both the client and server read. Fetched with a 30-minute
///     TTL plus a resume-triggered refresh (see [refreshIfStale]).
///   - `app_config/global` — the LEGACY, pre-migration doc, still the
///     ACTIVE one in production today. Kept as a fallback layer, refreshed
///     on the same cadence as `client`, so any admin override that already
///     exists there is never silently lost just because `client`/`critical`
///     are still empty (nothing has seeded them yet). Removed once the
///     migration is complete and observed in production.
///
/// Merge precedence (lowest to highest): each source's own nested groups,
/// merged: `global` < `client` < `critical`. During this phase of the
/// migration `client`/`critical` are empty, so this resolves to exactly
/// `global`'s data — bit-identical to pre-migration behavior, by
/// construction. `AppConfig`'s own per-field defaults (fixed to match the
/// canonical schema — see `app_config_model.dart`) are the ultimate
/// fallback beneath all three.
///
/// Pattern: return the cached value INSTANTLY on launch, refresh in the
/// background (stale-while-revalidate), hold it in memory for the session.
/// Everything fails safe — a missing/unreadable doc never overrides what's
/// already loaded.
///
/// Reactive: [notifier] rebuilds live consumers (maintenance banner, kill
/// switches, announcement) whenever ANY source refreshes.
class AppConfigService {
  static final AppConfigService _instance = AppConfigService._internal();
  factory AppConfigService() => _instance;
  AppConfigService._internal();

  final LogService _log = LogService();
  final String _serviceName = 'AppConfigService';

  // _v2: the shape changed (3 docs merged, not 1 flat doc) — a `_v1`-cached
  // blob must never be fed to the new merge logic.
  static const _cacheKey = 'app_config_client_v2';
  static const _cacheAtKey = 'app_config_cached_at_v2';
  static const _stickyMaintenanceKey = 'app_config_maintenance_sticky_v2';
  static const _ttl = Duration(minutes: 30);
  static const _forceRefreshAfterPause = Duration(minutes: 5);

  // `late` — deferred to first ACCESS, not construction. AppLifecycleService
  // now holds a reference to this singleton for notePaused()/refreshIfStale(),
  // neither of which touches Firestore; an eager instance-field initializer
  // here would make merely constructing AppConfigService() require
  // Firebase.initializeApp() to have run, breaking any test (e.g.
  // app_lifecycle_service_test.dart) that never otherwise needed it.
  late final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic> _globalData = const {};
  Map<String, dynamic> _clientData = const {};
  Map<String, dynamic> _criticalData = const {};
  DateTime? _fetchedAt;
  bool _stickyMaintenance = false;

  AppConfig _current = const AppConfig();
  final ValueNotifier<AppConfig> notifier =
      ValueNotifier<AppConfig>(const AppConfig());

  /// Session-scoped current config (never null; defaults until first load).
  AppConfig get config => _current;

  bool _initialized = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _criticalSub;
  DateTime? _pausedAt;

  /// Loads the cached config immediately, starts the `critical` realtime
  /// listener, then refreshes `global`+`client` in the background. Safe to
  /// call once at startup.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadFromCache();
    _recompute();

    _criticalSub = _db
        .collection('app_config')
        .doc('critical')
        .snapshots()
        .listen(_onCriticalSnapshot, onError: (e, st) {
      _log.error('AppConfig critical listener failed',
          service: _serviceName, error: e, stackTrace: st);
    });

    if (_fetchedAt == null) {
      // True first launch, no cache at all — the splash screen is already
      // running, so a short bounded wait here is free and closes the
      // cold-start window with real data instead of relying purely on
      // schema defaults for however long the background fetch takes.
      await refresh().timeout(const Duration(milliseconds: 1500),
          onTimeout: () {});
    } else {
      unawaited(refresh());
    }
  }

  void _onCriticalSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    _criticalData = _asMap(snap.data());
    _observeMaintenance(_criticalData);
    _recompute();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _stickyMaintenance = prefs.getBool(_stickyMaintenanceKey) ?? false;
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _globalData = _asMap(decoded['global']);
      _clientData = _asMap(decoded['client']);
      final atMs = prefs.getInt(_cacheAtKey);
      _fetchedAt =
          atMs != null ? DateTime.fromMillisecondsSinceEpoch(atMs) : null;
    } catch (e) {
      _log.warning('AppConfig cache load failed — using defaults',
          service: _serviceName);
    }
  }

  /// Force a fresh fetch of `global`+`client` (respects nothing — always
  /// hits Firestore). `critical` is not re-fetched here — its realtime
  /// listener is always current; a dropped connection reconnects via the
  /// Firestore SDK's own retry behavior, not this method.
  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        _db.collection('app_config').doc('global').get(),
        _db.collection('app_config').doc('client').get(),
      ]);
      _globalData = _asMap(results[0].data());
      _clientData = _asMap(results[1].data());
      _fetchedAt = DateTime.now();
      _recompute();
      unawaited(_saveToCache());
      _log.info('AppConfig refreshed (global+client)', service: _serviceName);
    } catch (e, s) {
      _log.error('AppConfig refresh failed — keeping current',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Refreshes if the cache is older than [_ttl], OR if the app was just
  /// resumed after being paused for longer than [_forceRefreshAfterPause].
  /// This is what makes `refreshIfStale` — previously dead code, zero
  /// callers — actually do something: call it from
  /// `AppLifecycleService._handleAppResumed`.
  Future<void> refreshIfStale() async {
    final pausedFor =
        _pausedAt == null ? null : DateTime.now().difference(_pausedAt!);
    _pausedAt = null;
    if (pausedFor != null && pausedFor > _forceRefreshAfterPause) {
      await refresh();
      return;
    }
    if (_fetchedAt == null || DateTime.now().difference(_fetchedAt!) > _ttl) {
      await refresh();
    }
  }

  /// Records that the app was just paused/backgrounded, so [refreshIfStale]
  /// can decide on the next resume whether the gap was long enough to force
  /// a refresh. Deliberately does NOT clear the in-memory config or force
  /// anything itself — that would flash defaults on a quick resume, which
  /// is a worse user experience than briefly-stale data.
  void notePaused() {
    _pausedAt = DateTime.now();
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Firestore Timestamps aren't JSON-serializable → convert to millis.
      final encoded = jsonEncode(
        {'global': _globalData, 'client': _clientData},
        toEncodable: (o) {
          if (o is Timestamp) return o.millisecondsSinceEpoch;
          if (o is DateTime) return o.millisecondsSinceEpoch;
          return o.toString();
        },
      );
      await prefs.setString(_cacheKey, encoded);
      await prefs.setInt(_cacheAtKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      _log.warning('AppConfig cache save failed', service: _serviceName);
    }
  }

  /// Deep merge — `global` < `client` < `critical` — NOT a shallow
  /// top-level spread. Three schema groups are genuinely SPLIT across more
  /// than one doc (`ai`: client+server; `gamification`: client+server;
  /// `client`: client+critical — see `functions/config_schema.json`'s own
  /// per-key `doc` assignment), so `{...a, ...b}` would let `b`'s partial
  /// `ai` map silently DISCARD every `ai.*` sub-field `a` had that `b`
  /// doesn't mention, rather than layering them. Harmless today only
  /// because `client`/`critical` are still empty (Faz 3 hasn't seeded
  /// them) — getting this right now avoids a latent corruption bug that
  /// would otherwise surface silently the moment they ARE seeded.
  Map<String, dynamic> _merged() =>
      deepMergeMaps([_globalData, _clientData, _criticalData]);

  void _recompute() {
    var c = AppConfig.fromMap(_merged(), fetchedAt: _fetchedAt);
    if (_stickyMaintenance && !c.maintenance.enabled) {
      // A real Firestore read hasn't yet delivered an authoritative
      // `false` since the sticky flag was set (see _observeMaintenance) —
      // keep maintenance mode on rather than let an offline device fall
      // through to the schema default and silently exit maintenance.
      c = AppConfig(
        configVersion: c.configVersion,
        ai: c.ai,
        version: c.version,
        maintenance:
            MaintenanceConfig(enabled: true, message: c.maintenance.message),
        announcement: c.announcement,
        features: c.features,
        rollout: c.rollout,
        limits: c.limits,
        aiProxyUrl: c.aiProxyUrl,
        fetchedAt: c.fetchedAt,
      );
    }
    _set(c);
  }

  /// Persists the "maintenance was seen ON" sticky flag (PLAN.md §A4:
  /// maintenance fails open, but STICKY closed once observed — otherwise
  /// killing network/app access is a bypass for maintenance mode). Only
  /// called with data that just arrived from a REAL Firestore read (the
  /// `critical` listener), never from cache or defaults, so a device that
  /// has never actually seen live maintenance data can't spuriously latch
  /// this from a coincidental default value.
  void _observeMaintenance(Map<String, dynamic> criticalData) {
    final maintenanceMap = criticalData['maintenance'];
    if (maintenanceMap is! Map) return;
    final enabled = maintenanceMap['enabled'];
    if (enabled is! bool) return;
    if (enabled == _stickyMaintenance) return;
    _stickyMaintenance = enabled;
    unawaited(SharedPreferences.getInstance()
        .then((p) => p.setBool(_stickyMaintenanceKey, enabled)));
  }

  void _set(AppConfig c) {
    _current = c;
    notifier.value = c;
    // Push AI-relevant values into AIService so admin changes take effect live.
    // Proxy URL only applied when non-empty (keeps Remote Config fallback —
    // see PLAN.md §A9 for why removing Remote Config before this field is
    // populated in production would be dangerous).
    AIService().applyRemoteConfig(
      textModel: c.ai.textModel,
      visionModel: c.ai.visionModel,
      timeoutSeconds: c.ai.timeoutS,
      proxyUrl: c.aiProxyUrl.isEmpty ? null : c.aiProxyUrl,
      maxRetries: c.ai.maxRetries,
      retryDelaySeconds: c.ai.retryDelayS,
    );
  }

  /// Deterministic 0..99 bucket for gradual rollout — stable per uid+feature
  /// AND reproducible server-side (`functions/stable_hash.js`'s identical
  /// FNV-1a implementation), unlike the previous `String.hashCode`-based
  /// version, which a Cloud Function could never reproduce. See PLAN.md §A3.
  bool isInRollout(String feature, String uid) {
    final pct = _current.rollout[feature];
    if (pct == null || pct >= 100) return true;
    if (pct <= 0) return false;
    final bucket = fnv1a32('$feature:$uid') % 100;
    return bucket < pct;
  }

  /// Single entry point combining the kill-switch (`isFeatureEnabled`) and
  /// gradual-rollout (`isInRollout`) checks. [uid] is optional: pass null to
  /// skip the rollout bucket check (e.g. for a logged-out context) — the
  /// kill-switch alone still applies.
  bool isAvailable(String feature, {String? uid}) {
    if (!_current.isFeatureEnabled(feature)) return false;
    if (uid == null) return true;
    return isInRollout(feature, uid);
  }

  /// Cancels the `critical` realtime listener. The service is a singleton
  /// living for the app's whole lifetime — this exists for completeness
  /// and tests, not because anything calls it in normal operation (matching
  /// the dozens of other long-lived `snapshots()` listeners already in
  /// this codebase, none of which are individually disposed either).
  void dispose() {
    _criticalSub?.cancel();
  }
}

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? v.map((k, val) => MapEntry('$k', val)) : const {};
