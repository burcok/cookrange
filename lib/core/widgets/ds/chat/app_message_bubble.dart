import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/message_model.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_gradients.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import 'app_reaction_bar.dart';
import 'app_reply_preview.dart';

/// Faz 2 §2.2 — the one chat bubble. Replaces chat_detail_screen.dart's old
/// `_buildSentBubble`/`_buildReceivedBubble`/`_buildImageBubble` private
/// methods with a single reusable component covering every message state:
/// text, image (single or multi-attachment), system/announcement, deleted,
/// edited, forwarded, replied-to, reacted-to — plus the interaction layer
/// (long-press, swipe-to-reply) so the screen's list builder stays a plain
/// data-to-widget mapping.
class AppMessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final String currentUid;

  /// Group/gym chats only — sender name shown above the first bubble of a
  /// consecutive run. Null/empty for private chats or a repeated sender.
  final String? senderLabel;

  /// Delivery ticks — computed by the caller (private: `isReadBy(otherUid)`/
  /// `isDeliveredTo(otherUid)`; group: read-by-everyone-else /
  /// delivered-to-anyone) so this widget stays agnostic of chat type.
  final bool isDelivered;
  final bool isRead;

  final bool isPinned;
  final bool isStarred;

  final VoidCallback? onLongPress;
  final VoidCallback? onSwipeReply;
  final VoidCallback? onTapReplyPreview;
  final void Function(int attachmentIndex)? onTapImage;
  final ValueChanged<String>? onToggleReaction;

  /// Faz 3 §3.5 — tapping a `plan_offer`-typed bubble. Null (or [isMe] true)
  /// renders the card as static/non-tappable: `plan_offers` read is
  /// recipient-only, so the SENDER's own copy of this chat has nowhere
  /// meaningful to navigate to. The caller (chat screen) resolves
  /// [MessagePlanOfferInfo.offerId] into an actual offer + screen — this
  /// widget stays navigation-agnostic (DS layer never imports a feature
  /// screen).
  final void Function(MessagePlanOfferInfo info)? onTapPlanOffer;

  /// Resolves a uid to a display label for the quoted reply preview ("You"
  /// for the current user, otherwise a cached display name). Defaults to
  /// echoing the uid back if the caller doesn't supply one.
  final String Function(String uid)? resolveSenderLabel;

  const AppMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUid,
    this.senderLabel,
    this.isDelivered = false,
    this.isRead = false,
    this.isPinned = false,
    this.isStarred = false,
    this.onLongPress,
    this.onSwipeReply,
    this.onTapReplyPreview,
    this.onTapImage,
    this.onToggleReaction,
    this.resolveSenderLabel,
    this.onTapPlanOffer,
  });

  @override
  State<AppMessageBubble> createState() => _AppMessageBubbleState();
}

