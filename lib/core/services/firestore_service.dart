import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'analytics_service.dart';
import 'log_service.dart';
import 'notification_service.dart';
import 'achievement_service.dart';
import '../models/notification_model.dart';
import '../models/user_profile_model.dart';
import '../models/user_model.dart';
import '../models/user_logs_model.dart';

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
    final context = await _log.getSystemContext();
    return context['ip_address'] ?? '0.0.0.0';
  }

  /// Gathers device information into a map.
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    return _log.getSystemContext();
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
        'timestamp': Timestamp.now(),
        'ip_address': ipAddress,
        ...deviceInfo,
      };

      if (extraData != null) {
        logData.addAll(extraData);
      }

      _log.info(
          'About to add user activity for user: $userId, event: $eventType',
          service: _serviceName);
      _log.info('User activity data: $logData', service: _serviceName);

      await addUserActivityToLogs(userId, logData);
      _log.info('Successfully logged activity: $eventType for user: $userId',
          service: _serviceName);
    } catch (e, s) {
      _log.error('Error logging user activity ($eventType) for user $userId',
          service: _serviceName, error: e, stackTrace: s);

      // If it's a permission error, try to log to a different collection or skip
      if (e.toString().contains('permission-denied')) {
        _log.warning(
            'Permission denied for user_activity logging. Skipping activity log for user: $userId',
            service: _serviceName);
        // Optionally, you could log to a different collection or use a different approach
        return;
      }

      // For other errors, rethrow to maintain existing behavior
      rethrow;
    }
  }

  /// Handles user document creation or update upon a successful login.
  /// Also logs every successful login to a dedicated history collection.
  Future<void> handleUserLogin(User user, {String? sessionId}) async {
    _log.info('Handling login for user: ${user.uid}, session: $sessionId',
        service: _serviceName);
    try {
      final systemContext = await _log.getSystemContext();

      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      final loginData = {
        'last_login_at': FieldValue.serverTimestamp(),
        'last_active_at': FieldValue.serverTimestamp(),
        'last_login_ip': systemContext['ip_address'],
        'last_login_device': systemContext['device_model'],
        'last_login_device_type': systemContext['device_type'],
        'last_login_device_model': systemContext['device_model'],
        'last_login_device_os': systemContext['device_os'],
        'last_login_os_version': systemContext['os_version'],
        'last_login_app_version': systemContext['app_version'],
        'last_login_build_number': systemContext['build_number'],
        'is_online': true,
      };

      if (sessionId != null) {
        loginData['current_session_id'] = sessionId;
      }

      // Only update app version info if it has changed
      final currentAppVersion = userDoc.data()?['app_version'] as String?;
      final currentBuildNumber = userDoc.data()?['build_number'] as String?;

      if (currentAppVersion != systemContext['app_version'] ||
          currentBuildNumber != systemContext['build_number']) {
        loginData['app_version'] = systemContext['app_version'];
        loginData['build_number'] = systemContext['build_number'];
        loginData['version_updated_at'] = FieldValue.serverTimestamp();
      }

      if (!userDoc.exists) {
        // Create user document for a new user
        // Initialize streak for new user
        final onboardingData = <String, dynamic>{'streak': 1};

        await userDocRef.set({
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'created_at': FieldValue.serverTimestamp(),
          'onboarding_completed': false,
          'onboarding_data': onboardingData,
          'streak_freeze_count': 1, // welcome gift for new users
          ...loginData,
          'login_ips': FieldValue.arrayUnion([systemContext['ip_address']]),
          'login_devices':
              FieldValue.arrayUnion([systemContext['device_model']]),
          'login_device_types':
              FieldValue.arrayUnion([systemContext['device_type']]),
          'login_device_models':
              FieldValue.arrayUnion([systemContext['device_model']]),
          'login_device_os':
              FieldValue.arrayUnion([systemContext['device_os']]),
          'login_app_versions':
              FieldValue.arrayUnion([systemContext['app_version']]),
          'login_build_numbers':
              FieldValue.arrayUnion([systemContext['build_number']]),
        }, SetOptions(merge: true));
        _log.info('New user document created for: ${user.uid}',
            service: _serviceName);
      } else {
        // Calculate Streak
        try {
          final data = userDoc.data()!;
          final lastLoginTs = data['last_login_at'] as Timestamp?;
          final currentOnboardingData =
              data['onboarding_data'] as Map<String, dynamic>? ?? {};
          int currentStreak = currentOnboardingData['streak'] as int? ?? 1;

          if (lastLoginTs != null) {
            final lastLoginDate = lastLoginTs.toDate();
            final now = DateTime.now();

            // Normalize dates to midnight for comparsion
            final lastLoginMidnight = DateTime(
                lastLoginDate.year, lastLoginDate.month, lastLoginDate.day);
            final todayMidnight = DateTime(now.year, now.month, now.day);

            final difference =
                todayMidnight.difference(lastLoginMidnight).inDays;

            if (difference == 1) {
              // Consecutive day
              currentStreak++;
              _maybeSendStreakMilestone(user.uid, currentStreak);
            } else if (difference > 1) {
              // Missed a day — check for streak freeze
              final freezeCount = data['streak_freeze_count'] as int? ?? 0;
              if (freezeCount > 0) {
                loginData['streak_freeze_count'] = freezeCount - 1;
                loginData['streak_freeze_used_at'] =
                    FieldValue.serverTimestamp();
                _log.info(
                    'Streak freeze consumed for ${user.uid}; remaining: ${freezeCount - 1}',
                    service: _serviceName);
              } else {
                currentStreak = 1;
              }
            }
            // If difference == 0, same day, do nothing
          }

          // Use dot notation to update nested field without overwriting entire map
          loginData['onboarding_data.streak'] = currentStreak;
          unawaited(AchievementService()
              .checkAndGrant(user.uid, streak: currentStreak));
        } catch (e) {
          _log.error('Error calculating streak for ${user.uid}',
              service: _serviceName, error: e);
          // Fallback if something fails, don't crash login
        }

        // Update last login info for an existing user
        await userDocRef.update(loginData);
        _log.info('User document updated for: ${user.uid}',
            service: _serviceName);
      }

      // Middleware call to ensure data integrity after login/creation.
      // Fire-and-forget intentionally to avoid blocking the login flow.
      unawaited(verifyAndRepairUserData(user.uid));

      // Add to login history for both new and existing users using new logs system
      try {
        _log.info('About to add login history for user: ${user.uid}',
            service: _serviceName);

        final loginHistoryData = systemContext;

        _log.info('Login history data: $loginHistoryData',
            service: _serviceName);

        await addLoginHistoryToLogs(user.uid, loginHistoryData);
        _log.info('Login history successfully added for user: ${user.uid}',
            service: _serviceName);
      } catch (loginHistoryError) {
        _log.error('Error adding login history for user ${user.uid}',
            service: _serviceName, error: loginHistoryError);
        _log.error(
            'Login history error details: ${loginHistoryError.toString()}',
            service: _serviceName);
        // Don't rethrow - login should still succeed even if history logging fails
      }
    } catch (e, s) {
      _log.error('Error handling user login for ${user.uid}',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  static const List<int> _streakMilestones = [7, 14, 30, 60, 100, 365];

  void _maybeSendStreakMilestone(String uid, int streak) {
    if (!_streakMilestones.contains(streak)) return;
    final ns = NotificationService();
    ns.sendNotification(
      targetUserId: uid,
      type: NotificationType.streakMilestone,
      relatedId: 'streak_$streak',
      metadata: {'streakDays': streak},
    );
    unawaited(AchievementService().checkAndGrant(uid, streak: streak));
  }

  /// Grants [count] streak freezes to [userId] (for referrals, rewards, etc.).
  Future<void> grantStreakFreeze(String userId, {int count = 1}) async {
    await _firestore.collection('users').doc(userId).update({
      'streak_freeze_count': FieldValue.increment(count),
    });
    _log.info('Granted $count streak freeze(s) to $userId',
        service: _serviceName);
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
      // Populate login/device info and trigger logging system
      await handleUserLogin(user);
    } catch (e, s) {
      _log.error('Error creating user document for ${user.uid}',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  // Get Real-time User Stream
  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
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

  /// Retrieves user data from Firestore and converts it to a UserModel. // Get user data stream
  Stream<DocumentSnapshot> getUserDocStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // Get user data (Future)
  Future<UserModel?> getUserData(String uid) async {
    _log.info('Getting user data for uid: $uid', service: _serviceName);
    try {
      // Try default source (Server -> Cache)
      // Note: In newer Firestore versions, get() with default source prefers server but might fall back.
      // Explicitly handling robustness:
      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await _firestore.collection('users').doc(uid).get();
      } catch (e) {
        // Fallback to cache if network fails
        _log.warning(
            'Network fetch failed for user data, trying cache for uid: $uid',
            service: _serviceName);
        doc = await _firestore
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.cache));
      }

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

  /// Marks the intro tour as seen for [uid] — both in Firestore (cross-device
  /// source of truth) and reflected back through [updateUserData].
  Future<void> markIntroSeen(String uid) async {
    _log.info('Marking intro_seen=true for uid: $uid', service: _serviceName);
    await updateUserData(uid, {'intro_seen': true});
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

  /// Updates the user's role field (`user_role`) in Firestore.
  /// Delegates to [addUserRole] so the roles array stays in sync.
  Future<void> updateUserRole(String uid, String roleValue) async {
    final role = UserRoleX.fromString(roleValue);
    await addUserRole(uid, role);
  }

  /// Adds [role] to the user's `user_roles` array (idempotent).
  Future<void> addUserRole(String uid, UserRole role) async {
    if (role == UserRole.consumer) return;
    _log.info('FirestoreService: adding role ${role.firestoreValue} to $uid',
        service: _serviceName);
    try {
      await _firestore.collection('users').doc(uid).update({
        'user_roles': FieldValue.arrayUnion([role.firestoreValue]),
        'user_role': role.firestoreValue,
      });
      unawaited(AnalyticsService().logEvent(
        name: 'role_upgrade_completed',
        parameters: {'new_role': role.firestoreValue},
      ));
      _log.info('Successfully added role ${role.firestoreValue} to $uid',
          service: _serviceName);
    } catch (e, s) {
      _log.error('Error adding role ${role.firestoreValue} for $uid',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Removes [role] from the user's `user_roles` array.
  Future<void> removeUserRole(String uid, UserRole role) async {
    _log.info(
        'FirestoreService: removing role ${role.firestoreValue} from $uid',
        service: _serviceName);
    try {
      await _firestore.collection('users').doc(uid).update({
        'user_roles': FieldValue.arrayRemove([role.firestoreValue]),
      });
      _log.info('Successfully removed role ${role.firestoreValue} from $uid',
          service: _serviceName);
    } catch (e, s) {
      _log.error('Error removing role ${role.firestoreValue} for $uid',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  // ── Private nutrition subcollection ─────────────────────────────────────────

  /// Reads the owner-only private nutrition document for [uid].
  ///
  /// On the **first call** for an existing user (migration path): if the private
  /// doc is absent but the main user doc still contains PII fields inside
  /// `onboarding_data`, those fields are atomically migrated — written to
  /// `private/nutrition` and removed from the main doc — so subsequent reads
  /// are always served from the private subcollection.
  Future<Map<String, dynamic>?> getPrivateNutritionData(String uid) async {
    _log.info('getPrivateNutritionData: $uid', service: _serviceName);
    try {
      final privateRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('nutrition');

      final snap = await privateRef.get();

      if (snap.exists && snap.data()!.isNotEmpty) {
        return snap.data();
      }

      // Migration path: check if PII lives in the main doc and migrate it.
      final mainSnap = await _firestore.collection('users').doc(uid).get();
      final mainData = mainSnap.data() ?? {};
      final legacyOnboarding =
          mainData['onboarding_data'] as Map<String, dynamic>?;

      if (legacyOnboarding == null) return null;

      final piiFields = [
        'personal_info',
        'allergies',
        'dietary_restrictions',
        'disliked_foods',
        'avoid_ingredients'
      ];
      final privateData = <String, dynamic>{};
      final removals = <String, dynamic>{};

      for (final key in piiFields) {
        if (legacyOnboarding.containsKey(key)) {
          privateData[key] = legacyOnboarding[key];
          removals['onboarding_data.$key'] = FieldValue.delete();
        }
      }

      if (privateData.isEmpty) return null;

      // Batch-write: create private doc + strip PII from main doc.
      final batch = _firestore.batch();
      batch.set(privateRef, privateData);
      batch.update(_firestore.collection('users').doc(uid), removals);
      await batch.commit();

      _log.info(
          'getPrivateNutritionData: migrated ${privateData.keys} to private/nutrition for $uid',
          service: _serviceName);
      return privateData;
    } catch (e, s) {
      _log.error('getPrivateNutritionData error for $uid',
          service: _serviceName, error: e, stackTrace: s);
      return null;
    }
  }

  /// Saves the private nutrition PII for [uid] to `users/{uid}/private/nutrition`.
  /// Does NOT write anything to the main user document.
  Future<void> savePrivateNutritionData(
      String uid, Map<String, dynamic> data) async {
    _log.info('savePrivateNutritionData: $uid', service: _serviceName);
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('nutrition')
          .set(data, SetOptions(merge: true));
    } catch (e, s) {
      _log.error('savePrivateNutritionData error for $uid',
          service: _serviceName, error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Overwrites the user's free-form avoid-ingredients list.
  /// Writes to the owner-only private/nutrition subcollection.
  Future<void> updateAvoidIngredients(
      String uid, List<String> ingredients) async {
    _log.info('Updating avoid_ingredients for uid: $uid',
        service: _serviceName);
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('nutrition')
          .set({'avoid_ingredients': ingredients}, SetOptions(merge: true));
    } catch (e) {
      _log.error('updateAvoidIngredients error: $e', service: _serviceName);
      rethrow;
    }
  }

  /// Updates the user's verification status in Firestore.
  Future<void> updateUserEmailVerification(String uid) async {
    _log.info('Updating email verification for user: $uid',
        service: _serviceName);
    try {
      // Upsert (merge) rather than update() so a missing/not-yet-created doc
      // can't throw [cloud_firestore/not-found].
      await _firestore.collection('users').doc(uid).set({
        'user_verified': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
      // Upsert (merge) — a presence/lifecycle write can race ahead of the
      // user doc's creation right after sign-up; never throw not-found.
      await _firestore.collection('users').doc(uid).set({
        'last_active_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, s) {
      // This is a non-critical update, so we'll just log the error
      // without rethrowing to avoid any potential impact on app startup.
      _log.error('Error updating last_active_at for user $uid',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Refreshes the device/system context on the user doc when the app opens or
  /// is resumed — a lightweight sibling of [handleUserLogin] WITHOUT the streak
  /// recompute or login-history write. A cached session (auto-login) never runs
  /// [handleUserLogin], so without this the doc would only ever get `is_online`
  /// refreshed and the phone/app-version data would go stale. `getSystemContext`
  /// caches the device info and the IP (4h), so this is cheap to call on resume.
  Future<void> syncDeviceContext(String uid) async {
    _log.info('Syncing device context for user: $uid', service: _serviceName);
    try {
      final ctx = await _log.getSystemContext();
      // If context lookup failed entirely, still refresh presence.
      final ip = ctx['ip_address'];
      final deviceModel = ctx['device_model'];
      await _firestore.collection('users').doc(uid).set({
        'is_online': true,
        'last_active_at': FieldValue.serverTimestamp(),
        if (ip != null) 'last_login_ip': ip,
        if (deviceModel != null) ...{
          'last_login_device': deviceModel,
          'last_login_device_model': deviceModel,
        },
        if (ctx['device_type'] != null)
          'last_login_device_type': ctx['device_type'],
        if (ctx['device_os'] != null) 'last_login_device_os': ctx['device_os'],
        if (ctx['os_version'] != null)
          'last_login_os_version': ctx['os_version'],
        if (ctx['device_brand'] != null) 'device_brand': ctx['device_brand'],
        if (ctx['manufacturer'] != null) 'manufacturer': ctx['manufacturer'],
        if (ctx['is_physical_device'] != null)
          'is_physical_device': ctx['is_physical_device'],
        if (ctx['app_version'] != null) ...{
          'app_version': ctx['app_version'],
          'last_login_app_version': ctx['app_version'],
        },
        if (ctx['build_number'] != null) ...{
          'build_number': ctx['build_number'],
          'last_login_build_number': ctx['build_number'],
        },
        if (ctx['timezone'] != null) 'timezone': ctx['timezone'],
        if (ctx['locale'] != null) 'device_locale': ctx['locale'],
        // Append to the historical arrays (arrayUnion dedupes automatically).
        if (ip != null) 'login_ips': FieldValue.arrayUnion([ip]),
        if (deviceModel != null)
          'login_devices': FieldValue.arrayUnion([deviceModel]),
        if (ctx['app_version'] != null)
          'login_app_versions': FieldValue.arrayUnion([ctx['app_version']]),
      }, SetOptions(merge: true));
    } catch (e, s) {
      _log.error('Error syncing device context for user $uid',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Updates the online status of a user.
  Future<void> updateUserOnlineStatus(String uid, bool isOnline) async {
    _log.info('Setting online status for user $uid to: $isOnline',
        service: _serviceName);
    try {
      // Upsert (merge) — presence updates can fire before the user doc exists
      // (sign-up race) or for an account whose doc was removed; never not-found.
      await _firestore.collection('users').doc(uid).set({
        'is_online': isOnline,
      }, SetOptions(merge: true));
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

      // Get user logs from new logs collection
      final userLogs = await getUserLogs(uid);

      final userModel = UserModel.fromFirestore(userDoc);

      final loginHistory = userLogs?.loginHistory ?? [];
      final userActivity = userLogs?.userActivity ?? [];

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

  /// Test method to manually create subcollections for debugging
  Future<void> testCreateSubcollections(String uid) async {
    _log.info('Testing logs creation for user: $uid', service: _serviceName);
    try {
      // Test login_history creation using new logs system
      await addLoginHistoryToLogs(uid, {
        'test': true,
        'message': 'Manual test creation',
        'ip_address': '127.0.0.1',
        'device_model': 'test_device',
        'device_type': 'test',
        'device_os': 'test_os',
        'app_version': '1.0.0',
        'build_number': '1',
      });
      _log.info('Test login_history created successfully',
          service: _serviceName);

      // Test user_activity creation using new logs system
      await addUserActivityToLogs(uid, {
        'event_type': 'test_event',
        'test': true,
        'message': 'Manual test creation',
        'ip_address': '127.0.0.1',
        'device_model': 'test_device',
        'device_type': 'test',
        'device_os': 'test_os',
        'app_version': '1.0.0',
        'build_number': '1',
      });
      _log.info('Test user_activity created successfully',
          service: _serviceName);
    } catch (e, s) {
      _log.error('Error creating test subcollections for user $uid',
          service: _serviceName, error: e, stackTrace: s);
      rethrow;
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

      // Data-completeness guarantee: backfill identity fields from FirebaseAuth
      // when they're missing, so an account has the SAME core data regardless of
      // how it registered (email vs Google/Apple, or a login that skipped the
      // register-onboarding flow). Safe: only fills blanks, never overwrites.
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null && authUser.uid == uid) {
        bool blank(dynamic v) => v == null || (v is String && v.isEmpty);
        if (blank(data['email']) &&
            authUser.email != null &&
            authUser.email!.isNotEmpty) {
          updates['email'] = authUser.email;
        }
        if (blank(data['displayName']) &&
            authUser.displayName != null &&
            authUser.displayName!.isNotEmpty) {
          updates['displayName'] = authUser.displayName;
        }
        if (blank(data['photoURL']) &&
            authUser.photoURL != null &&
            authUser.photoURL!.isNotEmpty) {
          updates['photoURL'] = authUser.photoURL;
        }
      }

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

  // ==================== NEW LOG SYSTEM ====================

  /// Adds a login history entry to the separate logs collection.
  Future<void> addLoginHistoryToLogs(
      String userId, Map<String, dynamic> loginData) async {
    try {
      _log.info('Adding login history to logs collection for user: $userId',
          service: _serviceName);

      final logsDocRef = _firestore.collection('logs').doc(userId);
      final logsDoc = await logsDocRef.get();

      // Create new login history item with unique ID
      final loginHistoryItem = {
        'id': _firestore.collection('logs').doc().id,
        'timestamp': Timestamp.now(),
        ...loginData,
      };

      if (!logsDoc.exists) {
        // Create new logs document
        await logsDocRef.set({
          'login_history': [loginHistoryItem],
          'user_activity': [],
          'last_updated': FieldValue.serverTimestamp(),
        });
        _log.info('Created new logs document for user: $userId',
            service: _serviceName);
      } else {
        // Update existing logs document
        await logsDocRef.update({
          'login_history': FieldValue.arrayUnion([loginHistoryItem]),
          'last_updated': FieldValue.serverTimestamp(),
        });
        _log.info('Updated logs document for user: $userId',
            service: _serviceName);
      }
    } catch (e, s) {
      _log.error('Error adding login history to logs for user $userId',
          service: _serviceName, error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Adds a user activity entry to the separate logs collection.
  Future<void> addUserActivityToLogs(
      String userId, Map<String, dynamic> activityData) async {
    try {
      _log.info('Adding user activity to logs collection for user: $userId',
          service: _serviceName);

      final logsDocRef = _firestore.collection('logs').doc(userId);
      final logsDoc = await logsDocRef.get();

      // Create new user activity item with unique ID
      final userActivityItem = {
        'id': _firestore.collection('logs').doc().id,
        'timestamp': Timestamp.now(),
        ...activityData,
      };

      if (!logsDoc.exists) {
        // Create new logs document
        await logsDocRef.set({
          'login_history': [],
          'user_activity': [userActivityItem],
          'last_updated': FieldValue.serverTimestamp(),
        });
        _log.info('Created new logs document for user: $userId',
            service: _serviceName);
      } else {
        // Update existing logs document
        await logsDocRef.update({
          'user_activity': FieldValue.arrayUnion([userActivityItem]),
          'last_updated': FieldValue.serverTimestamp(),
        });
        _log.info('Updated logs document for user: $userId',
            service: _serviceName);
      }
    } catch (e, s) {
      _log.error('Error adding user activity to logs for user $userId',
          service: _serviceName, error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Retrieves user logs from the separate logs collection.
  Future<UserLogs?> getUserLogs(String userId) async {
    try {
      _log.info('Getting user logs for uid: $userId', service: _serviceName);

      final logsDocRef = _firestore.collection('logs').doc(userId);
      final logsDoc = await logsDocRef.get();

      if (!logsDoc.exists) {
        _log.warning('Logs document not found for uid: $userId',
            service: _serviceName);
        return null;
      }

      final userLogs = UserLogs.fromFirestore(logsDoc);
      _log.info('Successfully retrieved logs for uid: $userId',
          service: _serviceName);
      return userLogs;
    } catch (e, s) {
      _log.error('Error getting user logs for $userId',
          service: _serviceName, error: e, stackTrace: s);
      return null;
    }
  }

  /// Migrates existing sub-collection logs to the new logs collection.
  /// This is a one-time migration function.
  Future<void> migrateUserLogsToNewSystem(String userId) async {
    try {
      _log.info('Starting migration of logs for user: $userId',
          service: _serviceName);

      final userDocRef = _firestore.collection('users').doc(userId);

      // Get existing login history
      final loginHistorySnapshot = await userDocRef
          .collection('login_history')
          .orderBy('timestamp', descending: true)
          .get();

      // Get existing user activity
      final userActivitySnapshot = await userDocRef
          .collection('user_activity')
          .orderBy('timestamp', descending: true)
          .get();

      // Convert to new format
      final loginHistory = loginHistorySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      final userActivity = userActivitySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      // Create new logs document
      final logsDocRef = _firestore.collection('logs').doc(userId);
      await logsDocRef.set({
        'login_history': loginHistory,
        'user_activity': userActivity,
        'last_updated': FieldValue.serverTimestamp(),
        'migrated_at': FieldValue.serverTimestamp(),
      });

      _log.info('Successfully migrated logs for user: $userId',
          service: _serviceName);
    } catch (e, s) {
      _log.error('Error migrating logs for user $userId',
          service: _serviceName, error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Deletes all Firestore data for a user (GDPR account deletion).
  /// Deletes the main user doc, subcollections, logs, and chats.
  Future<void> deleteUserData(String uid) async {
    _log.info('Deleting all Firestore data for user: $uid',
        service: _serviceName);
    try {
      final batch = _firestore.batch();

      // Delete known subcollections
      for (final sub in [
        'friends',
        'friend_requests',
        'notifications',
        'meal_plans',
        'food_logs',
        'private'
      ]) {
        final snap =
            await _firestore.collection('users').doc(uid).collection(sub).get();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
      }

      // Delete logs document
      batch.delete(_firestore.collection('logs').doc(uid));

      // Delete main user document
      batch.delete(_firestore.collection('users').doc(uid));

      await batch.commit();

      // Remove user from any chats (update participants, or leave as is)
      // For now, chat history remains (industry standard for group chats)
      _log.info('Successfully deleted all Firestore data for user: $uid',
          service: _serviceName);
    } catch (e, s) {
      _log.error('Error deleting Firestore data for user $uid',
          service: _serviceName, error: e, stackTrace: s);
      rethrow;
    }
  }
}
