import 'package:flutter/material.dart';
import '../../../core/models/community_post.dart';
import '../../community/widgets/community_widgets.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/community_service.dart';

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
    _post = _ensureLikeState(widget.post);
  }

  @override
  void didUpdateWidget(GlassPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post) {
      _post = _ensureLikeState(widget.post);
    }
  }

  CommunityPost _ensureLikeState(CommunityPost p) {
    if (p.isLiked && !p.userReactions.contains('❤️')) {
      return p.copyWith(
        userReactions: List.from(p.userReactions)..add('❤️'),
      );
    }
    return p;
  }

  void _handleReaction(String emoji) {
    setState(() {
      final hasReaction = _post.userReactions.contains(emoji);
      List<String> userReactions = List.from(_post.userReactions);
      Map<String, int> reactions = Map.from(_post.reactions);

      if (!hasReaction) {
        // Adding
        // Safety check: ensure it's not already in the list to prevent duplicates
        if (!userReactions.contains(emoji)) {
          userReactions.add(emoji);
          reactions[emoji] = (reactions[emoji] ?? 0) + 1;
        }
      } else {
        // Removing
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

    // Fire and forget, don't await to keep UI responsive
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
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage(_post.author.avatarUrl),
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
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF94A3B8)),
                    onSelected: (value) {
                      if (value == 'share') widget.onShare();
                      if (value == 'delete') {
                        _showDeleteDialog(context, _post.id);
                      }
                    },
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                          value: 'share',
                          child: Row(children: [
                            const Icon(Icons.share_outlined, size: 20),
                            const SizedBox(width: 12),
                            Text(AppLocalizations.of(context)
                                .translate('community.menu.share'))
                          ])),
                      PopupMenuItem(
                          value: 'report',
                          child: Row(children: [
                            const Icon(Icons.report_gmailerrorred,
                                size: 20, color: Colors.red),
                            const SizedBox(width: 12),
                            Text(
                                AppLocalizations.of(context)
                                    .translate('community.menu.report'),
                                style: const TextStyle(color: Colors.red))
                          ])),
                      if (_post.author.id == CommunityService().currentUserId)
                        PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.red),
                              const SizedBox(width: 12),
                              Text(
                                  AppLocalizations.of(context)
                                      .translate('community.menu.delete'),
                                  style: const TextStyle(color: Colors.red))
                            ])),
                    ],
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

              const SizedBox(height: 16),

              // Image content
              if (_post.imageUrls.isNotEmpty)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      height: 256,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: NetworkImage(_post.imageUrls.first),
                          fit: BoxFit.cover,
                        ),
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
                                ? const Color(0xFFF97316).withOpacity(0.2)
                                : (isDark
                                    ? Colors.white10
                                    : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isUserReaction
                                    ? const Color(0xFFF97316)
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
                    onTap: () => _handleReaction('❤️'),
                    child: Icon(
                      _post.userReactions.contains('❤️')
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: _post.userReactions.contains('❤️')
                          ? Colors.red
                          : (isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${_post.reactions['❤️'] ?? 0}",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),

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
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: Color(0xFFF97316)),
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
    final emojis = ['👎', '😂', '😮', '😢', '🔥'];

    return PopupMenuButton<String>(
      tooltip: "Add Reaction",
      offset: const Offset(-150, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      color: isDark ? const Color(0xFF334155) : Colors.white,
      elevation: 8,
      enableFeedback: true,
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            child: SizedBox(
              height: 40,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: emojis.map((e) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context, e);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          )
        ];
      },
      onSelected: (emoji) => _handleReaction(emoji),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: isSmall
            ? BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
                shape: BoxShape.circle)
            : null,
        child: Icon(Icons.add_reaction_outlined,
            size: isSmall ? 16 : 20,
            color: isDark ? Colors.white70 : Colors.grey.shade600),
      ),
    );
  }
}
