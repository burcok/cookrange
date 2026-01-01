import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import 'log_service.dart';

/// Test class for timestamp handling in the new logs system
class TimestampTest {
  final FirestoreService _firestoreService = FirestoreService();
  final LogService _log = LogService();
  final String _serviceName = 'TimestampTest';

  /// Test timestamp handling in the new logs system
  Future<void> testTimestampHandling() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _log.error('No authenticated user found for testing',
            service: _serviceName);
        return;
      }

      _log.info('Testing timestamp handling for user: ${user.uid}',
          service: _serviceName);

      // Test login history with timestamp
      await _firestoreService.addLoginHistoryToLogs(user.uid, {
        'ip_address': '192.168.1.100',
        'device_model': 'iPhone 15 Pro',
        'device_type': 'mobile',
        'device_os': 'iOS 17.0',
        'app_version': '1.0.0',
        'build_number': '1',
        'test_timestamp': true,
      });

      _log.info('Login history with timestamp added successfully',
          service: _serviceName);

      // Test user activity with timestamp
      await _firestoreService.addUserActivityToLogs(user.uid, {
        'event_type': 'timestamp_test',
        'ip_address': '192.168.1.100',
        'device_model': 'iPhone 15 Pro',
        'device_type': 'mobile',
        'device_os': 'iOS 17.0',
        'app_version': '1.0.0',
        'build_number': '1',
        'test_timestamp': true,
      });

      _log.info('User activity with timestamp added successfully',
          service: _serviceName);

      // Test retrieving logs to verify timestamps
      final userLogs = await _firestoreService.getUserLogs(user.uid);
      if (userLogs != null) {
        _log.info('Successfully retrieved logs with timestamps:',
            service: _serviceName);
        _log.info('Login history entries: ${userLogs.loginHistory.length}',
            service: _serviceName);
        _log.info('User activity entries: ${userLogs.userActivity.length}',
            service: _serviceName);

        // Check if timestamps are present
        if (userLogs.loginHistory.isNotEmpty) {
          final latestLogin = userLogs.loginHistory.first;
          _log.info('Latest login timestamp: ${latestLogin.timestamp}',
              service: _serviceName);
        }

        if (userLogs.userActivity.isNotEmpty) {
          final latestActivity = userLogs.userActivity.first;
          _log.info('Latest activity timestamp: ${latestActivity.timestamp}',
              service: _serviceName);
        }
      } else {
        _log.error('Failed to retrieve user logs', service: _serviceName);
      }

      _log.info('Timestamp handling test completed successfully',
          service: _serviceName);
    } catch (e, s) {
      _log.error('Error testing timestamp handling',
          service: _serviceName, error: e, stackTrace: s);
    }
  }
}
