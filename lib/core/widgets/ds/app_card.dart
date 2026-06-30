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

  /// Screen-reader label for tappable cards. If null and [onTap] is set,
  /// TalkBack/VoiceOver will fall back to the card's visible text content.
  final String? semanticLabel;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
    this.radius = AppRadius.card,
    this.bordered = false,
    this.elevated = true,
    this.semanticLabel,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
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
        padding: widget.padding is EdgeInsets
            ? EdgeInsets.fromLTRB(
                (widget.padding as EdgeInsets).left.w,
                (widget.padding as EdgeInsets).top.h,
                (widget.padding as EdgeInsets).right.w,
                (widget.padding as EdgeInsets).bottom.h,
              )
            : EdgeInsets.all(AppSpacing.md.r),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(widget.radius.r),
          border: widget.bordered ? Border.all(color: palette.border) : null,
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

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      child: GestureDetector(
        onTapDown: (_) => _c.forward(),
        onTapUp: (_) => _c.reverse(),
        onTapCancel: () => _c.reverse(),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap!();
        },
        child: card,
      ),
    );
  }
}

/// Frosted-glass surface — for premium hero cards / overlays.
///
/// Uses semantic [AppPalette] glass tokens so it automatically adapts to
/// dark/light themes. Supports [onTap] with a press-scale animation.
class AppGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const AppGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.card,
    this.blur = AppPalette.glassBlurDefault,
    this.onTap,
    this.semanticLabel,
  });

  @override
  State<AppGlassCard> createState() => _AppGlassCardState();
}

class _AppGlassCardState extends State<AppGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.instant,
    upperBound: 0.025,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  EdgeInsets _scaleInsets(EdgeInsetsGeometry p) {
    if (p is EdgeInsets) {
      return EdgeInsets.fromLTRB(
        p.left.w,
        p.top.h,
        p.right.w,
        p.bottom.h,
      );
    }
    return EdgeInsets.all(AppSpacing.lg.r);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final mq = MediaQuery.of(context);
    final reduceTransparency = mq.highContrast;

    final borderRadius = BorderRadius.circular(widget.radius.r);

    Widget glass = AnimatedBuilder(
      animation: _c,
      builder: (context, child) =>
          Transform.scale(scale: 1 - _c.value, child: child),
      child: reduceTransparency
          // ── Accessibility path: solid surface, no blur ──────────────────
          ? Container(
              padding: _scaleInsets(widget.padding),
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.97),
                borderRadius: borderRadius,
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow.withValues(
                        alpha: palette.isDark
                            ? AppElevation.opacityStrong
                            : AppElevation.opacityLight),
                    blurRadius: AppElevation.blurMd.r,
                    offset: AppElevation.offsetMd,
                  ),
                ],
              ),
              child: widget.child,
            )
          // ── Normal path: frosted glass ──────────────────────────────────
          : ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter:
                    ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
                child: Container(
                  padding: _scaleInsets(widget.padding),
                  decoration: BoxDecoration(
                    color: palette.glassFill,
                    borderRadius: borderRadius,
                    border: Border.all(color: palette.glassStroke),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        palette.glassHighlight,
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5],
                    ),
                  ),
                  child: widget.child,
                ),
              ),
            ),
    );

    // Wrap in Semantics whenever there is a label or the card is tappable.
    if (widget.semanticLabel != null || widget.onTap != null) {
      glass = Semantics(
        button: widget.onTap != null,
        label: widget.semanticLabel,
        child: glass,
      );
    }

    if (widget.onTap == null) return glass;

    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) => _c.reverse(),
      onTapCancel: () => _c.reverse(),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap!();
      },
      child: glass,
    );
  }
}
