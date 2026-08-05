import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/plan_offer_service.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../plan_offers/offer_inbox_screen.dart';

/// Faz 3 §3.5 — a quiet, contextual discovery nudge for a member's pending
/// plan offers, placed on the home screen (the only reliable, low-risk entry
/// point into `PlanOfferInboxScreen` outside the notification itself — see
/// this feature's own report for why deep-linking straight from a
/// notification tap was deliberately NOT built: no notification type in this
/// app does that today, in-app or push, and inventing it only for this one
/// type would be a new cross-cutting convention, not a §3.5-scoped change).
///
/// Renders nothing when there are zero pending offers — never an empty/zero
/// state occupying space on the busiest screen in the app.
class PlanOfferInboxBanner extends StatelessWidget {
  final String uid;
  const PlanOfferInboxBanner({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final accent = Theme.of(context).primaryColor;

    return StreamBuilder<int>(
      stream: PlanOfferService().pollPendingOfferCount(uid),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md.h),
          child: GestureDetector(
            onTap: () => Navigator.of(context)
                .push(AppTransitions.slideUp(const PlanOfferInboxScreen())),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: palette.isDark ? 0.08 : 0.05),
                borderRadius: BorderRadius.circular(AppRadius.card.r),
                border: Border.all(color: accent.withValues(alpha: 0.18)),
              ),
              padding: EdgeInsets.all(AppSpacing.md.r),
              child: Row(
                children: [
                  Container(
                    width: 36.r,
                    height: 36.r,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.sm.r),
                    ),
                    child: Icon(Icons.menu_book_rounded,
                        color: accent, size: 18.r),
                  ),
                  SizedBox(width: AppSpacing.sm.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.translate('home.plan_offer_banner.title'),
                          style: t.titleM,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          l10n.translate('home.plan_offer_banner.body',
                              variables: {'n': '$count'}),
                          style: t.bodyM.copyWith(color: palette.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.xs.w),
                  Icon(Icons.chevron_right_rounded,
                      color: palette.textSecondary, size: 20.r),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
