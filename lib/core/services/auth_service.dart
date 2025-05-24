import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
      print("Sign in with email error: ${e.code} - ${e.message}");
      switch (e.code) {
        case 'user-not-found':
          throw Exception('user-not-found');
        case 'wrong-password':
          throw Exception('wrong-password');
        case 'invalid-email':
          throw Exception('invalid-email');
        case 'user-disabled':
          throw Exception('user-disabled');
        case 'too-many-requests':
          throw Exception('too-many-requests');
        case 'network-request-failed':
          throw Exception('network-error');
        default:
          throw Exception('error-unknown');
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
      // TODO: Şu anda error doğru şekilde geliyor. channel hatası çözüldü fakat doğru case e girmiyor her zaman invalid
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        throw Exception('user-not-found');
      } else {
        throw Exception('error-unknown');
      }
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
