// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/app_routes.dart';
import '../../core/utils/auth_error_handler.dart';
import '../../core/widgets/ds/ds.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _passwordError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/icons/google.png'), context);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
  }

  Future<void> _login() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      if (email.isEmpty || password.isEmpty) {
        throw AuthException('empty-fields');
      }

      final user = await AuthService().signInWithEmail(email, password);
      if (!mounted) return;

      if (user != null && user.emailVerified) {
        final userModel = await AuthService().getUserData(user.uid);
        if (mounted) {
          Provider.of<UserProvider>(context, listen: false).setUser(userModel);
        }
      } else if (user != null && !user.emailVerified) {
        try {
          await AuthService().sendEmailVerification();
        } catch (_) {}
      }
    } on AuthException catch (e) {
      if (mounted) AuthErrorHandler.showSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Unexpected login error: $e');
      _showErrorSnack();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService().signInWithGoogle();
      if (!mounted) return;
      if (user != null) {
        final currentUser = AuthService().currentUser;
        if (currentUser != null && !currentUser.emailVerified) return;
        final userModel = await AuthService().getUserData(user.uid);
        if (mounted) {
          Provider.of<UserProvider>(context, listen: false).setUser(userModel);
        }
      }
    } on AuthException catch (e) {
      if (mounted) AuthErrorHandler.showSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Unexpected Google login error: $e');
      _showErrorSnack();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithApple() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService().signInWithApple();
      if (!mounted) return;
      if (user != null) {
        final userModel = await AuthService().getUserData(user.uid);
        if (mounted) {
          Provider.of<UserProvider>(context, listen: false).setUser(userModel);
        }
      }
    } on AuthException catch (e) {
      if (mounted) AuthErrorHandler.showSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnack() {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.translate('auth.login_errors.unexpected_error')),
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
                  // ── Brand header ────────────────────────────────────────────
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
                    l10n.translate('auth.welcome_back'),
                    textAlign: TextAlign.center,
                    style: t.titleL.copyWith(color: palette.textSecondary),
                  ),
                  SizedBox(height: AppSpacing.xxxl.h),
                  // ── Form card ───────────────────────────────────────────────
                  AppCard(
                    bordered: true,
                    elevated: false,
                    padding: EdgeInsets.all(AppSpacing.md.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: _emailController,
                          labelText: l10n.translate('auth.email'),
                          hintText: l10n.translate('auth.email_hint'),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: palette.textTertiary,
                            size: AppSize.iconMd.r,
                          ),
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
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: palette.textTertiary,
                            size: AppSize.iconMd.r,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.pushNamed(
                                  context, AppRoutes.forgotPassword);
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.sm.h,
                                horizontal: AppSpacing.xs.w,
                              ),
                              child: Text(
                                l10n.translate('auth.forgot_password'),
                                style: t.labelM.copyWith(
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl.h),
                  AppButton(
                    label: l10n.translate('auth.login'),
                    loading: _isLoading,
                    onPressed: _isLoading ? null : _login,
                  ),
                  SizedBox(height: AppSpacing.xl.h),
                  // ── Or divider ──────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: Divider(color: palette.divider)),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
                        child: Text(
                          l10n.translate('auth.or_divider'),
                          style: t.labelM.copyWith(color: palette.textTertiary),
                        ),
                      ),
                      Expanded(child: Divider(color: palette.divider)),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xl.h),
                  // ── Social buttons ──────────────────────────────────────────
                  _SocialButton(
                    icon: Image.asset('assets/icons/google.png', height: 22.h),
                    label: l10n.translate('auth.login_with_google'),
                    onTap: _isLoading ? null : _loginWithGoogle,
                  ),
                  if (Platform.isIOS) ...[
                    SizedBox(height: AppSpacing.sm.h),
                    _SocialButton(
                      icon: const Icon(Icons.apple,
                          color: Colors.white, size: 24),
                      label: l10n.translate('auth.login_with_apple'),
                      onTap: _isLoading ? null : _loginWithApple,
                      backgroundColor: Colors.black,
                      textColor: Colors.white,
                    ),
                  ],
                  SizedBox(height: AppSpacing.xxxl.h),
                  // ── Register link ───────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.translate('auth.no_account'),
                          style:
                              t.bodyM.copyWith(color: palette.textSecondary)),
                      SizedBox(width: 4.w),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pushNamed(context, AppRoutes.register);
                        },
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.xs.r),
                          child: Text(
                            l10n.translate('auth.register_now'),
                            style: t.labelM.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
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
