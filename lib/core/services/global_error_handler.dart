import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'log_service.dart';

/// Global error handler for the application
class GlobalErrorHandler {
  static final GlobalErrorHandler _instance = GlobalErrorHandler._internal();
  factory GlobalErrorHandler() => _instance;
  GlobalErrorHandler._internal();

  final LogService _log = LogService();
  final String _serviceName = 'GlobalErrorHandler';

  bool _isInitialized = false;

  /// Initialize global error handling
  void initialize() {
    if (_isInitialized) return;

    try {
      // Set up Flutter error handling
      FlutterError.onError = (FlutterErrorDetails details) {
        _handleFlutterError(details);
      };

      // Set up platform error handling
      PlatformDispatcher.instance.onError = (error, stack) {
        _handlePlatformError(error, stack);
        return true;
      };

      _isInitialized = true;
      _log.info('Global error handler initialized', service: _serviceName);
    } catch (e) {
      _log.error('Failed to initialize global error handler',
          service: _serviceName, error: e);
    }
  }

  /// Handle Flutter framework errors
  void _handleFlutterError(FlutterErrorDetails details) {
    _log.error('Flutter Error: ${details.exception}',
        service: _serviceName,
        error: details.exception,
        stackTrace: details.stack);

    // Record to Crashlytics
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);

    // In debug mode, show the error
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  }

  /// Handle platform errors
  void _handlePlatformError(Object error, StackTrace stack) {
    _log.error('Platform Error: $error',
        service: _serviceName, error: error, stackTrace: stack);

    // Record to Crashlytics
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  }

  /// Handle async errors
  static void handleAsyncError(Object error, StackTrace stack) {
    final handler = GlobalErrorHandler();
    handler._log.error('Async Error: $error',
        service: handler._serviceName, error: error, stackTrace: stack);

    // Record to Crashlytics
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
  }

  /// Handle network errors
  static void handleNetworkError(
    Object error,
    StackTrace stack, {
    String? endpoint,
    String? method,
    int? statusCode,
  }) {
    final handler = GlobalErrorHandler();
    final errorMessage = 'Network Error: $error';

    handler._log.error(errorMessage,
        service: handler._serviceName, error: error, stackTrace: stack);

    // Record to Crashlytics with additional context
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal: false,
      information: [
        'Endpoint: ${endpoint ?? 'unknown'}',
        'Method: ${method ?? 'unknown'}',
        'Status Code: ${statusCode ?? 'unknown'}',
      ],
    );
  }

  /// Handle authentication errors
  static void handleAuthError(
    Object error,
    StackTrace stack, {
    String? userId,
    String? action,
  }) {
    final handler = GlobalErrorHandler();
    final errorMessage = 'Auth Error: $error';

    handler._log.error(errorMessage,
        service: handler._serviceName, error: error, stackTrace: stack);

    // Record to Crashlytics with additional context
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal: false,
      information: [
        'User ID: ${userId ?? 'unknown'}',
        'Action: ${action ?? 'unknown'}',
      ],
    );
  }

  /// Handle database errors
  static void handleDatabaseError(
    Object error,
    StackTrace stack, {
    String? operation,
    String? table,
  }) {
    final handler = GlobalErrorHandler();
    final errorMessage = 'Database Error: $error';

    handler._log.error(errorMessage,
        service: handler._serviceName, error: error, stackTrace: stack);

    // Record to Crashlytics with additional context
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal: false,
      information: [
        'Operation: ${operation ?? 'unknown'}',
        'Table: ${table ?? 'unknown'}',
      ],
    );
  }

  /// Handle UI errors
  static void handleUIError(
    Object error,
    StackTrace stack, {
    String? screen,
    String? widget,
  }) {
    final handler = GlobalErrorHandler();
    final errorMessage = 'UI Error: $error';

    handler._log.error(errorMessage,
        service: handler._serviceName, error: error, stackTrace: stack);

    // Record to Crashlytics with additional context
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal: false,
      information: [
        'Screen: ${screen ?? 'unknown'}',
        'Widget: ${widget ?? 'unknown'}',
      ],
    );
  }

  /// Create error boundary widget
  static Widget createErrorBoundary({
    required Widget child,
    String? screen,
    Widget? fallback,
  }) {
    return ErrorBoundary(
      screen: screen,
      fallback: fallback,
      child: child,
    );
  }
}

/// Error boundary widget for catching widget errors
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? screen;
  final Widget? fallback;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.screen,
    this.fallback,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallback ?? _buildDefaultErrorWidget();
    }

    return widget.child;
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please try again or restart the app',
            textAlign: TextAlign.center,
          ),
          if (kDebugMode && _error != null) ...[
            const SizedBox(height: 16),
            Text(
              'Debug: $_error',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Set up error boundary
    FlutterError.onError = (FlutterErrorDetails details) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _error = details.exception;
        });
      }

      // Log the error
      GlobalErrorHandler.handleUIError(
        details.exception,
        details.stack ?? StackTrace.empty,
        screen: widget.screen,
      );
    };
  }
}
