import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../localization/app_localizations.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';

/// Faz 2 §2.2 — sticky per-day divider in the message list. Formalizes the
/// old chat_detail_screen.dart private `_DateSeparator` into a reusable DS
/// component (same `profile.chat.today`/`profile.chat.yesterday` keys, same
/// `DD/MM/YYYY` fallback for older dates — no locale text changes, purely a
/// visual/structural move).
class AppDateSeparator extends StatelessWidget {
  final DateTime date;

  const AppDateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    final String label;
    if (dateToCheck == today) {
      label = l10n.translate('profile.chat.today');
    } else if (dateToCheck == yesterday) {
      label = l10n.translate('profile.chat.yesterday');
    } else {
      label =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }

    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm.w, vertical: AppSpacing.xxs.h),
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.full.r),
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(alpha: 0.04),
              blurRadius: 4.r,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: t.labelM.copyWith(
            color: palette.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
