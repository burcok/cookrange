import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../localization/app_localizations.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/accessibility_utils.dart';

/// Faz 2 §2.2 — typing indicator, generalized from the old private-chat-only
/// bubble to any number of typers (group chats). [names] are already-resolved
/// display names of whoever is typing (excluding the current user) — the
/// screen resolves them (bounded `whereIn`, mirrors
/// `ChatService.getUserChatsWithStatus`'s existing 10-uid cap) so this widget
/// never touches Firestore itself.
///
/// Falls back to the plain `chat.typing` text when [names] is empty but
/// [visible] is true — covers the case where name resolution hasn't
/// completed yet (or failed) without hiding the indicator entirely.
class AppTypingIndicator extends StatefulWidget {
  final bool visible;
  final List<String> names;

  const AppTypingIndicator(
      {super.key, required this.visible, this.names = const []});

  @override
  State<AppTypingIndicator> createState() => _AppTypingIndicatorState();
}

class _AppTypingIndicatorState extends State<AppTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.ambient,
  );

  @override
  void initState() {
    super.initState();
    if (widget.visible) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant AppTypingIndicator old) {
    super.didUpdateWidget(old);
    if (widget.visible && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.visible && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _label(AppLocalizations l10n) {
    final names = widget.names;
    if (names.isEmpty) return l10n.translate('chat.typing');
    if (names.length == 1) {
      return l10n.translate('chat.typing_indicator.one',
          variables: {'name': names[0]});
    }
    if (names.length == 2) {
      return l10n.translate('chat.typing_indicator.two',
          variables: {'name1': names[0], 'name2': names[1]});
    }
    return l10n.translate('chat.typing_indicator.many');
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final reduceMotion = AccessibilityUtils.reduceMotion(context);

    return Padding(
      padding: EdgeInsets.only(left: AppSpacing.md.w, bottom: AppSpacing.xs.h),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppPalette.glassBlurSubtle,
              sigmaY: AppPalette.glassBlurSubtle,
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm.w, vertical: AppSpacing.xs.h),
              decoration: BoxDecoration(
                color: palette.glassFill,
                borderRadius: BorderRadius.circular(AppRadius.md.r),
                border: Border.all(color: palette.glassStroke, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dots(controller: _c, reduceMotion: reduceMotion),
                  SizedBox(width: AppSpacing.xs.w),
                  Text(
                    _label(l10n),
                    style: t.labelM.copyWith(color: palette.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final AnimationController controller;
  final bool reduceMotion;

  const _Dots({required this.controller, required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    if (reduceMotion) {
      // Static three-dot glyph — no bounce, but still communicates "typing".
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => Padding(
            padding: EdgeInsets.symmetric(horizontal: 1.w),
            child: Container(
              width: 5.r,
              height: 5.r,
              decoration: BoxDecoration(
                  color: palette.textTertiary, shape: BoxShape.circle),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: 26.w,
      height: 12.h,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              // Each dot bounces on its own phase offset within the loop.
              final phase = (controller.value + i * 0.2) % 1.0;
              final bounce = (phase < 0.5 ? phase : 1 - phase) * 2; // 0..1..0
              return Transform.translate(
                offset: Offset(0, -bounce * 4.h),
                child: Container(
                  width: 5.r,
                  height: 5.r,
                  decoration: BoxDecoration(
                      color: palette.textSecondary, shape: BoxShape.circle),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
