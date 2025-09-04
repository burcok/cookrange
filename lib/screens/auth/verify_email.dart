import 'dart:async';
import 'package:cookrange/core/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  late Timer _timer;
  bool _isSending = false;
  String _statusMessage = 'We have sent a verification email to your inbox.';

  @override
  void initState() {
    super.initState();
    if (_auth.currentUser == null) {
      // If no user is signed in, we shouldn't be on this screen.
      // Navigate to login screen. Using a post-frame callback to ensure
      // context is available.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return;
    }
    _sendVerificationEmail();

    _timer = Timer.periodic(
        const Duration(seconds: 5), (_) => _checkEmailVerified());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    setState(() {
      _isSending = true;
    });

    try {
      // Use the current user directly.
      final user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        setState(() {
          _statusMessage = 'Verification email sent to ${user.email}.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to send verification email. Please try again.';
      });
    }

    setState(() {
      _isSending = false;
    });
  }

  Future<void> _checkEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) {
      // This case should ideally not be reached if initState check is solid.
      _timer.cancel();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    try {
      await user.reload();
      // After reload, get the fresh user instance.
      final freshUser = _auth.currentUser;
      if (freshUser != null && freshUser.emailVerified) {
        _timer.cancel();
        await _authService.verifyUserEmail();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _timer.cancel();
        if (mounted) {
          // User doesn't exist, navigate to login
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
      // Handle other potential exceptions if necessary
    } catch (e) {
      // Handle other generic errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.email_outlined, size: 100, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            _isSending
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Resend Email'),
                    onPressed: _sendVerificationEmail,
                  ),
            const SizedBox(height: 24),
            const Text(
                'Once you verify your email, this screen will close automatically.'),
          ],
        ),
      ),
    );
  }
}
