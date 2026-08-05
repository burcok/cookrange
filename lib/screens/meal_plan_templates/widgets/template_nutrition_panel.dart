import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/plan_nutrition_calculator.dart';
import '../../../core/widgets/ds/ds.dart';

/// Faz 3 §3.3 — "her düzenlemede anlık besin değeri": a day/week toggle over
/// a calorie ring + macro bars + a colored deviation badge, recomputed from
/// live [PlanNutritionCalculator] totals on every parent rebuild (the parent
/// re-runs the calculator on every edit — this widget never sums anything
/// itself, only renders numbers it's given).
class TemplateNutritionPanel extends StatefulWidget {
  final PlanNutritionTotals dayTotals;

  /// Per-day AVERAGE across the week (`WeekNutritionTotals.average`) — the
  /// same "average daily" shape `WeeklyMealPlanModel.avgDailyCalories`/
  /// `avgMacros` already use, so the week view reads as "a typical day on
  /// this plan", comparable apples-to-apples against the day view.
  final PlanNutritionTotals weekAverageTotals;
  final double targetCalories;
  final Map<String, double> targetMacros;

  const TemplateNutritionPanel({
    super.key,
    required this.dayTotals,
    required this.weekAverageTotals,
    required this.targetCalories,
    required this.targetMacros,
  });

  @override
  State<TemplateNutritionPanel> createState() => _TemplateNutritionPanelState();
}

class _TemplateNutritionPanelState extends State<TemplateNutritionPanel> {
  bool _showWeek = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);
    final palette = AppPalette.of(context);
    final totals = _showWeek ? widget.weekAverageTotals : widget.dayTotals;
    final targetProtein = widget.targetMacros['protein'] ?? 0;
    final targetCarbs = widget.targetMacros['carbs'] ?? 0;
    final targetFat = widget.targetMacros['fat'] ?? 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.translate('template_builder.nutrition.title'),
                  style: t.titleL,
                ),
              ),
              SizedBox(
                width: 150.w,
                child: AppSegmentedControl(
                  labels: [
                    l10n.translate('template_builder.nutrition.view_day'),
                    l10n.translate('template_builder.nutrition.view_week'),
                  ],
                  selectedIndex: _showWeek ? 1 : 0,
                  onChanged: (i) => setState(() => _showWeek = i == 1),
                  height: 32.h,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),
          Row(
            children: [
              AppCalorieRing(
                consumed: totals.calories,
                target: widget.targetCalories,
                size: 108,
                strokeWidth: 10,
                caption: widget.targetCalories > 0
                    ? l10n.translate('template_builder.nutrition.of_target',
                        variables: {
                            'target': widget.targetCalories.round().toString(),
                          })
                    : null,
              ),
              SizedBox(width: AppSpacing.lg.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DeviationBadge(
                      deviation: PlanNutritionCalculator.classifyDeviation(
                          totals.calories, widget.targetCalories),
                      l10n: l10n,
                      palette: palette,
                      t: t,
                    ),
                    SizedBox(height: AppSpacing.sm.h),
                    _MacroBar(
                      label: l10n.translate('nutrition.macro_protein_short'),
                      value: totals.protein,
                      target: targetProtein,
                      color: palette.protein,
                    ),
                    SizedBox(height: 6.h),
                    _MacroBar(
                      label: l10n.translate('nutrition.macro_carbs_short'),
                      value: totals.carbs,
                      target: targetCarbs,
                      color: palette.carbs,
                    ),
                    SizedBox(height: 6.h),
                    _MacroBar(
                      label: l10n.translate('nutrition.macro_fat_short'),
                      value: totals.fat,
                      target: targetFat,
                      color: palette.fat,
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      l10n.translate('template_builder.nutrition.fiber_line',
                          variables: {
                            'g': totals.fiber.round().toString(),
                          }),
                      style: t.labelS.copyWith(color: palette.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Green/amber/red pill — the single "colored deviation indicator" §3.3 asks
/// for, driven by [PlanNutritionCalculator.classifyDeviation] so the exact
/// same ±10% band backs every deviation reading on this screen (calories
/// AND each macro bar below).
class _DeviationBadge extends StatelessWidget {
  final NutritionDeviation deviation;
  final AppLocalizations l10n;
  final AppPalette palette;
  final AppText t;

  const _DeviationBadge({
    required this.deviation,
    required this.l10n,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final (color, key, icon) = switch (deviation) {
      NutritionDeviation.under => (
          palette.warning,
          'template_builder.nutrition.deviation_under',
          Icons.arrow_downward_rounded
        ),
      NutritionDeviation.over => (
          palette.error,
          'template_builder.nutrition.deviation_over',
          Icons.arrow_upward_rounded
        ),
      NutritionDeviation.onTarget => (
          palette.success,
          'template_builder.nutrition.deviation_on_target',
          Icons.check_rounded
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.r, color: color),
          SizedBox(width: 4.w),
          Text(
            l10n.translate(key),
            style: t.labelS.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    // Bar fill is relative to whichever is larger — so overshooting the
    // target visibly overflows the track color instead of silently capping
    // at 100%, matching the calorie ring's own clamp-at-1.0-but-show-the-
    // number-uncapped convention (the number is never lied to, the fill is).
    final denom = target > 0 ? target : (value > 0 ? value : 1);
    final pct = (value / denom).clamp(0.0, 1.0);
    final deviation = PlanNutritionCalculator.classifyDeviation(value, target);

    return Row(
      children: [
        SizedBox(
          width: 16.w,
          child: Text(
            label,
            style: t.labelS.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(width: 6.w),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full.r),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6.h,
              backgroundColor: color.withValues(alpha: 0.15),
              color: color,
            ),
          ),
        ),
        SizedBox(width: 6.w),
        SizedBox(
          width: 34.w,
          child: Text(
            '${value.round()}g',
            textAlign: TextAlign.end,
            style: t.labelS.copyWith(color: color.withValues(alpha: 0.85)),
          ),
        ),
        SizedBox(width: 4.w),
        Icon(
          switch (deviation) {
            NutritionDeviation.under => Icons.arrow_downward_rounded,
            NutritionDeviation.over => Icons.arrow_upward_rounded,
            NutritionDeviation.onTarget => Icons.check_rounded,
          },
          size: 11.r,
          color: switch (deviation) {
            NutritionDeviation.under => AppPalette.of(context).warning,
            NutritionDeviation.over => AppPalette.of(context).error,
            NutritionDeviation.onTarget => AppPalette.of(context).success,
          },
        ),
      ],
    );
  }
}
