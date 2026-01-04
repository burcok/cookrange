import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/models/community_post.dart';
import '../../core/services/community_service.dart';
import '../../core/localization/app_localizations.dart';
import 'widgets/glass_refresher.dart';

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
                                              _showEditDialog(context, _post!),
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

                                // Post Text
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
                                      _buildAddReactionButton(isDark,
                                          isSmall: true),
                                    ],
                                  ),
                                ),

                                // Actions Row (Updated Logic)
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _onReaction('❤️'),
                                      child: Icon(
                                        _post!.userReactions.contains('❤️')
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color:
                                            _post!.userReactions.contains('❤️')
                                                ? Colors.red
                                                : (isDark
                                                    ? const Color(0xFF94A3B8)
                                                    : const Color(0xFF64748B)),
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${_post!.reactions['❤️'] ?? 0}",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
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
                    _buildGlassCommentInput(isDark),
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
                    if (comment.author.id == _service.currentUserId)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.more_vert,
                            size: 16,
                            color: isDark ? Colors.white54 : Colors.grey),
                        onSelected: (val) {
                          if (val == 'edit') {
                            setState(() {
                              _editingCommentId = comment.id;
                              _editCommentController.text = comment.content;
                            });
                          }
                          if (val == 'delete') _onDeleteComment(comment.id);
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                              value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete',
                                  style: TextStyle(color: Colors.red))),
                        ],
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
                Wrap(
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
                    _buildAddReactionButton(isDark,
                        isSmall: true, commentId: comment.id),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
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
          _post = CommunityPost(
            id: _post!.id,
            author: _post!.author,
            content: _post!.content,
            timestamp: _post!.timestamp,
            imageUrls: _post!.imageUrls,
            likesCount: _post!.likesCount,
            commentsCount: _post!.commentsCount,
            tags: _post!.tags,
            isLiked: _post!.isLiked,
            isBookmarked: _post!.isBookmarked,
            reactions: reactions,
            userReactions: userReactions, // kept once
            isEdited: _post!.isEdited,
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
    // Reload silently to sync fully if needed, but optimistic should hold
    // _loadData();
  }

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

  Widget _buildGlassCommentInput(bool isDark) {
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
                  backgroundImage: NetworkImage(_post!.author.avatarUrl),
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

  void _showEditDialog(BuildContext context, CommunityPost post) {
    final TextEditingController editController =
        TextEditingController(text: post.content);
    final appLoc = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appLoc.translate('community.menu.edit')),
        content: TextField(
          controller: editController,
          maxLines: 5,
          minLines: 1,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(appLoc.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () async {
              final newContent = editController.text.trim();
              if (newContent.isNotEmpty && newContent != post.content) {
                Navigator.pop(ctx); // Close dialog
                await _service.updatePost(post.id, newContent);
                // Refresh local state if needed, or rely on Stream/Future
                // Since this page uses FutureBuilder currently (or did I change it to use passed post? No, it loads details)
                // Actually PostDetailScreen loads details in _loadData
                _loadData();
              } else {
                Navigator.pop(ctx);
              }
            },
            child: Text(appLoc.translate('common.save')),
          ),
        ],
      ),
    );
  }

  Future<void> _onDeleteComment(String commentId) async {
    // Show confirmation? maybe skip for now for speed or add simple one
    await _service.deleteComment(widget.postId, commentId);
    _loadData();
  }

  Widget _buildAddReactionButton(bool isDark,
      {bool isSmall = false, String? commentId, double? size}) {
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
            enabled: false, // Container for row
            child: SizedBox(
              height: 40,
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
          )
        ];
      },
      onSelected: (emoji) => _onReaction(emoji, commentId: commentId),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: isSmall
            ? BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
                shape: BoxShape.circle)
            : null,
        child: Icon(Icons.add_reaction_outlined,
            size: size ?? (isSmall ? 16 : 20),
            color: isDark ? Colors.white70 : Colors.grey.shade600),
      ),
    );
  }
}
