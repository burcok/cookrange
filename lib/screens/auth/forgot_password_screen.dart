// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      body: Stack(
        children: [
          // Subtle brand glow
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
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: AppSpacing.md.h),
                  // ── Inline back button ──────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 40.r,
                        height: 40.r,
                        decoration: BoxDecoration(
                          color: palette.surfaceVariant.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.border),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: palette.textPrimary,
                          size: 16.r,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.xxl.h),
                  // ── Brand wordmark ──────────────────────────────────────────
                  Text(
                    'cookrange',
                    textAlign: TextAlign.center,
                    style: t.displayM.copyWith(
                      fontFamily: 'Lexend',
                      color: primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl.h),
                  // ── Animated content area ───────────────────────────────────
                  AnimatedSwitcher(
                    duration: AppMotion.normal,
                    switchInCurve: AppMotion.decelerate,
                    switchOutCurve: AppMotion.accelerate,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _isSuccess
                        ? _buildSuccess(palette, t, l10n)
                        : _buildForm(palette, t, l10n),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(AppPalette palette, AppText t, AppLocalizations l10n) {
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.translate('auth.forgot_password'),
          textAlign: TextAlign.center,
          style: t.headlineL.copyWith(
              fontWeight: FontWeight.bold, color: palette.textPrimary),
        ),
        SizedBox(height: AppSpacing.sm.h),
        Text(
          l10n.translate('auth.forgot_password_desc'),
          textAlign: TextAlign.center,
          style: t.bodyL.copyWith(color: palette.textSecondary),
        ),
        SizedBox(height: AppSpacing.xxxl.h),
        // Email field in a bordered card
        AppCard(
          bordered: true,
          elevated: false,
          padding: EdgeInsets.all(AppSpacing.md.r),
          child: AppTextField(
            controller: _emailController,
            labelText: l10n.translate('auth.email'),
            hintText: l10n.translate('auth.email_hint'),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _resetPassword(),
            prefixIcon: Icon(
              Icons.email_outlined,
              color: palette.textTertiary,
              size: AppSize.iconMd.r,
            ),
          ),
        ),
        SizedBox(height: AppSpacing.xl.h),
        AppButton(
          label: l10n.translate('common.send'),
          loading: _isLoading,
          onPressed: _isLoading ? null : _resetPassword,
        ),
        SizedBox(height: AppSpacing.xl.h),
      ],
    );
  }

  Widget _buildSuccess(AppPalette palette, AppText t, AppLocalizations l10n) {
    return Column(
      key: const ValueKey('success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: AppSpacing.md.h),
        // Success icon with ring
        Center(
          child: Container(
            width: 88.r,
            height: 88.r,
            decoration: BoxDecoration(
              color: palette.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                  color: palette.success.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(Icons.mark_email_read_rounded,
                size: 42.r, color: palette.success),
          ),
        ),
        SizedBox(height: AppSpacing.xl.h),
        // Success message in a subtle card
        AppCard(
          bordered: true,
          elevated: false,
          padding: EdgeInsets.all(AppSpacing.lg.r),
          child: Text(
            l10n.translate('auth.reset_link_sent'),
            textAlign: TextAlign.center,
            style: t.bodyL.copyWith(color: palette.textSecondary, height: 1.5),
          ),
        ),
        SizedBox(height: AppSpacing.xl.h),
        AppButton(
          label: l10n.translate('auth.back_to_login'),
          onPressed: () => Navigator.pop(context),
        ),
        SizedBox(height: AppSpacing.xl.h),
      ],
    );
  }
}
