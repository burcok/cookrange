import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../onboarding_scaffold.dart';
import '../widgets/onboarding_widgets.dart';

const _gold = Color(0xFFE8A317);
const _goldLight = Color(0xFFF6C453);

/// Page 13 — premium teaser.
///
/// Faz 0 §0.6 (audit finding beyond A8/AT-43 — the app's own text exceeding
/// reality, not just the site's): this page used to show two "locked
/// preview" cards for free-text custom AI meal requests and a personalized
/// app icon. Neither feature exists anywhere in the codebase — there is no
/// free-text meal-customization input (matches audit A-09) and no
/// alternate-app-icon mechanism at all. Shown to every new user during
/// onboarding, before they've seen a single real screen, with a lock-icon
/// treatment implying "this is real, upgrade to unlock" — removed rather
/// than reworded, since there's no true feature to preview. The benefit
/// list below now lists only what premium actually, verifiably does today:
/// the higher daily AI quota. The CTA only CAPTURES purchase intent — the
/// real purchase fires after the account exists (handled at registration).
class OnboardingPremiumPage extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingPremiumPage({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  void _choose(BuildContext context, bool wantsPremium) {
    HapticFeedback.mediumImpact();
    context.read<OnboardingProvider>().setWantsPremiumIntent(wantsPremium);
    onNext();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final name = context.read<OnboardingProvider>().firstName ?? '';

    final benefits = [
      'onboarding.v2.premium.benefit1',
      'onboarding.v2.premium.benefit2',
      'onboarding.v2.premium.benefit3',
    ];

    return OnboardingScaffold(
      progress: (step + 1) / totalSteps,
      onBack: onBack,
      onContinue: () => _choose(context, true),
      continueLabel: l10n.translate('onboarding.v2.premium.cta'),
      secondaryAction: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _choose(context, false),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.sm.r),
          child: Text(
            l10n.translate('onboarding.v2.premium.free'),
            style: t.labelL.copyWith(
                color: palette.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: ListView(
        padding: EdgeInsets.only(top: AppSpacing.md.h, bottom: AppSpacing.lg.h),
        children: [
          // Crown badge
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_goldLight, _gold]),
                borderRadius: BorderRadius.circular(AppRadius.full.r),
                boxShadow: [
                  BoxShadow(
                      color: _gold.withValues(alpha: 0.4),
                      blurRadius: 16.r,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      size: AppSize.iconSm.r, color: Colors.white),
                  SizedBox(width: AppSpacing.xxs.w),
                  Text(l10n.translate('onboarding.v2.premium.badge'),
                      style: t.labelM.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          SizedBox(height: AppSpacing.lg.h),
          OnboardingSectionLabel(
            title: l10n.translate('onboarding.v2.premium.title',
                variables: {'name': name}),
            subtitle: l10n.translate('onboarding.v2.premium.subtitle'),
          ),
          SizedBox(height: AppSpacing.lg.h),
          ...benefits.map((b) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: AppSize.iconMd.r, color: _gold),
                    SizedBox(width: AppSpacing.sm.w),
                    Expanded(
                      child: Text(l10n.translate(b),
                          style: t.bodyL.copyWith(color: palette.textPrimary)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
