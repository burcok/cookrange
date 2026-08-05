import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';

/// Faz 2 §2.2 — quoted-message preview. Two contexts, one widget:
/// - **Inside a bubble** (a message that IS a reply): [onTap] scrolls to the
///   original, [onClose] is null, [compact] true, tinted to sit on the
///   bubble's own background.
/// - **Above the composer** (composing a reply): [onClose] cancels it,
///   [compact] false, sits on the screen's surface.
class AppReplyPreview extends StatelessWidget {
  final String senderLabel;
  final String previewText;
  final IconData? kindIcon;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final bool compact;
  final Color? accentColor;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppReplyPreview({
    super.key,
    required this.senderLabel,
    required this.previewText,
    this.kindIcon,
    this.onTap,
    this.onClose,
    this.compact = false,
    this.accentColor,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final accent = accentColor ?? Theme.of(context).primaryColor;
    final bg = backgroundColor ??
        (compact ? accent.withValues(alpha: 0.08) : palette.surfaceVariant);
    final fg = foregroundColor ?? palette.textPrimary;

    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm.w,
        vertical: AppSpacing.xxs.h + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
        border: Border(left: BorderSide(color: accent, width: 3.w)),
      ),
      child: Row(
        children: [
          if (kindIcon != null) ...[
            Icon(kindIcon, size: AppSize.iconSm.r, color: accent),
            SizedBox(width: AppSpacing.xxs.w),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  senderLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelM
                      .copyWith(color: accent, fontWeight: FontWeight.w700),
                ),
                Text(
                  previewText,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyM.copyWith(color: fg.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          if (onClose != null) ...[
            SizedBox(width: AppSpacing.xxs.w),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onClose!();
              },
              child: Icon(Icons.close_rounded,
                  size: AppSize.iconSm.r, color: palette.textTertiary),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: content,
    );
  }
}
