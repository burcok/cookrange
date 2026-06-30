import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../onboarding_scaffold.dart';
import '../widgets/onboarding_widgets.dart';

/// Page 7 — trust & social proof. Per the locked product decision, journeys are
/// CLEARLY LABELED illustrative examples (not real reviews) + compliance badges.
class OnboardingTrustPage extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingTrustPage({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final name = context.read<OnboardingProvider>().firstName ?? '';

    final journeys = [
      (
        'onboarding.v2.trust.j1_name',
        'onboarding.v2.trust.j1_goal',
        'onboarding.v2.trust.j1_quote'
      ),
      (
        'onboarding.v2.trust.j2_name',
        'onboarding.v2.trust.j2_goal',
        'onboarding.v2.trust.j2_quote'
      ),
      (
        'onboarding.v2.trust.j3_name',
        'onboarding.v2.trust.j3_goal',
        'onboarding.v2.trust.j3_quote'
      ),
    ];

    final badges = [
      (Icons.science_outlined, 'onboarding.v2.trust.badge_science'),
      (Icons.shield_outlined, 'onboarding.v2.trust.badge_privacy'),
      (Icons.auto_awesome_rounded, 'onboarding.v2.trust.badge_ai'),
    ];

    return OnboardingScaffold(
      progress: (step + 1) / totalSteps,
      onBack: onBack,
      onContinue: onNext,
      continueLabel: l10n.translate('onboarding.continue'),
      child: ListView(
        padding: EdgeInsets.only(top: AppSpacing.lg.h, bottom: AppSpacing.xl.h),
        children: [
          OnboardingSectionLabel(
            title: l10n.translate('onboarding.v2.trust.title',
                variables: {'name': name}),
            subtitle: l10n.translate('onboarding.v2.trust.subtitle'),
          ),
          SizedBox(height: AppSpacing.lg.h),
          ...journeys.map((j) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md.h),
                child: _JourneyCard(
                  name: l10n.translate(j.$1),
                  goal: l10n.translate(j.$2),
                  quote: l10n.translate(j.$3),
                  exampleLabel:
                      l10n.translate('onboarding.v2.trust.example_label'),
                ),
              )),
          SizedBox(height: AppSpacing.sm.h),
          Wrap(
            spacing: AppSpacing.sm.w,
            runSpacing: AppSpacing.sm.h,
            children: badges
                .map((b) => _Badge(icon: b.$1, label: l10n.translate(b.$2)))
                .toList(),
          ),
          SizedBox(height: AppSpacing.md.h),
          Text(
            l10n.translate('onboarding.v2.trust.examples_note'),
            style: t.labelS.copyWith(
                color: palette.textTertiary, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  final String name;
  final String goal;
  final String quote;
  final String exampleLabel;
  const _JourneyCard({
    required this.name,
    required this.goal,
    required this.quote,
    required this.exampleLabel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;

    return AppCard(
      bordered: true,
      elevated: false,
      padding: EdgeInsets.all(AppSpacing.md.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20.r,
                backgroundColor: primary.withValues(alpha: 0.14),
                child: Text(
                  name.isNotEmpty ? name.characters.first : '•',
                  style: t.titleM
                      .copyWith(color: primary, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: t.titleM.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700)),
                    Text(goal,
                        style: t.labelS.copyWith(color: palette.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full.r),
                ),
                child: Text(exampleLabel,
                    style: t.labelS.copyWith(color: palette.textTertiary)),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm.h),
          Text(
            '“$quote”',
            style: t.bodyM.copyWith(color: palette.textPrimary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.full.r),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSize.iconSm.r, color: primary),
          SizedBox(width: AppSpacing.xs.w),
          Text(label,
              style: t.labelM.copyWith(
                  color: palette.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
