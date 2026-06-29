import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../onboarding_scaffold.dart';
import '../widgets/onboarding_widgets.dart';

/// Page 6 — a personalized motivational beat between data collection. No input.
class OnboardingMotivationPage extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingMotivationPage({
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
    final primary = context.read<ThemeProvider>().primaryColor;
    final name = context.read<OnboardingProvider>().firstName ?? '';

    final tips = [
      (Icons.restaurant_menu_rounded, 'onboarding.v2.motivation.tip1'),
      (Icons.tune_rounded, 'onboarding.v2.motivation.tip2'),
      (Icons.support_agent_rounded, 'onboarding.v2.motivation.tip3'),
    ];

    return OnboardingScaffold(
      progress: (step + 1) / totalSteps,
      onBack: onBack,
      onContinue: onNext,
      continueLabel: l10n.translate('onboarding.continue'),
      child: ListView(
        padding: EdgeInsets.only(top: AppSpacing.xl.h, bottom: AppSpacing.xl.h),
        children: [
          Center(
            child: Container(
              width: 120.r,
              height: 120.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  primary.withValues(alpha: 0.18),
                  primary.withValues(alpha: 0.02),
                ]),
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  size: 56.sp, color: primary),
            ),
          ),
          SizedBox(height: AppSpacing.xl.h),
          OnboardingSectionLabel(
            title: l10n.translate('onboarding.v2.motivation.title',
                variables: {'name': name}),
          ),
          SizedBox(height: AppSpacing.md.h),
          Text(
            l10n.translate('onboarding.v2.motivation.body'),
            style: t.bodyL.copyWith(color: palette.textSecondary, height: 1.6),
          ),
          SizedBox(height: AppSpacing.xl.h),
          ...tips.map((tip) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md.h),
                child: Row(
                  children: [
                    Container(
                      width: 40.r,
                      height: 40.r,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md.r),
                      ),
                      child: Icon(tip.$1, size: AppSize.iconMd.r, color: primary),
                    ),
                    SizedBox(width: AppSpacing.md.w),
                    Expanded(
                      child: Text(
                        l10n.translate(tip.$2),
                        style: t.titleM.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
