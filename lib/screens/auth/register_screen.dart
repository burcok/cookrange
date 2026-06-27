// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/app_routes.dart';
import '../../core/utils/auth_error_handler.dart';
import '../../core/widgets/ds/ds.dart';
import '../legal/legal_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordAgainController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscurePasswordAgain = true;
  bool _isLoading = false;
  bool _agreementsAccepted = false;
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
    if (email.isEmpty) { setState(() => _emailError = null); return; }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _emailError =
          AppLocalizations.of(context).translate('auth.error.invalid_email'));
    } else {
      setState(() => _emailError = null);
    }
  }

  void _validatePassword(String password) {
    if (password.isEmpty) { setState(() => _passwordError = null); return; }
    final l10n = AppLocalizations.of(context);
    if (password.length < 8) {
      setState(() => _passwordError = l10n.translate('auth.error.password_length'));
    } else if (!password.contains(RegExp(r'[0-9]'))) {
      setState(() => _passwordError = l10n.translate('auth.error.password_digit'));
    } else {
      setState(() => _passwordError = null);
    }
    _validatePasswordAgain(_passwordAgainController.text);
  }

  void _validatePasswordAgain(String passwordAgain) {
    if (passwordAgain.isEmpty) { setState(() => _passwordAgainError = null); return; }
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
      _agreementsAccepted;

  Future<void> _register() async {
    if (_isLoading || !_isFormValid()) return;
    setState(() => _isLoading = true);
    try {
      await AuthService().registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } on AuthException catch (e) {
      if (mounted) AuthErrorHandler.showSnackBar(context, e);
    } catch (e) {
      debugPrint('Unexpected registration error: $e');
      if (mounted) _showErrorSnack('auth.register_errors.register_error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerWithGoogle() async {
    if (!_agreementsAccepted) {
      _showErrorSnack('auth.error.accept_agreements');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService().signInWithGoogle();
      if (!mounted) return;
    } on AuthException catch (e) {
      if (mounted) AuthErrorHandler.showSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Unexpected Google registration error: $e');
      _showErrorSnack('auth.register_errors.register_error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerWithApple() async {
    if (!_agreementsAccepted) {
      _showErrorSnack('auth.register_errors.agreements_not_accepted');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService().signInWithApple();
      if (!mounted) return;
    } on AuthException catch (e) {
      if (mounted) AuthErrorHandler.showSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack('auth.register_errors.register_error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              // Email
              Text(l10n.translate('auth.email'),
                  style: t.labelL.copyWith(color: palette.textPrimary)),
              SizedBox(height: AppSpacing.xs.h),
              _buildTextField(
                controller: _emailController,
                hintText: l10n.translate('auth.email_hint'),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                onChanged: _validateEmail,
                errorText: _emailError,
                primary: primary,
                palette: palette,
                t: t,
              ),
              SizedBox(height: AppSpacing.xl.h),
              // Password
              Text(l10n.translate('auth.password'),
                  style: t.labelL.copyWith(color: palette.textPrimary)),
              SizedBox(height: AppSpacing.xs.h),
              _buildTextField(
                controller: _passwordController,
                hintText: '••••••••',
                obscureText: _obscurePassword,
                errorText: _passwordError,
                onChanged: _validatePassword,
                textInputAction: TextInputAction.next,
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
              SizedBox(height: AppSpacing.xl.h),
              // Password again
              Text(l10n.translate('auth.password_again'),
                  style: t.labelL.copyWith(color: palette.textPrimary)),
              SizedBox(height: AppSpacing.xs.h),
              _buildTextField(
                controller: _passwordAgainController,
                hintText: '••••••••',
                obscureText: _obscurePasswordAgain,
                errorText: _passwordAgainError,
                onChanged: _validatePasswordAgain,
                primary: primary,
                palette: palette,
                t: t,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePasswordAgain
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: palette.textSecondary,
                  ),
                  onPressed: () => setState(
                      () => _obscurePasswordAgain = !_obscurePasswordAgain),
                ),
              ),
              SizedBox(height: AppSpacing.md.h),
              // Agreements
              Row(
                children: [
                  Checkbox(
                    value: _agreementsAccepted,
                    activeColor: primary,
                    onChanged: (value) =>
                        setState(() => _agreementsAccepted = value ?? false),
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: t.labelM.copyWith(color: palette.textPrimary),
                        children: [
                          TextSpan(text: l10n.translate('auth.agreements.prefix')),
                          TextSpan(
                            text: l10n.translate('auth.agreements.privacy_policy'),
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const LegalScreen(
                                            type: LegalDocumentType
                                                .privacyPolicy)),
                                  ),
                          ),
                          TextSpan(text: l10n.translate('auth.agreements.and')),
                          TextSpan(
                            text: l10n.translate('auth.agreements.terms_of_use'),
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const LegalScreen(
                                            type: LegalDocumentType.termsOfUse)),
                                  ),
                          ),
                          TextSpan(text: l10n.translate('auth.agreements.suffix')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.xl.h),
              AppButton(
                label: l10n.translate('auth.register'),
                loading: _isLoading,
                onPressed: _isLoading || !_isFormValid() ? null : _register,
              ),
              SizedBox(height: AppSpacing.xl.h),
              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: palette.divider)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
                    child: Text(l10n.translate('auth.or_divider'),
                        style: t.labelM.copyWith(color: palette.textTertiary)),
                  ),
                  Expanded(child: Divider(color: palette.divider)),
                ],
              ),
              SizedBox(height: AppSpacing.xl.h),
              // Google
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _registerWithGoogle,
                icon: Image.asset('assets/icons/google.png', height: 22.h),
                label: Text(l10n.translate('auth.register_with_google'),
                    style: t.labelL.copyWith(color: palette.textPrimary)),
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
                  onPressed: _isLoading ? null : _registerWithApple,
                  icon: const Icon(Icons.apple, color: Colors.white, size: 24),
                  label: Text(l10n.translate('auth.register_with_apple'),
                      style: t.labelL.copyWith(color: Colors.white)),
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
                  Text(l10n.translate('auth.already_have_account'),
                      style: t.bodyM.copyWith(color: palette.textSecondary)),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.login),
                    child: Text(
                      l10n.translate('auth.login_now'),
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
}
