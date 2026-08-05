import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/accessibility_utils.dart';

/// Faz 2 §2.2 — per-message reaction pills, attached to a bubble's bottom
/// edge. Mirrors the post-level reaction rendering pattern (emoji + count),
/// scoped to one message. Tapping a pill toggles the CURRENT user's own
/// reaction for that emoji — [onToggle] doesn't distinguish add/remove, the
/// caller (chat_detail_screen) checks membership in `reactions[emoji]` and
/// calls `ChatService.addReaction`/`removeReaction` accordingly.
class AppReactionBar extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final String currentUid;
  final ValueChanged<String> onToggle;
  final bool alignEnd;

  const AppReactionBar({
    super.key,
    required this.reactions,
    required this.currentUid,
    required this.onToggle,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final entries = reactions.entries.where((e) => e.value.isNotEmpty).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final reduceMotion = AccessibilityUtils.reduceMotion(context);

    return Wrap(
      alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
      spacing: 4.w,
      runSpacing: 4.h,
      children: entries.map((entry) {
        final emoji = entry.key;
        final uids = entry.value;
        final mine = uids.contains(currentUid);
        final accent = Theme.of(context).primaryColor;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle(emoji);
          },
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : AppMotion.fast,
            curve: AppMotion.standard,
            padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: mine ? accent.withValues(alpha: 0.16) : palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.full.r),
              border: Border.all(
                color: mine ? accent.withValues(alpha: 0.5) : palette.border,
                width: mine ? 1.2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow.withValues(alpha: 0.05),
                  blurRadius: 3.r,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: TextStyle(fontSize: 12.sp)),
                if (uids.length > 1) ...[
                  SizedBox(width: 3.w),
                  Text(
                    '${uids.length}',
                    style: t.labelS.copyWith(
                      color: mine ? accent : palette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Quick-reaction row shown above the long-press context menu (WhatsApp/
/// iMessage pattern) — a fixed emoji set plus a "more" affordance that opens
/// the system emoji keyboard via a plain text field (no emoji-picker package
/// in this app's dependencies).
class AppReactionPicker extends StatelessWidget {
  final ValueChanged<String> onSelect;
  final VoidCallback? onMore;

  static const List<String> quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  const AppReactionPicker({super.key, required this.onSelect, this.onMore});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm.w, vertical: AppSpacing.xs.h),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.full.r),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.12),
            blurRadius: 16.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...quickEmojis.map((emoji) => _EmojiTapTarget(
                emoji: emoji,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onSelect(emoji);
                },
              )),
          if (onMore != null)
            _EmojiTapTarget(
              icon: Icons.add_circle_outline_rounded,
              onTap: onMore,
            ),
        ],
      ),
    );
  }
}

class _EmojiTapTarget extends StatefulWidget {
  final String? emoji;
  final IconData? icon;
  final VoidCallback? onTap;

  const _EmojiTapTarget({this.emoji, this.icon, this.onTap});

  @override
  State<_EmojiTapTarget> createState() => _EmojiTapTargetState();
}

class _EmojiTapTargetState extends State<_EmojiTapTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.instant,
    upperBound: 0.35,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) => _c.reverse(),
      onTapCancel: () => _c.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) =>
            Transform.scale(scale: 1 + _c.value, child: child),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: widget.emoji != null
              ? Text(widget.emoji!, style: TextStyle(fontSize: 24.sp))
              : Icon(widget.icon,
                  size: AppSize.iconMd.r, color: palette.textTertiary),
        ),
      ),
    );
  }
}
