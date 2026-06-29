import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../profile/profile_screen.dart';
import 'package:cookrange/core/widgets/app_image.dart';
import '../../../core/models/community_post.dart';
import '../../community/widgets/community_widgets.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/community_service.dart';
import '../../../core/utils/profile_navigation.dart';
import 'draggable_reaction_button.dart';
import '../../../../core/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/ds/app_avatar.dart';
import '../../../core/widgets/ds/app_sheet.dart';
import '../../../core/widgets/ds/app_snackbar.dart';
import '../../../core/widgets/ds/app_button.dart';
import '../community_topics.dart';

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
  bool _isSaved = false;
  StreamSubscription<bool>? _saveSub;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _saveSub = CommunityService()
        .isPostSavedStream(widget.post.id)
        .listen((saved) {
      if (mounted) setState(() => _isSaved = saved);
    });
  }

  @override
  void didUpdateWidget(GlassPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post) {
      _post = widget.post;
    }
  }

  @override
  void dispose() {
    _saveSub?.cancel();
    super.dispose();
  }

  void _toggleSave() {
    final service = CommunityService();
    if (_isSaved) {
      service.unsavePost(_post.id);
    } else {
      service.savePost(_post);
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
    final currentUid =
        AuthService().currentUser?.uid ?? '';
    final isOwner = _post.author.id == currentUid;

    AppSheet.show<void>(
      context: context,
      title: appLoc.translate('community.menu.options'),
      child: _PostMoreMenuContent(
        isOwner: isOwner,
        appLoc: appLoc,
        onShare: () {
          Navigator.pop(context);
          widget.onShare();
        },
        onCopyLink: () {
          Navigator.pop(context);
          Clipboard.setData(
              ClipboardData(text: 'https://cookrange.app/post/${_post.id}'));
          AppSnackBar.success(
              context, appLoc.translate('post.link_copied'));
        },
        onReport: isOwner
            ? null
            : () {
                Navigator.pop(context);
                _showReportSheet(context, currentUid: currentUid);
              },
        onBlock: isOwner
            ? null
            : () async {
                Navigator.pop(context);
                await service.blockUser(_post.author.id);
                if (context.mounted) {
                  AppSnackBar.success(
                      context, appLoc.translate('community.block_success'));
                }
              },
        onDelete: isOwner
            ? () {
                Navigator.pop(context);
                _showDeleteDialog(context, _post.id);
              }
            : null,
      ),
    );
  }

  void _showReportSheet(BuildContext context, {required String currentUid}) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);
    final service = CommunityService();

    final reasons = [
      ('spam', l10n.translate('report.reason_spam')),
      ('inappropriate', l10n.translate('report.reason_inappropriate')),
      ('misinformation', l10n.translate('report.reason_misinformation')),
      ('harassment', l10n.translate('report.reason_harassment')),
      ('other', l10n.translate('report.reason_other')),
    ];

    AppSheet.show<void>(
      context: context,
      title: l10n.translate('report.title'),
      child: _ReportReasonContent(
        reasons: reasons,
        palette: palette,
        textStyles: textStyles,
        l10n: l10n,
        onSubmit: (selectedReason) async {
          await service.reportContent(
            type: 'post',
            targetId: _post.id,
            targetAuthorUid: _post.author.id,
            reporterUid: currentUid,
            reason: selectedReason,
          );
        },
      ),
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
                        AppInitialsAvatar(
                          photoUrl: _post.author.avatarUrl,
                          name: _post.author.name,
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
                  if (_post.author.id != (AuthService().currentUser?.uid ?? ''))
                    IconButton(
                      icon: Icon(Icons.more_horiz_rounded,
                          color: palette.textTertiary),
                      onPressed: () => _showPostOptions(context),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Content Text — supports #hashtags and tappable @mentions
              RichText(
                text: TextSpan(
                  style: textStyles.bodyL,
                  children: _parseContentFull(
                    _post.content,
                    _post.tags,
                    primaryColor,
                    metadata: _post.metadata,
                  ),
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

              // Topic pill — shown when metadata contains a topic key
              _TopicPill(post: _post),

              const SizedBox(height: AppSpacing.md),

              // Structured post type attachment
              if (_post.postType != PostType.text)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _PostTypeCard(post: _post),
                ),

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

              // Verified author banner (coach / gym_owner only)
              if (_post.authorRole != null && _post.authorRole!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _VerifiedAuthorBanner(post: _post),
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
                  const Spacer(),
                  // Bookmark
                  GestureDetector(
                    onTap: _toggleSave,
                    child: Icon(
                      _isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: _isSaved ? primaryColor : palette.textSecondary,
                      size: AppSize.iconMd,
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

  /// Parses content and renders #hashtags and @mentions with distinct styles.
  /// @mentions are tappable — they open the mentioned user's profile if the uid
  /// is found in post.metadata['mentions'].
  List<InlineSpan> _parseContentFull(
      String content, List<String> tags, Color primaryColor,
      {Map<String, dynamic>? metadata}) {
    final textStyles = AppText.of(context);
    const mentionColor = AppPalette.brand;
    final mentions =
        (metadata?['mentions'] as List<dynamic>?) ?? <dynamic>[];

    final List<InlineSpan> spans = [];
    // Split by whitespace but keep delimiters to preserve spacing
    final parts = content.split(RegExp(r'(?<=\s)|(?=\s)'));

    for (final part in parts) {
      final trimmed = part.trimRight();
      if (trimmed.startsWith('#')) {
        spans.add(TextSpan(
          text: part,
          style: textStyles.bodyL.copyWith(
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ));
      } else if (trimmed.startsWith('@') && trimmed.length > 1) {
        final handle = trimmed.substring(1); // name without @
        // Find uid by matching name (case-insensitive)
        String? uid;
        for (final m in mentions) {
          if (m is Map &&
              (m['name'] as String?)?.toLowerCase() ==
                  handle.toLowerCase()) {
            uid = m['uid'] as String?;
            break;
          }
        }
        final trailing = part.substring(trimmed.length); // trailing whitespace
        if (uid != null) {
          final capturedUid = uid;
          spans.add(TextSpan(
            text: '@$handle$trailing',
            style: textStyles.bodyL.copyWith(
              fontWeight: FontWeight.w600,
              color: mentionColor,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () =>
                  openUserProfile(context, userId: capturedUid),
          ));
        } else {
          spans.add(TextSpan(
            text: '@$handle$trailing',
            style: textStyles.bodyL.copyWith(
              fontWeight: FontWeight.w600,
              color: mentionColor,
            ),
          ));
        }
      } else {
        spans.add(TextSpan(text: part));
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

// ─── Structured post type attachment card ─────────────────────────────────────

class _PostTypeCard extends StatelessWidget {
  final CommunityPost post;
  const _PostTypeCard({required this.post});

  @override
  Widget build(BuildContext context) {
    switch (post.postType) {
      case PostType.recipe:
        return _RecipeCard(metadata: post.metadata);
      case PostType.progress:
        return _ProgressCard(metadata: post.metadata);
      case PostType.meal:
        return _MealCard(metadata: post.metadata);
      case PostType.text:
        return const SizedBox.shrink();
    }
  }
}

class _RecipeCard extends StatelessWidget {
  final Map<String, dynamic> metadata;
  const _RecipeCard({required this.metadata});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final primaryColor = context.read<ThemeProvider>().primaryColor;
    final imageUrl = metadata['image_url'] as String?;
    final name = metadata['dish_name'] as String? ?? '';
    final cal = (metadata['calories'] as num?)?.toDouble() ?? 0;
    final prot = (metadata['protein'] as num?)?.toDouble() ?? 0;
    final carbs = (metadata['carbs'] as num?)?.toDouble() ?? 0;
    final fat = (metadata['fat'] as num?)?.toDouble() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppRadius.md)),
              child: AppImage(
                imageUrl: imageUrl,
                width: 72,
                height: 72,
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded,
                          size: 12, color: primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        l10n.translate('community.post_type.recipe'),
                        style: textStyles.labelS.copyWith(color: primaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(name,
                      style: textStyles.titleM,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      _MacroPill(
                          label: '${cal.toStringAsFixed(0)} kcal',
                          color: palette.calories),
                      _MacroPill(
                          label: '${prot.toStringAsFixed(0)}g P',
                          color: palette.protein),
                      _MacroPill(
                          label: '${carbs.toStringAsFixed(0)}g C',
                          color: palette.carbs),
                      _MacroPill(
                          label: '${fat.toStringAsFixed(0)}g F',
                          color: palette.fat),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final Map<String, dynamic> metadata;
  const _ProgressCard({required this.metadata});

  @override
  Widget build(BuildContext context) {
    final textStyles = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final primaryColor = context.read<ThemeProvider>().primaryColor;
    final weight = (metadata['weight'] as num?)?.toDouble();
    final label = metadata['label'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.trending_up_rounded,
                color: primaryColor, size: AppSize.iconMd),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('community.post_type.progress'),
                  style: textStyles.labelS.copyWith(color: primaryColor),
                ),
                if (weight != null)
                  Text(
                    '${weight.toStringAsFixed(1)} kg',
                    style: textStyles.headlineS,
                  ),
                if (label.isNotEmpty)
                  Text(label,
                      style: textStyles.bodyM,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final Map<String, dynamic> metadata;
  const _MealCard({required this.metadata});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final name = metadata['name'] as String? ?? '';
    final cal = (metadata['calories'] as num?)?.toDouble();
    final prot = (metadata['protein'] as num?)?.toDouble();
    final carbs = (metadata['carbs'] as num?)?.toDouble();
    final fat = (metadata['fat'] as num?)?.toDouble();
    final hasMacros =
        cal != null || prot != null || carbs != null || fat != null;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_rounded,
                  size: 12, color: palette.textSecondary),
              const SizedBox(width: 4),
              Text(
                l10n.translate('community.post_type.meal'),
                style:
                    textStyles.labelS.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
          if (name.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(name,
                style: textStyles.titleM,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
          if (hasMacros) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                if (cal != null)
                  _MacroPill(
                      label: '${cal.toStringAsFixed(0)} kcal',
                      color: palette.calories),
                if (prot != null)
                  _MacroPill(
                      label: '${prot.toStringAsFixed(0)}g P',
                      color: palette.protein),
                if (carbs != null)
                  _MacroPill(
                      label: '${carbs.toStringAsFixed(0)}g C',
                      color: palette.carbs),
                if (fat != null)
                  _MacroPill(
                      label: '${fat.toStringAsFixed(0)}g F',
                      color: palette.fat),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Topic pill shown on post cards ───────────────────────────────────────────

class _TopicPill extends StatelessWidget {
  final CommunityPost post;
  const _TopicPill({required this.post});

  @override
  Widget build(BuildContext context) {
    final topic = post.metadata['topic'] as String?;
    if (topic == null || topic.isEmpty) return const SizedBox.shrink();

    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final color = CommunityTopics.colorFor(topic, palette);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              l10n.translate(CommunityTopics.labelKeyFor(topic)),
              style: textStyles.labelS.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Verified author banner (coach / gym_owner) ───────────────────────────────

class _VerifiedAuthorBanner extends StatelessWidget {
  final CommunityPost post;
  const _VerifiedAuthorBanner({required this.post});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final role = (post.authorRole ?? '').toLowerCase();

    final bool isCoach = role == 'coach';
    final bool isGymOwner = role == 'gym_owner';

    if (!isCoach && !isGymOwner) return const SizedBox.shrink();

    final Color accentColor = isCoach ? AppPalette.brand : palette.energy;
    final IconData icon = isCoach
        ? Icons.workspace_premium_rounded
        : Icons.fitness_center_rounded;
    final String label = isCoach
        ? l10n.translate('community.verified_coach')
        : l10n.translate('community.verified_gym_owner');
    final String ctaLabel = isCoach
        ? l10n.translate('community.view_profile')
        : l10n.translate('community.view_gym_profile');

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: AppSize.iconSm, color: accentColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: textStyles.labelS.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => openUserProfile(context, userId: post.author.id),
            child: Text(
              ctaLabel,
              style: textStyles.labelS.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final Color color;
  const _MacroPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: AppText.of(context)
            .labelS
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Post "more" menu content (runs inside AppSheet) ─────────────────────────

class _PostMoreMenuContent extends StatelessWidget {
  final bool isOwner;
  final AppLocalizations appLoc;
  final VoidCallback onShare;
  final VoidCallback onCopyLink;
  final VoidCallback? onReport;
  final Future<void> Function()? onBlock;
  final VoidCallback? onDelete;

  const _PostMoreMenuContent({
    required this.isOwner,
    required this.appLoc,
    required this.onShare,
    required this.onCopyLink,
    this.onReport,
    this.onBlock,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MenuTile(
            icon: Icons.share_outlined,
            label: appLoc.translate('community.menu.share'),
            color: palette.textPrimary,
            textStyle: t.bodyM,
            onTap: onShare,
          ),
          _MenuTile(
            icon: Icons.link_rounded,
            label: appLoc.translate('post.copy_link'),
            color: palette.textSecondary,
            textStyle: t.bodyM,
            onTap: onCopyLink,
          ),
          if (onReport != null)
            _MenuTile(
              icon: Icons.flag_outlined,
              label: appLoc.translate('community.menu.report'),
              color: palette.error,
              textStyle: t.bodyM.copyWith(color: palette.error),
              onTap: onReport!,
            ),
          if (onBlock != null)
            _MenuTile(
              icon: Icons.block_rounded,
              label: appLoc.translate('community.menu.block'),
              color: palette.error,
              textStyle: t.bodyM.copyWith(color: palette.error),
              onTap: () => onBlock!(),
            ),
          if (onDelete != null)
            _MenuTile(
              icon: Icons.delete_outline_rounded,
              label: appLoc.translate('community.menu.delete'),
              color: palette.error,
              textStyle: t.bodyM.copyWith(color: palette.error),
              onTap: onDelete!,
            ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final TextStyle textStyle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.textStyle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: color, size: AppSize.iconMd),
            const SizedBox(width: AppSpacing.md),
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}

// ─── Shared report reason selector (AppSheet child) ──────────────────────────

class _ReportReasonContent extends StatefulWidget {
  final List<(String, String)> reasons;
  final AppPalette palette;
  final AppText textStyles;
  final AppLocalizations l10n;
  final Future<void> Function(String reason) onSubmit;

  const _ReportReasonContent({
    required this.reasons,
    required this.palette,
    required this.textStyles,
    required this.l10n,
    required this.onSubmit,
  });

  @override
  State<_ReportReasonContent> createState() => _ReportReasonContentState();
}

class _ReportReasonContentState extends State<_ReportReasonContent> {
  String? _selectedReason;
  bool _submitting = false;

  Future<void> _submit() async {
    final reason = _selectedReason;
    if (reason == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(reason);
      if (!mounted) return;
      Navigator.pop(context);
      AppSnackBar.success(context, widget.l10n.translate('report.submitted'));
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, widget.l10n.translate('report.error'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final t = widget.textStyles;
    final l10n = widget.l10n;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.screenH,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...widget.reasons.map((r) {
            final isSelected = _selectedReason == r.$1;
            return InkWell(
              onTap: () => setState(() => _selectedReason = r.$1),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                margin:
                    const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? palette.error.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected
                        ? palette.error.withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: AppSize.iconMd,
                      color: isSelected
                          ? palette.error
                          : palette.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: Text(r.$2,
                            style: t.titleM.copyWith(
                              color: isSelected
                                  ? palette.error
                                  : palette.textPrimary,
                            ))),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.translate('report.submit'),
            onPressed: (_selectedReason == null || _submitting) ? null : _submit,
            loading: _submitting,
            variant: AppButtonVariant.destructive,
          ),
        ],
      ),
    );
  }
}
