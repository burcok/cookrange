import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../../core/widgets/ds/ds.dart';

/// A page heading: large title + optional supporting line. Used at the top of
/// every V2 onboarding page for a consistent rhythm.
class OnboardingSectionLabel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final EdgeInsets? padding;

  const OnboardingSectionLabel({
    super.key,
    required this.title,
    this.subtitle,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: t.displayM.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: AppSpacing.sm.h),
            Text(
              subtitle!,
              style:
                  t.bodyL.copyWith(color: palette.textSecondary, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// A smaller in-page group header (e.g. "Allergies", "Your cooking level").
class OnboardingGroupLabel extends StatelessWidget {
  final String title;
  final String? trailing;
  const OnboardingGroupLabel({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: t.headlineS.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: t.labelS.copyWith(color: palette.textTertiary),
          ),
      ],
    );
  }
}

/// Compact selectable chip (icon + label + check) for [Wrap] layouts:
/// motivators, allergies, dietary prefs, equipment. Press-scale for 60fps feel.
class OnboardingChoiceChip extends StatefulWidget {
  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const OnboardingChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.selectedColor,
  });

  @override
  State<OnboardingChoiceChip> createState() => _OnboardingChoiceChipState();
}

class _OnboardingChoiceChipState extends State<OnboardingChoiceChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final accent =
        widget.selectedColor ?? context.read<ThemeProvider>().primaryColor;
    final on = widget.selected;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: AppMotion.fast,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
          decoration: BoxDecoration(
            color: on ? accent.withValues(alpha: 0.12) : palette.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(
              color: on ? accent : palette.border,
              width: on ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    size: AppSize.iconSm.r,
                    color: on ? accent : palette.textSecondary),
                SizedBox(width: AppSpacing.xs.w),
              ],
              Text(
                widget.label,
                style: t.labelM.copyWith(
                  color: on ? accent : palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (on) ...[
                SizedBox(width: AppSpacing.xxs.w),
                Icon(Icons.check_circle_rounded, size: 15.r, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width selectable row (icon + title + optional subtitle + check/radio).
/// Used for single-pick lists: main goal, activity level, cooking level.
class OnboardingChoiceCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  const OnboardingChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  @override
  State<OnboardingChoiceCard> createState() => _OnboardingChoiceCardState();
}

class _OnboardingChoiceCardState extends State<OnboardingChoiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final accent = context.read<ThemeProvider>().primaryColor;
    final on = widget.selected;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: AppMotion.fast,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: EdgeInsets.all(AppSpacing.md.r),
          decoration: BoxDecoration(
            color: on ? accent.withValues(alpha: 0.10) : palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg.r),
            border: Border.all(
              color: on ? accent : palette.border,
              width: on ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: on
                      ? accent.withValues(alpha: 0.16)
                      : palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                ),
                child: Icon(widget.icon,
                    size: AppSize.iconMd.r,
                    color: on ? accent : palette.textSecondary),
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: t.titleM.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        widget.subtitle!,
                        style: t.labelM.copyWith(color: palette.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              widget.trailing ??
                  AnimatedContainer(
                    duration: AppMotion.fast,
                    width: 24.r,
                    height: 24.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? accent : Colors.transparent,
                      border: Border.all(
                        color: on ? accent : palette.border,
                        width: 2,
                      ),
                    ),
                    child: on
                        ? Icon(Icons.check_rounded,
                            size: 15.r, color: palette.textInverse)
                        : null,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tappable value field (label + value + chevron) for metric pickers
/// (age / height / weight / date).
class OnboardingMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const OnboardingMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final accent = context.read<ThemeProvider>().primaryColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w, vertical: AppSpacing.md.h),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg.r),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: AppSize.iconMd.r, color: accent),
            SizedBox(width: AppSpacing.sm.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: t.labelS.copyWith(color: palette.textTertiary)),
                  SizedBox(height: 2.h),
                  Text(
                    value,
                    style: t.titleM.copyWith(
                      color: filled
                          ? palette.textPrimary
                          : palette.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.unfold_more_rounded,
                size: AppSize.iconSm.r, color: palette.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Soft inline note — for disclaimers, "why we ask", and optional hints.
class OnboardingInfoNote extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;

  const OnboardingInfoNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final c = color ?? palette.info;
    return Container(
      padding: EdgeInsets.all(AppSpacing.sm.r),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSize.iconSm.r, color: c),
          SizedBox(width: AppSpacing.xs.w),
          Expanded(
            child: Text(
              text,
              style: t.bodyM.copyWith(color: palette.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