class _AppMessageBubbleState extends State<AppMessageBubble>
    with TickerProviderStateMixin {
  static const double _swipeTriggerDx = 56.0;
  static const double _swipeMaxDx = 72.0;

  late final AnimationController _pressController = AnimationController(
    vsync: this,
    duration: AppMotion.instant,
    upperBound: 0.03,
  );

  late final AnimationController _swipeController = AnimationController(
    vsync: this,
    duration: AppMotion.fast,
    value: 0,
  );

  bool _swipeTriggered = false;

  @override
  void dispose() {
    _pressController.dispose();
    _swipeController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.onSwipeReply == null) return;
    // Only rightward drags open the reply reveal (matches WhatsApp's
    // swipe-right-to-reply on both bubble sides).
    final next = (_swipeController.value * _swipeMaxDx + details.delta.dx)
        .clamp(0.0, _swipeMaxDx);
    _swipeController.value = next / _swipeMaxDx;
    final crossedThreshold = next >= _swipeTriggerDx;
    if (crossedThreshold && !_swipeTriggered) {
      _swipeTriggered = true;
      HapticFeedback.selectionClick();
    } else if (!crossedThreshold) {
      _swipeTriggered = false;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.onSwipeReply == null) return;
    if (_swipeTriggered) {
      HapticFeedback.mediumImpact();
      widget.onSwipeReply!();
    }
    _swipeTriggered = false;
    _swipeController.animateTo(0, curve: AppMotion.standard);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);
    final message = widget.message;
    final isDeleted = message.isDeletedFor(widget.currentUid);

    if (message.type == MessageType.system ||
        message.type == MessageType.announcement) {
      return _SystemMessagePill(text: message.body);
    }

    if (message.type == MessageType.planOffer) {
      return _PlanOfferCard(
        message: message,
        isMe: widget.isMe,
        isDelivered: widget.isDelivered,
        isRead: widget.isRead,
        // Only the recipient's own bubble is tappable — see the field doc
        // comment on `onTapPlanOffer` for why the sender's copy never is.
        onTap: widget.isMe ? null : widget.onTapPlanOffer,
      );
    }

    final br = BorderRadius.circular(AppRadius.lg.r).copyWith(
      bottomRight: widget.isMe
          ? const Radius.circular(4)
          : Radius.circular(AppRadius.lg.r),
      bottomLeft: widget.isMe
          ? Radius.circular(AppRadius.lg.r)
          : const Radius.circular(4),
    );

    Widget bubbleContent = isDeleted
        ? _DeletedPlaceholder(isMe: widget.isMe)
        : _BubbleBody(
            message: message,
            isMe: widget.isMe,
            br: br,
            theme: theme,
            palette: palette,
            onTapImage: widget.onTapImage,
            onTapReplyPreview: widget.onTapReplyPreview,
            resolveSenderLabel: widget.resolveSenderLabel,
            isDelivered: widget.isDelivered,
            isRead: widget.isRead,
          );

    Widget row = Column(
      crossAxisAlignment:
          widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.senderLabel != null && widget.senderLabel!.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: AppSpacing.xxs.w, bottom: 2.h),
            child: Text(
              widget.senderLabel!,
              style: AppText.of(context).labelS.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        GestureDetector(
          onTapDown: isDeleted ? null : (_) => _pressController.forward(),
          onTapUp: isDeleted ? null : (_) => _pressController.reverse(),
          onTapCancel: isDeleted ? null : () => _pressController.reverse(),
          onLongPress: isDeleted
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  widget.onLongPress?.call();
                },
          onHorizontalDragUpdate: isDeleted ? null : _onHorizontalDragUpdate,
          onHorizontalDragEnd: isDeleted ? null : _onHorizontalDragEnd,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pressController, _swipeController]),
            builder: (context, child) {
              final dx = _swipeController.value * _swipeMaxDx;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  if (dx > 4)
                    Positioned(
                      left: -28.w,
                      child: Opacity(
                        opacity: (dx / _swipeTriggerDx).clamp(0.0, 1.0),
                        child: Icon(Icons.reply_rounded,
                            color: palette.textTertiary,
                            size: AppSize.iconMd.r),
                      ),
                    ),
                  Transform.translate(
                    offset: Offset(dx, 0),
                    child: Transform.scale(
                      scale: 1 + _pressController.value,
                      child: child,
                    ),
                  ),
                ],
              );
            },
            child: bubbleContent,
          ),
        ),
        if (message.reactions.isNotEmpty && !isDeleted) ...[
          SizedBox(height: 2.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: AppReactionBar(
              reactions: message.reactions,
              currentUid: widget.currentUid,
              alignEnd: widget.isMe,
              onToggle: (emoji) {
                widget.onToggleReaction?.call(emoji);
              },
            ),
          ),
        ],
      ],
    );

    if (!widget.isPinned && !widget.isStarred) return row;

    // Small pin/star glyphs above the bubble — purely informational, no tap
    // target of their own (the context menu is reached via long-press).
    return Column(
      crossAxisAlignment:
          widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isPinned) ...[
                Icon(Icons.push_pin_rounded,
                    size: 11.r, color: palette.textTertiary),
                SizedBox(width: 3.w),
              ],
              if (widget.isStarred)
                Icon(Icons.star_rounded, size: 11.r, color: palette.warning),
            ],
          ),
        ),
        row,
      ],
    );
  }
}

