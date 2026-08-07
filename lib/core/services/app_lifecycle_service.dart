import 'dart:async';
import 'package:flutter/material.dart';
import 'app_config_service.dart';
import 'auth_service.dart';
import 'device_registry_service.dart';
import 'firestore_service.dart';
import 'log_service.dart';
import 'presence_service.dart';

/// A service that listens to the application's lifecycle events.
///
/// This service is responsible for performing actions when the app's state
/// changes, such as when it is paused, resumed, or closed. A key use case
/// is updating the user's `last_active_at` timestamp when the app is brought
/// to the foreground.
///
/// Chat Upgrade Phase 2 — this is now the ONE call site driving
/// `PresenceService` (RTDB presence). The old direct Firestore writes of
/// `is_online`/`last_active_at` that used to live here have been removed —
/// those two fields are now mirrored exclusively by
/// `functions/chat_presence.js`'s `mirrorPresence`, so there is exactly one
/// writer instead of a race between this service and the RTDB mirror.
class AppLifecycleService with WidgetsBindingObserver {
  AppLifecycleService({
    AuthService? authService,
    FirestoreService? firestoreService,
    LogService? logService,
    PresenceService? presenceService,
    DeviceRegistryService? deviceRegistryService,
  })  : _authService = authService ?? AuthService(),
        _firestoreService = firestoreService ?? FirestoreService(),
        _log = logService ?? LogService(),
        _presence = presenceService ?? PresenceService(),
        _deviceRegistry = deviceRegistryService ?? DeviceRegistryService();

  final AuthService _authService;
  final FirestoreService _firestoreService;
  final LogService _log;
  final PresenceService _presence;
  final DeviceRegistryService _deviceRegistry;
  final String _serviceName = 'AppLifecycleService';

  // Throttling and Debouncing
  Timer? _sessionPauseTimer; // New debounce timer for session end
  DateTime? _sessionStartTime;
  StreamSubscription? _authSubscription;
  static const Duration _sessionPauseDebounce =
      Duration(seconds: 2); // Quick debounce for session end

  /// Initializes the service and registers it as an observer of lifecycle events.
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    _log.info('AppLifecycleService initialized and listening.',
        service: _serviceName);
    unawaited(_presence.initialize());

    // listen to auth state to handle session start/end on login/logout
    _authSubscription = _authService.authStateChanges.listen((user) {
      if (user != null) {
        _goOnlineAndSyncDevice();
        _startSession();
      } else {
        _endSession();
        // PresenceService.goOffline() reads its own internally-tracked uid
        // (not `user`, which is already null here) — see its doc comment.
        unawaited(_presence.goOffline());
      }
    });

