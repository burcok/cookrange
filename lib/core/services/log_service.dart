import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LogService {
  static final Logger _logger = Logger('CookrangeApp');

  // Singleton pattern for consistent access
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

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

  /// Logs a user activity to Firestore `user_logs` collection.
  Future<void> logActivity(String eventType, Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final activityItem = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'event_type': eventType,
        'timestamp': FieldValue.serverTimestamp(),
        'user_id': user.uid,
        ...data,
      };

      await _firestore
          .collection('user_logs')
          .doc(user.uid)
          .collection('user_activity')
          .add(activityItem);

      info('User Activity: $eventType', service: 'ActivityLog');
    } catch (e, stack) {
      error('Failed to log activity',
          service: 'ActivityLog', error: e, stackTrace: stack);
    }
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
