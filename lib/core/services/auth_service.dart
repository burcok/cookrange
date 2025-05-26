import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/analytics_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/device_info_provider.dart';

class AuthException implements Exception {
  final String code;
  AuthException(this.code);

  @override
  String toString() => code;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AnalyticsService _analyticsService = AnalyticsService();
  static const String _languageKey = 'language_code';
  static const String _onboardingDataKey = 'onboarding_data';
  late SharedPreferences _prefs;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Initialize service
  Future<void> initialize() async {
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
    } catch (e) {
      print("Error setting language code: $e");
    }
  }

  // Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.exists && doc.data()?['onboarding_completed'] == true;
    } catch (e) {
      print('Error checking onboarding status: $e');
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

  // Get IP address
  Future<String> _getIpAddress() async {
    try {
      final response =
          await http.get(Uri.parse('https://api.ipify.org?format=json'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['ip'] ?? '0.0.0.0';
      }
    } catch (e) {
      print('Error getting IP address: $e');
    }
    return '0.0.0.0';
  }

  // Update last login info
  Future<void> _updateLastLoginInfo(
      User user, DeviceInfoProvider deviceInfo) async {
    final ipAddress = await _getIpAddress();

    // Check if user document exists
    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      // Create user document if it doesn't exist
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'created_at': FieldValue.serverTimestamp(),
        'last_login_at': FieldValue.serverTimestamp(),
        'last_login_ip': ipAddress,
        'last_login_device': deviceInfo.deviceModel,
        'last_login_device_type': deviceInfo.deviceType,
        'last_login_device_model': deviceInfo.deviceModel,
        'last_login_device_os': deviceInfo.deviceOs,
        'app_version': deviceInfo.appVersion,
        'build_number': deviceInfo.buildNumber,
        'onboarding_completed': false,
      });
    } else {
      // Update last login info
      await _firestore.collection('users').doc(user.uid).update({
        'last_login_at': FieldValue.serverTimestamp(),
        'last_login_ip': ipAddress,
        'last_login_device': deviceInfo.deviceModel,
        'last_login_device_type': deviceInfo.deviceType,
        'last_login_device_model': deviceInfo.deviceModel,
        'last_login_device_os': deviceInfo.deviceOs,
        'app_version': deviceInfo.appVersion,
        'build_number': deviceInfo.buildNumber,
      });
    }
  }

  // Email & Password Login
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      print("Sign in result: $result");

      if (result.user == null) {
        throw AuthException('user-not-found');
      }

      // Get device info
      final deviceInfo = DeviceInfoProvider();
      await deviceInfo.initialize();

      // Update last login info
      await _updateLastLoginInfo(result.user!, deviceInfo);

      // Check if user has completed onboarding
      final hasOnboarding = await hasCompletedOnboarding();
      if (!hasOnboarding) {
        // If no onboarding data, redirect to onboarding
        return result.user;
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code);
    } catch (e, stackTrace) {
      print("Unexpected error during sign in: $e");
      print("Stack trace: $stackTrace");
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
    try {
      final result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      if (result.user != null) {
        // Get onboarding data
        final onboardingData = await getOnboardingData();

        // Save user data including onboarding data
        await _firestore.collection('users').doc(result.user!.uid).set({
          'email': email,
          'onboarding_completed': onboardingData != null,
          'onboarding_data': onboardingData,
          'created_at': FieldValue.serverTimestamp(),
          'last_login_at': FieldValue.serverTimestamp(),
          'last_login_ip': '0.0.0.0',
          'last_login_device': 'unknown',
          'last_login_location': 'unknown',
          'last_login_device_type': 'unknown',
          'last_login_device_model': 'unknown',
          'last_login_device_os': 'unknown',
        });

        await result.user?.sendEmailVerification();
        return result.user;
      } else {
        throw AuthException('user-creation-failed');
      }
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error during register: ${e.code} - ${e.message}");
      throw AuthException(e.code);
    } catch (e) {
      print("Unexpected error during register: $e");
      if (e is TypeError) {
        print("Type error details: ${e.toString()}");
      }
      throw AuthException('error-unknown');
    }
  }

  // Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);

      final time = DateTime.now();
      _analyticsService.logEvent(
        name: 'sign_in_with_email',
        parameters: {
          'email': email,
          'time': time.toIso8601String(),
        },
      );
    } catch (e) {
      print("Error sending password reset email: $e");
      throw AuthException('error-unknown');
    }
  }

  // Send Email Verification
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
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
      } catch (e) {
        print("Error sending email verification: $e");
        throw AuthException('error-unknown');
      }
    }
  }

  // Google Sign-In
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);

      // Check if user exists in Firestore
      final userDoc =
          await _firestore.collection('users').doc(result.user!.uid).get();

      if (!userDoc.exists) {
        // If new user, check for onboarding data
        final onboardingData = await getOnboardingData();

        // Save user data including onboarding data
        await _firestore.collection('users').doc(result.user!.uid).set({
          'email': result.user!.email,
          'created_at': FieldValue.serverTimestamp(),
          'onboarding_completed': onboardingData != null,
          'onboarding_data': onboardingData,
          'last_login_at': FieldValue.serverTimestamp(),
          'last_login_ip': '0.0.0.0',
          'last_login_device': 'unknown',
          'last_login_location': 'unknown',
          'last_login_device_type': 'unknown',
          'last_login_device_model': 'unknown',
          'last_login_device_os': 'unknown',
        });
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      print("Sign in with google error: ${e.code}");
      throw AuthException(e.code);
    } catch (e) {
      print("Unexpected error during Google sign in: $e");
      throw AuthException('error-unknown');
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
    await clearOnboardingData();
  }

  // Get Current User
  User? get currentUser => _auth.currentUser;

  // Listen to Auth State Changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data();
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Update user data in Firestore
  Future<void> updateUserData(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update(data);
    } catch (e) {
      print('Error updating user data: $e');
      throw AuthException('update-failed');
    }
  }
}
