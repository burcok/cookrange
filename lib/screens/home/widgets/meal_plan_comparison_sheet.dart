import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/weekly_meal_plan_model.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/ai_credit_service.dart';
import '../../../core/services/weekly_meal_plan_service.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../ai/widgets/ai_credits_sheet.dart';

class MealPlanComparisonSheet {
  static Future<void> show(
    BuildContext context, {
    required UserModel user,
    required WeeklyMealPlanModel currentPlan,
    required VoidCallback onApplyAlternate,
  }) async {
    // Credit gate — check before opening sheet
    final isPremium = user.subscriptionTier.isPremiumOrAbove;
    final canUse = await AiCreditService().checkAndConsume(user.uid, isPremium);
    if (!canUse) {
      if (context.mounted) {
        unawaited(
            AiCreditsSheet.show(context, uid: user.uid, isPremium: isPremium));
      }
      return;
    }

    if (!context.mounted) return;
    final locale = context.read<LanguageProvider>().currentLocale.languageCode;

    unawaited(AppSheet.show(
      context: context,
      title: AppLocalizations.of(context).translate('meal_compare.title'),
      child: _MealPlanComparisonBody(
        user: user,
        currentPlan: currentPlan,
        onApplyAlternate: onApplyAlternate,
        locale: locale,
      ),
    ));
  }
}

class _MealPlanComparisonBody extends StatefulWidget {
  final UserModel user;
  final WeeklyMealPlanModel currentPlan;
  final VoidCallback onApplyAlternate;
  final String locale;

  const _MealPlanComparisonBody({
    required this.user,
    required this.currentPlan,
    required this.onApplyAlternate,
    required this.locale,
  });

  @override
  State<_MealPlanComparisonBody> createState() =>
      _MealPlanComparisonBodyState();
}

class _MealPlanComparisonBodyState extends State<_MealPlanComparisonBody> {
  List<PlanAlternate>? _alternates;
  bool _isLoading = true;
  bool _hasError = false;
  int? _selectedAlternateIndex;

  @override
  void initState() {
    super.initState();
    _loadAlternates();
  }

  Future<void> _loadAlternates() async {
    try {
      final alts = await WeeklyMealPlanService()
          .generatePlanAlternates(widget.user, locale: widget.locale);
      if (alts.isEmpty) {
        unawaited(AiCreditService().rollbackCredit(widget.user.uid));
      }
      if (mounted) {
        setState(() {
          _alternates = alts;
          _isLoading = false;
        });
      }
    } on AIQuotaExceededException {
      if (mounted) {
        setState(() => _isLoading = false);
        final isPremium = widget.user.subscriptionTier.isPremiumOrAbove;
        unawaited(AiCreditsSheet.show(context,
            uid: widget.user.uid, isPremium: isPremium));
      }
    } catch (_) {
      unawaited(AiCreditService().rollbackCredit(widget.user.uid));
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;

    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('meal_compare.generating'),
            style: t.bodyM.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 16),
          const AppSkeletonList(itemCount: 2, itemHeight: 160),
        ],
      );
    }

    if (_hasError || (_alternates?.isEmpty ?? true)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          l10n.translate('meal_compare.error'),
          style: t.bodyM.copyWith(color: palette.error),
        ),
      );
    }

    final alternates = _alternates!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('meal_compare.subtitle'),
          style: t.bodyM.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 20),

        // Current plan card
        _PlanCard(
          label: l10n.translate('meal_compare.current_label'),
          name: l10n.translate('meal_compare.current_plan'),
          description: l10n.translate('meal_compare.current_desc'),
          avgCalories: widget.currentPlan.avgDailyCalories,
          avgMacros: widget.currentPlan.avgMacros,
          isSelected: _selectedAlternateIndex == null,
          isCurrent: true,
          palette: palette,
          t: t,
          primary: primary,
          onTap: () => setState(() => _selectedAlternateIndex = null),
        ),

        const SizedBox(height: 12),

        Text(
          l10n.translate('meal_compare.alternates_label'),
          style: t.labelS.copyWith(
            color: palette.textTertiary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),

        ...alternates.asMap().entries.map((entry) {
          final i = entry.key;
          final alt = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PlanCard(
              label: '${l10n.translate('meal_compare.alt_label')} ${i + 1}',
              name: alt.name,
              description: alt.description,
              avgCalories: alt.avgCalories,
              avgMacros: alt.avgMacros,
              isSelected: _selectedAlternateIndex == i,
              isCurrent: false,
              palette: palette,
              t: t,
              primary: primary,
              onTap: () => setState(() => _selectedAlternateIndex = i),
            ),
          );
        }),

        const SizedBox(height: 20),

        AppButton(
          label: _selectedAlternateIndex == null
              ? l10n.translate('meal_compare.keep_plan')
              : l10n.translate('meal_compare.apply_alt'),
          onPressed: () {
            Navigator.pop(context);
            if (_selectedAlternateIndex != null) {
              widget.onApplyAlternate();
            }
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String label;
  final String name;
  final String description;
  final double avgCalories;
  final Map<String, double> avgMacros;
  final bool isSelected;
  final bool isCurrent;
  final AppPalette palette;
  final AppText t;
  final Color primary;
  final VoidCallback onTap;

  const _PlanCard({
    required this.label,
    required this.name,
    required this.description,
    required this.avgCalories,
    required this.avgMacros,
    required this.isSelected,
    required this.isCurrent,
    required this.palette,
    required this.t,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final protein = avgMacros['protein'] ?? 0;
    final carbs = avgMacros['carbs'] ?? 0;
    final fat = avgMacros['fat'] ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primary.withValues(alpha: 0.08) : palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isSelected ? primary : palette.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isCurrent ? palette.info : primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    label.toUpperCase(),
                    style: t.labelS.copyWith(
                      color: isCurrent ? palette.info : primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      fontSize: 10,
                    ),
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: primary, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(name, style: t.titleM.copyWith(color: palette.textPrimary)),
            const SizedBox(height: 4),
            Text(description,
                style: t.bodyM.copyWith(color: palette.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            Row(
              children: [
                _CalorieChip(
                  calories: avgCalories,
                  primary: primary,
                  t: t,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      _MacroBar(
                        label:
                            l10n.translate('nutrition.macro_protein_short'),
                        value: protein,
                        total: protein + carbs + fat,
                        color: palette.protein,
                        t: t,
                      ),
                      const SizedBox(height: 4),
                      _MacroBar(
                        label: l10n.translate('nutrition.macro_carbs_short'),
                        value: carbs,
                        total: protein + carbs + fat,
                        color: palette.carbs,
                        t: t,
                      ),
                      const SizedBox(height: 4),
                      _MacroBar(
                        label: l10n.translate('nutrition.macro_fat_short'),
                        value: fat,
                        total: protein + carbs + fat,
                        color: palette.fat,
                        t: t,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalorieChip extends StatelessWidget {
  final double calories;
  final Color primary;
  final AppText t;

  const _CalorieChip({
    required this.calories,
    required this.primary,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '${calories.round()}',
            style: t.labelL.copyWith(
              color: primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'kcal',
            style: t.labelS.copyWith(
              color: primary.withValues(alpha: 0.7),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final double total;
  final Color color;
  final AppText t;

  const _MacroBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 14,
          child: Text(
            label,
            style: t.labelS.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${value.round()}g',
          style: t.labelS.copyWith(
            color: color.withValues(alpha: 0.8),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
