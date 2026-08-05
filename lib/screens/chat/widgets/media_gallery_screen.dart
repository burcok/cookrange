import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cookrange/core/localization/app_localizations.dart';
import 'package:cookrange/core/models/message_model.dart';
import 'package:cookrange/core/services/chat_service.dart';
import 'package:cookrange/core/widgets/ds/ds.dart';

/// Faz 2 §2.2 — media gallery: every image ever sent in [chatId], newest
/// first, backed by `ChatService.getChatMediaPage`'s `(type, timestamp)`
/// composite-indexed query (NOT a client-side filter of whatever happens to
/// be paginated into the main chat view — a real gallery over full history).
class MediaGalleryScreen extends StatefulWidget {
  final String chatId;

  const MediaGalleryScreen({super.key, required this.chatId});

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  final ChatService _chatService = ChatService();
  final List<AppMediaGridItem> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _lastMessageId;
  Object? _error;

  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _chatService.getChatMediaPage(widget.chatId);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(_flatten(page.media));
        _lastMessageId = page.lastMessageId;
        _hasMore = page.media.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _lastMessageId == null) return;
    setState(() => _loadingMore = true);
    final page = await _chatService.getChatMediaPage(
      widget.chatId,
      startAfterMessageId: _lastMessageId,
    );
    if (!mounted) return;
    setState(() {
      _items.addAll(_flatten(page.media));
      _lastMessageId = page.lastMessageId ?? _lastMessageId;
      _hasMore = page.media.length >= _pageSize;
      _loadingMore = false;
    });
  }

  List<AppMediaGridItem> _flatten(List<MessageModel> messages) {
    final out = <AppMediaGridItem>[];
    for (final m in messages) {
      for (var i = 0; i < m.attachments.length; i++) {
        out.add(AppMediaGridItem(
            attachment: m.attachments[i],
            sourceMessage: m,
            attachmentIndex: i));
      }
    }
    return out;
  }

  void _openViewer(int index) {
    Navigator.of(context).push(AppTransitions.fadeScale(
      _MediaViewerScreen(items: _items, initialIndex: index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text(l10n.translate('chat.media_gallery.title'),
            style: AppText.of(context).titleL),
      ),
      body: _loading
          ? const AppSkeletonStatGrid(itemCount: 9, crossAxisCount: 3)
          : _error != null
              ? AppErrorState(
                  title: l10n.translate('common.something_wrong'),
                  onRetry: _loadFirstPage,
                  retryLabel: l10n.translate('common.retry'),
                )
              : _items.isEmpty
                  ? AppEmptyState(
                      icon: Icons.photo_library_outlined,
                      title: l10n.translate('chat.media_gallery.empty'),
                    )
                  : AppMediaGrid(
                      items: _items,
                      onTapItem: _openViewer,
                      onLoadMore: _loadMore,
                      isLoadingMore: _loadingMore,
                    ),
    );
  }
}

class _MediaViewerScreen extends StatefulWidget {
  final List<AppMediaGridItem> items;
  final int initialIndex;

  const _MediaViewerScreen({required this.items, required this.initialIndex});

  @override
  State<_MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<_MediaViewerScreen> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index];
    final ts = item.sourceMessage.timestamp;
    final dateLabel =
        '${ts.day.toString().padLeft(2, '0')}/${ts.month.toString().padLeft(2, '0')}/${ts.year} '
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(dateLabel,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final it = widget.items[i];
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: it.attachment.url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image,
                    color: Colors.white38, size: 48),
              ),
            ),
          );
        },
      ),
    );
  }
}
