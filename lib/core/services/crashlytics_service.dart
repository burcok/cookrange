import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'log_service.dart';

class CrashlyticsService {
  FirebaseCrashlytics get _crashlytics => FirebaseCrashlytics.instance;
  final String _serviceName = 'CrashlyticsService';

  // Singleton pattern
  static final CrashlyticsService _instance = CrashlyticsService._internal();
  factory CrashlyticsService() => _instance;
  CrashlyticsService._internal();

  Future<void> initialize() async {
    LogService().info('Initializing CrashlyticsService', service: _serviceName);
    try {
      // Privacy-by-default: collection stays OFF until the user's analytics
      // consent is applied via [setConsentEnabled]. Never collect in debug.
      await _crashlytics.setCrashlyticsCollectionEnabled(false);

      LogService().info('Crashlytics initialized (collection gated on consent).',
          service: _serviceName);

      // Listen to the log stream for severe errors.
      Logger.root.onRecord.listen((record) {
        if (record.level == Level.SEVERE) {
          _crashlytics.recordError(
            record.error,
            record.stackTrace,
            reason: record.message,
            fatal: true, // Mark as fatal to ensure it's reported
          );
        }
      });
    } catch (e, stackTrace) {
      LogService().error('Error initializing CrashlyticsService',
          service: _serviceName, error: e, stackTrace: stackTrace);
    }
  }

  /// Enables/disables Crashlytics collection per the user's analytics consent.
  /// Never collects in debug. Called by ConsentService on consent load/change.
  Future<void> setConsentEnabled(bool granted) async {
    try {
      await _crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode && granted);
    } catch (e) {
      LogService().warning('Crashlytics setConsentEnabled failed: $e',
          service: _serviceName);
    }
  }

  Future<void> log(String message) async {
    if (!_crashlytics.isCrashlyticsCollectionEnabled) return;
    try {
      await _crashlytics.log(message);
    } catch (e) {
      LogService().error('CrashlyticsService: Error logging message',
          service: _serviceName, error: e);
    }
  }

  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!_crashlytics.isCrashlyticsCollectionEnabled) return;
    try {
      await _crashlytics.recordError(
        exception,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      LogService().error('CrashlyticsService: Error recording error',
          service: _serviceName, error: e);
    }
  }

  Future<void> setUserIdentifier(String identifier) async {
    if (!_crashlytics.isCrashlyticsCollectionEnabled) return;
    try {
      await _crashlytics.setUserIdentifier(identifier);
    } catch (e) {
      LogService().error('CrashlyticsService: Error setting user identifier',
          service: _serviceName, error: e);
    }
  }

  /// Set structured triage keys visible in the Crashlytics dashboard.
  /// Call whenever one of these values changes (login, screen transition, etc.)
  Future<void> setCustomKeys({
    String? screen,
    String? userTier,
    String? aiModel,
  }) async {
    if (!_crashlytics.isCrashlyticsCollectionEnabled) return;
    try {
      if (screen != null) {
        await _crashlytics.setCustomKey('screen', screen);
      }
      if (userTier != null) {
        await _crashlytics.setCustomKey('user_tier', userTier);
      }
      if (aiModel != null) {
        await _crashlytics.setCustomKey('ai_model', aiModel);
      }
    } catch (e) {
      LogService().error('CrashlyticsService: Error setting custom keys',
          service: _serviceName, error: e);
    }
  }
}
