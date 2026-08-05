import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../app_sheet.dart';
import 'app_reaction_bar.dart';

/// One row in the long-press action list (reply/forward/copy/pin/star/edit/
/// delete/report). The menu itself is generic/dumb — the screen decides
/// WHICH actions apply to a given message (sender, 15-minute edit window,
/// current pin/star state) and passes only the applicable ones.
class AppMessageContextMenuAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const AppMessageContextMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
}

/// Faz 2 §2.2 — long-press context menu. Built on the existing [AppSheet]
/// primitive (R7: reuse, don't reinvent bottom-sheet chrome) with a compact
/// message preview + quick-reaction row above the action list — mirrors the
/// WhatsApp/iMessage long-press pattern without the fragility of a
/// screen-position-cloned bubble overlay.
class AppMessageContextMenu {
  AppMessageContextMenu._();

  static Future<void> show(
    BuildContext context, {
    required String previewSenderLabel,
    required String previewText,
    required ValueChanged<String> onReact,
    VoidCallback? onMoreReactions,
    required List<AppMessageContextMenuAction> actions,
  }) {
    return AppSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewRow(senderLabel: previewSenderLabel, text: previewText),
          SizedBox(height: AppSpacing.md.h),
          Center(
            child: AppReactionPicker(
              onSelect: (emoji) {
                Navigator.of(context).pop();
                onReact(emoji);
              },
              onMore: onMoreReactions == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      onMoreReactions();
                    },
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          ...actions.map((a) => _ActionRow(
                action: a,
                onTap: () {
                  Navigator.of(context).pop();
                  a.onTap();
                },
              )),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String senderLabel;
  final String text;

  const _PreviewRow({required this.senderLabel, required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return Container(
      padding: EdgeInsets.all(AppSpacing.sm.r),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(senderLabel,
              style: t.labelM.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 2.h),
          Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: t.bodyM.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final AppMessageContextMenuAction action;
  final VoidCallback onTap;

  const _ActionRow({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final color = action.destructive ? palette.error : palette.textPrimary;

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
      leading: Icon(action.icon, color: color, size: AppSize.iconMd.r),
      title: Text(action.label, style: t.bodyL.copyWith(color: color)),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}
