import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../onboarding_scaffold.dart';
import '../widgets/onboarding_widgets.dart';

/// Page 12 — household: do they also cook for someone else? Captured as a flag
/// only; per-person meal scaling is a shelved future feature (see roadmap §7).
class OnboardingHouseholdPage extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingHouseholdPage({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ob = context.watch<OnboardingProvider>();
    final name = ob.firstName ?? '';

    return OnboardingScaffold(
      progress: (step + 1) / totalSteps,
      onBack: onBack,
      onContinue: onNext,
      continueLabel: l10n.translate('onboarding.continue'),
      child: ListView(
        padding: EdgeInsets.only(top: AppSpacing.lg.h, bottom: AppSpacing.xl.h),
        children: [
          OnboardingSectionLabel(
            title: l10n.translate('onboarding.v2.household.title',
                variables: {'name': name}),
            subtitle: l10n.translate('onboarding.v2.household.subtitle'),
          ),
          SizedBox(height: AppSpacing.xl.h),
          OnboardingChoiceCard(
            icon: Icons.restaurant_rounded,
            title: l10n.translate('onboarding.v2.household.yes'),
            selected: ob.cooksForOthers,
            onTap: () =>
                context.read<OnboardingProvider>().setCooksForOthers(true),
          ),
          SizedBox(height: AppSpacing.sm.h),
          OnboardingChoiceCard(
            icon: Icons.person_rounded,
            title: l10n.translate('onboarding.v2.household.no'),
            selected: !ob.cooksForOthers,
            onTap: () =>
                context.read<OnboardingProvider>().setCooksForOthers(false),
          ),
          if (ob.cooksForOthers) ...[
            SizedBox(height: AppSpacing.lg.h),
            OnboardingInfoNote(
              text: l10n.translate('onboarding.v2.household.note'),
              icon: Icons.celebration_outlined,
            ),
          ],
        ],
      ),
    );
  }
}