    // Ensure user is marked online on app start if already logged in
    _goOnlineAndSyncDevice();
    _startSession();
  }

  void _startSession() {
    if (_sessionStartTime != null) return; // Session already active
    _sessionStartTime = DateTime.now();
    _log.info('Session started at $_sessionStartTime', service: _serviceName);
  }

  Future<void> _endSession() async {
    final user = _authService.currentUser;
    if (user == null || _sessionStartTime == null) return;

    final endTime = DateTime.now();
    final duration = endTime.difference(_sessionStartTime!);
    _sessionStartTime = null;

    _log.info('Session ended. Duration: ${duration.inSeconds}s',
        service: _serviceName);

    // Log Session Duration (analytics-only). `last_active_at` is no longer
    // written directly here — it's now owned exclusively by
    // functions/chat_presence.js's mirrorPresence via PresenceService's RTDB
    // writes (see this class's header comment).
    await _firestoreService.logUserActivity(user.uid, 'session_end',
        extraData: {'duration_seconds': duration.inSeconds});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _log.info('App lifecycle state changed to: ${state.name}',
        service: _serviceName);

    if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    } else if (state == AppLifecycleState.detached) {
      _handleAppPaused(immediate: true);
    } else if (state == AppLifecycleState.paused) {
      // Inactive is often transient (e.g. notification shade), Paused is backgrounding.
      // We'll treat Paused as end of session.
      _handleAppPaused();
    }
  }

  Future<void> _handleAppResumed() async {
    // Faz A Faz 1 — makes AppConfigService.refreshIfStale() (previously
    // dead code, zero callers) actually run on resume. Deliberately BEFORE
    // the user==null check below: maintenance mode / kill-switches matter
    // even logged out, and this is the connection point DECISIONS.md
    // ADR-023 describes ("mevcut AppLifecycleService'e bağlanır").
    unawaited(AppConfigService().refreshIfStale());

    final user = _authService.currentUser;
    if (user == null) return;

    // Presence goes back to foreground/online immediately on every resume —
    // independent of the session-pause debounce below. A quick app-switch
    // glance still needs "away" cleared right away; RTDB's own
    // onDisconnect, not a client debounce, is what protects against a
    // genuinely killed app.
    unawaited(_presence.goOnline(uid: user.uid));

    // 1. Check if we are within the session pause debounce period
    if (_sessionPauseTimer?.isActive ?? false) {
      _sessionPauseTimer!.cancel();
      _log.info(
          'App resumed within session pause debounce. Session continues uninterrupted.',
          service: _serviceName);
      // Session effectively never ended, so we don't need to start a new one or update online status excessively
    } else {
      // Normal resume (after a long pause or fresh start)
      _startSession();
      // Only set online if we weren't just briefly paused (though duplicate online set is cheap)
      await _goOnlineAndSyncDevice();
    }
  }

  void _handleAppPaused({bool immediate = false}) {
    // Records the pause moment regardless of auth state — see the
    // matching comment in _handleAppResumed above.
    AppConfigService().notePaused();

    final user = _authService.currentUser;
    if (user == null) return;

    // Cancel existing timers to be safe
    _sessionPauseTimer?.cancel();

    if (immediate) {
      // Detached: End immediately
      _log.info('App detached. Ending session and going offline immediately.',
          service: _serviceName);
      _endSession(); // Logs session duration
      unawaited(_presence.goOffline());
      return;
    }

    // Paused (backgrounded): presence flips to `away` immediately — no
    // debounce for RTDB, since `onDisconnect` (not a client timer) is what
    // protects against a genuinely killed app. The session-duration
    // debounce below is a separate, unrelated analytics concern and keeps
    // its existing grace window so a quick app-switch doesn't fragment one
    // session into several.
    _log.info(
        'App paused. Marking away immediately; scheduling session end in ${_sessionPauseDebounce.inSeconds} seconds.',
        service: _serviceName);
    unawaited(_presence.goAway());

    _sessionPauseTimer = Timer(_sessionPauseDebounce, () async {
      _log.info('Session pause debounce over. Ending session.',
          service: _serviceName);
      await _endSession();
    });
  }

  Future<void> _goOnlineAndSyncDevice() async {
    final user = _authService.currentUser;
    if (user == null) return;

    _log.info(
        'Marking user ${user.uid} online (RTDB presence + device context sync).',
        service: _serviceName);
    unawaited(_presence.goOnline(uid: user.uid));
    // Refresh the FULL device/system context (not just is_online) on every
    // app open/resume — a cached auto-login never runs handleUserLogin, so this
    // is what keeps the phone/app-version/IP data fresh on the user doc.
    await _firestoreService.syncDeviceContext(user.uid);
    // Backfill created_at / onboarding_completed if missing (also only runs in
    // handleUserLogin, which a cached auto-login skips). Fire-and-forget.
    unawaited(_firestoreService.verifyAndRepairUserData(user.uid));
    // Faz 1 — multi-device registry: touch THIS device's registry doc so
    // `last_seen_at` (shown on device_management_screen.dart) reflects
    // actual resume activity, not just login time. Injected (like every
    // other dependency on this class) so a unit test can substitute a fake
    // — see test/app_lifecycle_service_test.dart.
    unawaited(_deviceRegistry.registerOrTouchThisDevice(uid: user.uid));
  }

  /// Disposes the service and unregisters it as an observer.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionPauseTimer?.cancel();
    _authSubscription?.cancel();
    _endSession(); // Try to capture session end on dispose
    _log.info('AppLifecycleService disposed.', service: _serviceName);
  }
}
