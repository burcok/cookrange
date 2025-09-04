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
      if (kReleaseMode) {
        await _crashlytics.setCrashlyticsCollectionEnabled(true);
        LogService().info(
            'Firebase Crashlytics collection enabled for release mode.',
            service: _serviceName);
      } else {
        await _crashlytics.setCrashlyticsCollectionEnabled(false);
        LogService().info(
            'Firebase Crashlytics collection disabled for debug mode.',
            service: _serviceName);
      }

      // Pass all uncaught errors from the framework to Crashlytics.
      FlutterError.onError = _crashlytics.recordFlutterError;
      LogService()
          .info('Crashlytics FlutterError handler set.', service: _serviceName);

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
}