class _BubbleBody extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final BorderRadius br;
  final ThemeData theme;
  final AppPalette palette;
  final void Function(int)? onTapImage;
  final VoidCallback? onTapReplyPreview;
  final String Function(String uid)? resolveSenderLabel;
  final bool isDelivered;
  final bool isRead;

  const _BubbleBody({
    required this.message,
    required this.isMe,
    required this.br,
    required this.theme,
    required this.palette,
    required this.onTapImage,
    required this.onTapReplyPreview,
    required this.resolveSenderLabel,
    required this.isDelivered,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    final isImage =
        message.type == MessageType.image && message.attachments.isNotEmpty;

    if (isImage) {
      return _ImageBubble(
        message: message,
        isMe: isMe,
        br: br,
        palette: palette,
        onTapImage: onTapImage,
        isDelivered: isDelivered,
        isRead: isRead,
      );
    }

    final bg = isMe ? null : palette.glassFill;
    final textColor = isMe ? Colors.white : palette.textPrimary;

    Widget textBubble = Container(
      constraints: BoxConstraints(maxWidth: 260.w),
      decoration: BoxDecoration(
        gradient: isMe ? AppGradients.brand(theme.primaryColor) : null,
        color: bg,
        borderRadius: br,
        border:
            isMe ? null : Border.all(color: palette.glassStroke, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: (isMe ? theme.primaryColor : palette.shadow)
                .withValues(alpha: isMe ? 0.25 : 0.05),
            blurRadius: 6.r,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm.w + 4, vertical: AppSpacing.xs.h + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.forwardedFrom != null) _ForwardedTag(color: textColor),
            if (message.replyTo != null)
              Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: AppReplyPreview(
                  compact: true,
                  senderLabel:
                      resolveSenderLabel?.call(message.replyTo!.senderId) ??
                          message.replyTo!.senderId,
                  previewText: message.replyTo!.preview,
                  kindIcon: message.replyTo!.kind == 'image'
                      ? Icons.image_outlined
                      : null,
                  onTap: onTapReplyPreview,
                  accentColor: isMe ? Colors.white : theme.primaryColor,
                  backgroundColor: isMe
                      ? Colors.white.withValues(alpha: 0.15)
                      : theme.primaryColor.withValues(alpha: 0.08),
                  foregroundColor: textColor,
                ),
              ),
            Text.rich(
              buildMentionSpans(
                body: message.body,
                mentions: message.mentions,
                baseStyle:
                    TextStyle(color: textColor, fontSize: 15.sp, height: 1.3),
                mentionColor: isMe ? Colors.white : theme.primaryColor,
              ),
            ),
            SizedBox(height: 3.h),
            _MetaRow(
              message: message,
              isMe: isMe,
              tint: isMe
                  ? Colors.white.withValues(alpha: 0.75)
                  : palette.textTertiary,
              readTint: isMe ? palette.info : palette.textTertiary,
              isDelivered: isDelivered,
              isRead: isRead,
            ),
          ],
        ),
      ),
    );

    return textBubble;
  }
}

