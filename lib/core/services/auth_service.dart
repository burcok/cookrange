import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/analytics_service.dart';
import 'firestore_service.dart';
import 'log_service.dart';
import '../models/user_model.dart';

class AuthException implements Exception {
  final String code;
  AuthException(this.code);

  @override
  String toString() => code;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
    _log.info('Initializing AuthService', service: _serviceName);
    _prefs = await SharedPreferences.getInstance();

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
    final data = _prefs.getString(_onboardingDataKey);
    if (data == null) return null;

    final mapEntries =
        data.replaceAll('{', '').replaceAll('}', '').split(',').map((e) {
      final parts = e.split(':');
      return MapEntry(parts[0].trim(), parts[1].trim());
    });

    return Map<String, dynamic>.from(Map.fromEntries(mapEntries));
  }

  // Clear onboarding data
  Future<void> clearOnboardingData() async {
    await _prefs.remove(_onboardingDataKey);
  }

  // Email & Password Login
  Future<User?> signInWithEmail(String email, String password) async {
    _log.info('Attempting to sign in with email: $email',
        service: _serviceName);
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      if (result.user == null) {
        // This case is unlikely as FirebaseAuth throws for user-not-found
        _log.error('Sign in failed: User object is null after successful auth.',
            service: _serviceName);
        throw AuthException('user-not-found');
      }

      // Delegate login handling to FirestoreService
      await _firestoreService.handleUserLogin(result.user!);
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
        print("Type error details: ${e.toString()}");
        print("Type error stack trace: ${e.stackTrace}");
        throw AuthException('type-error');
      }
      throw AuthException('error-unknown');
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
        await result.user?.sendEmailVerification();
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
      print("Firebase Auth Error during register: ${e.code} - ${e.message}");
      throw AuthException(e.code);
    } catch (e, s) {
      _log.error('Unexpected error during registration for $email',
          service: _serviceName, error: e, stackTrace: s);
      print("Unexpected error during register: $e");
      if (e is TypeError) {
        print("Type error details: ${e.toString()}");
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
      _analyticsService.logEvent(
        name: 'password_reset_request',
        parameters: {
          'email': email,
          'time': time.toIso8601String(),
        },
      );
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
        _analyticsService.logEvent(
          name: 'send_email_verification',
          parameters: {
            'email': user.email ?? 'unknown',
            'time': time.toIso8601String(),
          },
        );
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
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
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
        // Delegate login handling to FirestoreService
        await _firestoreService.handleUserLogin(user);
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
      print("Sign in with google error: ${e.code}");
      throw AuthException(e.code);
    } catch (e, s) {
      _log.error('Unexpected error during Google Sign-In',
          service: _serviceName, error: e, stackTrace: s);
      print("Unexpected error during Google sign in: $e");
      throw AuthException('error-unknown');
    }
  }

  // Sign Out
  Future<void> signOut() async {
    final user = _auth.currentUser;
    _log.info('Attempting to sign out user: ${user?.uid}',
        service: _serviceName);
    if (user != null) {
      await _firestoreService.logUserActivity(user.uid, 'logout');
    }
    await _auth.signOut();
    await GoogleSignIn().signOut();
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

  Future<void> completeOnboarding() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    await _firestoreService.updateUserData(
      currentUser.uid,
      {'onboarding_complete': true},
    );
  }

  Future<void> updateUserOnboardingData(Map<String, dynamic> data) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    await _firestoreService.updateUserData(
      currentUser.uid,
      data,
    );
  }
}
