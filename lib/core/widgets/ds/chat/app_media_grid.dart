import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../models/message_model.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_palette.dart';
import 'app_chat_attachment_image.dart';

/// One flattened grid cell — a single attachment plus a pointer back to its
/// parent message (multi-attachment messages contribute more than one item).
class AppMediaGridItem {
  final MessageAttachment attachment;
  final MessageModel sourceMessage;
  final int attachmentIndex;

  const AppMediaGridItem({
    required this.attachment,
    required this.sourceMessage,
    required this.attachmentIndex,
  });
}

/// Faz 2 §2.2 — media gallery grid. Purely presentational: the hosting
/// screen owns loading/empty/error states (via the existing
/// `AppShimmer`/`AppEmptyState`/`AppErrorState` primitives) and flattens
/// `ChatService.getChatMediaPage` results into [items].
class AppMediaGrid extends StatelessWidget {
  final List<AppMediaGridItem> items;
  final ValueChanged<int> onTapItem;
  final ScrollController? scrollController;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;
  final int crossAxisCount;

  const AppMediaGrid({
    super.key,
    required this.items,
    required this.onTapItem,
    this.scrollController,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.crossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (onLoadMore != null &&
            !isLoadingMore &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          onLoadMore!();
        }
        return false;
      },
      child: GridView.builder(
        controller: scrollController,
        padding: EdgeInsets.all(AppSpacing.xxs.r),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 2.w,
          mainAxisSpacing: 2.h,
        ),
        itemCount: items.length + (isLoadingMore ? crossAxisCount : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return Container(color: palette.shimmerBase);
          }
          final item = items[index];

          // Faz 5 — ChatAttachmentImage is the shared resolve point for both
          // attachment shapes (already-resolved `chat_images/` URLs AND
          // scoped `chat_media/` storage paths that need the
          // `getChatMediaUrl` callable) — see its own doc comment.
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onTapItem(index);
            },
            child: ChatAttachmentImage(
              attachment: item.attachment,
            ),
          );
        },
      ),
    );
  }
}
