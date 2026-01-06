import 'package:flutter/material.dart';
import 'package:cookrange/core/widgets/app_image.dart';
import '../../../core/models/community_post.dart';
import '../../community/widgets/community_widgets.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/community_service.dart';
import 'draggable_reaction_button.dart';
import '../../../../core/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/unified_action_sheet.dart';

class GlassPostCard extends StatefulWidget {
  final CommunityPost post;
  final VoidCallback onTap;
  final VoidCallback onLike; // Legacy, can use onReaction('❤️') instead
  final VoidCallback onComment;
  final VoidCallback onShare;
  final Function(String emoji) onReaction;

  const GlassPostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onReaction,
  });

  @override
  State<GlassPostCard> createState() => _GlassPostCardState();
}

class _GlassPostCardState extends State<GlassPostCard> {
  late CommunityPost _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void didUpdateWidget(GlassPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post) {
      _post = widget.post;
    }
  }

  void _handleLike() {
    setState(() {
      final isLiked = !_post.isLiked;
      final likesCount = _post.likesCount + (isLiked ? 1 : -1);

      _post = _post.copyWith(
        isLiked: isLiked,
        likesCount: likesCount,
      );
    });
    widget.onLike();
  }

  void _showPostOptions(BuildContext context) {
    final appLoc = AppLocalizations.of(context);
    final isOwner = _post.author.id == CommunityService().currentUserId;

    showUnifiedActionSheet(
      context: context,
      title: appLoc.translate('community.menu.options'),
      actions: [
        ActionSheetItem(
          label: appLoc.translate('community.menu.share'),
          icon: Icons.share_outlined,
          onTap: widget.onShare,
        ),
        ActionSheetItem(
          label: appLoc.translate('community.menu.report'),
          icon: Icons.report_gmailerrorred,
          isDestructive: true,
          onTap: () {
            CommunityService().reportPost(_post.id, "Inappropriate content");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(appLoc.translate('community.report_success',
                      variables: {'type': 'Post'}))),
            );
          },
        ),
        if (isOwner)
          ActionSheetItem(
            label: appLoc.translate('community.menu.delete'),
            icon: Icons.delete_outline,
            isDestructive: true,
            onTap: () => _showDeleteDialog(context, _post.id),
          ),
      ],
    );
  }

  void _handleReaction(String emoji) {
    setState(() {
      final hasReaction = _post.userReactions.contains(emoji);
      List<String> userReactions = List.from(_post.userReactions);
      Map<String, int> reactions = Map.from(_post.reactions);

      if (!hasReaction) {
        if (!userReactions.contains(emoji)) {
          userReactions.add(emoji);
          reactions[emoji] = (reactions[emoji] ?? 0) + 1;
        }
      } else {
        userReactions.remove(emoji);
        final count = (reactions[emoji] ?? 0) - 1;
        if (count > 0) {
          reactions[emoji] = count;
        } else {
          reactions.remove(emoji);
        }
      }

      _post = _post.copyWith(
        reactions: reactions,
        userReactions: userReactions,
      );
    });

    widget.onReaction(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter out '❤️' from the chips display
    final displayReactions =
        _post.reactions.entries.where((e) => e.key != '❤️').toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: GestureDetector(
        onTap: widget.onTap,
        child: GlassContainer(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(20),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          opacity: isDark ? 0.6 : 0.6,
          enableBlur: false, // OPTIMIZATION: Disable blur for list performance
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F2687).withOpacity(0.05),
              offset: const Offset(0, 8),
              blurRadius: 32,
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: ClipOval(
                          child: AppImage(
                            imageUrl: _post.author.avatarUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _post.author.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            _formatTime(context, _post.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF94A3B8)),
                    onPressed: () => _showPostOptions(context),
                  )
                ],
              ),
              const SizedBox(height: 16),

              // Content Text
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF334155),
                    fontFamily: 'Poppins',
                  ),
                  children: _parseContentFull(_post.content, _post.tags),
                ),
              ),

              if (_post.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _post.tags
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      isDark ? Colors.white10 : Colors.black12,
                                ),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),

              const SizedBox(height: 16),

              // Image content
              if (_post.imageUrls.isNotEmpty)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AppImage(
                        imageUrl: _post.imageUrls.first,
                        height: 256,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (_post.imageUrls.length > 1)
                      Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "+${_post.imageUrls.length - 1}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),

              const SizedBox(height: 16),

              // Reactions Component (Always Visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...displayReactions.map((entry) {
                      final isUserReaction =
                          _post.userReactions.contains(entry.key);
                      return GestureDetector(
                        onTap: () => _handleReaction(entry.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isUserReaction
                                ? context
                                    .watch<ThemeProvider>()
                                    .primaryColor
                                    .withOpacity(0.2)
                                : (isDark
                                    ? Colors.white10
                                    : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isUserReaction
                                    ? context
                                        .watch<ThemeProvider>()
                                        .primaryColor
                                    : Colors.transparent),
                          ),
                          child: Text(
                            "${entry.key} ${entry.value}",
                            style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: isUserReaction
                                    ? FontWeight.bold
                                    : FontWeight.normal),
                          ),
                        ),
                      );
                    }),
                    _buildAddReactionButton(context, isDark, isSmall: true),
                  ],
                ),
              ),

              // Actions Row
              Row(
                children: [
                  // Like (Heart) Action
                  GestureDetector(
                    onTap: _handleLike,
                    child: Icon(
                      _post.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _post.isLiked
                          ? Colors.red
                          : (isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                      size: 24,
                    ),
                  ),
                  // Face Pile & Text
                  if (_post.likesCount > 0) ...[
                    const SizedBox(width: 8),
                    if (_post.likedByUsers.isNotEmpty)
                      SizedBox(
                        width: 24.0 +
                            (14.0 * (_post.likedByUsers.take(3).length - 1)),
                        height: 24,
                        child: Stack(
                          children: _post.likedByUsers
                              .take(3)
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) {
                            return Positioned(
                              left: entry.key * 14.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF1E293B)
                                        : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: AppImage(
                                    imageUrl: entry.value.avatarUrl,
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _getLikeText(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark ? Colors.white70 : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 6),
                    Text(
                      "${_post.likesCount}",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],

                  const SizedBox(width: 24),
                  // Comments
                  GestureDetector(
                    onTap: widget.onComment,
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            size: 22),
                        const SizedBox(width: 6),
                        Text(
                          "${_post.commentsCount}",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(BuildContext context, DateTime time) {
    if (!context.mounted) return "";
    final appLoc = AppLocalizations.of(context);
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) {
      return "${diff.inMinutes} ${diff.inMinutes == 1 ? appLoc.translate('community.time.min') : appLoc.translate('community.time.mins')}";
    }
    if (diff.inHours < 24) {
      return "${diff.inHours} ${diff.inHours == 1 ? appLoc.translate('community.time.hour') : appLoc.translate('community.time.hours')}";
    }
    return "${diff.inDays} ${diff.inDays == 1 ? appLoc.translate('community.time.day') : appLoc.translate('community.time.days')}";
  }

  List<InlineSpan> _parseContentFull(String content, List<String> tags) {
    List<InlineSpan> spans = [];
    final words = content.split(' ');
    for (var word in words) {
      if (word.startsWith('#')) {
        spans.add(TextSpan(
          text: "$word ",
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.watch<ThemeProvider>().primaryColor),
        ));
      } else {
        spans.add(TextSpan(text: "$word "));
      }
    }

    return spans;
  }

  void _showDeleteDialog(BuildContext context, String postId) {
    final appLoc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appLoc.translate('community.delete_confirm.title')),
        content: Text(appLoc.translate('community.delete_confirm.content')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(appLoc.translate('community.delete_confirm.cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await CommunityService().deletePost(postId);
            },
            child: Text(
              appLoc.translate('community.delete_confirm.action'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddReactionButton(BuildContext context, bool isDark,
      {bool isSmall = false}) {
    return DraggableReactionButton(
      isDark: isDark,
      isSmall: isSmall,
      onReactionSelected: (emoji) => _handleReaction(emoji),
    );
  }

  String _getLikeText() {
    final likes = _post.likesCount;
    if (likes == 0) return "";

    final appLoc = AppLocalizations.of(context);
    final likers = _post.likedByUsers;

    // Check isLiked
    // Note: In GlassPostCard, _post is a CommunityPost which has isLiked
    final isLikedByMe = _post.isLiked;
    // We can't easily get currentUserId here without a provider look up or service call,
    // but we can check if likers contains 'Me'? No, assume isLiked is source.
    // However, to filter 'Me' out of names, we need my ID.
    // GlassPostCard is usually stateless-ish but has state.
    // Let's assume we can get ID from simple check or pass it.
    // Actually we can check 'isLiked'. If true, we *should* see if one of the avatars matches us?
    // But simplest is to match logic:

    if (isLikedByMe) {
      if (likes == 1) return appLoc.translate('community.likes.you');

      // We need to remove 'Self' from names list if present.
      // Since we don't have 'currentUserId' easily handy as a variable (it's in service),
      // let's grab it or try to find a user with "You"? No.
      // Let's look at `CommunityService`.
      // We can use `CommunityService().currentUserId`.
      final currentUserId = CommunityService().currentUserId;

      final otherLikers = likers.where((u) => u.id != currentUserId).toList();
      final otherCount = likes - 1;

      if (otherLikers.isEmpty) {
        return appLoc.translate('community.likes.you_many',
            variables: {'name': 'User', 'count': otherCount.toString()});
      }

      final name1 = otherLikers[0].name.split(' ').first;

      if (otherCount == 1) {
        return appLoc
            .translate('community.likes.you_1', variables: {'name': name1});
      }

      if (otherLikers.length >= 2 && otherCount > 2) {
        final name2 = otherLikers[1].name.split(' ').first;
        return appLoc.translate('community.likes.you_many_2', variables: {
          'name1': name1,
          'name2': name2,
          'count': (otherCount - 2).toString()
        });
      }

      return appLoc.translate('community.likes.you_many', variables: {
        'name1': name1,
        'name': name1,
        'count': (otherCount - 1).toString()
      });
    }

    if (likers.isEmpty) {
      return appLoc.translate('community.likes.simple',
          variables: {'count': likes.toString()});
    }

    final name1 = likers[0].name.split(' ').first;

    if (likers.length == 1 && likes == 1) {
      return appLoc
          .translate('community.likes.one', variables: {'name': name1});
    }

    if (likers.length >= 2) {
      final name2 = likers[1].name.split(' ').first;
      if (likes == 2) {
        return appLoc.translate('community.likes.two',
            variables: {'name1': name1, 'name2': name2});
      }
      return appLoc.translate('community.likes.many', variables: {
        'name1': name1,
        'name2': name2,
        'count': (likes - 2).toString()
      });
    }

    return appLoc.translate('community.likes.many', variables: {
      'name1': name1,
      'name2': 'User',
      'count': (likes - 1).toString()
    });
  }
}
