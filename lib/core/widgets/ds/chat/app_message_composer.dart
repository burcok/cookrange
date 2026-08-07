import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../localization/app_localizations.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_gradients.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import 'app_reply_preview.dart';

/// A chat participant eligible for @mention autocomplete. Deliberately not
/// `UserModel` — keeps this DS widget decoupled from the user model/Firestore.
class AppMentionCandidate {
  final String uid;
  final String name;
  final String? photoUrl;

  const AppMentionCandidate(
      {required this.uid, required this.name, this.photoUrl});
}

/// Faz 2 §2.2 — the message composer: attachment bar, reply preview,
/// @mention autocomplete popup, upload spinner, send button. The screen owns
/// all business logic (typing status, actually picking/uploading images,
/// filtering mention candidates, splicing a selected mention into the text)
/// — this widget only renders and reports intents via callbacks.
class AppMessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback onSend;
  final VoidCallback onAttachTap;
  final bool isUploading;

  final String? replyingToSenderLabel;
  final String? replyingToPreview;
  final IconData? replyingToIcon;
  final VoidCallback? onCancelReply;

  final List<AppMentionCandidate> mentionCandidates;
  final ValueChanged<AppMentionCandidate>? onSelectMention;

  /// Faz 6 — when the composer's text is empty AND [onMicPressStart] is
  /// non-null, the send button is replaced with a mic button. The whole
  /// press→drag→release gesture is tracked HERE (not inside a separate
  /// recorder widget) because Flutter binds a pointer's entire down→move→up
  /// sequence to whichever widget was hit-tested at pointer-DOWN — the
  /// active-recording bar (`AppVoiceRecorder`) only mounts once recording
  /// has already started, so it could never receive this same pointer's
  /// later move/end events. See `AppVoiceRecorder`'s own doc comment for the
  /// other half of this design.
  final VoidCallback? onMicPressStart;
  final void Function(double dragDx, double dragDy)? onMicDragUpdate;
  final VoidCallback? onMicPressEnd;

  const AppMessageComposer({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    required this.onSend,
    required this.onAttachTap,
    this.isUploading = false,
    this.replyingToSenderLabel,
    this.replyingToPreview,
    this.replyingToIcon,
    this.onCancelReply,
    this.mentionCandidates = const [],
    this.onSelectMention,
    this.onMicPressStart,
    this.onMicDragUpdate,
    this.onMicPressEnd,
  });

  bool get _isReplying =>
      replyingToSenderLabel != null && replyingToPreview != null;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mentionCandidates.isNotEmpty)
          _MentionPopup(
            candidates: mentionCandidates,
            onSelect: onSelectMention,
          ),
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppPalette.glassBlurDefault,
              sigmaY: AppPalette.glassBlurDefault,
            ),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.md.w,
                  AppSpacing.sm.h,
                  AppSpacing.md.w,
                  AppSpacing.sm.h + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: palette.glassFill,
                border: Border(
                    top: BorderSide(color: palette.glassStroke, width: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow.withValues(alpha: 0.06),
                    blurRadius: 12.r,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isReplying)
                    Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.xs.h),
                      child: AppReplyPreview(
                        senderLabel: replyingToSenderLabel!,
                        previewText: replyingToPreview!,
                        kindIcon: replyingToIcon,
                        onClose: onCancelReply,
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      isUploading
                          ? Padding(
                              padding: EdgeInsets.all(AppSpacing.sm.r),
                              child: SizedBox(
                                width: 20.r,
                                height: 20.r,
                                child: const CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            )
                          : Semantics(
                              button: true,
                              label: l10n.translate('chat.actions.attach'),
                              child: IconButton(
                                icon: const Icon(
                                    Icons.add_circle_outline_rounded),
                                color: palette.textTertiary,
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  onAttachTap();
                                },
                              ),
                            ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xl.r),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: AppPalette.glassBlurSubtle,
                              sigmaY: AppPalette.glassBlurSubtle,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: palette.surfaceVariant
                                    .withValues(alpha: 0.7),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.xl.r),
                                border: Border.all(
                                    color: palette.glassStroke, width: 0.5),
                              ),
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                onChanged: onChanged,
                                style: AppText.of(context)
                                    .bodyL
                                    .copyWith(color: palette.textPrimary),
                                decoration: InputDecoration(
                                  hintText: l10n.translate(
                                      'chat.actions.placeholder_message_input'),
                                  hintStyle:
                                      TextStyle(color: palette.textTertiary),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md.w,
                                      vertical: AppSpacing.sm.h),
                                ),
                                minLines: 1,
                                maxLines: 5,
                                textCapitalization:
                                    TextCapitalization.sentences,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.xs.w),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, _) {
                          final showMic = value.text.trim().isEmpty &&
                              onMicPressStart != null;
                          if (showMic) {
                            return Semantics(
                              button: true,
                              label:
                                  l10n.translate('chat.actions.record_voice'),
                              child: GestureDetector(
                                onLongPressStart: (_) {
                                  HapticFeedback.mediumImpact();
                                  onMicPressStart?.call();
                                },
                                onLongPressMoveUpdate: (details) {
                                  // Positive dragDx/dragDy grow toward
                                  // cancel(left)/lock(up) — screen
                                  // coordinates grow right/down, so both
                                  // are sign-flipped from `offsetFromOrigin`.
                                  onMicDragUpdate?.call(
                                    -details.localOffsetFromOrigin.dx,
                                    -details.localOffsetFromOrigin.dy,
                                  );
                                },
                                onLongPressEnd: (_) => onMicPressEnd?.call(),
                                child: Container(
                                  padding: EdgeInsets.all(AppSpacing.xs.r + 2),
                                  decoration: BoxDecoration(
                                    gradient:
                                        AppGradients.brand(theme.primaryColor),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.primaryColor
                                            .withValues(alpha: 0.35),
                                        blurRadius: 8.r,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(Icons.mic_rounded,
                                      color: Colors.white,
                                      size: AppSize.iconSm.r),
                                ),
                              ),
                            );
                          }
                          return Semantics(
                            button: true,
                            label: l10n.translate('chat.actions.send'),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                onSend();
                              },
                              child: Container(
                                padding: EdgeInsets.all(AppSpacing.xs.r + 2),
                                decoration: BoxDecoration(
                                  gradient:
                                      AppGradients.brand(theme.primaryColor),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.primaryColor
                                          .withValues(alpha: 0.35),
                                      blurRadius: 8.r,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.arrow_upward_rounded,
                                    color: Colors.white,
                                    size: AppSize.iconSm.r),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MentionPopup extends StatelessWidget {
  final List<AppMentionCandidate> candidates;
  final ValueChanged<AppMentionCandidate>? onSelect;

  const _MentionPopup({required this.candidates, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: 200.h),
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.12),
            blurRadius: 12.r,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxs.h),
        itemCount: candidates.length,
        itemBuilder: (context, i) {
          final c = candidates[i];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14.r,
              backgroundColor: palette.surfaceVariant,
              backgroundImage:
                  c.photoUrl != null ? NetworkImage(c.photoUrl!) : null,
              child: c.photoUrl == null
                  ? Icon(Icons.person, size: 16.r, color: palette.textTertiary)
                  : null,
            ),
            title: Text(c.name,
                style: t.bodyM.copyWith(color: palette.textPrimary)),
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect?.call(c);
            },
          );
        },
      ),
    );
  }
}