class _ImageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final BorderRadius br;
  final AppPalette palette;
  final void Function(int)? onTapImage;
  final bool isDelivered;
  final bool isRead;

  const _ImageBubble({
    required this.message,
    required this.isMe,
    required this.br,
    required this.palette,
    required this.onTapImage,
    required this.isDelivered,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    final attachments = message.attachments;
    final showGrid = attachments.length > 1;

    return ClipRRect(
      borderRadius: br,
      child: Container(
        constraints: BoxConstraints(maxWidth: 240.w),
        color: palette.surfaceVariant,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            if (!showGrid)
              GestureDetector(
                onTap: () => onTapImage?.call(0),
                child: CachedNetworkImage(
                  imageUrl: attachments.first.thumbUrl ?? attachments.first.url,
                  fit: BoxFit.cover,
                  width: 240.w,
                  placeholder: (_, __) => SizedBox(
                    width: 240.w,
                    height: 180.h,
                    child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => SizedBox(
                    width: 240.w,
                    height: 180.h,
                    child:
                        Icon(Icons.broken_image, color: palette.textTertiary),
                  ),
                ),
              )
            else
              _MiniGrid(attachments: attachments, onTapImage: onTapImage),
            Positioned(
              bottom: 6.h,
              right: 8.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(AppRadius.full.r),
                ),
                child: _MetaRow(
                  message: message,
                  isMe: isMe,
                  tint: Colors.white,
                  readTint: palette.info,
                  isDelivered: isDelivered,
                  isRead: isRead,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniGrid extends StatelessWidget {
  final List<MessageAttachment> attachments;
  final void Function(int)? onTapImage;

  const _MiniGrid({required this.attachments, required this.onTapImage});

  @override
  Widget build(BuildContext context) {
    final shown = attachments.take(4).toList();
    final overflow = attachments.length - shown.length;

    return SizedBox(
      width: 240.w,
      height: 180.h,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: shown.length,
        itemBuilder: (context, i) {
          final isLastOverflow = overflow > 0 && i == shown.length - 1;
          return GestureDetector(
            onTap: () => onTapImage?.call(i),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: shown[i].thumbUrl ?? shown[i].url,
                  fit: BoxFit.cover,
                ),
                if (isLastOverflow)
                  Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    alignment: Alignment.center,
                    child: Text(
                      '+$overflow',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final Color tint;
  final Color readTint;
  final bool isDelivered;
  final bool isRead;

  const _MetaRow({
    required this.message,
    required this.isMe,
    required this.tint,
    required this.readTint,
    required this.isDelivered,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ts = message.timestamp;
    final time =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.editedAt != null) ...[
          Text(l10n.translate('chat.message.edited_tag'),
              style: TextStyle(
                  fontSize: 10.sp, color: tint, fontStyle: FontStyle.italic)),
          SizedBox(width: 4.w),
        ],
        Text(time, style: TextStyle(fontSize: 10.sp, color: tint)),
        if (isMe) ...[
          SizedBox(width: 4.w),
          Icon(
            isRead
                ? Icons.done_all_rounded
                : (isDelivered ? Icons.done_all_rounded : Icons.done_rounded),
            size: 14.r,
            color: isRead ? readTint : tint,
          ),
        ],
      ],
    );
  }
}

class _ForwardedTag extends StatelessWidget {
  final Color color;
  const _ForwardedTag({required this.color});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.reply_rounded,
              size: 12.r, color: color.withValues(alpha: 0.7)),
          SizedBox(width: 3.w),
          Text(
            l10n.translate('chat.message.forwarded_tag'),
            style: TextStyle(
                fontSize: 11.sp,
                fontStyle: FontStyle.italic,
                color: color.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _DeletedPlaceholder extends StatelessWidget {
  final bool isMe;
  const _DeletedPlaceholder({required this.isMe});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      constraints: BoxConstraints(maxWidth: 240.w),
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm.w, vertical: AppSpacing.xs.h),
      decoration: BoxDecoration(
        color: palette.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block_rounded, size: 14.r, color: palette.textTertiary),
          SizedBox(width: 6.w),
          Flexible(
            child: Text(
              l10n.translate('chat.message.deleted_placeholder'),
              style: TextStyle(
                  color: palette.textTertiary,
                  fontStyle: FontStyle.italic,
                  fontSize: 13.sp),
            ),
          ),
        ],
      ),
    );
  }
}

/// Faz 3 §3.5 — "sohbette plan_offer tipi mesaj kartı". Renders from
/// [MessageModel.planOfferInfo] alone (denormalized at send time by the
/// `sendPlanOffer` callable) — never re-fetches `meal_plan_templates`/
/// `plan_offers` itself, so it renders identically for both chat
/// participants even though only the recipient can actually read the
/// underlying offer doc.
class _PlanOfferCard extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isDelivered;
  final bool isRead;
  final void Function(MessagePlanOfferInfo info)? onTap;

  const _PlanOfferCard({
    required this.message,
    required this.isMe,
    required this.isDelivered,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final info = message.planOfferInfo;

    // Defensive: a plan_offer-typed message with no denormalized payload
    // (should never happen — sendPlanOffer always writes it) falls back to
    // a plain pill rather than crashing on a null field.
    if (info == null) {
      return _SystemMessagePill(text: message.body);
    }

    final primary = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: onTap != null ? () => onTap!(info) : null,
      child: Container(
        constraints: BoxConstraints(maxWidth: 260.w),
        padding: EdgeInsets.all(AppSpacing.sm.r),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg.r),
          border: Border.all(color: palette.glassStroke, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(alpha: 0.05),
              blurRadius: 6.r,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded, size: 16.r, color: primary),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    l10n.translate('chat.plan_offer.label'),
                    style: t.labelS
                        .copyWith(color: primary, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              info.templateName.isEmpty
                  ? l10n.translate('template_builder.library.untitled')
                  : info.templateName,
              style: t.bodyM.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (info.targetCalories > 0) ...[
              SizedBox(height: 2.h),
              Text('${info.targetCalories.round()} kcal',
                  style: t.labelS.copyWith(color: palette.textSecondary)),
            ],
            if (message.body.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(message.body, style: t.bodyM),
            ],
            if (onTap != null) ...[
              SizedBox(height: 8.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.translate('chat.plan_offer.view_cta'),
                    style: t.labelM
                        .copyWith(color: primary, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 2.w),
                  Icon(Icons.chevron_right_rounded, size: 16.r, color: primary),
                ],
              ),
            ],
            SizedBox(height: 4.h),
            _MetaRow(
              message: message,
              isMe: isMe,
              tint: palette.textTertiary,
              readTint: palette.info,
              isDelivered: isDelivered,
              isRead: isRead,
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemMessagePill extends StatelessWidget {
  final String text;
  const _SystemMessagePill({required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6.h),
        padding:
            EdgeInsets.symmetric(horizontal: AppSpacing.sm.w, vertical: 6.h),
        constraints: BoxConstraints(maxWidth: 280.w),
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.md.r),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: t.labelM.copyWith(color: palette.textSecondary),
        ),
      ),
    );
  }
}

/// Renders `message.body` with each `MessageMention` span bolded/tinted.
/// `MessageMention.offset`/`len` are UTF-16 code-unit indices (the model's own
/// doc comment — Dart's `String` indexing is already UTF-16), so a direct
/// `substring` is correct. Defensive against stale offsets (e.g. a mention
/// recorded before a later edit shifted the text) — any span that no longer
/// fits inside `body` is simply skipped rather than throwing.
///
/// Public (not `_`-private) specifically so it's unit-testable without a
/// widget harness — pure function, zero Firebase/Flutter-binding dependency
/// (`CLAUDE.md` §8: "new pure logic gets a unit test... has no excuse").
/// See `test/mention_spans_test.dart`.
TextSpan buildMentionSpans({
  required String body,
  required List<MessageMention> mentions,
  required TextStyle baseStyle,
  required Color mentionColor,
}) {
  if (mentions.isEmpty) {
    return TextSpan(text: body, style: baseStyle);
  }

  final valid = mentions
      .where(
          (m) => m.offset >= 0 && m.len > 0 && m.offset + m.len <= body.length)
      .toList()
    ..sort((a, b) => a.offset.compareTo(b.offset));

  final spans = <TextSpan>[];
  var cursor = 0;
  final mentionStyle =
      baseStyle.copyWith(color: mentionColor, fontWeight: FontWeight.w700);

  for (final m in valid) {
    if (m.offset < cursor) continue; // overlapping/duplicate — skip
    if (m.offset > cursor) {
      spans.add(
          TextSpan(text: body.substring(cursor, m.offset), style: baseStyle));
    }
    spans.add(TextSpan(
        text: body.substring(m.offset, m.offset + m.len), style: mentionStyle));
    cursor = m.offset + m.len;
  }
  if (cursor < body.length) {
    spans.add(TextSpan(text: body.substring(cursor), style: baseStyle));
  }
  return TextSpan(children: spans, style: baseStyle);
}
