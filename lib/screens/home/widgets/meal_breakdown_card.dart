import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/food_log_model.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/ds/ds.dart';

class MealBreakdownCard extends StatelessWidget {
  final Map<String, NutritionTotals> breakdown;

  const MealBreakdownCard({super.key, required this.breakdown});

  static const _mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);

    final orderedEntries = _mealOrder
        .where((m) => breakdown.containsKey(m))
        .map((m) => MapEntry(m, breakdown[m]!))
        .toList();

    if (orderedEntries.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.pie_chart_rounded, color: primary, size: 16.sp),
              ),
              SizedBox(width: 10.w),
              Text(l10n.translate('home.meal_breakdown.title'),
                  style: t.titleL),
            ],
          ),
          SizedBox(height: 14.h),
          ...orderedEntries.map((e) => _MealRow(
                mealType: e.key,
                totals: e.value,
                primary: primary,
                palette: palette,
                l10n: l10n,
                t: t,
              )),
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  final String mealType;
  final NutritionTotals totals;
  final Color primary;
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _MealRow({
    required this.mealType,
    required this.totals,
    required this.primary,
    required this.palette,
    required this.l10n,
    required this.t,
  });

  IconData get _icon {
    switch (mealType) {
      case 'breakfast':
        return Icons.wb_sunny_rounded;
      case 'lunch':
        return Icons.light_mode_rounded;
      case 'dinner':
        return Icons.nights_stay_rounded;
      default:
        return Icons.cookie_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: palette.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.sm.r),
            ),
            child: Icon(_icon, color: primary, size: 16.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.translate('food_scan.meal.$mealType'),
                      style: t.titleM,
                    ),
                    Text(
                      '${totals.calories.toInt()} kcal',
                      style: t.labelM.copyWith(
                          color: palette.calories, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    _MacroChip(
                        label:
                            l10n.translate('nutrition.macro_protein_short'),
                        value: totals.protein.toInt(),
                        color: palette.protein),
                    SizedBox(width: 6.w),
                    _MacroChip(
                        label: l10n.translate('nutrition.macro_carbs_short'),
                        value: totals.carbs.toInt(),
                        color: palette.carbs),
                    SizedBox(width: 6.w),
                    _MacroChip(
                        label: l10n.translate('nutrition.macro_fat_short'),
                        value: totals.fat.toInt(),
                        color: palette.fat),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MacroChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs.r),
      ),
      child: Text(
        '$label: ${value}g',
        style: AppText.of(context)
            .labelS
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
