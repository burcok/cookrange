import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';

/// Cookrange DS — branded snackbar variants.
///
/// Usage:
/// ```dart
/// AppSnackBar.show(context, message: 'Saved!', variant: AppSnackBarVariant.success);
/// AppSnackBar.error(context, 'Something went wrong');
/// AppSnackBar.success(context, 'Profile updated');
/// AppSnackBar.info(context, 'Tap to learn more', onTap: () { ... });
/// ```
enum AppSnackBarVariant { success, error, warning, info }

class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context, {
    required String message,
    AppSnackBarVariant variant = AppSnackBarVariant.info,
    String? actionLabel,
    VoidCallback? onAction,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: _AppSnackBarContent(
          message: message,
          variant: variant,
          onTap: onTap,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        padding: EdgeInsets.zero,
        margin: EdgeInsets.fromLTRB(
            AppSpacing.xl.w, 0, AppSpacing.xl.w, AppSpacing.lg.h),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                onPressed: onAction ?? () {},
                textColor: Colors.transparent,
              )
            : null,
      ),
    );
  }

  static void success(BuildContext context, String message,
          {String? actionLabel, VoidCallback? onAction}) =>
      show(context,
          message: message,
          variant: AppSnackBarVariant.success,
          actionLabel: actionLabel,
          onAction: onAction);

  static void error(BuildContext context, String message,
          {String? actionLabel, VoidCallback? onAction}) =>
      show(context,
          message: message,
          variant: AppSnackBarVariant.error,
          actionLabel: actionLabel,
          onAction: onAction);

  static void warning(BuildContext context, String message,
          {String? actionLabel, VoidCallback? onAction}) =>
      show(context,
          message: message,
          variant: AppSnackBarVariant.warning,
          actionLabel: actionLabel,
          onAction: onAction);

  static void info(BuildContext context, String message,
          {String? actionLabel, VoidCallback? onAction}) =>
      show(context,
          message: message, actionLabel: actionLabel, onAction: onAction);
}

class _AppSnackBarContent extends StatelessWidget {
  final String message;
  final AppSnackBarVariant variant;
  final VoidCallback? onTap;

  const _AppSnackBarContent({
    required this.message,
    required this.variant,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    final (Color bg, Color iconBg, Color iconColor, IconData icon) =
        switch (variant) {
      AppSnackBarVariant.success => (
          palette.success.withValues(alpha: palette.isDark ? 0.2 : 0.12),
          palette.success.withValues(alpha: 0.25),
          palette.success,
          Icons.check_circle_rounded,
        ),
      AppSnackBarVariant.error => (
          palette.error.withValues(alpha: palette.isDark ? 0.2 : 0.12),
          palette.error.withValues(alpha: 0.25),
          palette.error,
          Icons.error_rounded,
        ),
      AppSnackBarVariant.warning => (
          palette.warning.withValues(alpha: palette.isDark ? 0.2 : 0.12),
          palette.warning.withValues(alpha: 0.25),
          palette.warning,
          Icons.warning_rounded,
        ),
      AppSnackBarVariant.info => (
          palette.info.withValues(alpha: palette.isDark ? 0.2 : 0.12),
          palette.info.withValues(alpha: 0.25),
          palette.info,
          Icons.info_rounded,
        ),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg.r),
          border: Border.all(color: iconColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(alpha: 0.12),
              blurRadius: 16.r,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18.r),
            ),
            SizedBox(width: AppSpacing.md.w),
            Expanded(
              child: Text(
                message,
                style: t.bodyM.copyWith(
                    color: palette.textPrimary, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
