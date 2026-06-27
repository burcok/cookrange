import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';

// ──────────────────────────────────────────────────────────────────────────────
// AppSegmentedControl
// ──────────────────────────────────────────────────────────────────────────────

/// iOS-style segmented control with a sliding primary-color indicator.
///
/// Usage:
/// ```dart
/// AppSegmentedControl(
///   labels: ['Active', 'Mine'],
///   selectedIndex: _tab,
///   onChanged: (i) => setState(() => _tab = i),
/// )
/// ```
class AppSegmentedControl extends StatelessWidget {
  final List<String> labels;
  final List<IconData?>? icons;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double? height;

  const AppSegmentedControl({
    super.key,
    required this.labels,
    this.icons,
    required this.selectedIndex,
    required this.onChanged,
    this.height,
  }) : assert(labels.length >= 2 && labels.length <= 5);

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final h = height ?? 40.h;

    return Container(
      height: h,
      padding: EdgeInsets.all(2.r),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.full.r),
        border: Border.all(color: palette.border.withValues(alpha: 0.4)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segW = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              // Sliding pill indicator
              AnimatedPositioned(
                duration: AppMotion.fast,
                curve: AppMotion.standard,
                left: selectedIndex * segW,
                width: segW,
                top: 0,
                bottom: 0,
                child: Container(
                  margin: EdgeInsets.all(1.r),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular((AppRadius.full - 2).r),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.3),
                        blurRadius: 6.r,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Label row — sits above the indicator
              Row(
                children: List.generate(labels.length, (i) {
                  final isSelected = i == selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(i),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icons != null && icons![i] != null) ...[
                            AnimatedSwitcher(
                              duration: AppMotion.fast,
                              child: Icon(
                                icons![i],
                                key: ValueKey('${i}_$isSelected'),
                                size: 14.r,
                                color: isSelected
                                    ? Colors.white
                                    : palette.textSecondary,
                              ),
                            ),
                            SizedBox(width: 4.w),
                          ],
                          Text(
                            labels[i],
                            style: t.labelM.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : palette.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// AppChipPicker
// ──────────────────────────────────────────────────────────────────────────────

/// A single chip option for [AppChipPicker].
class AppChipOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const AppChipOption({required this.value, required this.label, this.icon});
}

/// Wrap-layout chip picker supporting single or multi-select.
///
/// Usage:
/// ```dart
/// AppChipPicker<String>(
///   options: [
///     AppChipOption(value: 'steps', label: 'Steps', icon: Icons.directions_walk),
///     AppChipOption(value: 'calories', label: 'Calories', icon: Icons.local_fire_department),
///   ],
///   selected: {_selectedType},
///   onToggle: (v) => setState(() => _selectedType = v),
/// )
/// ```
class AppChipPicker<T> extends StatelessWidget {
  final List<AppChipOption<T>> options;

  /// Currently selected values (single-select → set with one item).
  final Set<T> selected;

  /// Called when a chip is tapped with the tapped value.
  final ValueChanged<T> onToggle;

  /// If false (default), tapping a selected chip does nothing (single-select).
  /// If true, allows deselecting — caller must handle the empty set case.
  final bool multiSelect;

  const AppChipPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.multiSelect = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;

    return Wrap(
      spacing: AppSpacing.xs.w,
      runSpacing: AppSpacing.xs.h,
      children: options.map((opt) {
        final isSelected = selected.contains(opt.value);
        return GestureDetector(
          onTap: () {
            if (!multiSelect && isSelected) return;
            onToggle(opt.value);
          },
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w,
              vertical: (AppSpacing.xs + 2).h,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? primary.withValues(alpha: 0.12)
                  : palette.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.full.r),
              border: Border.all(
                color: isSelected
                    ? primary.withValues(alpha: 0.7)
                    : palette.border,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (opt.icon != null) ...[
                  Icon(
                    opt.icon,
                    size: 14.r,
                    color: isSelected ? primary : palette.textSecondary,
                  ),
                  SizedBox(width: 4.w),
                ],
                Text(
                  opt.label,
                  style: t.labelM.copyWith(
                    color: isSelected ? primary : palette.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (isSelected && multiSelect) ...[
                  SizedBox(width: 4.w),
                  Icon(Icons.check_rounded, size: 13.r, color: primary),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// AppToggle
// ──────────────────────────────────────────────────────────────────────────────

/// Branded toggle switch. If [label] is provided, renders a row with
/// the label (and optional [description]) on the left and the switch on the right.
///
/// Usage:
/// ```dart
/// AppToggle(
///   value: _isPublic,
///   onChanged: (v) => setState(() => _isPublic = v),
///   label: 'Public challenge',
///   description: 'Anyone can join',
/// )
/// ```
class AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? description;

  const AppToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;

    final sw = Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: primary,
      inactiveThumbColor: palette.textTertiary,
      inactiveTrackColor: palette.surfaceVariant,
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary.withValues(alpha: 0.4);
        }
        return palette.border;
      }),
    );

    if (label == null) return sw;

    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label!,
                  style: t.bodyM.copyWith(color: palette.textPrimary),
                ),
                if (description != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    description!,
                    style: t.labelS.copyWith(color: palette.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          sw,
        ],
      ),
    );
  }
}
