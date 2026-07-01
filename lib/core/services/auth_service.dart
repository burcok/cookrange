import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/analytics_service.dart';
import 'crashlytics_service.dart';
import 'firestore_service.dart';
import 'log_service.dart';
import '../models/user_model.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthException implements Exception {
  final String code;
  AuthException(this.code);

  @override
  String toString() => code;
}

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirestoreService _firestoreService = FirestoreService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final LogService _log = LogService();
  final String _serviceName = 'AuthService';

  static const String _languageKey = 'language_code';
  static const String _onboardingDataKey = 'onboarding_data';
  late SharedPreferences _prefs;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Cache for user data
  UserModel? _userDataCache;

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Initialize service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final String? savedLanguageCode = _prefs.getString(_languageKey);
      final String deviceLanguage =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;

      if (savedLanguageCode != null) {
        await _auth.setLanguageCode(savedLanguageCode);
      } else {
        await _auth.setLanguageCode(deviceLanguage);
      }
      _log.info('Language code set', service: _serviceName);
    } catch (e) {
      _log.error('Error setting language code',
          service: _serviceName, error: e);
    }
  }

  // Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.warning('hasCompletedOnboarding check failed: User is null.',
          service: _serviceName);
      return false;
    }
    _log.info('Checking onboarding status for user: ${user.uid}',
        service: _serviceName);
    try {
      final userData = await _firestoreService.getUserData(user.uid);
      final isCompleted = userData?.onboardingCompleted == true;
      _log.info('Onboarding status for user ${user.uid}: $isCompleted',
          service: _serviceName);
      return isCompleted;
    } catch (e, s) {
      _log.error('Error checking onboarding status for ${user.uid}',
          service: _serviceName, error: e, stackTrace: s);
      return false;
    }
  }

  // Save onboarding data
  Future<void> saveOnboardingData(Map<String, dynamic> data) async {
    await _prefs.setString(_onboardingDataKey, data.toString());
  }

  // Get onboarding data
  Future<Map<String, dynamic>?> getOnboardingData() async {
    final String? data = _prefs.getString(_onboardingDataKey);
    if (data == null || data.isEmpty) return null;

    // Defensive: this legacy cache stores a Map.toString(); a naive parse can
    // throw (RangeError) on nested/empty values. Never let it break sign-up.
    try {
      final mapEntries = data
          .replaceAll('{', '')
          .replaceAll('}', '')
          .split(',')
          .where((e) => e.contains(':'))
          .map((e) {
        final i = e.indexOf(':');
        return MapEntry(e.substring(0, i).trim(), e.substring(i + 1).trim());
      });
      return Map<String, dynamic>.from(Map.fromEntries(mapEntries));
    } catch (e) {
      _log.warning('getOnboardingData parse failed; ignoring stale cache: $e',
          service: _serviceName);
      return null;
    }
  }

  // Clear onboarding data
  Future<void> clearOnboardingData() async {
    await _prefs.remove(_onboardingDataKey);
  }

  // Session Management
  String? _currentSessionId;
  StreamSubscription<DocumentSnapshot>? _sessionSubscription;
  final Uuid _uuid = const Uuid();

  // Email & Password Login
  Future<User?> signInWithEmail(String email, String password) async {
    _log.info('Attempting to sign in with email: $email',
        service: _serviceName);
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      if (result.user == null) {
        // This case is unlikely as FirebaseAuth throws for user-not-found
        _log.error('Sign in failed: User object is null.',
            service: _serviceName);
        throw AuthException('user-not-found');
      }

      // Generate Session ID
      final sessionId = _uuid.v4();
      _currentSessionId = sessionId;

      // Delegate login handling to FirestoreService with Session ID
      _log.info(
          'About to call handleUserLogin for user: ${result.user!.uid}, session: $sessionId',
          service: _serviceName);
      await _firestoreService.handleUserLogin(result.user!,
          sessionId: sessionId);

      // Start Monitoring Session
      _startSessionMonitoring(result.user!.uid);

      unawaited(CrashlyticsService().setCustomKeys(userTier: 'free'));

      _log.info('Successfully signed in user: ${result.user!.uid}',
          service: _serviceName);
      return result.user;
    } on FirebaseAuthException catch (e) {
      _log.error('FirebaseAuthException during sign in for email: $email',
          service: _serviceName, error: e);
      // Log failed login attempt via FirestoreService
      await _firestoreService.logFailedLogin(email, e.code);
      throw AuthException(e.code);
    } catch (e, s) {
      _log.error('Unexpected error during sign in for $email',
          service: _serviceName, error: e, stackTrace: s);
      if (e is TypeError) {
        _log.error("Type error details: ${e.toString()}",
            service: _serviceName, error: e, stackTrace: s);
        throw AuthException('type-error');
      }
      throw AuthException('error-unknown');
    }
  }

  void _startSessionMonitoring(String uid) {
    _sessionSubscription?.cancel();
    _sessionSubscription =
        _firestoreService.getUserStream(uid).listen((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final remoteSessionId = data['current_session_id'] as String?;

      // If remote session ID exists and differs from local, log out
      if (remoteSessionId != null &&
          _currentSessionId != null &&
          remoteSessionId != _currentSessionId) {
        _log.warning('Session mismatch detected. Logging out.',
            service: _serviceName);
        _handleSessionMismatch();
      }
    });
  }

  void _handleSessionMismatch() {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    signOut();

    // Show Dialog
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title:
              Text(AppLocalizations.of(context).translate('auth.dialog_logged_out')),
          content: Text(AppLocalizations.of(context)
              .translate('auth.dialog_logged_out_message')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Ensure we are at login screen (usually handled by auth stream, but safe to force)
                // Navigator.of(context).pushReplacementNamed('/login');
              },
              child: Text(AppLocalizations.of(context).translate('common.ok')),
            ),
          ],
        ),
      );
    }
  }

  // Email & Password Register
  Future<User?> registerWithEmail(String email, String password) async {
    _log.info('Attempting to register with email: $email',
        service: _serviceName);
    try {
      final result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      if (result.user != null) {
        final onboardingData = await getOnboardingData();
        // Create user document via FirestoreService
        await _firestoreService.createUserDocumentOnRegister(
            result.user!, onboardingData);
        // Non-blocking: if the verification email fails (e.g. App Check not
        // configured for release, Dynamic Links missing on Android), the account
        // is still usable and the verify-email screen offers a resend button.
        try {
          await result.user?.sendEmailVerification();
        } catch (e) {
          _log.error('sendEmailVerification failed (non-blocking): $e',
              service: _serviceName);
        }
        _log.info('Successfully registered user: ${result.user!.uid}',
            service: _serviceName);
        return result.user;
      } else {
        _log.error('Registration failed: User object is null.',
            service: _serviceName);
        throw AuthException('user-creation-failed');
      }
    } on FirebaseAuthException catch (e) {
      _log.error('FirebaseAuthException during registration for $email',
          service: _serviceName, error: e);
      _log.error(
          "Firebase Auth Error during register: ${e.code} - ${e.message}",
          service: _serviceName);
      throw AuthException(e.code);
    } catch (e, s) {
      _log.error('Unexpected error during registration for $email',
          service: _serviceName, error: e, stackTrace: s);
      _log.error("Unexpected error during register: $e", service: _serviceName);
      if (e is TypeError) {
        _log.error("Type error details: ${e.toString()}",
            service: _serviceName, error: e, stackTrace: s);
      }
      throw AuthException('error-unknown');
    }
  }

  // Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    _log.info('Attempting to send password reset email to: $email',
        service: _serviceName);
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _log.info('Password reset email sent to: $email', service: _serviceName);
      // Log the password reset request
      final userDoc = await _firestoreService.findUserByEmail(email);

      if (userDoc != null) {
        await _firestoreService.logUserActivity(
            userDoc.id, 'password_reset_requested');
      } else {
        _log.warning(
            'Could not log password_reset_requested activity: user not found for email $email',
            service: _serviceName);
      }

      final time = DateTime.now();
      // No PII (email) in Analytics — Google policy forbids it and it is a
      // privacy leak. Track only the non-identifying event.
      unawaited(_analyticsService.logEvent(
        name: 'password_reset_request',
        parameters: {
          'time': time.toIso8601String(),
        },
      ));
    } catch (e, s) {
      _log.error('Error sending password reset email to $email',
          service: _serviceName, error: e, stackTrace: s);
      throw AuthException('error-unknown');
    }
  }

  // Send Email Verification
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      _log.info('Attempting to send email verification to: ${user.email}',
          service: _serviceName);
      try {
        await user.sendEmailVerification();

        final time = DateTime.now();
        // No PII (email) in Analytics.
        unawaited(_analyticsService.logEvent(
          name: 'send_email_verification',
          parameters: {
            'time': time.toIso8601String(),
          },
        ));
        _log.info('Email verification sent to: ${user.email}',
            service: _serviceName);
      } catch (e, s) {
        _log.error('Error sending email verification',
            service: _serviceName, error: e, stackTrace: s);
        throw AuthException('error-unknown');
      }
    }
  }

  // Google Sign-In
  Future<User?> signInWithGoogle() async {
    _log.info('Attempting Google Sign-In', service: _serviceName);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _log.warning('Google Sign-In was cancelled by user.',
            service: _serviceName);
        return null;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;

      if (user != null) {
        final sessionId = _uuid.v4();
        _currentSessionId = sessionId;

        // Delegate login handling to FirestoreService
        _log.info(
            'About to call handleUserLogin for Google user: ${user.uid}, session: $sessionId',
            service: _serviceName);
        await _firestoreService.handleUserLogin(user, sessionId: sessionId);

        _startSessionMonitoring(user.uid);
        unawaited(CrashlyticsService().setCustomKeys(userTier: 'free'));

        _log.info('Google Sign-In successful for user: ${user.uid}',
            service: _serviceName);
      } else {
        _log.warning('Google Sign-In was cancelled by user.',
            service: _serviceName);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      _log.error('FirebaseAuthException during Google Sign-In',
          service: _serviceName, error: e);
      _log.error("Sign in with google error: ${e.code}", service: _serviceName);
      throw AuthException(e.code);
    } catch (e, s) {
      _log.error('Unexpected error during Google Sign-In',
          service: _serviceName, error: e, stackTrace: s);
      _log.error("Unexpected error during Google sign in: $e",
          service: _serviceName);
      throw AuthException('error-unknown');
    }
  }

  // Sign Out
  Future<void> signOut() async {
    final user = _auth.currentUser;
    _log.info('Attempting to sign out user: ${user?.uid}',
        service: _serviceName);
    if (user != null) {
      // Update user's online status to false before logging out
      await _firestoreService.updateUserOnlineStatus(user.uid, false);
      await _firestoreService.logUserActivity(user.uid, 'logout');
    }

    // Cancel session monitoring
    await _sessionSubscription?.cancel();
    _sessionSubscription = null;

    try {
      await _googleSignIn.disconnect();
    } catch (e, s) {
      _log.error('Error during Google Sign-In disconnect',
          service: _serviceName, error: e, stackTrace: s);
    }

    await _auth.signOut();
    await clearOnboardingData();
    _userDataCache = null; // Clear cache on sign out
    _log.info('User ${user?.uid} signed out successfully.',
        service: _serviceName);
  }

  // Get Current User
  User? get currentUser => _auth.currentUser;

  // Listen to Auth State Changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get user data from Firestore
  /// Session-static flag: set true the moment the onboarding meal-plan step
  /// completes (generated OR skipped). RouteGuard's meal-plan gate honours this
  /// so a stale [_userDataCache] re-fetch can't bounce the user back into a
  /// regeneration loop before the `meal_plan_generated` write is observed.
  static bool mealPlanGatePassed = false;

  /// Drops the in-memory user cache so the next [getUserData] reads fresh from
  /// Firestore. Call after writing user-doc fields OUTSIDE AuthService (e.g. the
  /// meal-plan gate) so a re-fetch doesn't resurrect stale values.
  void invalidateUserCache() {
    _userDataCache = null;
  }

  Future<UserModel?> getUserData(String uid) async {
    _log.info('Getting user data for uid: $uid (from cache or service)',
        service: _serviceName);
    if (_userDataCache != null && _auth.currentUser?.uid == uid) {
      _log.info('Returning cached user data for uid: $uid',
          service: _serviceName);
      return _userDataCache;
    }
    final data = await _firestoreService.getUserData(uid);
    if (data != null) {
      _log.info('Caching new user data for uid: $uid', service: _serviceName);
      _userDataCache = data;
    }
    return data;
  }

  // Update user data in Firestore
  Future<void> updateUserData(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.error('Update user data failed: user is null.',
          service: _serviceName);
      return;
    }
    _log.info('Attempting to update user data for ${user.uid}',
        service: _serviceName);
    try {
      await _firestoreService.updateUserData(user.uid, data);
      _userDataCache = null; // Invalidate cache
      _log.info('Successfully updated user data for ${user.uid}',
          service: _serviceName);
    } catch (e, s) {
      _log.error('Error updating user data for ${user.uid}',
          service: _serviceName, error: e, stackTrace: s);
      throw AuthException('update-failed');
    }
  }

  // Verify user email
  Future<void> verifyUserEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.error('Verify user email failed: user is null.',
          service: _serviceName);
      return;
    }
    _log.info('Attempting to verify email for user: ${user.uid}',
        service: _serviceName);
    try {
      await _firestoreService.updateUserEmailVerification(user.uid);
      _userDataCache = null; // Invalidate cache
      _log.info('Successfully marked email as verified for ${user.uid}',
          service: _serviceName);
    } catch (e, s) {
      _log.error('Error verifying email for ${user.uid}',
          service: _serviceName, error: e, stackTrace: s);
      throw AuthException('verification-failed');
    }
  }

  // Update user email
  Future<void> updateEmail(String newEmail, String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.error('Update email failed: user is null.', service: _serviceName);
      throw AuthException('user-not-found');
    }
    _log.info('Attempting to update email for user: ${user.uid}',
        service: _serviceName);
    try {
      final cred =
          EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);

      final oldEmail = user.email;
      await user.verifyBeforeUpdateEmail(newEmail);

      await _firestoreService.logUserActivity(
        user.uid,
        'email_changed',
        extraData: {'old_email': oldEmail, 'new_email': newEmail},
      );
      _log.info('Successfully updated email for user: ${user.uid}',
          service: _serviceName);
    } on FirebaseAuthException catch (e) {
      _log.error('FirebaseAuthException while updating email for ${user.uid}',
          service: _serviceName, error: e);
      throw AuthException(e.code);
    } catch (e, s) {
      _log.error('Unexpected error while updating email for ${user.uid}',
          service: _serviceName, error: e, stackTrace: s);
      throw AuthException('error-unknown');
    }
  }

  // Update user password
  Future<void> updatePassword(
      String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.error('Update password failed: user is null.',
          service: _serviceName);
      throw AuthException('user-not-found');
    }
    _log.info('Attempting to update password for user: ${user.uid}',
        service: _serviceName);
    try {
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);

      await _firestoreService.logUserActivity(user.uid, 'password_changed');
      _log.info('Successfully updated password for user: ${user.uid}',
          service: _serviceName);
    } on FirebaseAuthException catch (e) {
      _log.error(
          'FirebaseAuthException while updating password for ${user.uid}',
          service: _serviceName,
          error: e);
      throw AuthException(e.code);
    } catch (e, s) {
      _log.error('Unexpected error while updating password for ${user.uid}',
          service: _serviceName, error: e, stackTrace: s);
      throw AuthException('error-unknown');
    }
  }

  Future<void> updateUserOnboardingData(Map<String, dynamic> data) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    await _firestoreService.updateUserData(
      currentUser.uid,
      data,
    );
  }

  // ─── Apple Sign-In ──────────────────────────────────────────────────────────

  /// Generates a cryptographically random nonce string for Apple Sign-In.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Sign in with Apple (iOS only for now; Android requires a web service).
  Future<User?> signInWithApple() async {
    _log.info('Attempting Apple Sign-In', service: _serviceName);
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final result = await _auth.signInWithCredential(oauthCredential);
      final user = result.user;

      if (user != null) {
        // Update display name from Apple credential if first sign-in
        final fullName = [
          appleCredential.givenName,
          appleCredential.familyName,
        ].where((s) => s != null && s.isNotEmpty).join(' ');

        if (fullName.isNotEmpty &&
            (user.displayName == null || user.displayName!.isEmpty)) {
          await user.updateDisplayName(fullName);
        }

        final sessionId = _uuid.v4();
        _currentSessionId = sessionId;
        await _firestoreService.handleUserLogin(user, sessionId: sessionId);
        _startSessionMonitoring(user.uid);
        unawaited(CrashlyticsService().setCustomKeys(userTier: 'free'));

        _log.info('Apple Sign-In successful for user: ${user.uid}',
            service: _serviceName);
      }

      return user;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        _log.warning('Apple Sign-In cancelled by user.', service: _serviceName);
        return null;
      }
      _log.error('Apple Sign-In error: ${e.message}',
          service: _serviceName, error: e);
      throw AuthException('apple-sign-in-failed');
    } on FirebaseAuthException catch (e) {
      _log.error('FirebaseAuthException during Apple Sign-In',
          service: _serviceName, error: e);
      throw AuthException(e.code);
    } catch (e, s) {
      _log.error('Unexpected error during Apple Sign-In',
          service: _serviceName, error: e, stackTrace: s);
      throw AuthException('error-unknown');
    }
  }

  // ─── Account Deletion (GDPR / App Store requirement) ───────────────────────

  /// Permanently deletes the user account and all associated Firestore data.
  /// Requires re-authentication for security.
  Future<void> deleteAccount({
    required String password,
    String? appleAuthCode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('user-not-found');

    _log.info('Attempting account deletion for user: ${user.uid}',
        service: _serviceName);

    try {
      // Re-authenticate before deletion
      if (user.providerData.any((p) => p.providerId == 'google.com')) {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) throw AuthException('cancelled');
        final googleAuth = await googleUser.authentication;
        final cred = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(cred);
      } else if (user.providerData.any((p) => p.providerId == 'apple.com')) {
        if (appleAuthCode == null) throw AuthException('reauth-required');
        final cred = OAuthProvider('apple.com').credential(
          idToken: appleAuthCode,
        );
        await user.reauthenticateWithCredential(cred);
      } else {
        // Email/password
        final email = user.email;
        if (email == null) throw AuthException('user-not-found');
        final cred =
            EmailAuthProvider.credential(email: email, password: password);
        await user.reauthenticateWithCredential(cred);
      }

      final uid = user.uid;

      // Complete, server-side erasure (GDPR Art.17 / KVKK Art.7): the
      // deleteUserAccount Cloud Function recursively deletes the entire
      // users/{uid} subtree, server-only docs, authored content, ALL Storage
      // objects, and the Auth identity itself — none of which the client can do
      // reliably. Requires the reauth performed above.
      await FirebaseFunctions.instance.httpsCallable('deleteUserAccount').call();

      // Cancel session monitoring
      await _sessionSubscription?.cancel();
      _sessionSubscription = null;
      _userDataCache = null;

      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
      // The Auth user is already deleted server-side; ensure local sign-out so
      // the app returns to the unauthenticated state.
      try {
        await _auth.signOut();
      } catch (_) {}
      await clearOnboardingData();

      _log.info('Account erased (server-side) for uid: $uid',
          service: _serviceName);
      unawaited(_analyticsService.logEvent(name: 'account_deleted'));
    } on FirebaseAuthException catch (e) {
      _log.error('FirebaseAuthException during account deletion',
          service: _serviceName, error: e);
      throw AuthException(e.code);
    } catch (e, s) {
      _log.error('Unexpected error during account deletion',
          service: _serviceName, error: e, stackTrace: s);
      if (e is AuthException) rethrow;
      throw AuthException('error-unknown');
    }
  }
}
