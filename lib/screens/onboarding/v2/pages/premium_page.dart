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

/// Page 13 — premium teaser. Two genuinely locked previews (custom AI requests,
/// personalized icon) behind a decorative chain/lock, plus the benefit list.
/// Per the locked decision, the CTA only CAPTURES intent — the real purchase
/// fires after the account exists (handled at registration).
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
      'onboarding.v2.premium.benefit4',
      'onboarding.v2.premium.benefit5',
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
          _LockedFeature(
            icon: Icons.edit_note_rounded,
            title:
                l10n.translate('onboarding.v2.premium.locked_requests_title'),
            desc: l10n.translate('onboarding.v2.premium.locked_requests_desc'),
          ),
          SizedBox(height: AppSpacing.md.h),
          _LockedFeature(
            icon: Icons.palette_rounded,
            title: l10n.translate('onboarding.v2.premium.locked_icon_title'),
            desc: l10n.translate('onboarding.v2.premium.locked_icon_desc'),
          ),
          SizedBox(height: AppSpacing.xl.h),
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

class _LockedFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _LockedFeature(
      {required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return Stack(
      children: [
        Container(
          padding: EdgeInsets.all(AppSpacing.md.r),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg.r),
            border: Border.all(color: _gold.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                ),
                child: Icon(icon, size: AppSize.iconMd.r, color: _gold),
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Opacity(
                  opacity: 0.55,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: t.titleM.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 2.h),
                      Text(desc,
                          style:
                              t.labelM.copyWith(color: palette.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Chain-lock decoration, top-right
        Positioned(
          top: AppSpacing.xs.h,
          right: AppSpacing.xs.w,
          child: Container(
            padding: EdgeInsets.all(AppSpacing.xxs.r),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_goldLight, _gold]),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_rounded, size: 14.r, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
