import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, tonal, ghost, destructive }

enum AppButtonSize { small, medium, large }

/// Cookrange Design System — the one button.
///
/// Variants, sizes, leading/trailing icons, built-in loading spinner, disabled
/// styling, press-scale micro-interaction, and haptic feedback. Use this instead
/// of raw `ElevatedButton` / `OutlinedButton` everywhere (Rule R7).
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final bool expand;
  final bool enableHaptics;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
    this.enableHaptics = true,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.instant,
    upperBound: 0.04,
  );

  bool get _disabled => widget.onPressed == null || widget.loading;

  void _onTapDown(_) {
    if (_disabled) return;
    _c.forward();
  }

  void _onTapUp(_) {
    if (_c.isAnimating || _c.value > 0) _c.reverse();
  }

  void _onTap() {
    if (_disabled) return;
    if (widget.enableHaptics) HapticFeedback.lightImpact();
    widget.onPressed!.call();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _height {
    switch (widget.size) {
      case AppButtonSize.small:
        return AppSize.buttonHeightSm;
      case AppButtonSize.medium:
        return 46;
      case AppButtonSize.large:
        return AppSize.buttonHeight;
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case AppButtonSize.small:
        return 13;
      case AppButtonSize.medium:
        return 14;
      case AppButtonSize.large:
        return 15;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final t = AppText.of(context);

    final _ButtonStyle style = _resolveStyle(palette, primary);
    final contentColor = _disabled
        ? style.foreground.withValues(alpha: 0.45)
        : style.foreground;

    Widget content = widget.loading
        ? SizedBox(
            width: 18.r,
            height: 18.r,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(contentColor),
            ),
          )
        : Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: AppSize.iconSm.r, color: contentColor),
                SizedBox(width: AppSpacing.xs.w),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelL.copyWith(
                    fontSize: _fontSize.sp,
                    color: contentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.trailingIcon != null) ...[
                SizedBox(width: AppSpacing.xs.w),
                Icon(widget.trailingIcon,
                    size: AppSize.iconSm.r, color: contentColor),
              ],
            ],
          );

    return Semantics(
      button: true,
      enabled: !_disabled,
      label: widget.loading ? '${widget.label}, loading' : widget.label,
      onTap: _disabled ? null : _onTap,
      child: GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: () => _onTapUp(null),
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.scale(
          scale: 1 - _c.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          height: _height.h,
          width: widget.expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _disabled
                ? style.background.withValues(
                    alpha: style.background.a == 0 ? 0 : 0.5)
                : style.background,
            borderRadius: BorderRadius.circular(AppRadius.button.r),
            border: style.borderColor != null
                ? Border.all(
                    color: _disabled
                        ? style.borderColor!.withValues(alpha: 0.4)
                        : style.borderColor!,
                    width: 1.5,
                  )
                : null,
            boxShadow: style.elevated && !_disabled
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.28),
                      blurRadius: AppElevation.blurMd.r,
                      offset: AppElevation.offsetMd,
                    ),
                  ]
                : null,
          ),
          child: content,
        ),
      ),
      ),
    );
  }

  _ButtonStyle _resolveStyle(AppPalette palette, Color primary) {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return _ButtonStyle(
          background: primary,
          foreground: Colors.white,
          elevated: true,
        );
      case AppButtonVariant.secondary:
        return _ButtonStyle(
          background: Colors.transparent,
          foreground: primary,
          borderColor: primary,
        );
      case AppButtonVariant.tonal:
        return _ButtonStyle(
          background:
              primary.withValues(alpha: palette.isDark ? 0.20 : 0.10),
          foreground: primary,
        );
      case AppButtonVariant.ghost:
        return _ButtonStyle(
          background: Colors.transparent,
          foreground: palette.textPrimary,
        );
      case AppButtonVariant.destructive:
        return _ButtonStyle(
          background: palette.error,
          foreground: Colors.white,
        );
    }
  }
}

class _ButtonStyle {
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final bool elevated;

  const _ButtonStyle({
    required this.background,
    required this.foreground,
    this.borderColor,
    this.elevated = false,
  });
}
