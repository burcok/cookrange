import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';

/// Canonical single-row, horizontally-scrollable filter bar used across the
/// app (gym & coach discovery, program marketplace, community feed, group
/// discovery). Build pills with [AppFilterPill] and insert [AppFilterDivider]
/// to separate logical groups (e.g. location vs sort).
///
/// ```dart
/// AppFilterBar(children: [
///   AppFilterPill.picker(label: city ?? 'City', active: city != null, onTap: pickCity),
///   const AppFilterDivider(),
///   AppFilterPill(label: 'Popular', icon: Icons.local_fire_department_rounded,
///       active: sort == 'popular', onTap: () => setSort('popular')),
/// ])
/// ```
class AppFilterBar extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double? height;

  const AppFilterBar({
    super.key,
    required this.children,
    this.padding,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Interleave a fixed gap between pills (dividers carry their own margin).
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i != children.length - 1) spaced.add(SizedBox(width: 6.w));
    }

    return SizedBox(
      height: height ?? 40.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: padding ?? EdgeInsets.symmetric(horizontal: 16.w),
        children: spaced,
      ),
    );
  }
}

/// A vertical divider for separating filter-pill groups inside [AppFilterBar].
class AppFilterDivider extends StatelessWidget {
  const AppFilterDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        indent: 6.h,
        endIndent: 6.h,
        color: palette.border,
      ),
    );
  }
}

/// A single filter pill matching the canonical 34h design.
///
/// Two styles:
/// - **sort/category** (default): leading icon (or a check when active), label.
///   Fill is transparent when inactive, accent-tinted when active.
/// - **picker** ([AppFilterPill.picker]): leading icon, value/placeholder label,
///   trailing chevron when inactive / check when active. Fill is a neutral
///   surface when inactive (so it reads as a tappable dropdown), accent-tinted
///   when active.
class AppFilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback? onTap;

  /// Picker style (trailing chevron/check, neutral inactive fill).
  final bool picker;

  /// Per-pill accent (defaults to the theme primary). Used e.g. for community
  /// topic colors or the energy-tinted "Near me" pill.
  final Color? accent;

  /// Shows a small spinner instead of the leading icon (e.g. resolving GPS).
  final bool loading;

  const AppFilterPill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.accent,
    this.loading = false,
  }) : picker = false;

  const AppFilterPill.picker({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.accent,
    this.loading = false,
  }) : picker = true;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = AppText.of(context);
    final color = accent ?? Theme.of(context).primaryColor;

    final Color bg = active
        ? color.withValues(alpha: 0.1)
        : (picker ? palette.surfaceVariant : Colors.transparent);
    final Color borderColor =
        active ? color.withValues(alpha: 0.45) : palette.border;
    final Color fg = active ? color : palette.textSecondary;

    // Geometry mirrors the canonical gym/coach pills exactly:
    // picker → icon 13r + 5w gap + label + 4w + chevron/check 13r.
    // sort   → (check 11r | icon 12r) + 4w gap + label.
    final double leadingGap = picker ? 5.w : 4.w;

    Widget leading;
    if (loading) {
      leading = SizedBox(
        width: 12.r,
        height: 12.r,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
      );
    } else if (picker) {
      leading = Icon(icon ?? Icons.tune_rounded,
          size: 13.r, color: active ? color : palette.textSecondary);
    } else {
      // Sort/category: a check replaces the icon when active.
      leading = Icon(
        active ? Icons.check_rounded : (icon ?? Icons.circle_outlined),
        size: active ? 11.r : 12.r,
        color: active ? color : palette.textTertiary,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        height: 34.h,
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.full.r),
          border: Border.all(
            color: borderColor,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading || icon != null || !picker) ...[
              leading,
              // While loading we show only the spinner (matches gym "Near me").
              if (!loading) SizedBox(width: leadingGap),
            ],
            // Label hidden during loading.
            if (!loading)
              Text(
                label,
                style: text.labelM.copyWith(
                  fontSize: 12.sp,
                  color: fg,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            if (picker && !loading) ...[
              SizedBox(width: 4.w),
              Icon(
                active
                    ? Icons.check_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 13.r,
                color: active ? color : palette.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
