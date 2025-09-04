import 'package:flutter/foundation.dart';
import 'crashlytics_service.dart';

/// A centralized service for logging throughout the application.
///
/// This service abstracts the logging implementation, making it easy to switch
/// between different logging backends (e.g., console, file, remote server)
/// without changing the application code.
class LogService {
  final CrashlyticsService _crashlyticsService = CrashlyticsService();

  // Singleton pattern
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  /// Logs an informational message.
  /// Used for general application flow events.
  void info(String message, {String? service}) {
    _log('INFO', message, service: service);
  }

  /// Logs a warning message.
  /// Used for potential issues that don't crash the app.
  void warning(String message, {String? service}) {
    _log('WARN', message, service: service);
  }

  /// Logs an error message.
  /// Used for exceptions and critical failures.
  /// This will also send the error to Firebase Crashlytics.
  void error(String message,
      {String? service, Object? error, StackTrace? stackTrace}) {
    final errorMessage = '''
      $message
      Error: ${error?.toString()}
    ''';
    _log('ERROR', errorMessage, service: service);

    // Send non-fatal errors to Crashlytics
    _crashlyticsService.recordError(
      error ?? message,
      stackTrace,
      reason: 'Handled Exception: [$service] $message',
      fatal: false,
    );
  }

  void _log(String level, String message, {String? service}) {
    // Only print logs in debug mode to avoid cluttering release builds.
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final serviceTag = service != null ? '[$service]' : '';
      print('$timestamp [$level]$serviceTag $message');
    }
  }
}
