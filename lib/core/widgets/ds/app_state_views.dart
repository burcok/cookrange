import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import 'app_button.dart';

/// Shared scaffolding for centered, illustrated state views (empty / error).
class _CenteredState extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  const _CenteredState({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  State<_CenteredState> createState() => _CenteredStateState();
}

class _CenteredStateState extends State<_CenteredState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  )..forward();

  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: AppMotion.decelerate);
  late final Animation<double> _scale =
      Tween<double>(begin: 0.85, end: 1).animate(
    CurvedAnimation(parent: _c, curve: AppMotion.emphasized),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final iconBox = widget.compact ? 64.0 : 96.0;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: FadeTransition(
                opacity: _fade,
                child: Container(
                  width: iconBox.r,
                  height: iconBox.r,
                  decoration: BoxDecoration(
                    color: widget.iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.iconColor,
                    size: (widget.compact ? 30 : 44).r,
                  ),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.lg.h),
            FadeTransition(
              opacity: _fade,
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                style: widget.compact ? t.titleL : t.headlineS,
              ),
            ),
            if (widget.message != null) ...[
              SizedBox(height: AppSpacing.xs.h),
              FadeTransition(
                opacity: _fade,
                child: Text(
                  widget.message!,
                  textAlign: TextAlign.center,
                  style: t.bodyM,
                ),
              ),
            ],
            if (widget.actionLabel != null && widget.onAction != null) ...[
              SizedBox(height: AppSpacing.xl.h),
              FadeTransition(
                opacity: _fade,
                child: AppButton(
                  label: widget.actionLabel!,
                  onPressed: widget.onAction,
                  size: AppButtonSize.medium,
                  expand: false,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Branded empty state — illustrated icon, title, optional message + CTA.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    return Semantics(
      liveRegion: true,
      label: [title, if (message != null) message].join('. '),
      child: _CenteredState(
        icon: icon,
        iconColor: primary,
        iconBg: primary.withValues(alpha: palette.isDark ? 0.18 : 0.10),
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
        compact: compact,
      ),
    );
  }
}

/// Branded error state — friendly, with retry. Use full-screen or inline.
class AppErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final bool compact;

  const AppErrorState({
    super.key,
    required this.title,
    this.message,
    this.retryLabel,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('🔴 [AppErrorState] Title: $title');
      if (message != null) {
        debugPrint('🔴 [AppErrorState] Message: $message');
      }
    }

    final palette = AppPalette.of(context);
    return Semantics(
      liveRegion: true,
      label: [title, if (message != null) message].join('. '),
      child: _CenteredState(
        icon: Icons.error_outline_rounded,
        iconColor: palette.error,
        iconBg: palette.error.withValues(alpha: palette.isDark ? 0.18 : 0.10),
        title: title,
        message: message,
        actionLabel: onRetry != null ? (retryLabel ?? 'Retry') : null,
        onAction: onRetry,
        compact: compact,
      ),
    );
  }
}
