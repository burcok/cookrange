import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/app_routes.dart';
import '../../core/widgets/ds/ds.dart';

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
      });
      return;
    }
    _startCountdown();
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
      if (!mounted) { timer.cancel(); return; }
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  Future<void> _sendVerificationEmail() async {
    setState(() => _isSending = true);
    final l10n = AppLocalizations.of(context);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.translate('auth.verify_email_sent',
                  variables: {'email': user.email ?? ''}))));
        }
        _startCountdown();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMsg = e.message ?? e.toString();
        if (e.code == 'too-many-requests') {
          errorMsg = l10n.translate('auth.error.too_many_requests');
          _startCountdown();
        } else {
          _canResend = true;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.translate('auth.verify_email_failed',
                variables: {'error': errorMsg}))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.translate('auth.verify_email_failed',
                variables: {'error': e.toString()}))));
        setState(() => _canResend = true);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _checkEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        final reloadedUser = _auth.currentUser;
        if (reloadedUser != null && reloadedUser.emailVerified) {
          _timer?.cancel();
          _countdownTimer?.cancel();
          await _authService.verifyUserEmail();
          final userModel =
              await _authService.getUserData(reloadedUser.uid);
          final onboardingCompleted = userModel?.onboardingCompleted ?? false;
          if (mounted) {
            unawaited(Navigator.pushReplacementNamed(
              context,
              onboardingCompleted ? AppRoutes.home : AppRoutes.onboarding,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking email verification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xl.w, vertical: AppSpacing.md.h),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: palette.textSecondary),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await _authService.signOut();
                    if (mounted) {
                      unawaited(navigator.pushNamedAndRemoveUntil(
                          AppRoutes.login, (route) => false));
                    }
                  },
                ),
              ),
              Image.asset('assets/images/onboarding/verify-email.png'),
              SizedBox(height: AppSpacing.xxxl.h),
              Text(
                l10n.translate('auth.verify_title'),
                style: t.headlineL.copyWith(
                    fontWeight: FontWeight.bold, color: palette.textPrimary),
              ),
              SizedBox(height: AppSpacing.md.h),
              Text(
                l10n.translate('auth.verify_desc'),
                textAlign: TextAlign.center,
                style: t.bodyL.copyWith(color: palette.textSecondary),
              ),
              const Spacer(),
              if (!_canResend)
                Text(
                  l10n.translate('auth.resend_wait',
                      variables: {'time': '$minutes:$seconds'}),
                  style: t.labelM.copyWith(color: palette.textTertiary),
                ),
              SizedBox(height: AppSpacing.md.h),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: l10n.translate('auth.resend_btn'),
                  loading: _isSending,
                  onPressed: _canResend && !_isSending
                      ? _sendVerificationEmail
                      : null,
                ),
              ),
              SizedBox(height: AppSpacing.md.h),
            ],
          ),
        ),
      ),
    );
  }
}
