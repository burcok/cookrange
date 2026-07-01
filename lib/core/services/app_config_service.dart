import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_config_model.dart';
import 'ai/ai_service.dart';
import 'log_service.dart';

/// Loads + caches the remote, admin-editable [AppConfig] from
/// `app_config/global`. Pattern: return the cached value INSTANTLY on launch,
/// refresh from Firestore in the background (stale-while-revalidate), and hold
/// it in memory for the session. Everything fails safe to [AppConfig] defaults.
///
/// Reactive: [notifier] rebuilds live consumers (maintenance banner, kill
/// switches, announcement) when a refresh lands.
class AppConfigService {
  static final AppConfigService _instance = AppConfigService._internal();
  factory AppConfigService() => _instance;
  AppConfigService._internal();

  final LogService _log = LogService();
  final String _serviceName = 'AppConfigService';
  static const _cacheKey = 'app_config_cache_v1';
  static const _cacheAtKey = 'app_config_cached_at';
  static const _ttl = Duration(hours: 6);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AppConfig _current = const AppConfig();
  final ValueNotifier<AppConfig> notifier =
      ValueNotifier<AppConfig>(const AppConfig());

  /// Session-scoped current config (never null; defaults until first load).
  AppConfig get config => _current;

  bool _initialized = false;

  /// Loads the cached config immediately, then refreshes in the background.
  /// Safe to call once at startup; awaiting it is cheap (cache read only).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadFromCache();
    // Background refresh — do not block startup on the network.
    unawaited(refresh());
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final atMs = prefs.getInt(_cacheAtKey);
      _set(AppConfig.fromMap(map,
          fetchedAt: atMs != null
              ? DateTime.fromMillisecondsSinceEpoch(atMs)
              : null));
    } catch (e) {
      _log.warning('AppConfig cache load failed — using defaults',
          service: _serviceName);
    }
  }

  /// Force a fresh fetch (respects nothing — always hits Firestore).
  Future<void> refresh() async {
    try {
      final snap = await _db.collection('app_config').doc('global').get();
      if (!snap.exists) {
        _log.info('app_config/global missing — using defaults',
            service: _serviceName);
        return;
      }
      final data = snap.data() ?? {};
      _set(AppConfig.fromMap(data, fetchedAt: DateTime.now()));
      await _saveToCache(data);
      _log.info('AppConfig refreshed', service: _serviceName);
    } catch (e, s) {
      _log.error('AppConfig refresh failed — keeping current',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Refresh only if the cache is older than the TTL (cheap background call).
  Future<void> refreshIfStale() async {
    final at = _current.fetchedAt;
    if (at == null || DateTime.now().difference(at) > _ttl) {
      await refresh();
    }
  }

  Future<void> _saveToCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Firestore Timestamps aren't JSON-serializable → convert to millis.
      final encoded = jsonEncode(data, toEncodable: (o) {
        if (o is Timestamp) return o.millisecondsSinceEpoch;
        if (o is DateTime) return o.millisecondsSinceEpoch;
        return o.toString();
      });
      await prefs.setString(_cacheKey, encoded);
      await prefs.setInt(_cacheAtKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      _log.warning('AppConfig cache save failed', service: _serviceName);
    }
  }

  void _set(AppConfig c) {
    _current = c;
    notifier.value = c;
    // Push AI-relevant values into AIService so admin changes take effect live.
    // Proxy URL only applied when non-empty (keeps Remote Config fallback).
    AIService().applyRemoteConfig(
      textModel: c.ai.textModel,
      visionModel: c.ai.visionModel,
      timeoutSeconds: c.ai.timeoutS,
      proxyUrl: c.aiProxyUrl.isEmpty ? null : c.aiProxyUrl,
    );
  }

  /// Deterministic 0..99 bucket for gradual rollout (stable per uid+feature).
  bool isInRollout(String feature, String uid) {
    final pct = _current.rollout[feature];
    if (pct == null || pct >= 100) return true;
    if (pct <= 0) return false;
    final bucket = (('$feature:$uid').hashCode & 0x7fffffff) % 100;
    return bucket < pct;
  }
}
