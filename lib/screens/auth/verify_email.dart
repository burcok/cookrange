import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/app_routes.dart';
import '../../core/widgets/ds/ds.dart';
import '../onboarding/v2/onboarding_flow_screen.dart';

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
      if (!mounted) {
        timer.cancel();
        return;
      }
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
          setState(() => _canResend = true);
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
          final userModel = await _authService.getUserData(reloadedUser.uid);
          final onboardingCompleted = userModel?.onboardingCompleted ?? false;
          if (mounted) {
            if (!onboardingCompleted) {
              // Unfinished onboarding → complete it in the V2 flow in logged-in
              // mode (persists against this account's uid).
              unawaited(Navigator.pushReplacementNamed(
                context,
                AppRoutes.onboardingV2,
                arguments: OnboardingFlowScreen.loggedInCompletionArgs,
              ));
            } else {
              // Onboarding done → generate the first meal plan (same destination
              // as OnboardingCompletion.finalizeAndRoute for social-auth users).
              unawaited(Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.mealPlanGeneration,
                (route) => false,
              ));
            }
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
    final primary = context.watch<ThemeProvider>().primaryColor;
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final email = _auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          // Subtle brand glow at top
          Positioned(
            top: -80.h,
            left: -60.w,
            right: -60.w,
            child: Container(
              height: 240.h,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  colors: [primary.withValues(alpha: 0.10), Colors.transparent],
                  radius: 0.75,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
              child: Column(
                children: [
                  SizedBox(height: AppSpacing.sm.h),
                  // ── Top bar: wordmark + sign-out ────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'cookrange',
                        style: t.headlineM.copyWith(
                          fontFamily: 'Lexend',
                          color: primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          unawaited(HapticFeedback.selectionClick());
                          final navigator = Navigator.of(context);
                          await _authService.signOut();
                          if (mounted) {
                            unawaited(navigator.pushNamedAndRemoveUntil(
                                AppRoutes.login, (route) => false));
                          }
                        },
                        child: Container(
                          width: 36.r,
                          height: 36.r,
                          decoration: BoxDecoration(
                            color:
                                palette.surfaceVariant.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                            border: Border.all(color: palette.border),
                          ),
                          child: Icon(Icons.close_rounded,
                              color: palette.textSecondary, size: 18.r),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xl.h),
                  // ── Main card: illustration + info ──────────────────────────
                  AppCard(
                    bordered: true,
                    elevated: false,
                    padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg.w, vertical: AppSpacing.xl.h),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/onboarding/verify-email.png',
                          height: 148.h,
                        ),
                        SizedBox(height: AppSpacing.xl.h),
                        Text(
                          l10n.translate('auth.verify_title'),
                          textAlign: TextAlign.center,
                          style: t.headlineM.copyWith(
                              fontWeight: FontWeight.bold,
                              color: palette.textPrimary),
                        ),
                        SizedBox(height: AppSpacing.sm.h),
                        // Email address pill
                        if (email.isNotEmpty) ...[
                          SizedBox(height: AppSpacing.xxs.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.md.w,
                                vertical: AppSpacing.xxs.h),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.09),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full.r),
                              border: Border.all(
                                  color: primary.withValues(alpha: 0.22)),
                            ),
                            child: Text(
                              email,
                              style: t.labelM.copyWith(
                                  color: primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                          SizedBox(height: AppSpacing.sm.h),
                        ],
                        Text(
                          l10n.translate('auth.verify_desc'),
                          textAlign: TextAlign.center,
                          style: t.bodyM.copyWith(
                              color: palette.textSecondary, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // ── Countdown pill ──────────────────────────────────────────
                  AnimatedSwitcher(
                    duration: AppMotion.normal,
                    child: !_canResend
                        ? Container(
                            key: const ValueKey('countdown'),
                            padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg.w,
                                vertical: AppSpacing.xs.h),
                            decoration: BoxDecoration(
                              color: palette.surfaceVariant,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full.r),
                              border: Border.all(color: palette.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_outlined,
                                    size: 15.r, color: palette.textTertiary),
                                SizedBox(width: 6.w),
                                Text(
                                  l10n.translate('auth.resend_wait',
                                      variables: {'time': '$minutes:$seconds'}),
                                  style: t.labelM
                                      .copyWith(color: palette.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('no-countdown')),
                  ),
                  SizedBox(height: AppSpacing.md.h),
                  // ── Resend button ───────────────────────────────────────────
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
        ],
      ),
    );
  }
}
