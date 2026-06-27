// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
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
  bool _obscurePassword = true;
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
      setState(() =>
          _passwordError = l10n.translate('auth.error.password_length'));
    } else if (!password.contains(RegExp(r'[0-9]'))) {
      setState(() =>
          _passwordError = l10n.translate('auth.error.password_digit'));
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
      if (email.isEmpty || password.isEmpty) throw AuthException('empty-fields');

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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: AppSpacing.xxl.h),
              // Brand wordmark
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
              // Email field
              Text(l10n.translate('auth.email'),
                  style: t.labelL.copyWith(color: palette.textPrimary)),
              SizedBox(height: AppSpacing.xs.h),
              _buildTextField(
                controller: _emailController,
                hintText: l10n.translate('auth.email_hint'),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                primary: primary,
                palette: palette,
                t: t,
              ),
              SizedBox(height: AppSpacing.xl.h),
              // Password field
              Text(l10n.translate('auth.password'),
                  style: t.labelL.copyWith(color: palette.textPrimary)),
              SizedBox(height: AppSpacing.xs.h),
              _buildTextField(
                controller: _passwordController,
                hintText: '••••••••',
                obscureText: _obscurePassword,
                errorText: _passwordError,
                onChanged: _validatePassword,
                primary: primary,
                palette: palette,
                t: t,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: palette.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.forgotPassword),
                  child: Text(
                    l10n.translate('auth.forgot_password'),
                    style: t.labelM.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.xl.h),
              AppButton(
                label: l10n.translate('auth.login'),
                loading: _isLoading,
                onPressed: _isLoading ? null : _login,
              ),
              SizedBox(height: AppSpacing.xl.h),
              // Divider
              Row(
                children: [
                  Expanded(
                      child: Divider(
                          color: palette.divider)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
                    child: Text(
                      l10n.translate('auth.or_divider'),
                      style: t.labelM.copyWith(color: palette.textTertiary),
                    ),
                  ),
                  Expanded(
                      child: Divider(
                          color: palette.divider)),
                ],
              ),
              SizedBox(height: AppSpacing.xl.h),
              // Google sign-in
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _loginWithGoogle,
                icon: Image.asset('assets/icons/google.png', height: 22.h),
                label: Text(
                  l10n.translate('auth.login_with_google'),
                  style: t.labelL.copyWith(color: palette.textPrimary),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: palette.surface,
                  foregroundColor: palette.textPrimary,
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                  side: BorderSide(color: palette.border),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.button.r)),
                ),
              ),
              if (Platform.isIOS) ...[
                SizedBox(height: AppSpacing.sm.h),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loginWithApple,
                  icon: const Icon(Icons.apple, color: Colors.white, size: 24),
                  label: Text(
                    l10n.translate('auth.login_with_apple'),
                    style: t.labelL.copyWith(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding:
                        EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.button.r)),
                  ),
                ),
              ],
              SizedBox(height: AppSpacing.xxxl.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.translate('auth.no_account'),
                      style: t.bodyM.copyWith(color: palette.textSecondary)),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.register),
                    child: Text(
                      l10n.translate('auth.register_now'),
                      style: t.labelM.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required Color primary,
    required AppPalette palette,
    required AppText t,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    TextInputAction? textInputAction,
    bool obscureText = false,
    String? errorText,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onChanged: onChanged,
      cursorColor: primary,
      style: t.bodyL.copyWith(color: palette.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        errorText: errorText,
        hintStyle: TextStyle(color: palette.textTertiary),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input.r),
          borderSide: BorderSide(color: palette.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input.r),
          borderSide: BorderSide(color: primary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input.r),
          borderSide: BorderSide(color: palette.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input.r),
          borderSide: BorderSide(color: palette.error, width: 2.0),
        ),
        filled: true,
        fillColor: palette.surfaceVariant.withValues(alpha: 0.5),
        contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xl.w, vertical: AppSpacing.md.h),
      ),
    );
  }
}
