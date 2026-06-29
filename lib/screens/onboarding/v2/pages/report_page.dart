import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/onboarding_projection_service.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../onboarding_scaffold.dart';
import '../widgets/onboarding_widgets.dart';

/// Page 14 — the personalized report. Summarizes BMI, calorie/water targets,
/// goal timeline, and macros from the projection, with a "why us" block and a
/// medical disclaimer. "Onayla" → registration; "I already have an account"
/// discards onboarding and goes to login.
class OnboardingReportPage extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingReportPage({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  Color _bmiColor(String? cat, AppPalette p) {
    switch (cat) {
      case 'underweight':
        return p.info;
      case 'normal':
        return p.success;
      case 'overweight':
        return p.warning;
      case 'obese':
        return p.error;
      default:
        return p.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    final ob = context.watch<OnboardingProvider>();
    final name = ob.firstName ?? '';
    final locale = Localizations.localeOf(context).languageCode;

    final p = OnboardingProjectionService.compute(
      gender: ob.gender,
      birthDate: ob.birthDate,
      heightCm: ob.height,
      weightKg: ob.weight,
      targetWeightKg: ob.targetWeight,
      mainGoal: ob.mainGoal,
      activityLevel: ob.activityLevel?['value'] as String?,
    );

    final why = [
      'onboarding.v2.report.why1',
      'onboarding.v2.report.why2',
      'onboarding.v2.report.why3',
    ];

    return OnboardingScaffold(
      progress: 1.0,
      onBack: onBack,
      onContinue: onNext,
      continueLabel: l10n.translate('onboarding.v2.report.confirm'),
      child: ListView(
        padding: EdgeInsets.only(top: AppSpacing.lg.h, bottom: AppSpacing.lg.h),
        children: [
          OnboardingSectionLabel(
            title: l10n.translate('onboarding.v2.report.title',
                variables: {'name': name}),
            subtitle: l10n.translate('onboarding.v2.report.subtitle'),
          ),
          SizedBox(height: AppSpacing.lg.h),
          // BMI
          if (p.bmi != null)
            AppCard(
              bordered: true,
              elevated: false,
              padding: EdgeInsets.all(AppSpacing.lg.r),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.translate('onboarding.v2.report.bmi_title'),
                          style: t.labelM
                              .copyWith(color: palette.textTertiary)),
                      SizedBox(height: AppSpacing.xxs.h),
                      Text(p.bmi!.toStringAsFixed(1),
                          style: t.displayM.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
                    decoration: BoxDecoration(
                      color: _bmiColor(p.bmiCategory, palette)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.full.r),
                    ),
                    child: Text(
                      l10n.translate('onboarding.v2.bmi.${p.bmiCategory}'),
                      style: t.labelL.copyWith(
                          color: _bmiColor(p.bmiCategory, palette),
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: AppSpacing.md.h),
          // Calories + water
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.local_fire_department_rounded,
                  label: l10n.translate('onboarding.v2.report.calories_title'),
                  value: p.dailyCalories != null ? '${p.dailyCalories}' : '—',
                  unit: l10n.translate('onboarding.v2.report.calories_unit'),
                  color: primary,
                ),
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: _StatCard(
                  icon: Icons.water_drop_rounded,
                  label: l10n.translate('onboarding.v2.report.water_title'),
                  value: (p.dailyWaterMl / 1000).toStringAsFixed(1),
                  unit: 'L',
                  color: palette.info,
                ),
              ),
            ],
          ),
          if (p.estimatedWeeks != null) ...[
            SizedBox(height: AppSpacing.md.h),
            AppCard(
              bordered: true,
              elevated: false,
              padding: EdgeInsets.all(AppSpacing.md.r),
              child: Row(
                children: [
                  Icon(Icons.flag_rounded, color: primary, size: AppSize.iconMd.r),
                  SizedBox(width: AppSpacing.sm.w),
                  Expanded(
                    child: Text(l10n.translate('onboarding.v2.report.eta_title'),
                        style: t.bodyM.copyWith(color: palette.textSecondary)),
                  ),
                  Text(
                    l10n.translate('onboarding.v2.target.eta_weeks',
                            variables: {'weeks': '${p.estimatedWeeks}'}) +
                        (p.estimatedDate != null
                            ? '  ·  ${DateFormat('MMM yyyy', locale).format(p.estimatedDate!)}'
                            : ''),
                    style: t.titleM.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
          if (p.macros.isNotEmpty) ...[
            SizedBox(height: AppSpacing.lg.h),
            OnboardingGroupLabel(
                title: l10n.translate('onboarding.v2.report.macros_title')),
            SizedBox(height: AppSpacing.sm.h),
            Row(
              children: [
                Expanded(
                    child: _MacroChip(
                        label: l10n.translate('onboarding.v2.report.protein'),
                        grams: p.macros['protein'] ?? 0,
                        color: palette.protein)),
                SizedBox(width: AppSpacing.sm.w),
                Expanded(
                    child: _MacroChip(
                        label: l10n.translate('onboarding.v2.report.carbs'),
                        grams: p.macros['carbs'] ?? 0,
                        color: palette.carbs)),
                SizedBox(width: AppSpacing.sm.w),
                Expanded(
                    child: _MacroChip(
                        label: l10n.translate('onboarding.v2.report.fat'),
                        grams: p.macros['fat'] ?? 0,
                        color: palette.fat)),
              ],
            ),
          ],
          SizedBox(height: AppSpacing.xl.h),
          OnboardingGroupLabel(
              title: l10n.translate('onboarding.v2.report.why_title')),
          SizedBox(height: AppSpacing.sm.h),
          ...why.map((w) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_rounded,
                        size: AppSize.iconMd.r, color: primary),
                    SizedBox(width: AppSpacing.sm.w),
                    Expanded(
                      child: Text(l10n.translate(w),
                          style: t.bodyM.copyWith(
                              color: palette.textPrimary, height: 1.4)),
                    ),
                  ],
                ),
              )),
          SizedBox(height: AppSpacing.md.h),
          OnboardingInfoNote(
            text: l10n.translate('onboarding.v2.report.disclaimer'),
            icon: Icons.health_and_safety_outlined,
            color: palette.warning,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return AppCard(
      bordered: true,
      elevated: false,
      padding: EdgeInsets.all(AppSpacing.md.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: AppSize.iconMd.r),
          SizedBox(height: AppSpacing.sm.h),
          Text(label, style: t.labelS.copyWith(color: palette.textTertiary)),
          SizedBox(height: AppSpacing.xxs.h),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: value,
                  style: t.headlineM.copyWith(
                      color: palette.textPrimary, fontWeight: FontWeight.w800)),
              TextSpan(
                  text: ' $unit',
                  style: t.labelM.copyWith(color: palette.textSecondary)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final int grams;
  final Color color;
  const _MacroChip(
      {required this.label, required this.grams, required this.color});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return Container(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
      ),
      child: Column(
        children: [
          Text('${grams}g',
              style: t.titleM
                  .copyWith(color: color, fontWeight: FontWeight.w800)),
          SizedBox(height: 2.h),
          Text(label, style: t.labelS.copyWith(color: palette.textSecondary)),
        ],
      ),
    );
  }
}
