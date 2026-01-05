import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'log_service.dart';

/// A service that listens to the application's lifecycle events.
///
/// This service is responsible for performing actions when the app's state
/// changes, such as when it is paused, resumed, or closed. A key use case
/// is updating the user's `last_active_at` timestamp when the app is brought
/// to the foreground.
class AppLifecycleService with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final LogService _log = LogService();
  final String _serviceName = 'AppLifecycleService';

  // Throttling and Debouncing
  Timer? _offlineTimer;
  DateTime? _lastActiveUpdate;
  DateTime? _sessionStartTime;
  StreamSubscription? _authSubscription;
  static const Duration _activeUpdateThrottle = Duration(minutes: 5);
  static const Duration _offlineDebounce = Duration(minutes: 2);

  /// Initializes the service and registers it as an observer of lifecycle events.
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    _log.info('AppLifecycleService initialized and listening.',
        service: _serviceName);

    // listen to auth state to handle session start/end on login/logout
    _authSubscription = _authService.authStateChanges.listen((user) {
      if (user != null) {
        _setOnline();
        _startSession();
      } else {
        _endSession();
        // Offline status is handled by AuthService signOut usually, but safety check:
        // (If we have the info, but user is null here so we can't update Firestore unless we kept the ID)
      }
    });

    // Ensure user is marked online on app start if already logged in
    _setOnline();
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

    // 1. Log Session Duration
    await _firestoreService.logUserActivity(user.uid, 'session_end',
        extraData: {'duration_seconds': duration.inSeconds});

    // 2. Update Last Active At IMMEDIATELY so "Last Seen" is accurate to the exit time
    await _firestoreService.updateUserLastActiveTimestamp(user.uid);
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
      _handleAppPaused(immediate: false);
    }
  }

  Future<void> _handleAppResumed() async {
    final user = _authService.currentUser;
    if (user == null) return;

    // Start Session
    _startSession();

    // Cancel any pending offline timer (Debounce)
    if (_offlineTimer?.isActive ?? false) {
      _offlineTimer!.cancel();
      _log.info(
          'App resumed within debounce period. Cancelled offline status update.',
          service: _serviceName);
      return;
    }

    // Set online status immediately
    await _setOnline();

    // Throttle last_active_at updates (still useful while using the app)
    final now = DateTime.now();
    if (_lastActiveUpdate == null ||
        now.difference(_lastActiveUpdate!) > _activeUpdateThrottle) {
      _log.info('Updating last_active_at (Throttled)', service: _serviceName);
      _lastActiveUpdate = now;
      await _firestoreService.updateUserLastActiveTimestamp(user.uid);
    }
  }

  void _handleAppPaused({bool immediate = false}) {
    final user = _authService.currentUser;
    if (user == null) return;

    // End Session and Log Metrics immediately when leaving
    _endSession();

    // Cancel existing timer to reset debounce
    _offlineTimer?.cancel();

    if (immediate) {
      _log.info(
          'App detached. Setting user ${user.uid} to offline immediately.',
          service: _serviceName);
      _firestoreService.updateUserOnlineStatus(user.uid, false);
      return;
    }

    _log.info(
        'App paused. Scheduling offline status update in ${_offlineDebounce.inMinutes} minutes.',
        service: _serviceName);

    _offlineTimer = Timer(_offlineDebounce, () async {
      _log.info('Debounce period over. Setting user ${user.uid} to offline.',
          service: _serviceName);
      await _firestoreService.updateUserOnlineStatus(user.uid, false);
    });
  }

  Future<void> _setOnline() async {
    final user = _authService.currentUser;
    if (user == null) return;

    _log.info('Setting user ${user.uid} to online.', service: _serviceName);
    await _firestoreService.updateUserOnlineStatus(user.uid, true);
  }

  /// Disposes the service and unregisters it as an observer.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offlineTimer?.cancel();
    _authSubscription?.cancel();
    _endSession(); // Try to capture session end on dispose
    _log.info('AppLifecycleService disposed.', service: _serviceName);
  }
}
