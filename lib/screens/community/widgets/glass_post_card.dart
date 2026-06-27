import 'package:flutter/material.dart';
import '../../profile/profile_screen.dart';
import 'package:cookrange/core/widgets/app_image.dart';
import '../../../core/models/community_post.dart';
import '../../community/widgets/community_widgets.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/community_service.dart';
import 'draggable_reaction_button.dart';
import '../../../../core/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/unified_action_sheet.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_dimensions.dart';

class GlassPostCard extends StatefulWidget {
  final CommunityPost post;
  final VoidCallback onTap;
  final VoidCallback onLike;
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
    final service = CommunityService();
    final isOwner = _post.author.id == service.currentUserId;

    showUnifiedActionSheet(
      context: context,
      title: appLoc.translate('community.menu.options'),
      actions: [
        ActionSheetItem(
          label: appLoc.translate('community.menu.share'),
          icon: Icons.share_outlined,
          onTap: widget.onShare,
        ),
        if (!isOwner) ...[
          ActionSheetItem(
            label: appLoc.translate('community.menu.report'),
            icon: Icons.report_gmailerrorred,
            isDestructive: true,
            onTap: () => _showReportSheet(context, service),
          ),
          ActionSheetItem(
            label: appLoc.translate('community.menu.block'),
            icon: Icons.block,
            isDestructive: true,
            onTap: () async {
              await service.blockUser(_post.author.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        appLoc.translate('community.block_success'))));
              }
            },
          ),
        ],
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

  void _showReportSheet(BuildContext context, CommunityService service) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);

    final reasons = [
      ('spam', l10n.translate('community.report.reason_spam')),
      ('harassment', l10n.translate('community.report.reason_harassment')),
      ('inappropriate', l10n.translate('community.report.reason_inappropriate')),
      ('misinformation', l10n.translate('community.report.reason_misinformation')),
      ('other', l10n.translate('community.report.reason_other')),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String? selectedReason;
        bool submitting = false;

        return StatefulBuilder(builder: (context, setModal) {
          return Container(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.sm, AppSpacing.xl,
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: AppSize.sheetHandleW,
                    height: AppSize.sheetHandleH,
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
                Text(
                  l10n.translate('community.report.dialog_title'),
                  style: textStyles.headlineS,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.translate('community.report.dialog_subtitle'),
                  style: textStyles.bodyM,
                ),
                const SizedBox(height: AppSpacing.md),
                RadioGroup<String>(
                  groupValue: selectedReason,
                  onChanged: (v) => setModal(() => selectedReason = v),
                  child: Column(
                    children: reasons
                        .map((r) => RadioListTile<String>(
                              value: r.$1,
                              title: Text(r.$2, style: textStyles.titleM),
                              activeColor: palette.error,
                              contentPadding: EdgeInsets.zero,
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (selectedReason == null || submitting)
                        ? null
                        : () async {
                            setModal(() => submitting = true);
                            await service.reportPost(_post.id, selectedReason!);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(l10n.translate(
                                          'community.report.submitted'))));
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(l10n.translate('post.submit')),
                  ),
                ),
              ],
            ),
          );
        });
      },
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
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);
    final primaryColor = context.watch<ThemeProvider>().primaryColor;

    final displayReactions =
        _post.reactions.entries.where((e) => e.key != '❤️').toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: GestureDetector(
        onTap: widget.onTap,
        child: GlassContainer(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          color: palette.surface,
          opacity: 1.0,
          enableBlur: false, // OPTIMIZATION: Disable blur for list performance
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(alpha: AppElevation.opacityLight),
              offset: AppElevation.offsetLg,
              blurRadius: AppElevation.blurLg,
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProfileScreen(userId: _post.author.id),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: AppSize.avatarMd,
                          height: AppSize.avatarMd,
                          decoration:
                              const BoxDecoration(shape: BoxShape.circle),
                          child: ClipOval(
                            child: AppImage(
                              imageUrl: _post.author.avatarUrl,
                              width: AppSize.avatarMd,
                              height: AppSize.avatarMd,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _post.author.name,
                              style: textStyles.titleM,
                            ),
                            Text(
                              _formatTime(context, _post.timestamp),
                              style: textStyles.labelS,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: palette.textTertiary),
                    onPressed: () => _showPostOptions(context),
                  )
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Content Text
              RichText(
                text: TextSpan(
                  style: textStyles.bodyL,
                  children: _parseContentFull(_post.content, _post.tags, primaryColor),
                ),
              ),

              if (_post.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _post.tags
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs + 2, vertical: AppSpacing.xxs),
                              decoration: BoxDecoration(
                                color: palette.surfaceVariant,
                                borderRadius: BorderRadius.circular(AppRadius.full),
                                border: Border.all(color: palette.border),
                              ),
                              child: Text(
                                tag,
                                style: textStyles.labelS,
                              ),
                            ))
                        .toList(),
                  ),
                ),

              const SizedBox(height: AppSpacing.md),

              // Image content
              if (_post.imageUrls.isNotEmpty)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: AppImage(
                        imageUrl: _post.imageUrls.first,
                        height: 256,
                        width: double.infinity,
                      ),
                    ),
                    if (_post.imageUrls.length > 1)
                      Container(
                        margin: const EdgeInsets.all(AppSpacing.sm),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs + 2, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(AppRadius.full),
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

              const SizedBox(height: AppSpacing.md),

              // Reactions Component (Always Visible)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...displayReactions.map((entry) {
                      final isUserReaction =
                          _post.userReactions.contains(entry.key);
                      return GestureDetector(
                        onTap: () => _handleReaction(entry.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                          decoration: BoxDecoration(
                            color: isUserReaction
                                ? primaryColor.withValues(alpha: 0.2)
                                : palette.surfaceVariant,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                                color: isUserReaction
                                    ? primaryColor
                                    : Colors.transparent),
                          ),
                          child: Text(
                            "${entry.key} ${entry.value}",
                            style: textStyles.bodyM.copyWith(
                              color: palette.textPrimary,
                              fontWeight: isUserReaction
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }),
                    _buildAddReactionButton(context, isSmall: true),
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
                          ? palette.error
                          : palette.textSecondary,
                      size: AppSize.iconLg,
                    ),
                  ),
                  // Face Pile & Text
                  if (_post.likesCount > 0) ...[
                    const SizedBox(width: AppSpacing.xs),
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
                                    color: palette.surface,
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: AppImage(
                                    imageUrl: entry.value.avatarUrl,
                                    width: 20,
                                    height: 20,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        _getLikeText(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyles.labelM,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 6),
                    Text(
                      "${_post.likesCount}",
                      style: textStyles.titleM,
                    ),
                  ],

                  const SizedBox(width: AppSpacing.xl),
                  // Comments
                  GestureDetector(
                    onTap: widget.onComment,
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            color: palette.textSecondary,
                            size: AppSize.iconMd),
                        const SizedBox(width: 6),
                        Text(
                          "${_post.commentsCount}",
                          style: textStyles.labelM,
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

  List<InlineSpan> _parseContentFull(
      String content, List<String> tags, Color primaryColor) {
    List<InlineSpan> spans = [];
    final words = content.split(' ');
    for (var word in words) {
      if (word.startsWith('#')) {
        spans.add(TextSpan(
          text: "$word ",
          style: TextStyle(
              fontWeight: FontWeight.w600, color: primaryColor),
        ));
      } else {
        spans.add(TextSpan(text: "$word "));
      }
    }
    return spans;
  }

  void _showDeleteDialog(BuildContext context, String postId) {
    final appLoc = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
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
              style: TextStyle(color: palette.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddReactionButton(BuildContext context, {bool isSmall = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    final isLikedByMe = _post.isLiked;

    if (isLikedByMe) {
      if (likes == 1) return appLoc.translate('community.likes.you');

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
