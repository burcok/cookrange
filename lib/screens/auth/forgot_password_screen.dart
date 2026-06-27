// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/auth_error_handler.dart';
import '../../core/widgets/ds/ds.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_isLoading) return;
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('auth.login_errors.empty_fields')),
          backgroundColor: palette.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm.r)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService().sendPasswordResetEmail(email);
      if (mounted) setState(() => _isSuccess = true);
    } on AuthException catch (e) {
      if (mounted) AuthErrorHandler.showSnackBar(context, e);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: palette.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm.r)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: AppSpacing.lg.h),
              Text(
                'cookrange',
                textAlign: TextAlign.center,
                style: t.displayM.copyWith(
                  fontFamily: 'Lexend',
                  color: primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: AppSpacing.xxxl.h),
              Text(
                l10n.translate('auth.forgot_password'),
                textAlign: TextAlign.center,
                style: t.headlineL.copyWith(
                    fontWeight: FontWeight.bold,
                    color: palette.textPrimary),
              ),
              SizedBox(height: AppSpacing.md.h),
              if (!_isSuccess) ...[
                Text(
                  l10n.translate('auth.forgot_password_desc'),
                  textAlign: TextAlign.center,
                  style: t.bodyL.copyWith(color: palette.textSecondary),
                ),
                SizedBox(height: AppSpacing.xxxl.h),
                Text(l10n.translate('auth.email'),
                    style: t.labelL.copyWith(color: palette.textPrimary)),
                SizedBox(height: AppSpacing.xs.h),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  cursorColor: primary,
                  style: t.bodyL.copyWith(color: palette.textPrimary),
                  decoration: InputDecoration(
                    hintText: l10n.translate('auth.email_hint'),
                    hintStyle: TextStyle(color: palette.textTertiary),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input.r),
                      borderSide: BorderSide(color: palette.border, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input.r),
                      borderSide: BorderSide(color: primary, width: 2.0),
                    ),
                    filled: true,
                    fillColor: palette.surfaceVariant.withValues(alpha: 0.5),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl.w,
                        vertical: AppSpacing.md.h),
                  ),
                ),
                SizedBox(height: AppSpacing.xxl.h),
                AppButton(
                  label: l10n.translate('common.send'),
                  loading: _isLoading,
                  onPressed: _isLoading ? null : _resetPassword,
                ),
              ] else ...[
                SizedBox(height: AppSpacing.xxl.h),
                Icon(Icons.mark_email_read_rounded,
                    size: 80.r, color: palette.success),
                SizedBox(height: AppSpacing.xl.h),
                Text(
                  l10n.translate('auth.reset_link_sent'),
                  textAlign: TextAlign.center,
                  style: t.titleL.copyWith(
                      fontWeight: FontWeight.w500,
                      color: palette.textPrimary),
                ),
                SizedBox(height: AppSpacing.xxxl.h),
                AppButton(
                  label: l10n.translate('auth.back_to_login'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
