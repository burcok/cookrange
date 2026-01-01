import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import 'log_service.dart';

/// Test class for the new logs system
class LogMigrationTest {
  final FirestoreService _firestoreService = FirestoreService();
  final LogService _log = LogService();
  final String _serviceName = 'LogMigrationTest';

  /// Test the new logs system by creating sample data
  Future<void> testNewLogsSystem() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _log.error('No authenticated user found for testing',
            service: _serviceName);
        return;
      }

      _log.info('Testing new logs system for user: ${user.uid}',
          service: _serviceName);

      // Test login history logging
      await _firestoreService.addLoginHistoryToLogs(user.uid, {
        'ip_address': '192.168.1.100',
        'device_model': 'iPhone 15 Pro',
        'device_type': 'mobile',
        'device_os': 'iOS 17.0',
        'app_version': '1.0.0',
        'build_number': '1',
        'test_entry': true,
      });

      // Test user activity logging
      await _firestoreService.addUserActivityToLogs(user.uid, {
        'event_type': 'app_opened',
        'ip_address': '192.168.1.100',
        'device_model': 'iPhone 15 Pro',
        'device_type': 'mobile',
        'device_os': 'iOS 17.0',
        'app_version': '1.0.0',
        'build_number': '1',
        'test_entry': true,
      });

      // Test retrieving logs
      final userLogs = await _firestoreService.getUserLogs(user.uid);
      if (userLogs != null) {
        _log.info('Successfully retrieved logs:', service: _serviceName);
        _log.info('Login history entries: ${userLogs.loginHistory.length}',
            service: _serviceName);
        _log.info('User activity entries: ${userLogs.userActivity.length}',
            service: _serviceName);
      } else {
        _log.error('Failed to retrieve user logs', service: _serviceName);
      }

      _log.info('New logs system test completed successfully',
          service: _serviceName);
    } catch (e, s) {
      _log.error('Error testing new logs system',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Test migration from old sub-collection system to new logs system
  Future<void> testMigration() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _log.error('No authenticated user found for migration testing',
            service: _serviceName);
        return;
      }

      _log.info('Testing migration for user: ${user.uid}',
          service: _serviceName);

      // Run migration
      await _firestoreService.migrateUserLogsToNewSystem(user.uid);

      // Verify migration by retrieving logs
      final userLogs = await _firestoreService.getUserLogs(user.uid);
      if (userLogs != null) {
        _log.info('Migration test completed successfully:',
            service: _serviceName);
        _log.info(
            'Migrated login history entries: ${userLogs.loginHistory.length}',
            service: _serviceName);
        _log.info(
            'Migrated user activity entries: ${userLogs.userActivity.length}',
            service: _serviceName);
      } else {
        _log.error('Migration test failed - no logs found',
            service: _serviceName);
      }
    } catch (e, s) {
      _log.error('Error testing migration',
          service: _serviceName, error: e, stackTrace: s);
    }
  }
}
