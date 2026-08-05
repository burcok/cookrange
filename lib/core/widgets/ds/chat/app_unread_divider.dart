import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../localization/app_localizations.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';

/// Faz 2 §2.2 — WhatsApp-style "N unread messages" divider. Inserted once,
/// immediately above the first unread/unseen message in the loaded window
/// (chat_detail_screen computes the split point from `MessageModel.isReadBy`
/// against the current uid — this widget is purely presentational).
class AppUnreadDivider extends StatelessWidget {
  final int count;

  const AppUnreadDivider({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final color = palette.energy;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
      child: Row(
        children: [
          Expanded(child: Divider(color: color.withValues(alpha: 0.4))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w),
            child: Text(
              l10n.translate('chat.unread_messages_divider',
                  variables: {'count': count.toString()}),
              style: t.labelM.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Divider(color: color.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}
