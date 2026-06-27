import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_palette.dart';

/// Cookrange Design System — standard content surface.
///
/// Theme-aware card with consistent radius, soft shadow and optional tap
/// (with press-scale + haptics). Use instead of ad-hoc `Container` decorations.
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final bool bordered;
  final bool elevated;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
    this.radius = AppRadius.card,
    this.bordered = false,
    this.elevated = true,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.instant,
    upperBound: 0.03,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final surface = widget.color ?? palette.surface;

    final card = AnimatedBuilder(
      animation: _c,
      builder: (context, child) =>
          Transform.scale(scale: 1 - _c.value, child: child),
      child: Container(
        padding: EdgeInsets.all(
          (widget.padding is EdgeInsets
                  ? (widget.padding as EdgeInsets).top
                  : AppSpacing.md)
              .r,
        ),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(widget.radius.r),
          border: widget.bordered
              ? Border.all(color: palette.border)
              : null,
          boxShadow: widget.elevated
              ? [
                  BoxShadow(
                    color: palette.shadow.withValues(
                        alpha: palette.isDark
                            ? AppElevation.opacityStrong
                            : AppElevation.opacityLight),
                    blurRadius: AppElevation.blurMd.r,
                    offset: AppElevation.offsetMd,
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );

    if (widget.onTap == null) return card;

    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) => _c.reverse(),
      onTapCancel: () => _c.reverse(),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap!();
      },
      child: card,
    );
  }
}

/// Frosted-glass surface — for premium hero cards / overlays.
class AppGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;

  const AppGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.card,
    this.blur = 12,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: EdgeInsets.all(
            (padding is EdgeInsets
                    ? (padding as EdgeInsets).top
                    : AppSpacing.lg)
                .r,
          ),
          decoration: BoxDecoration(
            color: palette.surface
                .withValues(alpha: palette.isDark ? 0.55 : 0.65),
            borderRadius: BorderRadius.circular(radius.r),
            border: Border.all(
              color: palette.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.6),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
