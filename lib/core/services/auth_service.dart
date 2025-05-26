import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class AuthException implements Exception {
  final String code;
  AuthException(this.code);

  @override
  String toString() => code;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _languageKey = 'language_code';
  late SharedPreferences _prefs;

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Email & Password Login
  Future<User?> signInWithEmail(String email, String password) async {
    try {
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

      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      print("Sign in result: $result");

      if (result.user == null) {
        throw AuthException('user-not-found');
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
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Send Email Verification
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
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
      return result.user;
    } on FirebaseAuthException catch (e) {
      print("Sign in with google error: \u001b[31m");
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
  }

  // Get Current User
  User? get currentUser => _auth.currentUser;

  // Listen to Auth State Changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
