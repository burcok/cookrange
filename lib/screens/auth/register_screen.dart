// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/consent_service.dart';
import '../../core/utils/app_routes.dart';
import '../../core/utils/auth_error_handler.dart';
import '../../core/widgets/ds/ds.dart';
import '../legal/legal_screen.dart';
import '../onboarding/v2/onboarding_completion.dart';
import '../onboarding/v2/registration_handoff.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordAgainController = TextEditingController();
  bool _isLoading = false;
  bool _agreementsAccepted = false;
  // Explicit consent (KVKK/GDPR) — essential is required; the rest are opt-in.
  bool _essentialDataConsent = false;
  bool _analyticsConsent = false;
  bool _marketingConsent = false;
  String? _emailError;
  String? _passwordError;
  String? _passwordAgainError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/icons/google.png'), context);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordAgainController.dispose();
    super.dispose();
  }

  void _validateEmail(String email) {
    if (email.isEmpty) {
      setState(() => _emailError = null);
      return;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _emailError =
          AppLocalizations.of(context).translate('auth.error.invalid_email'));
    } else {
      setState(() => _emailError = null);
    }
  }

  void _validatePassword(String password) {
    if (password.isEmpty) {
      setState(() => _passwordError = null);
      return;
    }
    final l10n = AppLocalizations.of(context);
    if (password.length < 8) {
      setState(
          () => _passwordError = l10n.translate('auth.error.password_length'));
    } else if (!password.contains(RegExp(r'[0-9]'))) {
      setState(
          () => _passwordError = l10n.translate('auth.error.password_digit'));
    } else {
      setState(() => _passwordError = null);
    }
    _validatePasswordAgain(_passwordAgainController.text);
  }

  void _validatePasswordAgain(String passwordAgain) {
    if (passwordAgain.isEmpty) {
      setState(() => _passwordAgainError = null);
      return;
    }
    if (_passwordController.text != passwordAgain) {
      setState(() => _passwordAgainError = AppLocalizations.of(context)
          .translate('auth.error.passwords_do_not_match'));
    } else {
      setState(() => _passwordAgainError = null);
    }
  }

  bool _isFormValid() =>
      _emailError == null &&
      _passwordError == null &&
      _passwordAgainError == null &&
      _emailController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _passwordAgainController.text.isNotEmpty &&
      _agreementsAccepted &&
      _essentialDataConsent;

  /// Persists the consent decisions captured at registration (KVKK/GDPR:
  /// essential granted, optional per opt-in) and suppresses the first-run
  /// consent nudge since the choice was just made here.
  Future<void> _recordConsents() async {
    await ConsentService().recordInitialConsents(
      analytics: _analyticsConsent,
      marketing: _marketingConsent,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consent_prompt_seen', true);
  }

  /// True when this screen was reached from the V2 onboarding flow, meaning the
  /// collected [OnboardingProvider] profile must be persisted at sign-up.
  bool get _fromOnboarding {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is Map &&
        args[OnboardingRegistrationHandoff.fromOnboardingArg] == true;
  }

  /// Persists the in-memory V2 onboarding profile against the new account and
  /// routes to AI meal-plan generation, skipping the (removed) legacy
  /// post-register onboarding. Consents are recorded here because they're
  /// captured on this screen; the shared tail — persist + water reminder +
  /// UserProvider + navigation, all best-effort so a hiccup never strands the
  /// new account — is reused by the logged-in completion path via
  /// [OnboardingCompletion.finalizeAndRoute].
  Future<void> _completeV2Onboarding(User user) async {
    try {
      await _recordConsents();
    } catch (e) {
      debugPrint('V2 onboarding: consent recording failed: $e');
    }
    if (!mounted) return;
    await OnboardingCompletion.finalizeAndRoute(context, user: user);
  }

  Future<void> _register() async {
    if (_isLoading || !_isFormValid()) return;
    setState(() => _isLoading = true);
    // Guard RouteGuard against the account-creation `authStateChanges` race:
    // set BEFORE registerWithEmail so the register screen can't be bounced to
    // onboarding mid-flight. Cleared by finalizeAndRoute on success, or here on
    // failure.
    final fromOnboarding = _fromOnboarding;
    if (fromOnboarding) OnboardingCompletion.isFinalizing = true;
    var handedOff = false;
    try {
      final user = await AuthService().registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (user != null && mounted && fromOnboarding) {
        handedOff = true;
        await _completeV2Onboarding(user);
        return;
      }
      await _recordConsents();
    } on AuthException catch (e) {
      if (mounted) AuthErrorHandler.showSnackBar(context, e);
    } catch (e) {
      debugPrint('Unexpected registration error: $e');
      if (mounted) _showErrorSnack('auth.register_errors.register_error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
      if (fromOnboarding && !handedOff) {
        OnboardingCompletion.isFinalizing = false;
      }
    }
  }

  Future<void> _registerWithGoogle() async {
    if (!_agreementsAccepted) {
      _showErrorSnack('auth.error.accept_agreements');
      return;
    }
    if (!_essentialDataConsent) {
      _showErrorSnack('auth.error.accept_essential');
      return;
    }
    setState(() => _isLoading = true);
    final fromOnboarding = _fromOnboarding;
    if (fromOnboarding) OnboardingCompletion.isFinalizing = true;
    var handedOff = false;
    try {
      final user = await AuthService().signInWithGoogle();
      if (user != null && mounted && fromOnboarding) {
        handedOff = true;
        await _completeV2Onboarding(user);
        return;
      }
      await _recordConsents();
      if (!mounted) return;
    } on AuthException catch (e) {
      if (mounted) AuthErrorHandler.showSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Unexpected Google registration error: $e');
      _showErrorSnack('auth.register_errors.register_error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
      if (fromOnboarding && !handedOff) {
        OnboardingCompletion.isFinalizing = false;
      }
    }
  }

  Future<void> _registerWithApple() async {
    if (!_agreementsAccepted) {
      _showErrorSnack('auth.register_errors.agreements_not_accepted');
      return;
    }
    if (!_essentialDataConsent) {
      _showErrorSnack('auth.error.accept_essential');
      return;
    }
    setState(() => _isLoading = true);
    final fromOnboarding = _fromOnboarding;
    if (fromOnboarding) OnboardingCompletion.isFinalizing = true;
    var handedOff = false;
    try {
      final user = await AuthService().signInWithApple();
      if (user != null && mounted && fromOnboarding) {
        handedOff = true;
        await _completeV2Onboarding(user);
        return;
      }
      await _recordConsents();
      if (!mounted) return;
    } on AuthException catch (e) {
      if (mounted) AuthErrorHandler.showSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack('auth.register_errors.register_error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
      if (fromOnboarding && !handedOff) {
        OnboardingCompletion.isFinalizing = false;
      }
    }
  }

  void _showErrorSnack(String key) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.translate(key)),
        backgroundColor: palette.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm.r)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          // Subtle radial glow behind the header
          Positioned(
            top: -80.h,
            left: -60.w,
            right: -60.w,
            child: Container(
              height: 280.h,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  colors: [primary.withValues(alpha: 0.11), Colors.transparent],
                  radius: 0.75,
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: AppSpacing.lg.h),
                  // ── Brand header ──────────────────────────────────────────
                  Text(
                    'cookrange',
                    textAlign: TextAlign.center,
                    style: t.displayM.copyWith(
                      fontFamily: 'Lexend',
                      color: primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs.h),
                  Text(
                    l10n.translate('auth.create_account'),
                    textAlign: TextAlign.center,
                    style: t.titleL.copyWith(color: palette.textSecondary),
                  ),
                  SizedBox(height: AppSpacing.xxxl.h),
                  // ── Form fields card ──────────────────────────────────────
                  AppCard(
                    bordered: true,
                    elevated: false,
                    padding: EdgeInsets.all(AppSpacing.md.r),
                    child: Column(
                      children: [
                        AppTextField(
                          controller: _emailController,
                          labelText: l10n.translate('auth.email'),
                          hintText: l10n.translate('auth.email_hint'),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          onChanged: _validateEmail,
                          errorText: _emailError,
                          prefixIcon: Icon(Icons.email_outlined,
                              color: palette.textTertiary,
                              size: AppSize.iconMd.r),
                        ),
                        SizedBox(height: AppSpacing.lg.h),
                        AppTextField(
                          controller: _passwordController,
                          labelText: l10n.translate('auth.password'),
                          hintText: '••••••••',
                          obscureText: true,
                          showPasswordToggle: true,
                          errorText: _passwordError,
                          onChanged: _validatePassword,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icon(Icons.lock_outline_rounded,
                              color: palette.textTertiary,
                              size: AppSize.iconMd.r),
                        ),
                        SizedBox(height: AppSpacing.lg.h),
                        AppTextField(
                          controller: _passwordAgainController,
                          labelText: l10n.translate('auth.password_again'),
                          hintText: '••••••••',
                          obscureText: true,
                          showPasswordToggle: true,
                          errorText: _passwordAgainError,
                          onChanged: _validatePasswordAgain,
                          prefixIcon: Icon(Icons.lock_outline_rounded,
                              color: palette.textTertiary,
                              size: AppSize.iconMd.r),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg.h),
                  // ── Consent panel (KVKK/GDPR — required + optional, granular) ──
                  AppCard(
                    bordered: true,
                    elevated: false,
                    padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ConsentTile(
                          value: _agreementsAccepted,
                          primary: primary,
                          onToggle: () => setState(
                              () => _agreementsAccepted = !_agreementsAccepted),
                          child: RichText(
                            text: TextSpan(
                              style: t.labelM.copyWith(
                                  color: palette.textSecondary, height: 1.45),
                              children: [
                                TextSpan(
                                    text: l10n
                                        .translate('auth.agreements.prefix')),
                                TextSpan(
                                  text: l10n.translate(
                                      'auth.agreements.privacy_policy'),
                                  style: TextStyle(
                                      color: primary,
                                      fontWeight: FontWeight.w700),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => const LegalScreen(
                                                  type: LegalDocumentType
                                                      .privacyPolicy)),
                                        ),
                                ),
                                TextSpan(
                                    text:
                                        l10n.translate('auth.agreements.and')),
                                TextSpan(
                                  text: l10n.translate(
                                      'auth.agreements.terms_of_use'),
                                  style: TextStyle(
                                      color: primary,
                                      fontWeight: FontWeight.w700),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => const LegalScreen(
                                                  type: LegalDocumentType
                                                      .termsOfUse)),
                                        ),
                                ),
                                TextSpan(
                                    text: l10n
                                        .translate('auth.agreements.suffix')),
                              ],
                            ),
                          ),
                        ),
                        Divider(height: 1, color: palette.divider),
                        _ConsentTile(
                          value: _essentialDataConsent,
                          primary: primary,
                          onToggle: () => setState(() =>
                              _essentialDataConsent = !_essentialDataConsent),
                          child: Text(
                            l10n.translate('auth.consent.essential'),
                            style: t.labelM.copyWith(
                                color: palette.textSecondary, height: 1.45),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              2.w, AppSpacing.sm.h, 0, AppSpacing.xxs.h),
                          child: Text(
                            l10n.translate('auth.consent.optional_header'),
                            style: t.overline.copyWith(
                                color: palette.textTertiary,
                                letterSpacing: 0.6),
                          ),
                        ),
                        _ConsentTile(
                          value: _analyticsConsent,
                          primary: primary,
                          onToggle: () => setState(
                              () => _analyticsConsent = !_analyticsConsent),
                          child: Text(
                            l10n.translate('auth.consent.analytics'),
                            style: t.labelM.copyWith(
                                color: palette.textSecondary, height: 1.4),
                          ),
                        ),
                        _ConsentTile(
                          value: _marketingConsent,
                          primary: primary,
                          onToggle: () => setState(
                              () => _marketingConsent = !_marketingConsent),
                          child: Text(
                            l10n.translate('auth.consent.marketing'),
                            style: t.labelM.copyWith(
                                color: palette.textSecondary, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl.h),
                  AppButton(
                    label: l10n.translate('auth.register'),
                    loading: _isLoading,
                    onPressed: _isLoading || !_isFormValid() ? null : _register,
                  ),
                  SizedBox(height: AppSpacing.xl.h),
                  // ── Or divider ──────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: Divider(color: palette.divider)),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
                        child: Text(l10n.translate('auth.or_divider'),
                            style:
                                t.labelM.copyWith(color: palette.textTertiary)),
                      ),
                      Expanded(child: Divider(color: palette.divider)),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xl.h),
                  // ── Social buttons ──────────────────────────────────────────
                  _SocialButton(
                    icon: Image.asset('assets/icons/google.png', height: 22.h),
                    label: l10n.translate('auth.register_with_google'),
                    onTap: _isLoading ? null : _registerWithGoogle,
                  ),
                  if (Platform.isIOS) ...[
                    SizedBox(height: AppSpacing.sm.h),
                    _SocialButton(
                      icon: const Icon(Icons.apple,
                          color: Colors.white, size: 24),
                      label: l10n.translate('auth.register_with_apple'),
                      onTap: _isLoading ? null : _registerWithApple,
                      backgroundColor: Colors.black,
                      textColor: Colors.white,
                    ),
                  ],
                  SizedBox(height: AppSpacing.xxxl.h),
                  // ── Login link ──────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.translate('auth.already_have_account'),
                          style:
                              t.bodyM.copyWith(color: palette.textSecondary)),
                      SizedBox(width: 4.w),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pushNamed(context, AppRoutes.login);
                        },
                        child: Text(
                          l10n.translate('auth.login_now'),
                          style: t.labelM.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xl.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single consent row with a DS-styled, animated rounded checkbox. The whole
/// row is tappable; [child] is the (rich) label.
class _ConsentTile extends StatelessWidget {
  final bool value;
  final VoidCallback onToggle;
  final Widget child;
  final Color primary;

  const _ConsentTile({
    required this.value,
    required this.onToggle,
    required this.child,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onToggle();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              width: 22.r,
              height: 22.r,
              decoration: BoxDecoration(
                color: value ? primary : Colors.transparent,
                borderRadius: BorderRadius.circular(7.r),
                border: Border.all(
                  color: value ? primary : palette.border,
                  width: 2,
                ),
              ),
              child: value
                  ? Icon(Icons.check_rounded, size: 15.sp, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 1.h),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// DS-consistent social auth button — press-scale + haptic, no raw Material buttons.
class _SocialButton extends StatefulWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;

  const _SocialButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.backgroundColor,
    this.textColor,
  });

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final isDisabled = widget.onTap == null;
    final bgColor = widget.backgroundColor ?? palette.surface;
    final fgColor = widget.textColor ?? palette.textPrimary;

    return Semantics(
      button: true,
      enabled: !isDisabled,
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: isDisabled
            ? null
            : (_) {
                setState(() => _pressed = false);
                HapticFeedback.lightImpact();
                widget.onTap?.call();
              },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          child: AnimatedOpacity(
            opacity: isDisabled ? 0.45 : 1.0,
            duration: AppMotion.fast,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(AppRadius.button.r),
                border: widget.backgroundColor == null
                    ? Border.all(color: palette.border, width: 1.5)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  widget.icon,
                  SizedBox(width: AppSpacing.sm.w),
                  Text(
                    widget.label,
                    style: t.labelL.copyWith(
                      color: fgColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
