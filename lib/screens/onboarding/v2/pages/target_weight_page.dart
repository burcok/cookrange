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

/// Page 5 — target weight with a live, medically-safe projection. As the user
/// drags the slider, the pace/ETA recompute via [OnboardingProjectionService]
/// (rate clamped to a safe range) with a "not medical advice" disclaimer.
class OnboardingTargetWeightPage extends StatefulWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingTargetWeightPage({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<OnboardingTargetWeightPage> createState() =>
      _OnboardingTargetWeightPageState();
}

class _OnboardingTargetWeightPageState
    extends State<OnboardingTargetWeightPage> {
  @override
  void initState() {
    super.initState();
    // Default the target to current weight so the page is valid on arrival;
    // the user slides to adjust.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ob = context.read<OnboardingProvider>();
      if (ob.targetWeight == null && ob.weight != null) {
        ob.setTargetWeight(ob.weight);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    final ob = context.watch<OnboardingProvider>();
    final name = ob.firstName ?? '';

    final current = ob.weight ?? 70;
    final target = ob.targetWeight ?? current;
    final minW = (current * 0.6).round().clamp(40, 250);
    final maxW = (current * 1.4).round().clamp(45, 300);

    final projection = OnboardingProjectionService.compute(
      gender: ob.gender,
      birthDate: ob.birthDate,
      heightCm: ob.height,
      weightKg: current,
      targetWeightKg: target,
      mainGoal: ob.mainGoal,
      activityLevel: ob.activityLevel?['value'] as String?,
    );

    return OnboardingScaffold(
      progress: (widget.step + 1) / widget.totalSteps,
      onBack: widget.onBack,
      onContinue: ob.targetWeight != null ? widget.onNext : null,
      continueLabel: l10n.translate('onboarding.continue'),
      child: ListView(
        padding: EdgeInsets.only(top: AppSpacing.lg.h, bottom: AppSpacing.xl.h),
        children: [
          OnboardingSectionLabel(
            title: l10n.translate('onboarding.v2.target.title',
                variables: {'name': name}),
            subtitle: l10n.translate('onboarding.v2.target.subtitle'),
          ),
          SizedBox(height: AppSpacing.xxl.h),
          // Big target readout
          Center(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$target',
                    style: t.displayL.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: ' ${l10n.translate('onboarding.v2.units.kg')}',
                    style: t.headlineS.copyWith(color: palette.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6.h,
              activeTrackColor: primary,
              inactiveTrackColor: primary.withValues(alpha: 0.15),
              thumbColor: primary,
              overlayColor: primary.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: target.toDouble().clamp(minW.toDouble(), maxW.toDouble()),
              min: minW.toDouble(),
              max: maxW.toDouble(),
              onChanged: (v) =>
                  context.read<OnboardingProvider>().setTargetWeight(v.round()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _EndLabel(
                  label: l10n.translate('onboarding.v2.target.current'),
                  value: '$current'),
              _EndLabel(
                  label: l10n.translate('onboarding.v2.target.goal'),
                  value: '$target',
                  accent: primary),
            ],
          ),
          SizedBox(height: AppSpacing.xl.h),
          _ProjectionCard(projection: projection),
          SizedBox(height: AppSpacing.md.h),
          OnboardingInfoNote(
            text: l10n.translate('onboarding.v2.target.disclaimer'),
            icon: Icons.health_and_safety_outlined,
            color: palette.warning,
          ),
        ],
      ),
    );
  }
}

class _EndLabel extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;
  const _EndLabel({required this.label, required this.value, this.accent});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return Column(
      children: [
        Text(label, style: t.labelS.copyWith(color: palette.textTertiary)),
        SizedBox(height: 2.h),
        Text('$value kg',
            style: t.labelL.copyWith(
                color: accent ?? palette.textSecondary,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  final OnboardingProjection projection;
  const _ProjectionCard({required this.projection});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    final locale = Localizations.localeOf(context).languageCode;

    final isMaintain = projection.estimatedWeeks == null;

    return AppCard(
      bordered: true,
      elevated: false,
      padding: EdgeInsets.all(AppSpacing.lg.r),
      child: isMaintain
          ? Row(
              children: [
                Icon(Icons.balance_rounded,
                    color: primary, size: AppSize.iconLg.r),
                SizedBox(width: AppSpacing.md.w),
                Expanded(
                  child: Text(
                    l10n.translate('onboarding.v2.target.maintain_note'),
                    style: t.bodyM
                        .copyWith(color: palette.textPrimary, height: 1.4),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _ProjRow(
                  icon: Icons.speed_rounded,
                  label: l10n.translate('onboarding.v2.target.rate_label'),
                  value: l10n.translate('onboarding.v2.target.weekly_rate',
                      variables: {
                        'kg': projection.weeklyRateKg!.toStringAsFixed(2)
                      }),
                ),
                Divider(height: AppSpacing.lg.h, color: palette.divider),
                _ProjRow(
                  icon: Icons.event_available_rounded,
                  label: l10n.translate('onboarding.v2.target.eta_label'),
                  value: l10n.translate('onboarding.v2.target.eta_weeks',
                          variables: {
                            'weeks': projection.estimatedWeeks.toString()
                          }) +
                      (projection.estimatedDate != null
                          ? '  ·  ${DateFormat('MMM yyyy', locale).format(projection.estimatedDate!)}'
                          : ''),
                  highlight: true,
                ),
              ],
            ),
    );
  }
}

class _ProjRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  const _ProjRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    return Row(
      children: [
        Icon(icon, size: AppSize.iconMd.r, color: palette.textTertiary),
        SizedBox(width: AppSpacing.sm.w),
        Expanded(
          child: Text(label,
              style: t.bodyM.copyWith(color: palette.textSecondary)),
        ),
        Text(
          value,
          style: t.titleM.copyWith(
            color: highlight ? primary : palette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
