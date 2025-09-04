import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/device_info_provider.dart';
import 'log_service.dart';
import '../models/user_profile_model.dart';
import '../models/user_model.dart';
import '../models/login_history_model.dart';
import '../models/user_activity_model.dart';

/// A service dedicated to all Firestore interactions related to user data.
/// This centralization allows for easier management, logging, and implementation
/// of data integrity checks (middleware).
class FirestoreService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final LogService _log = LogService();
  final String _serviceName = 'FirestoreService';

  // Singleton pattern
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // --- PRIVATE UTILITIES ---

  /// Fetches the public IP address of the user.
  Future<String> _getIpAddress() async {
    try {
      final response =
          await http.get(Uri.parse('https://api.ipify.org?format=json'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['ip'] ?? '0.0.0.0';
      }
    } catch (e) {
      _log.error('Failed to get IP address', service: _serviceName, error: e);
    }
    return '0.0.0.0';
  }

  /// Gathers device information into a map.
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoProvider();
    await deviceInfo.initialize();
    return {
      'device_model': deviceInfo.deviceModel,
      'device_type': deviceInfo.deviceType,
      'device_os': deviceInfo.deviceOs,
      'app_version': deviceInfo.appVersion,
      'build_number': deviceInfo.buildNumber,
    };
  }

  // --- PUBLIC API ---

  /// A centralized logger for various user activities.
  /// Events like 'logout', 'password_changed', etc., are logged here.
  Future<void> logUserActivity(String userId, String eventType,
      {Map<String, dynamic>? extraData}) async {
    _log.info('Attempting to log activity: $eventType for user: $userId',
        service: _serviceName);
    try {
      final ipAddress = await _getIpAddress();
      final deviceInfo = await _getDeviceInfo();

      final Map<String, dynamic> logData = {
        'event_type': eventType,
        'timestamp': FieldValue.serverTimestamp(),
        'ip_address': ipAddress,
        ...deviceInfo,
      };

      if (extraData != null) {
        logData.addAll(extraData);
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('user_activity')
          .add(logData);
      _log.info('Successfully logged activity: $eventType for user: $userId',
          service: _serviceName);
    } catch (e, s) {
      _log.error('Error logging user activity ($eventType) for user $userId',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Handles user document creation or update upon a successful login.
  /// Also logs every successful login to a dedicated history collection.
  Future<void> handleUserLogin(User user) async {
    _log.info('Handling login for user: ${user.uid}', service: _serviceName);
    try {
      final ipAddress = await _getIpAddress();
      final deviceInfoMap = await _getDeviceInfo();

      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      final loginData = {
        'last_login_at': FieldValue.serverTimestamp(),
        'last_active_at': FieldValue.serverTimestamp(),
        'last_login_ip': ipAddress,
        'last_login_device': deviceInfoMap['device_model'],
        'last_login_device_type': deviceInfoMap['device_type'],
        'last_login_device_model': deviceInfoMap['device_model'],
        'last_login_device_os': deviceInfoMap['device_os'],
        'app_version': deviceInfoMap['app_version'],
        'build_number': deviceInfoMap['build_number'],
      };

      if (!userDoc.exists) {
        // Create user document for a new user
        await userDocRef.set({
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'created_at': FieldValue.serverTimestamp(),
          'onboarding_completed': false,
          ...loginData,
        });
        _log.info('New user document created for: ${user.uid}',
            service: _serviceName);
      } else {
        // Update last login info for an existing user
        await userDocRef.update(loginData);
        _log.info('User document updated for: ${user.uid}',
            service: _serviceName);
      }

      // Middleware call to ensure data integrity after login/creation.
      // This can be run without awaiting to avoid blocking the login flow.
      verifyAndRepairUserData(user.uid);

      // Add to login history for both new and existing users
      await userDocRef.collection('login_history').add({
        'timestamp': FieldValue.serverTimestamp(),
        'ip_address': ipAddress,
        ...deviceInfoMap
      });
      _log.info('Login history added for user: ${user.uid}',
          service: _serviceName);
    } catch (e, s) {
      _log.error('Error handling user login for ${user.uid}',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Creates a user document during the initial registration process.
  Future<void> createUserDocumentOnRegister(
      User user, Map<String, dynamic>? onboardingData) async {
    _log.info('Creating user document on register for: ${user.uid}',
        service: _serviceName);
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'onboarding_completed': onboardingData != null,
        'onboarding_data': onboardingData,
        'created_at': FieldValue.serverTimestamp(),
        'last_login_at': FieldValue.serverTimestamp(),
        'user_verified': false,
      });
      _log.info('Successfully created user document for: ${user.uid}',
          service: _serviceName);
    } catch (e, s) {
      _log.error('Error creating user document for ${user.uid}',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Logs a failed login attempt to a root collection for security monitoring.
  Future<void> logFailedLogin(String email, String errorCode) async {
    _log.info('Logging failed login attempt for email: $email',
        service: _serviceName);
    try {
      final ipAddress = await _getIpAddress();
      final deviceInfo = await _getDeviceInfo();
      await _firestore.collection('failed_login_attempts').add({
        'email': email,
        'error_code': errorCode,
        'timestamp': FieldValue.serverTimestamp(),
        'ip_address': ipAddress,
        ...deviceInfo,
      });
      _log.info('Successfully logged failed login for email: $email',
          service: _serviceName);
    } catch (e, s) {
      _log.error('Error logging failed login for $email',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Retrieves user data from Firestore and converts it to a UserModel.
  Future<UserModel?> getUserData(String uid) async {
    _log.info('Getting user data for uid: $uid', service: _serviceName);
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _log.info('Successfully retrieved user data for uid: $uid',
            service: _serviceName);
        return UserModel.fromFirestore(doc);
      }
      _log.warning('User document not found for uid: $uid',
          service: _serviceName);
      return null;
    } catch (e, s) {
      _log.error('Error getting user data for $uid',
          service: _serviceName, error: e, stackTrace: s);
      return null;
    }
  }

  /// Updates a user's document with the provided data.
  /// Handles special cases, like logging onboarding completion.
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    _log.info('Updating user data for uid: $uid with data: $data',
        service: _serviceName);
    try {
      // Middleware-like check: If onboarding is being completed, log it.
      if (data['onboarding_completed'] == true) {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists && doc.data()?['onboarding_completed'] != true) {
          data['onboarding_completed_at'] = FieldValue.serverTimestamp();
          await logUserActivity(uid, 'onboarding_completed');
          _log.info('Onboarding completion logged for user: $uid',
              service: _serviceName);
        }
      }
      await _firestore
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));
      _log.info('Successfully updated user data for uid: $uid',
          service: _serviceName);
    } catch (e, s) {
      _log.error('Error updating user data for $uid',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Updates the user's verification status in Firestore.
  Future<void> updateUserEmailVerification(String uid) async {
    _log.info('Updating email verification for user: $uid',
        service: _serviceName);
    try {
      await _firestore.collection('users').doc(uid).update({
        'user_verified': FieldValue.serverTimestamp(),
      });
      _log.info('Successfully updated email verification for user: $uid',
          service: _serviceName);
    } catch (e, s) {
      _log.error('Error updating email verification for $uid',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Updates only the last_active_at timestamp for a user.
  /// This is useful for tracking activity when the app is resumed.
  Future<void> updateUserLastActiveTimestamp(String uid) async {
    _log.info('Updating last_active_at for user: $uid', service: _serviceName);
    try {
      await _firestore.collection('users').doc(uid).update({
        'last_active_at': FieldValue.serverTimestamp(),
      });
    } catch (e, s) {
      // This is a non-critical update, so we'll just log the error
      // without rethrowing to avoid any potential impact on app startup.
      _log.error('Error updating last_active_at for user $uid',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Updates the online status of a user.
  Future<void> updateUserOnlineStatus(String uid, bool isOnline) async {
    _log.info('Setting online status for user $uid to: $isOnline',
        service: _serviceName);
    try {
      await _firestore.collection('users').doc(uid).update({
        'is_online': isOnline,
      });
    } catch (e, s) {
      _log.error('Error updating online status for user $uid',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Retrieves the complete profile for a user, including sub-collections.
  Future<UserProfile?> getFullUserProfile(String uid) async {
    _log.info('Getting full user profile for uid: $uid', service: _serviceName);
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        _log.warning('User document not found for uid: $uid',
            service: _serviceName);
        return null;
      }

      // Fetch sub-collections in parallel
      final results = await Future.wait([
        userDocRef
            .collection('login_history')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .get(),
        userDocRef
            .collection('user_activity')
            .orderBy('timestamp', descending: true)
            .limit(100)
            .get(),
      ]);

      final loginHistorySnapshot =
          results[0] as QuerySnapshot<Map<String, dynamic>>;
      final userActivitySnapshot =
          results[1] as QuerySnapshot<Map<String, dynamic>>;

      final userModel = UserModel.fromFirestore(userDoc);

      final loginHistory = loginHistorySnapshot.docs
          .map((doc) => LoginHistoryItem.fromFirestore(doc))
          .toList();

      final userActivity = userActivitySnapshot.docs
          .map((doc) => UserActivityItem.fromFirestore(doc))
          .toList();

      _log.info('Successfully retrieved full profile for uid: $uid',
          service: _serviceName);
      return UserProfile(
        user: userModel,
        loginHistory: loginHistory,
        userActivity: userActivity,
      );
    } catch (e, s) {
      _log.error('Error getting full user profile for $uid',
          service: _serviceName, error: e, stackTrace: s);
      return null;
    }
  }

  /// Finds a user document by their email address.
  Future<DocumentSnapshot?> findUserByEmail(String email) async {
    _log.info('Finding user by email: $email', service: _serviceName);
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        _log.info('Found user for email: $email', service: _serviceName);
        return querySnapshot.docs.first;
      }
      _log.warning('No user found for email: $email', service: _serviceName);
      return null;
    } catch (e, s) {
      _log.error('Error finding user by email $email',
          service: _serviceName, error: e, stackTrace: s);
      return null;
    }
  }

  /// Middleware function to verify and repair user data.
  /// Checks for essential fields and adds them with default values if missing.
  Future<void> verifyAndRepairUserData(String uid) async {
    _log.info('Verifying and repairing data for user: $uid',
        service: _serviceName);
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        _log.warning(
            "User document does not exist for uid: $uid. Cannot repair.");
        return;
      }

      final data = userDoc.data()!;
      final Map<String, dynamic> updates = {};

      // Example check: Ensure 'created_at' exists
      if (data['created_at'] == null) {
        updates['created_at'] =
            FieldValue.serverTimestamp(); // Or a default past date
      }

      // Example check: Ensure 'last_active_at' exists
      if (data['last_active_at'] == null) {
        updates['last_active_at'] =
            data['last_login_at'] ?? FieldValue.serverTimestamp();
      }

      // Example check: Ensure 'onboarding_completed' flag exists
      if (data['onboarding_completed'] == null) {
        updates['onboarding_completed'] = false;
      }

      if (updates.isNotEmpty) {
        _log.warning('Repairing user document for $uid with updates: $updates',
            service: _serviceName);
        await userDocRef.update(updates);
        _log.info('Successfully repaired data for user: $uid',
            service: _serviceName);
      } else {
        _log.info('No data repair needed for user: $uid',
            service: _serviceName);
      }
    } catch (e, s) {
      _log.error('Error repairing data for user $uid',
          service: _serviceName, error: e, stackTrace: s);
    }
  }
}
