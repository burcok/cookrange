import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../onboarding_scaffold.dart';
import '../widgets/onboarding_widgets.dart';

/// Page 2 — primary goal (single) + biological sex, with a KVKK-friendly
/// explainer for why sex is asked (metabolic-rate accuracy).
class OnboardingGoalGenderPage extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingGoalGenderPage({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  static const List<(String, IconData)> _goals = [
    ('lose_weight', Icons.trending_down_rounded),
    ('gain_weight', Icons.trending_up_rounded),
    ('build_muscle', Icons.fitness_center_rounded),
    ('healthy_eating', Icons.favorite_rounded),
  ];

  static const List<(String, String, IconData)> _genders = [
    ('Male', 'onboarding.profile.male', Icons.male_rounded),
    ('Female', 'onboarding.profile.female', Icons.female_rounded),
    ('Prefer not to say', 'onboarding.profile.preferNotToSay',
        Icons.do_not_disturb_alt_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final onboarding = context.watch<OnboardingProvider>();
    final name = onboarding.firstName ?? '';
    final valid = onboarding.mainGoal != null && onboarding.gender != null;

    return OnboardingScaffold(
      progress: (step + 1) / totalSteps,
      onBack: onBack,
      onContinue: valid ? onNext : null,
      continueLabel: l10n.translate('onboarding.continue'),
      child: ListView(
        padding: EdgeInsets.only(top: AppSpacing.lg.h, bottom: AppSpacing.xl.h),
        children: [
          OnboardingSectionLabel(
            title: l10n
                .translate('onboarding.v2.goal.title', variables: {'name': name}),
            subtitle: l10n.translate('onboarding.v2.goal.subtitle'),
          ),
          SizedBox(height: AppSpacing.lg.h),
          ..._goals.map((g) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
                child: OnboardingChoiceCard(
                  icon: g.$2,
                  title: l10n.translate('onboarding.v2.goal.options.${g.$1}'),
                  selected: onboarding.mainGoal == g.$1,
                  onTap: () => context.read<OnboardingProvider>().setMainGoal(g.$1),
                ),
              )),
          SizedBox(height: AppSpacing.xl.h),
          OnboardingGroupLabel(
              title: l10n.translate('onboarding.v2.goal.gender_title')),
          SizedBox(height: AppSpacing.xxs.h),
          Text(
            l10n.translate('onboarding.v2.goal.gender_subtitle'),
            style: t.bodyM.copyWith(color: palette.textSecondary),
          ),
          SizedBox(height: AppSpacing.md.h),
          Wrap(
            spacing: AppSpacing.sm.w,
            runSpacing: AppSpacing.sm.h,
            children: _genders
                .map((g) => OnboardingChoiceChip(
                      icon: g.$3,
                      label: l10n.translate(g.$2),
                      selected: onboarding.gender == g.$1,
                      onTap: () =>
                          context.read<OnboardingProvider>().setGender(g.$1),
                    ))
                .toList(),
          ),
          SizedBox(height: AppSpacing.md.h),
          OnboardingInfoNote(text: l10n.translate('onboarding.v2.goal.why_gender')),
        ],
      ),
    );
  }
}
