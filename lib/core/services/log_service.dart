import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

class LogService {
  static final Logger _logger = Logger('CookrangeApp');

  // Singleton pattern for consistent access
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  void setup() {
    // Configure logging levels based on build mode
    Logger.root.level = kDebugMode ? Level.ALL : Level.WARNING;
    
    Logger.root.onRecord.listen((record) {
      // Only log in debug mode or for important messages
      if (kDebugMode || record.level >= Level.WARNING) {
        debugPrint(
            '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');

        // Include error and stack trace if present
        if (record.error != null) {
          debugPrint('Error: ${record.error}');
        }
        if (record.stackTrace != null) {
          debugPrint('Stack Trace: ${record.stackTrace}');
        }
      }
    });
  }

  void info(String message, {String? service}) {
    _logger.info('${_formatService(service)}$message');
  }

  void warning(String message, {String? service, Object? error}) {
    _logger.warning('${_formatService(service)}$message', error);
  }

  void error(String message,
      {String? service, Object? error, StackTrace? stackTrace}) {
    _logger.severe('${_formatService(service)}$message', error, stackTrace);
  }

  String _formatService(String? service) {
    return service != null ? '[$service] ' : '';
  }
}
