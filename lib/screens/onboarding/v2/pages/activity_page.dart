import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/onboarding_options.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../onboarding_scaffold.dart';
import '../widgets/onboarding_widgets.dart';

/// Page 3 — daily activity level (single) + "what excites you" motivators
/// (multi, up to 5). Reuses the existing [OnboardingOptions] sets.
class OnboardingActivityPage extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingActivityPage({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onboarding = context.watch<OnboardingProvider>();
    final name = onboarding.firstName ?? '';
    final selectedActivity = onboarding.activityLevel?['value'] as String?;
    final selectedGoals =
        onboarding.primaryGoals.map((g) => g['value'] as String).toSet();
    final valid = selectedActivity != null && selectedGoals.isNotEmpty;

    return OnboardingScaffold(
      progress: (step + 1) / totalSteps,
      onBack: onBack,
      onContinue: valid ? onNext : null,
      continueLabel: l10n.translate('onboarding.continue'),
      child: ListView(
        padding: EdgeInsets.only(top: AppSpacing.lg.h, bottom: AppSpacing.xl.h),
        children: [
          OnboardingSectionLabel(
            title: l10n.translate('onboarding.v2.activity.title',
                variables: {'name': name}),
            subtitle: l10n.translate('onboarding.v2.activity.subtitle'),
          ),
          SizedBox(height: AppSpacing.lg.h),
          ...OnboardingOptions.activityLevels.entries.map((e) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
                child: OnboardingChoiceCard(
                  icon: e.value['icon'] as IconData,
                  title: l10n.translate(e.value['label'] as String),
                  selected: selectedActivity == e.key,
                  onTap: () => context
                      .read<OnboardingProvider>()
                      .setActivityLevel(e.key),
                ),
              )),
          SizedBox(height: AppSpacing.xl.h),
          OnboardingGroupLabel(
            title: l10n.translate('onboarding.v2.activity.motivators_title'),
            trailing: l10n.translate('onboarding.v2.activity.selected_count',
                variables: {'count': selectedGoals.length.toString()}),
          ),
          SizedBox(height: AppSpacing.xxs.h),
          _Subtitle(
              text: l10n.translate('onboarding.v2.activity.motivators_subtitle')),
          SizedBox(height: AppSpacing.md.h),
          Wrap(
            spacing: AppSpacing.sm.w,
            runSpacing: AppSpacing.sm.h,
            children: OnboardingOptions.primaryGoals.entries.map((e) {
              final on = selectedGoals.contains(e.key);
              final atLimit = selectedGoals.length >= 5;
              return OnboardingChoiceChip(
                icon: e.value['icon'] as IconData,
                label: l10n.translate(e.value['label'] as String),
                selected: on,
                onTap: () {
                  if (!on && atLimit) return;
                  context.read<OnboardingProvider>().togglePrimaryGoal(e.key);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  final String text;
  const _Subtitle({required this.text});
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return Text(text, style: t.bodyM.copyWith(color: palette.textSecondary));
  }
}
