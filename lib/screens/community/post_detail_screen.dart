import 'dart:async';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:cookrange/core/providers/user_provider.dart';
import 'package:flutter/material.dart';
import '../../core/models/community_post.dart';
import '../../core/services/community_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/profile_navigation.dart';
import 'widgets/glass_refresher.dart';
import 'widgets/draggable_reaction_button.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/ds/app_avatar.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final CommunityService _service = CommunityService();
  CommunityPost? _post;
  List<CommunityComment> _comments = [];
  bool _isLoading = true;
  StreamSubscription<List<CommunityComment>>? _commentsSub;
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _editCommentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _editingCommentId;
  bool _isSendingComment = false;
  bool _isEditingPost = false;
  final TextEditingController _editPostController = TextEditingController();
  List<String> _editingTags = [];
  final List<String> _suggestedTags = [
    "🔥 Bugün trend",
    "🥦 Vegan",
    "⏱️ 15 dk",
    "💪 Spor sonrası",
    "🍳 Kolay Tarif",
    "🍝 Akşam Yemeği"
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _commentsSub?.cancel();
    _pageController.dispose();
    _commentController.dispose();
    _editCommentController.dispose();
    _editPostController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _openFullScreenImage(int initialIndex) {
    if (_post?.imageUrls.isEmpty ?? true) return;

    final PageController fullScreenController =
        PageController(initialPage: initialIndex);
    final ValueNotifier<int> currentIndexNotifier =
        ValueNotifier<int>(initialIndex + 1);

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => Scaffold(
          backgroundColor: Colors.black.withValues(alpha: 0.95),
          body: Stack(
            children: [
              // Swipeable Image View
              PageView.builder(
                controller: fullScreenController,
                itemCount: _post!.imageUrls.length,
                onPageChanged: (index) {
                  currentIndexNotifier.value = index + 1;
                },
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    child: Center(
                      child: Hero(
                        tag: 'post_image_carousel_$index',
                        child: Image.network(
                          _post!.imageUrls[index],
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Close Button
              Positioned(
                top: 50,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // 1/X Indicator
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: ValueListenableBuilder<int>(
                    valueListenable: currentIndexNotifier,
                    builder: (context, value, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          "$value / ${_post!.imageUrls.length}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      );
                    },
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);
    final appLoc = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Background
          Positioned.fill(
            child: Container(color: palette.background),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Ambient Glows
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context
                        .watch<ThemeProvider>()
                        .primaryColor
                        .withValues(alpha: 0.12),
                    blurRadius: 100,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: palette.info.withValues(alpha: 0.08),
                    blurRadius: 100,
                  ),
                ],
              ),
            ),
          ),

          // 2. Main Content
          _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                      color: context.watch<ThemeProvider>().primaryColor))
              : Column(
                  children: [
                    Expanded(
                      child: GlassRefresher(
                        onRefresh: _loadData,
                        topPadding: MediaQuery.of(context).padding.top + 60,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics()),
                          padding: EdgeInsets.fromLTRB(AppSpacing.xl,
                              MediaQuery.of(context).padding.top + AppSpacing.lg, AppSpacing.xl, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // HEADER
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const BackButton(),
                                  Row(
                                    children: [
                                      if (_post != null &&
                                          _post!.author.id ==
                                              _service.currentUserId)
                                        IconButton(
                                          onPressed: () =>
                                              _toggleEditMode(_post!),
                                          icon: Icon(Icons.edit_outlined,
                                              color: palette.textPrimary),
                                        ),
                                      // Menu
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert,
                                            color: palette.textPrimary),
                                        onSelected: (value) async {
                                          if (value == 'report') {
                                            _showReportDialog(context);
                                          } else if (value == 'share') {
                                            _sharePost();
                                          } else if (value == 'delete') {
                                            _showDeleteDialog(context);
                                          } else if (value == 'block' &&
                                              _post != null) {
                                            await _service.blockUser(
                                                _post!.author.id);
                                            if (context.mounted) {
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(appLoc.translate(
                                                          'community.block_success'))));
                                            }
                                          }
                                        },
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(AppRadius.md)),
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                              value: 'share',
                                              child: Row(children: [
                                                const Icon(Icons.share_outlined,
                                                    size: AppSize.iconMd),
                                                const SizedBox(width: AppSpacing.sm),
                                                Text(appLoc.translate(
                                                    'community.menu.share'))
                                              ])),
                                          if (_post != null &&
                                              _post!.author.id !=
                                                  _service.currentUserId) ...[
                                            PopupMenuItem(
                                                value: 'report',
                                                child: Row(children: [
                                                  Icon(
                                                      Icons.report_gmailerrorred,
                                                      size: AppSize.iconMd,
                                                      color: palette.error),
                                                  const SizedBox(width: AppSpacing.sm),
                                                  Text(
                                                      appLoc.translate(
                                                          'community.menu.report'),
                                                      style: TextStyle(
                                                          color: palette.error))
                                                ])),
                                            PopupMenuItem(
                                                value: 'block',
                                                child: Row(children: [
                                                  Icon(Icons.block,
                                                      size: AppSize.iconMd,
                                                      color: palette.error),
                                                  const SizedBox(width: AppSpacing.sm),
                                                  Text(
                                                      appLoc.translate(
                                                          'community.menu.block'),
                                                      style: TextStyle(
                                                          color: palette.error))
                                                ])),
                                          ],
                                          if (_post != null &&
                                              _post!.author.id ==
                                                  _service.currentUserId)
                                            PopupMenuItem(
                                                value: 'delete',
                                                child: Row(children: [
                                                  Icon(
                                                      Icons.delete_outline,
                                                      size: AppSize.iconMd,
                                                      color: palette.error),
                                                  const SizedBox(width: AppSpacing.sm),
                                                  Text(
                                                      appLoc.translate(
                                                          'community.menu.delete'),
                                                      style: TextStyle(
                                                          color: palette.error))
                                                ])),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              if (_post != null) ...[
                                // Author Info
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => openUserProfile(context,
                                          userId: _post!.author.id),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                              backgroundImage: NetworkImage(
                                                  _post!.author.avatarUrl)),
                                          const SizedBox(width: AppSpacing.sm),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _post!.author.name,
                                                style: textStyles.headlineS,
                                              ),
                                              Text(
                                                _formatTime(_post!.timestamp),
                                                style: textStyles.labelS,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // Post Text or Inline Edit
                                if (_isEditingPost)
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: palette.surface.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      border: Border.all(
                                          color: palette.info.withValues(alpha: 0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        TextField(
                                          controller: _editPostController,
                                          maxLines: null,
                                          autofocus: true,
                                          style: textStyles.bodyL.copyWith(
                                            color: palette.textPrimary,
                                          ),
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            hintText: appLoc.translate(
                                                'community.whats_cooking',
                                                variables: {'name': 'Chef'}),
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        // Edit Tags
                                        if (_editingTags.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: AppSpacing.sm),
                                            child: Wrap(
                                              spacing: AppSpacing.xs,
                                              runSpacing: AppSpacing.xs,
                                              children: _editingTags
                                                  .map((tag) => Chip(
                                                        label: Text(tag,
                                                            style: textStyles.labelS),
                                                        backgroundColor: context
                                                            .watch<ThemeProvider>()
                                                            .primaryColor
                                                            .withValues(alpha: 0.1),
                                                        labelStyle: TextStyle(
                                                            color: context
                                                                .watch<ThemeProvider>()
                                                                .primaryColor),
                                                        deleteIcon: Icon(
                                                            Icons.close,
                                                            size: AppSize.iconXs,
                                                            color: context
                                                                .watch<ThemeProvider>()
                                                                .primaryColor),
                                                        onDeleted: () {
                                                          setState(() {
                                                            _editingTags
                                                                .remove(tag);
                                                          });
                                                        },
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        AppRadius.full)),
                                                        side: BorderSide.none,
                                                      ))
                                                  .toList(),
                                            ),
                                          ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.tag,
                                                  color: context
                                                      .watch<ThemeProvider>()
                                                      .primaryColor),
                                              onPressed: _openTagPicker,
                                              tooltip: appLoc.translate(
                                                  'community.create_post.add_tags'),
                                            ),
                                            Row(
                                              children: [
                                                TextButton(
                                                  onPressed: () => setState(
                                                      () => _isEditingPost =
                                                          false),
                                                  child: Text(
                                                      appLoc.translate(
                                                          'common.cancel'),
                                                      style: textStyles.labelM),
                                                ),
                                                const SizedBox(width: AppSpacing.xs),
                                                ElevatedButton(
                                                  onPressed: _savePostEdit,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: context
                                                        .watch<ThemeProvider>()
                                                        .primaryColor,
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        AppRadius.full)),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: AppSpacing.md),
                                                  ),
                                                  child: Text(appLoc.translate(
                                                      'common.save')),
                                                ),
                                              ],
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  )
                                else
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _post!.content,
                                        style: textStyles.bodyL,
                                      ),
                                      if (_post!.tags.isNotEmpty) ...[
                                        const SizedBox(height: AppSpacing.sm),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: _post!.tags
                                              .map((tag) => Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: AppSpacing.xs + 2,
                                                        vertical: AppSpacing.xxs),
                                                    decoration: BoxDecoration(
                                                      color: palette.surfaceVariant,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              AppRadius.full),
                                                      border: Border.all(
                                                        color: palette.border,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      tag,
                                                      style: textStyles.labelS,
                                                    ),
                                                  ))
                                              .toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                if (_post!.isEdited)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      "(edited)",
                                      style: textStyles.labelS.copyWith(
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: AppSpacing.md),

                                // Images
                                if (_post!.imageUrls.isNotEmpty)
                                  Container(
                                    height: 300,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppRadius.card),
                                      boxShadow: [
                                        BoxShadow(
                                          color: palette.shadow
                                              .withValues(alpha: AppElevation.opacityMedium),
                                          blurRadius: AppElevation.blurLg,
                                          offset: AppElevation.offsetLg,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(AppRadius.card),
                                      child: Stack(
                                        children: [
                                          PageView.builder(
                                            controller: _pageController,
                                            itemCount: _post!.imageUrls.length,
                                            onPageChanged: (index) {
                                              setState(() =>
                                                  _currentImageIndex = index);
                                            },
                                            itemBuilder: (context, index) {
                                              return GestureDetector(
                                                onTap: () =>
                                                    _openFullScreenImage(index),
                                                child: Hero(
                                                  tag: 'post_image_carousel_$index',
                                                  child: Image.network(
                                                    _post!.imageUrls[index],
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          // Dot Indicator
                                          if (_post!.imageUrls.length > 1)
                                            Positioned(
                                              bottom: 12,
                                              left: 0,
                                              right: 0,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: List.generate(
                                                    _post!.imageUrls.length,
                                                    (index) {
                                                  return Container(
                                                    margin: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 3),
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color:
                                                          _currentImageIndex ==
                                                                  index
                                                              ? Colors.white
                                                              : Colors.white
                                                                  .withValues(
                                                                      alpha: 0.5),
                                                    ),
                                                  );
                                                }),
                                              ),
                                            ),
                                          // 1/X Indicator (Top Right)
                                          if (_post!.imageUrls.length > 1)
                                            Positioned(
                                              top: 12,
                                              right: 12,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: AppSpacing.xs + 2,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius:
                                                      BorderRadius.circular(AppRadius.full),
                                                ),
                                                child: Text(
                                                  "${_currentImageIndex + 1}/${_post!.imageUrls.length}",
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            )
                                        ],
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: AppSpacing.lg),

                                // Reactions Summary (Always Visible)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  child: Wrap(
                                    spacing: AppSpacing.xs,
                                    runSpacing: AppSpacing.xs,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      ..._post!.reactions.entries
                                          .where((e) => e.key != '❤️')
                                          .map((entry) {
                                        final isUserReaction = _post!
                                            .userReactions
                                            .contains(entry.key);
                                        final primaryColor = context
                                            .watch<ThemeProvider>()
                                            .primaryColor;
                                        return GestureDetector(
                                          onTap: () => _onReaction(entry.key),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: AppSpacing.xs,
                                                vertical: AppSpacing.xxs),
                                            decoration: BoxDecoration(
                                              color: isUserReaction
                                                  ? primaryColor
                                                      .withValues(alpha: 0.2)
                                                  : palette.surfaceVariant,
                                              borderRadius:
                                                  BorderRadius.circular(AppRadius.full),
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
                                      _buildAddReactionButton(context,
                                          isSmall: true),
                                    ],
                                  ),
                                ),

                                // Actions Row (Updated Logic with Face Pile)
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _onToggleLike(),
                                      child: Icon(
                                        _post!.isLiked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: _post!.isLiked
                                            ? palette.error
                                            : palette.textSecondary,
                                        size: AppSize.iconLg,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    // Face Pile & Text
                                    if (_post!.likesCount > 0)
                                      Expanded(
                                        child: Row(
                                          children: [
                                            if (_post!.likedByUsers.isNotEmpty)
                                              SizedBox(
                                                width: 24.0 +
                                                    (14.0 *
                                                        (_post!.likedByUsers
                                                                .take(3)
                                                                .length -
                                                            1)),
                                                height: 24,
                                                child: Stack(
                                                  children: _post!.likedByUsers
                                                      .take(3)
                                                      .toList()
                                                      .asMap()
                                                      .entries
                                                      .map((entry) {
                                                    return Positioned(
                                                      left: entry.key * 14.0,
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color: palette.background,
                                                            width: 2,
                                                          ),
                                                        ),
                                                        child: CircleAvatar(
                                                          radius: 10,
                                                          backgroundImage:
                                                              NetworkImage(entry
                                                                  .value
                                                                  .avatarUrl),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            const SizedBox(width: AppSpacing.xs),
                                            Expanded(
                                              child: Text(
                                                _getLikeText(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: textStyles.labelM,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: AppSpacing.xxl),
                                Text(
                                  appLoc.translate('community.post.comments',
                                      variables: {
                                        'count': '${_post?.commentsCount ?? 0}'
                                      }),
                                  style: textStyles.headlineS,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                ..._comments.map((comment) =>
                                    _buildCommentItem(comment)),

                                const SizedBox(height: 100),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildGlassCommentInput(context),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(CommunityComment comment) {
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);
    final isEditing = _editingCommentId == comment.id;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () =>
                openUserProfile(context, userId: comment.author.id),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(comment.author.avatarUrl),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => openUserProfile(context,
                                userId: comment.author.id),
                            child: Text(
                              comment.author.name,
                              style: textStyles.titleM,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _formatTime(comment.timestamp),
                                style: textStyles.labelS,
                              ),
                              if (comment.isEdited)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Text(
                                    "(edited)",
                                    style: textStyles.labelS.copyWith(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.more_vert,
                          size: AppSize.iconXs + 2,
                          color: palette.textTertiary),
                      onSelected: (val) async {
                        if (val == 'edit') {
                          setState(() {
                            _editingCommentId = comment.id;
                            _editCommentController.text = comment.content;
                          });
                        }
                        if (val == 'delete') unawaited(_onDeleteComment(comment.id));
                        if (val == 'report') {
                          _showReportDialog(context,
                              commentId: comment.id);
                        }
                      },
                      itemBuilder: (ctx) {
                        final isAuthor =
                            comment.author.id == _service.currentUserId;
                        if (isAuthor) {
                          return [
                            PopupMenuItem(
                                value: 'edit',
                                child: Text(AppLocalizations.of(context)
                                    .translate('common.edit'))),
                            PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                    AppLocalizations.of(context)
                                        .translate('common.delete'),
                                    style: TextStyle(color: palette.error))),
                          ];
                        } else {
                          return [
                            PopupMenuItem(
                                value: 'report',
                                child: Row(
                                  children: [
                                    Icon(Icons.report_gmailerrorred,
                                        size: AppSize.iconXs + 2,
                                        color: palette.error),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                        AppLocalizations.of(context)
                                            .translate('community.menu.report'),
                                        style: TextStyle(color: palette.error)),
                                  ],
                                )),
                          ];
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),

                // Content or Edit Field
                if (isEditing)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TextField(
                        controller: _editCommentController,
                        autofocus: true,
                        maxLines: null,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                          border: InputBorder.none,
                        ),
                        style: textStyles.bodyM.copyWith(
                            color: palette.textPrimary),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _editingCommentId = null),
                            child: Text(
                                AppLocalizations.of(context)
                                    .translate('common.cancel'),
                                style: textStyles.labelS),
                          ),
                          TextButton(
                            onPressed: () async {
                              final newContent =
                                  _editCommentController.text.trim();
                              if (newContent.isNotEmpty &&
                                  newContent != comment.content) {
                                await _service.updateComment(
                                    widget.postId, comment.id, newContent);
                                unawaited(_loadData());
                              }
                              setState(() => _editingCommentId = null);
                            },
                            child: Text(
                                AppLocalizations.of(context)
                                    .translate('common.save'),
                                style: textStyles.labelS),
                          ),
                        ],
                      )
                    ],
                  )
                else
                  Text(
                    comment.content,
                    style: textStyles.bodyM.copyWith(color: palette.textPrimary),
                  ),
                const SizedBox(height: AppSpacing.xs),
                // Reactions for Comment
                Row(
                  children: [
                    // Like Action
                    GestureDetector(
                      onTap: () => _onToggleLikeComment(comment.id),
                      child: Icon(
                        comment.isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: AppSize.iconXs + 2,
                        color: comment.isLiked
                            ? palette.error
                            : palette.textTertiary,
                      ),
                    ),
                    if (comment.likesCount > 0) ...[
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        "${comment.likesCount}",
                        style: textStyles.labelS,
                      ),
                    ],
                    const SizedBox(width: AppSpacing.sm),

                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.xxs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ...comment.reactions.entries
                              .where((e) => e.key != '❤️')
                              .map((entry) {
                            final isUserReact =
                                comment.userReactions.contains(entry.key);
                            final primaryColor = context
                                .watch<ThemeProvider>()
                                .primaryColor;
                            return GestureDetector(
                              onTap: () =>
                                  _onReaction(entry.key, commentId: comment.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isUserReact
                                      ? primaryColor.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppRadius.xs),
                                  border: Border.all(
                                      color: isUserReact
                                          ? primaryColor
                                          : palette.border),
                                ),
                                child: Text("${entry.key} ${entry.value}",
                                    style: const TextStyle(fontSize: 11)),
                              ),
                            );
                          }),
                          // Add Reaction Button for Comment
                          _buildAddReactionButton(context,
                              isSmall: true, commentId: comment.id),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _onToggleLike() async {
    if (_post == null) return;

    setState(() {
      final isLiked = !_post!.isLiked;
      final likesCount = _post!.likesCount + (isLiked ? 1 : -1);

      _post = _post!.copyWith(
        isLiked: isLiked,
        likesCount: likesCount,
      );
    });

    await _service.likePost(_post!.id);
  }

  Future<void> _onToggleLikeComment(String commentId) async {
    final index = _comments.indexWhere((c) => c.id == commentId);
    if (index == -1) return;

    final comment = _comments[index];
    setState(() {
      final isLiked = !comment.isLiked;
      final likesCount = comment.likesCount + (isLiked ? 1 : -1);

      _comments[index] = CommunityComment(
        id: comment.id,
        author: comment.author,
        content: comment.content,
        timestamp: comment.timestamp,
        likesCount: likesCount,
        isLiked: isLiked,
        reactions: comment.reactions,
        userReactions: comment.userReactions,
        isEdited: comment.isEdited,
      );
    });

    await _service.likeComment(widget.postId, commentId);
  }

  Future<void> _onReaction(String emoji, {String? commentId}) async {
    setState(() {
      if (commentId == null) {
        if (_post != null) {
          final isAdding = !_post!.userReactions.contains(emoji);
          List<String> userReactions = List.from(_post!.userReactions);
          Map<String, int> reactions = Map.from(_post!.reactions);

          if (isAdding) {
            userReactions.add(emoji);
            reactions[emoji] = (reactions[emoji] ?? 0) + 1;
          } else {
            userReactions.remove(emoji);
            final count = (reactions[emoji] ?? 0) - 1;
            if (count > 0) {
              reactions[emoji] = count;
            } else {
              reactions.remove(emoji);
            }
          }
          _post = _post!.copyWith(
            reactions: reactions,
            userReactions: userReactions,
          );
        }
      } else {
        final index = _comments.indexWhere((c) => c.id == commentId);
        if (index != -1) {
          final comment = _comments[index];
          final isAdding = !comment.userReactions.contains(emoji);
          List<String> userReactions = List.from(comment.userReactions);
          Map<String, int> reactions = Map.from(comment.reactions);

          if (isAdding) {
            userReactions.add(emoji);
            reactions[emoji] = (reactions[emoji] ?? 0) + 1;
          } else {
            userReactions.remove(emoji);
            final count = (reactions[emoji] ?? 0) - 1;
            if (count > 0) {
              reactions[emoji] = count;
            } else {
              reactions.remove(emoji);
            }
          }

          _comments[index] = CommunityComment(
            id: comment.id,
            author: comment.author,
            content: comment.content,
            timestamp: comment.timestamp,
            likesCount: comment.likesCount,
            isLiked: comment.isLiked,
            reactions: reactions,
            userReactions: userReactions,
            isEdited: comment.isEdited,
          );
        }
      }
    });

    await _service.toggleReaction(
        postId: widget.postId, commentId: commentId, emoji: emoji);
  }

  Future<void> _onAddComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    setState(() => _isSendingComment = true);
    try {
      await _service.addComment(widget.postId, content);
      _commentController.clear();
      unawaited(_loadData());
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final msg = e.toString().contains('content_blocked')
            ? l10n.translate('community.content_blocked')
            : e.toString();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _loadData() async {
    try {
      final post = await _service.getPostDetails(widget.postId);
      if (mounted) {
        setState(() {
          _post = post;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error loading post details: $e");
    }

    unawaited(_commentsSub?.cancel());
    _commentsSub = _service.commentsStream(widget.postId).listen((comments) {
      if (mounted) setState(() => _comments = comments);
    });
  }

  void _sharePost() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(AppLocalizations.of(context).translate('post.link_copied'))));
  }

  void _showReportDialog(BuildContext context, {String? commentId}) {
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
            decoration: const BoxDecoration(
              color: Colors.transparent,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
            ),
            child: Material(
              color: palette.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.sm, AppSpacing.xl,
                    MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl),
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
                                if (commentId != null) {
                                  await _service.reportComment(
                                      widget.postId, commentId, selectedReason!);
                                } else {
                                  await _service.reportPost(
                                      widget.postId, selectedReason!);
                                }
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text(
                                          l10n.translate('community.report.submitted'))));
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
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildGlassCommentInput(BuildContext context) {
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);
    final primaryColor = context.watch<ThemeProvider>().primaryColor;
    final user = Provider.of<UserProvider>(context, listen: false).user;
    final userImage = user?.photoURL;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md,
              MediaQuery.of(context).padding.bottom + AppSpacing.sm),
          decoration: BoxDecoration(
            color: palette.background.withValues(alpha: 0.85),
            border: Border(
                top: BorderSide(color: palette.divider)),
          ),
          child: Row(
            children: [
              if (_post != null)
                AppInitialsAvatar(
                  photoUrl: userImage,
                  name: user?.displayName ?? '',
                  size: 36,
                ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: palette.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          style: textStyles.bodyM.copyWith(
                              color: palette.textPrimary),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)
                                .translate('post.add_comment_hint'),
                            hintStyle: textStyles.bodyM,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.only(bottom: 2),
                          ),
                          onSubmitted: (_) => _onAddComment(),
                        ),
                      ),
                      IconButton(
                        onPressed: _isSendingComment ? null : _onAddComment,
                        icon: _isSendingComment
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primaryColor))
                            : Icon(Icons.send_rounded,
                                color: primaryColor.withValues(alpha: 0.8),
                                size: AppSize.iconMd),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLikeText() {
    final likes = _post!.likesCount;
    if (likes == 0) return "";

    final appLoc = AppLocalizations.of(context);
    final likers = _post!.likedByUsers;
    final currentUserId = _service.currentUserId;
    final isLikedByMe = _post!.isLiked;

    if (isLikedByMe) {
      if (likes == 1) return appLoc.translate('community.likes.you');

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

  String _formatTime(DateTime time) {
    if (!mounted) return "";
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

  void _showDeleteDialog(BuildContext context) {
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
              final nav = Navigator.of(context);
              final success = await _service.deletePost(widget.postId);
              if (success && nav.canPop()) {
                nav.pop();
              }
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

  void _toggleEditMode(CommunityPost post) {
    setState(() {
      _isEditingPost = true;
      _editPostController.text = post.content;
      _editingTags = List.from(post.tags);
    });
  }

  Future<void> _savePostEdit() async {
    final newContent = _editPostController.text.trim();
    if (newContent.isNotEmpty &&
        (newContent != _post?.content || _editingTags != _post?.tags)) {
      await _service.updatePost(_post!.id, newContent, newTags: _editingTags);
      unawaited(_loadData());
    }
    setState(() {
      _isEditingPost = false;
    });
  }

  Future<void> _onDeleteComment(String commentId) async {
    await _service.deleteComment(widget.postId, commentId);
    unawaited(_loadData());
  }

  void _openTagPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final palette = AppPalette.of(context);
        final textStyles = AppText.of(context);
        final primaryColor = context.watch<ThemeProvider>().primaryColor;
        return StatefulBuilder(builder: (context, setStateSheet) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Add Tags",
                  style: textStyles.headlineS,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: _suggestedTags.map((tag) {
                    final isSelected = _editingTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setStateSheet(() {
                          if (selected) {
                            if (!_editingTags.contains(tag)) {
                              _editingTags.add(tag);
                            }
                          } else {
                            _editingTags.remove(tag);
                          }
                        });
                        setState(() {});
                      },
                      selectedColor:
                          primaryColor.withValues(alpha: 0.2),
                      checkmarkColor: primaryColor,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? primaryColor
                            : palette.textSecondary,
                      ),
                      backgroundColor: palette.surfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        side: BorderSide(
                          color: isSelected ? primaryColor : Colors.transparent,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          );
        });
      },
    ).then((_) => setState(() {}));
  }

  Widget _buildAddReactionButton(BuildContext context,
      {bool isSmall = false, String? commentId}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableReactionButton(
      isDark: isDark,
      isSmall: isSmall,
      commentId: commentId,
      onReactionSelected: (emoji) => _onReaction(emoji, commentId: commentId),
    );
  }
}
