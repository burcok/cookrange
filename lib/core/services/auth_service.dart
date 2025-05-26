import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthException implements Exception {
  final String code;
  AuthException(this.code);

  @override
  String toString() => code;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Email & Password Login
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw AuthException('user-not-found');
        case 'wrong-password':
          throw AuthException('wrong-password');
        case 'invalid-email':
          throw AuthException('invalid-email');
        case 'user-disabled':
          throw AuthException('user-disabled');
        case 'too-many-requests':
          throw AuthException('too-many-requests');
        case 'network-request-failed':
          throw AuthException('network-error');
        default:
          throw AuthException('error-unknown');
      }
    } catch (e) {
      print("Unexpected error during sign in: $e");
      throw Exception('error-unknown');
    }
  }

  // Email & Password Register
  Future<User?> registerWithEmail(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await result.user?.sendEmailVerification();
    return result.user;
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
      print("Sign in with google error: ${e.code}");
      throw Exception(e.code);
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

  Future<void> signUpWithEmail(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      print("Sign up with email error: ${e.code}");
      throw Exception(e.code);
    }
  }
}
