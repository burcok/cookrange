import 'dart:async';
import 'package:cookrange/constants.dart';
import 'package:cookrange/core/services/auth_service.dart';
import 'package:cookrange/core/theme/app_theme.dart';
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
  Timer? _timer;
  Timer? _countdownTimer;
  int _remainingSeconds = 180;
  bool _isSending = false;
  bool _canResend = false;

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
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _canResend = false;
      _remainingSeconds = 180;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  Future<void> _sendVerificationEmail() async {
    setState(() {
      _isSending = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Verification email sent to ${user.email}.')),
          );
        }
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send verification email: $e')),
        );
        _canResend = true;
      }
    }

    setState(() {
      _isSending = false;
    });
  }

  Future<void> _checkEmailVerified() async {
    final user = _auth.currentUser;
    await user?.reload();
    if (user != null && user.emailVerified) {
      _timer?.cancel();
      _countdownTimer?.cancel();
      await _authService.verifyUserEmail();
      final userModel = await _authService.getUserData(user.uid);
      final bool onboardingCompleted = userModel?.onboardingCompleted ?? false;

      if (mounted) {
        if (onboardingCompleted) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(context, '/onboarding');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    String seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
          child: Container(
        color: colorScheme.backgroundColor2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await _authService.signOut();
                    if (mounted) {
                      navigator.pushNamedAndRemoveUntil(
                          '/login', (route) => false);
                    }
                  },
                ),
              ),
              Image.asset('assets/images/onboarding/verify-email.png'),
              const SizedBox(height: 48),
              Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  color: colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "We've sent a verification link to your email. Please click the link to verify your account.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.titleColor,
                    fontFamily: 'Poppins'),
              ),
              const Spacer(),
              if (!_canResend)
                Text(
                  '$minutes:$seconds saniye sonra tekrar gönderebilirsiniz.',
                  style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.titleColor,
                      fontFamily: 'Poppins'),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _canResend ? primaryColor : primaryColor.withAlpha(20),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed:
                      _canResend && !_isSending ? _sendVerificationEmail : null,
                  child: _isSending
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Resend Verification Email',
                          style: TextStyle(
                              fontSize: 16,
                              color: _canResend
                                  ? Colors.white
                                  : Colors.white.withAlpha(20)),
                        ),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}
