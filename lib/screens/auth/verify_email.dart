import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late User _user;
  late Timer _timer;
  bool _isSending = false;
  String _statusMessage = 'We have sent a verification email to your inbox.';

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser!;
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
      await _user.sendEmailVerification();
      setState(() {
        _statusMessage = 'Verification email sent to ${_user.email}.';
      });
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
    await _user.reload();
    _user = _auth.currentUser!;
    if (_user.emailVerified) {
      _timer.cancel();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
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
