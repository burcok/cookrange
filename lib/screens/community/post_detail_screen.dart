import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:cookrange/core/providers/user_provider.dart';
import 'package:flutter/material.dart';
import '../../core/models/community_post.dart';
import '../../core/services/community_service.dart';
import '../../core/localization/app_localizations.dart';
import 'widgets/glass_refresher.dart';
import 'widgets/draggable_reaction_button.dart';

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
    _pageController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _openFullScreenImage(int initialIndex) {
    if (_post?.imageUrls.isEmpty ?? true) return;

    // Use a local controller for the full screen view
    final PageController fullScreenController =
        PageController(initialPage: initialIndex);
    // We need a ValueNotifier to update the counter text in full screen
    final ValueNotifier<int> currentIndexNotifier =
        ValueNotifier<int>(initialIndex + 1);

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => Scaffold(
          backgroundColor: Colors.black.withOpacity(0.95),
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
                        tag:
                            'post_image_carousel_$index', // Use the same tag as in the carousel
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
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appLoc = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Glowing Glass Background
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Ambient Glows (Simplified for update)
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
                    color: const Color(0xFFF97316).withOpacity(0.12),
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
                    color: Colors.blueAccent.withOpacity(0.08),
                    blurRadius: 100,
                  ),
                ],
              ),
            ),
          ),

          // 2. Main Content
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFF97316)))
              : Column(
                  children: [
                    Expanded(
                      child: GlassRefresher(
                        onRefresh: _loadData,
                        topPadding: MediaQuery.of(context).padding.top + 60,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics()),
                          padding: EdgeInsets.fromLTRB(24,
                              MediaQuery.of(context).padding.top + 20, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // HEADER (Moved inside scrollable area per request)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const BackButton(),
                                  Row(
                                    children: [
                                      // Edit Button for Owner
                                      if (_post != null &&
                                          _post!.author.id ==
                                              _service.currentUserId)
                                        IconButton(
                                          onPressed: () =>
                                              _toggleEditMode(_post!),
                                          icon: Icon(Icons.edit_outlined,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A)),
                                        ),
                                      // Menu
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A)),
                                        onSelected: (value) {
                                          if (value == 'report')
                                            _showReportDialog(context);
                                          else if (value == 'share')
                                            _sharePost();
                                          else if (value == 'delete')
                                            _showDeleteDialog(context);
                                        },
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                              value: 'share',
                                              child: Row(children: [
                                                const Icon(Icons.share_outlined,
                                                    size: 20),
                                                const SizedBox(width: 12),
                                                Text(appLoc.translate(
                                                    'community.menu.share'))
                                              ])),
                                          PopupMenuItem(
                                              value: 'report',
                                              child: Row(children: [
                                                const Icon(
                                                    Icons.report_gmailerrorred,
                                                    size: 20,
                                                    color: Colors.red),
                                                const SizedBox(width: 12),
                                                Text(
                                                    appLoc.translate(
                                                        'community.menu.report'),
                                                    style: const TextStyle(
                                                        color: Colors.red))
                                              ])),
                                          if (_post != null &&
                                              _post!.author.id ==
                                                  _service.currentUserId)
                                            PopupMenuItem(
                                                value: 'delete',
                                                child: Row(children: [
                                                  const Icon(
                                                      Icons.delete_outline,
                                                      size: 20,
                                                      color: Colors.red),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                      appLoc.translate(
                                                          'community.menu.delete'),
                                                      style: const TextStyle(
                                                          color: Colors.red))
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
                                    CircleAvatar(
                                        backgroundImage: NetworkImage(
                                            _post!.author.avatarUrl)),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _post!.author.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          _formatTime(_post!.timestamp),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : const Color(0xFF64748B),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Post Text or Inline Edit
                                if (_isEditingPost)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.05)
                                          : Colors.white.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: isDark
                                              ? Colors.white10
                                              : Colors.blueAccent
                                                  .withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        TextField(
                                          controller: _editPostController,
                                          maxLines: null,
                                          autofocus: true,
                                          style: TextStyle(
                                            fontSize: 15,
                                            height: 1.5,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF334155),
                                          ),
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            hintText: "What's cooking?",
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        // Edit Tags
                                        if (_editingTags.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12),
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: _editingTags
                                                  .map((tag) => Chip(
                                                        label: Text(tag,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        12)),
                                                        backgroundColor:
                                                            const Color(
                                                                    0xFFF97316)
                                                                .withOpacity(
                                                                    0.1),
                                                        labelStyle:
                                                            const TextStyle(
                                                                color: Color(
                                                                    0xFFF97316)),
                                                        deleteIcon: const Icon(
                                                            Icons.close,
                                                            size: 14,
                                                            color: Color(
                                                                0xFFF97316)),
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
                                                                        20)),
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
                                              icon: const Icon(Icons.tag,
                                                  color: Color(0xFFF97316)),
                                              onPressed: _openTagPicker,
                                              tooltip: "Add Tags",
                                            ),
                                            Row(
                                              children: [
                                                TextButton(
                                                  onPressed: () => setState(
                                                      () => _isEditingPost =
                                                          false),
                                                  child: Text("Cancel",
                                                      style: TextStyle(
                                                          color: isDark
                                                              ? Colors.grey
                                                              : Colors
                                                                  .grey[700])),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton(
                                                  onPressed: _savePostEdit,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFFF97316),
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        20)),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 16,
                                                        vertical: 0),
                                                  ),
                                                  child: const Text("Save"),
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
                                        style: TextStyle(
                                          fontSize: 15,
                                          height: 1.5,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                      if (_post!.tags.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: _post!.tags
                                              .map((tag) => Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isDark
                                                          ? Colors.white
                                                              .withOpacity(0.1)
                                                          : Colors.black
                                                              .withOpacity(
                                                                  0.05),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      border: Border.all(
                                                        color: isDark
                                                            ? Colors.white10
                                                            : Colors.black12,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      tag,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isDark
                                                            ? Colors.white70
                                                            : Colors.black87,
                                                      ),
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
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white30
                                            : Colors.black38,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 16),

                                // Images
                                if (_post!.imageUrls.isNotEmpty)
                                  Container(
                                    height: 300,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 15,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
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
                                                  tag:
                                                      'post_image_carousel_$index', // Unique tag
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
                                                                  .withOpacity(
                                                                      0.5),
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
                                                        horizontal: 10,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
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
                                const SizedBox(height: 20),

                                // Reactions Summary (Always Visible)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      ..._post!.reactions.entries
                                          .where((e) => e.key != '❤️')
                                          .map((entry) {
                                        final isUserReaction = _post!
                                            .userReactions
                                            .contains(entry.key);
                                        return GestureDetector(
                                          onTap: () => _onReaction(entry.key),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isUserReaction
                                                  ? const Color(0xFFF97316)
                                                      .withOpacity(0.2)
                                                  : (isDark
                                                      ? Colors.white10
                                                      : Colors.grey.shade100),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                  color: isUserReaction
                                                      ? const Color(0xFFF97316)
                                                      : Colors.transparent),
                                            ),
                                            child: Text(
                                              "${entry.key} ${entry.value}",
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  fontWeight: isUserReaction
                                                      ? FontWeight.bold
                                                      : FontWeight.normal),
                                            ),
                                          ),
                                        );
                                      }),
                                      _buildAddReactionButton(context, isDark,
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
                                            ? Colors.red
                                            : (isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B)),
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
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
                                                            color: isDark
                                                                ? const Color(
                                                                    0xFF0F172A)
                                                                : Colors.white,
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
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _getLikeText(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 32),
                                Text(
                                  "Comments (${_post?.commentsCount ?? 0})",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ..._comments.map((comment) =>
                                    _buildCommentItem(comment, isDark)),

                                const SizedBox(height: 100),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildGlassCommentInput(isDark, context),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(CommunityComment comment, bool isDark) {
    final isEditing = _editingCommentId == comment.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.white),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(comment.author.avatarUrl),
          ),
          const SizedBox(width: 12),
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
                          Text(
                            comment.author.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _formatTime(comment.timestamp),
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11),
                              ),
                              if (comment.isEdited)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Text(
                                    "(edited)",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white30
                                          : Colors.black38,
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
                          size: 16,
                          color: isDark ? Colors.white54 : Colors.grey),
                      onSelected: (val) async {
                        if (val == 'edit') {
                          setState(() {
                            _editingCommentId = comment.id;
                            _editCommentController.text = comment.content;
                          });
                        }
                        if (val == 'delete') _onDeleteComment(comment.id);
                        if (val == 'report') {
                          await _service.reportComment(widget.postId,
                              comment.id, "Inappropriate content");
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(AppLocalizations.of(context)
                                      .translate('community.report_success',
                                          variables: {'type': 'Comment'}))),
                            );
                          }
                        }
                      },
                      itemBuilder: (ctx) {
                        final isAuthor =
                            comment.author.id == _service.currentUserId;
                        if (isAuthor) {
                          return [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete',
                                    style: TextStyle(color: Colors.red))),
                          ];
                        } else {
                          return [
                            PopupMenuItem(
                                value: 'report',
                                child: Row(
                                  children: [
                                    const Icon(Icons.report_gmailerrorred,
                                        size: 16, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Text(
                                        AppLocalizations.of(context)
                                            .translate('community.menu.report'),
                                        style:
                                            const TextStyle(color: Colors.red)),
                                  ],
                                )),
                          ];
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),

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
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          border: InputBorder.none,
                        ),
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: isDark
                                ? Colors.grey[300]
                                : const Color(0xFF334155)),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _editingCommentId = null),
                            child: const Text("Cancel",
                                style: TextStyle(fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: () async {
                              final newContent =
                                  _editCommentController.text.trim();
                              if (newContent.isNotEmpty &&
                                  newContent != comment.content) {
                                await _service.updateComment(
                                    widget.postId, comment.id, newContent);
                                _loadData();
                              }
                              setState(() => _editingCommentId = null);
                            },
                            child: const Text("Save",
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      )
                    ],
                  )
                else
                  Text(
                    comment.content,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark
                            ? Colors.grey[300]
                            : const Color(0xFF334155)),
                  ),
                const SizedBox(height: 8),
                // Reactions for Comment
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Like Action
                    GestureDetector(
                      onTap: () => _onToggleLikeComment(comment.id),
                      child: Icon(
                        comment.isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 16,
                        color: comment.isLiked
                            ? Colors.red
                            : (isDark ? Colors.grey : Colors.grey.shade400),
                      ),
                    ),
                    if (comment.likesCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        "${comment.likesCount}",
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey : Colors.grey.shade600),
                      ),
                    ],
                    const SizedBox(width: 12),

                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ...comment.reactions.entries
                              .where((e) => e.key != '❤️')
                              .map((entry) {
                            final isUserReact =
                                comment.userReactions.contains(entry.key);
                            return GestureDetector(
                              onTap: () =>
                                  _onReaction(entry.key, commentId: comment.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isUserReact
                                      ? const Color(0xFFF97316).withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: isUserReact
                                          ? const Color(0xFFF97316)
                                          : Colors.grey.withOpacity(0.3)),
                                ),
                                child: Text("${entry.key} ${entry.value}",
                                    style: const TextStyle(fontSize: 11)),
                              ),
                            );
                          }),
                          // Add Reaction Button for Comment
                          _buildAddReactionButton(context, isDark,
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

    // Optimistic Update
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
    // Optimistic Update
    setState(() {
      if (commentId == null) {
        // Post Reaction
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
        // Comment Reaction
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
            isLiked: comment.isLiked, // Preserve like state
            reactions: reactions,
            userReactions: userReactions,
            isEdited: comment.isEdited,
          );
        }
      }
    });

    // Async Update
    await _service.toggleReaction(
        postId: widget.postId, commentId: commentId, emoji: emoji);
  } // Reload silently to sync fully if needed, but optimistic should hold
  // _loadData();

  Future<void> _onAddComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    setState(() => _isSendingComment = true);
    await _service.addComment(widget.postId, content);
    _commentController.clear();
    setState(() => _isSendingComment = false);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final post = await _service.getPostDetails(widget.postId);
      final comments = await _service.getComments(widget.postId);
      if (mounted) {
        setState(() {
          _post = post;
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error loading post details: $e");
    }
  }

  void _sharePost() {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Link copied to clipboard!")));
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Report Post"),
        content: const Text("Select a reason to report this post..."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Submit")),
        ],
      ),
    );
  }

  Widget _buildGlassCommentInput(bool isDark, BuildContext context) {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    final userImage = user?.photoURL;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F172A).withOpacity(0.8)
                : Colors.white.withOpacity(0.8),
            border: Border(
                top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              if (_post != null)
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(
                      userImage ?? 'https://i.pravatar.cc/150?u=current'),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: isDark ? Colors.white10 : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            hintText: "Add a comment...",
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade500,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.only(bottom: 2),
                          ),
                          onSubmitted: (_) => _onAddComment(),
                        ),
                      ),
                      IconButton(
                        onPressed: _isSendingComment ? null : _onAddComment,
                        icon: _isSendingComment
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFFF97316)))
                            : Icon(Icons.send_rounded,
                                color: const Color(0xFFF97316).withOpacity(0.8),
                                size: 20),
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
    // Check if current user is in the liked list or if isLiked is true
    // Note: likedByUsers only contains top 3. isLiked is the single source of truth.
    final isLikedByMe = _post!.isLiked;

    if (isLikedByMe) {
      if (likes == 1) return appLoc.translate('community.likes.you');

      // Filter out current user from names to show other names
      final otherLikers = likers.where((u) => u.id != currentUserId).toList();
      final otherCount = likes - 1;

      if (otherLikers.isEmpty) {
        // We liked it, but we don't have other names in the top list (should be rare if we just liked it)
        // But if count > 1, we must have others.
        return appLoc.translate('community.likes.you_many',
            variables: {'name': 'User', 'count': otherCount.toString()});
      }

      final name1 = otherLikers[0].name.split(' ').first;

      if (otherCount == 1) {
        return appLoc
            .translate('community.likes.you_1', variables: {'name': name1});
      }

      // You + One Name + Others
      if (otherLikers.length >= 2 && otherCount > 2) {
        // You, Name1, Name2 and X others
        final name2 = otherLikers[1].name.split(' ').first;
        return appLoc.translate('community.likes.you_many_2', variables: {
          'name1': name1,
          'name2': name2,
          'count': (otherCount - 2).toString()
        });
      }

      return appLoc.translate('community.likes.you_many', variables: {
        'name1': name1,
        'name': name1, // fallback
        'count': (otherCount - 1).toString()
      });
    }

    if (likers.isEmpty)
      return appLoc.translate('community.likes.simple',
          variables: {'count': likes.toString()});

    final name1 = likers[0].name.split(' ').first;

    if (likers.length == 1 && likes == 1) {
      return appLoc
          .translate('community.likes.one', variables: {'name': name1});
    }

    if (likers.length >= 2) {
      final name2 = likers[1].name.split(' ').first;
      if (likes == 2)
        return appLoc.translate('community.likes.two',
            variables: {'name1': name1, 'name2': name2});
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
              Navigator.pop(ctx); // Close dialog
              final nav = Navigator.of(context);
              final success = await _service.deletePost(widget.postId);
              if (success && nav.canPop()) {
                nav.pop(); // Close detail screen
              }
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
      _loadData();
    }
    setState(() {
      _isEditingPost = false;
    });
  }

  Future<void> _onDeleteComment(String commentId) async {
    // Show confirmation? maybe skip for now for speed or add simple one
    await _service.deleteComment(widget.postId, commentId);
    _loadData();
  }

  void _openTagPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(builder: (context, setStateSheet) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Add Tags",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                        // Also update parent state to reflect immediately if visible behind sheet
                        this.setState(() {});
                      },
                      selectedColor: const Color(0xFFF97316).withOpacity(0.2),
                      checkmarkColor: const Color(0xFFF97316),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? const Color(0xFFF97316)
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                      backgroundColor:
                          isDark ? Colors.white10 : Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFFF97316)
                              : Colors.transparent,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        });
      },
    ).then((_) => setState(() {}));
  }

  Widget _buildAddReactionButton(BuildContext context, bool isDark,
      {bool isSmall = false, String? commentId}) {
    return DraggableReactionButton(
      isDark: isDark,
      isSmall: isSmall,
      commentId: commentId,
      onReactionSelected: (emoji) => _onReaction(emoji, commentId: commentId),
    );
  }
}
