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

  /// Initializes the service and registers it as an observer of lifecycle events.
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    _log.info('AppLifecycleService initialized and listening.',
        service: _serviceName);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    _log.info('App lifecycle state changed to: ${state.name}',
        service: _serviceName);

    final user = _authService.currentUser;
    if (user == null) {
      _log.info('No user logged in, skipping activity update.',
          service: _serviceName);
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _log.info('App resumed, updating last_active_at for user ${user.uid}',
          service: _serviceName);
      await _firestoreService.updateUserLastActiveTimestamp(user.uid);
      await _firestoreService.updateUserOnlineStatus(user.uid, true);
    } else {
      // When the app is paused, inactive, or detached, mark user as offline.
      _log.info(
          'App not in resumed state, marking user ${user.uid} as offline.',
          service: _serviceName);
      await _firestoreService.updateUserOnlineStatus(user.uid, false);
    }
  }

  /// Disposes the service and unregisters it as an observer.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _log.info('AppLifecycleService disposed.', service: _serviceName);
  }
}
