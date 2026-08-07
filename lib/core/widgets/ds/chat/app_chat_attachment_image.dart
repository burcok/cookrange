import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../models/message_model.dart';
import '../../../services/chat_media_url_cache.dart';
import '../../../theme/app_palette.dart';

/// Faz 5 — the ONE place a chat image attachment's renderable URL gets
/// resolved, shared by `AppMessageBubble`'s image bubble/mini-grid and
/// `AppMediaGrid`'s gallery cells (CLAUDE.md R7: "build the component once
/// in `lib/core/widgets/ds/` and reuse it") so the two call sites can never
/// drift on how a scoped-storage-path attachment resolves.
///
/// Two attachment shapes coexist by design — Piece D (storage scoping fix)
/// is additive, not a migration of existing uploads:
///  - Legacy/current (`chat_images/{scopeId}/` uploads —
///    `StorageUploadService.uploadChatImage`): [MessageAttachment.url]/
///    [MessageAttachment.thumbUrl] are already-resolved `https://` download
///    URLs. Rendered directly — zero indirection, zero extra frame.
///  - New (`chat_media/{chatId}/{uid}/{fileName}` uploads —
///    `StorageUploadService.uploadGroupChatMedia`, the group-chat storage-
///    scoping fix): that Storage path's `read` rule is always `false`, so
///    there is no download URL to read directly. [MessageAttachment
///    .storagePath]/[thumbStoragePath] carry the bare path instead, resolved
///    through `ChatMediaUrlCache` (which calls the `getChatMediaUrl`
///    callable — re-verifies chat membership server-side — and caches the
///    short-lived signed URL it returns).
class ChatAttachmentImage extends StatefulWidget {
  final MessageAttachment attachment;

  /// Prefer the thumbnail (either [MessageAttachment.thumbUrl] or
  /// [MessageAttachment.thumbStoragePath]) over the full-size image when
  /// available — true for every existing call site (bubble + grid both
  /// render a small preview, never the full-resolution image inline).
  final bool preferThumb;

  final BoxFit fit;
  final double? width;

  /// Applied ONLY to the loading/error placeholder box, never to the
  /// resolved image itself — matches this file's pre-Faz-5 behavior exactly
  /// (the successful image was never height-constrained, only
  /// width-constrained, so it always rendered at its natural aspect ratio).
  final double? height;

  const ChatAttachmentImage({
    super.key,
    required this.attachment,
    this.preferThumb = true,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  State<ChatAttachmentImage> createState() => _ChatAttachmentImageState();
}

class _ChatAttachmentImageState extends State<ChatAttachmentImage> {
  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;
    final path =
        widget.preferThumb ? (a.thumbStoragePath ?? a.storagePath) : a.storagePath;

    if (path == null || path.isEmpty) {
      // Legacy/current attachment — already a resolved URL. Render directly,
      // with NO async indirection: this is the overwhelming majority of
      // chat images today (every `chat_images/`-uploaded one), and it must
      // never regress to an extra loading frame just because a sibling
      // attachment shape now exists.
      final directUrl = widget.preferThumb ? (a.thumbUrl ?? a.url) : a.url;
      return _networkImage(context, directUrl);
    }

    final chatId = ChatMediaUrlCache.chatIdFromStoragePath(path);
    if (chatId == null) {
      // Malformed path (shouldn't happen — StorageUploadService constructs
      // it) — best-effort fall back to whatever URL exists rather than a
      // guaranteed broken-image state.
      final directUrl = widget.preferThumb ? (a.thumbUrl ?? a.url) : a.url;
      return _networkImage(context, directUrl);
    }

    return FutureBuilder<String?>(
      future: ChatMediaUrlCache().resolve(chatId: chatId, storagePath: path),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _placeholderBox(context);
        }
        final url = snap.data;
        if (url == null || url.isEmpty) return _errorBox(context);
        return _networkImage(context, url);
      },
    );
  }

  Widget _networkImage(BuildContext context, String url) {
    if (url.isEmpty) return _errorBox(context);
    return CachedNetworkImage(
      imageUrl: url,
      fit: widget.fit,
      width: widget.width,
      placeholder: (_, __) => _placeholderBox(context),
      errorWidget: (_, __, ___) => _errorBox(context),
    );
  }

  Widget _placeholderBox(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Container(color: palette.shimmerBase),
    );
  }

  Widget _errorBox(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Container(
        color: palette.shimmerBase,
        child: Icon(Icons.broken_image_outlined, color: palette.textTertiary),
      ),
    );
  }
}
