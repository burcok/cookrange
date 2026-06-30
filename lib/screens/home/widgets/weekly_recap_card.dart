import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/ai_insight_service.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ds/app_card.dart';
import '../../../core/widgets/ds/app_shimmer.dart';
import '../../../core/widgets/ds/app_transitions.dart';
import '../../ai/weekly_recap_screen.dart';

/// Home-screen teaser card for the weekly AI coach recap.
///
/// Shows the week score + trend if a recap exists; CTA button otherwise.
/// Tapping opens [WeeklyRecapScreen].
class WeeklyRecapCard extends StatelessWidget {
  final String uid;

  const WeeklyRecapCard({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final primary = context.watch<ThemeProvider>().primaryColor;
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<DocumentSnapshot?>(
      stream: AiInsightService().getLatestWeeklyRecapStream(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return AppSkeletonBox(
            width: double.infinity,
            height: 72.h,
            radius: AppRadius.card.r,
          );
        }

        final doc = snap.data;
        final hasData = doc != null && doc.exists;

        // Only show the card if there's a recap for this week
        Map<String, dynamic>? data;
        bool isCurrentWeek = false;
        if (hasData) {
          data = doc.data() as Map<String, dynamic>;
          final docWeekKey = data['weekKey'] as String? ?? '';
          isCurrentWeek =
              docWeekKey == AiInsightService.weekKey(DateTime.now());
        }

        return GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            AppTransitions.slideUp(const WeeklyRecapScreen()),
          ),
          child: AppGlassCard(
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
            child: Row(
              children: [
                Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 20.r, color: primary),
                ),
                SizedBox(width: AppSpacing.sm.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('ai.weekly_recap_card_title'),
                        style: t.labelM.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.bold),
                      ),
                      if (isCurrentWeek && data != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          '${data['score'] ?? 0}/100 · ${_trendLabel(data['trend'] as String? ?? 'steady', l10n)}',
                          style: t.bodyM.copyWith(color: palette.textSecondary),
                        ),
                      ] else ...[
                        SizedBox(height: 2.h),
                        Text(
                          l10n.translate('ai.weekly_recap_no_recap'),
                          style: t.bodyM.copyWith(color: palette.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm.w),
                Text(
                  isCurrentWeek
                      ? l10n.translate('ai.weekly_recap_card_view')
                      : l10n.translate('ai.weekly_recap_card_cta'),
                  style: t.labelM
                      .copyWith(color: primary, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 4.w),
                Icon(Icons.chevron_right_rounded, size: 18.r, color: primary),
              ],
            ),
          ),
        );
      },
    );
  }

  String _trendLabel(String trend, AppLocalizations l10n) {
    switch (trend) {
      case 'improving':
        return l10n.translate('ai.weekly_recap_trend_improving');
      case 'declining':
        return l10n.translate('ai.weekly_recap_trend_declining');
      default:
        return l10n.translate('ai.weekly_recap_trend_steady');
    }
  }
}
