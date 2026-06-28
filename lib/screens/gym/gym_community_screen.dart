import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/gym_post_model.dart';
import '../../core/services/gym_post_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Per-gym community screen: Feed tab + Announcements tab.
///
/// All gym members can create posts; only the owner can post announcements,
/// pin/unpin posts, delete any post, and toggle announcement status.
class GymCommunityScreen extends StatefulWidget {
  final String gymId;
  final String gymName;
  final bool isOwner;
  final Color? brandColor;

  const GymCommunityScreen({
    super.key,
    required this.gymId,
    required this.gymName,
    required this.isOwner,
    this.brandColor,
  });

  @override
  State<GymCommunityScreen> createState() => _GymCommunityScreenState();
}

class _GymCommunityScreenState extends State<GymCommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openComposer() {
    final l10n = AppLocalizations.of(context);
    AppSheet.show(
      context: context,
      title: l10n.translate('gym.community_new_post'),
      child: _PostComposerSheet(
        gymId: widget.gymId,
        isOwner: widget.isOwner,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final primary = widget.brandColor ?? Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.gymName,
              style: AppText.of(context).titleM.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              l10n.translate('gym.community_title'),
              style: AppText.of(context).labelS.copyWith(
                    color: palette.textSecondary,
                  ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primary,
          unselectedLabelColor: palette.textSecondary,
          indicatorColor: primary,
          labelStyle: AppText.of(context)
              .labelL
              .copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: AppText.of(context).labelL,
          tabs: [
            Tab(text: l10n.translate('gym.community_feed_tab')),
            Tab(text: l10n.translate('gym.community_announcements_tab')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          _openComposer();
        },
        backgroundColor: primary,
        foregroundColor: Colors.white,
        tooltip: l10n.translate('gym.community_new_post'),
        child: const Icon(Icons.edit_rounded),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FeedTab(
            gymId: widget.gymId,
            isOwner: widget.isOwner,
            currentUid: _currentUid,
          ),
          _AnnouncementsTab(
            gymId: widget.gymId,
            isOwner: widget.isOwner,
            currentUid: _currentUid,
          ),
        ],
      ),
    );
  }
}

// ── Feed tab ──────────────────────────────────────────────────────────────────

class _FeedTab extends StatelessWidget {
  final String gymId;
  final bool isOwner;
  final String? currentUid;

  const _FeedTab({
    required this.gymId,
    required this.isOwner,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<List<GymPostModel>>(
      stream: GymPostService().getFeedStream(gymId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: AppSkeletonList(itemCount: 3),
          );
        }
        if (snap.hasError) {
          return AppErrorState(
            title: 'Something went wrong',
            message: snap.error.toString(),
          );
        }
        final posts = snap.data ?? [];
        if (posts.isEmpty) {
          return AppEmptyState(
            icon: Icons.forum_outlined,
            title: l10n.translate('gym.community_empty_feed_title'),
            message: l10n.translate('gym.community_empty_feed_sub'),
          );
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: posts.length,
          itemBuilder: (ctx, i) => _GymPostCard(
            key: ValueKey(posts[i].id),
            post: posts[i],
            gymId: gymId,
            isOwner: isOwner,
            currentUid: currentUid,
          ),
        );
      },
    );
  }
}

// ── Announcements tab ─────────────────────────────────────────────────────────

class _AnnouncementsTab extends StatelessWidget {
  final String gymId;
  final bool isOwner;
  final String? currentUid;

  const _AnnouncementsTab({
    required this.gymId,
    required this.isOwner,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<List<GymPostModel>>(
      stream: GymPostService().getAnnouncementsStream(gymId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: AppSkeletonList(itemCount: 3),
          );
        }
        if (snap.hasError) {
          return AppErrorState(
            title: 'Something went wrong',
            message: snap.error.toString(),
          );
        }
        final posts = snap.data ?? [];
        if (posts.isEmpty) {
          return AppEmptyState(
            icon: Icons.campaign_outlined,
            title: l10n.translate('gym.community_empty_announcements_title'),
            message: l10n.translate('gym.community_empty_announcements_sub'),
          );
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: posts.length,
          itemBuilder: (ctx, i) => _GymPostCard(
            key: ValueKey(posts[i].id),
            post: posts[i],
            gymId: gymId,
            isOwner: isOwner,
            currentUid: currentUid,
          ),
        );
      },
    );
  }
}

// ── Post card ─────────────────────────────────────────────────────────────────

class _GymPostCard extends StatefulWidget {
  final GymPostModel post;
  final String gymId;
  final bool isOwner;
  final String? currentUid;

  const _GymPostCard({
    super.key,
    required this.post,
    required this.gymId,
    required this.isOwner,
    required this.currentUid,
  });

  @override
  State<_GymPostCard> createState() => _GymPostCardState();
}

class _GymPostCardState extends State<_GymPostCard>
    with SingleTickerProviderStateMixin {
  late bool _likedOptimistic;
  late int _likeCountOptimistic;
  bool _likeInFlight = false;

  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _likedOptimistic =
        widget.post.isLikedBy(widget.currentUid ?? '');
    _likeCountOptimistic = widget.post.likeCount;

    _entryCtrl = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    )..forward();

    _fadeAnim =
        CurvedAnimation(parent: _entryCtrl, curve: AppMotion.emphasized);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: AppMotion.emphasized,
    ));
  }

  @override
  void didUpdateWidget(_GymPostCard old) {
    super.didUpdateWidget(old);
    if (!_likeInFlight) {
      _likedOptimistic =
          widget.post.isLikedBy(widget.currentUid ?? '');
      _likeCountOptimistic = widget.post.likeCount;
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLike() async {
    if (_likeInFlight || widget.currentUid == null) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _likeInFlight = true;
      _likedOptimistic = !_likedOptimistic;
      _likeCountOptimistic += _likedOptimistic ? 1 : -1;
    });
    try {
      await GymPostService().toggleLike(
        widget.gymId,
        widget.post.id,
        widget.currentUid!,
        !_likedOptimistic, // was liked before toggle
      );
    } catch (_) {
      // Revert optimistic update
      if (mounted) {
        setState(() {
          _likedOptimistic = !_likedOptimistic;
          _likeCountOptimistic += _likedOptimistic ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _likeInFlight = false);
    }
  }

  void _openComments() {
    AppSheet.show(
      context: context,
      title: 'Comments',
      child: _CommentsSheet(
        gymId: widget.gymId,
        postId: widget.post.id,
        currentUid: widget.currentUid,
        isOwner: widget.isOwner,
      ),
    );
  }

  void _showMoreOptions() {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final primary = Theme.of(context).primaryColor;
    final post = widget.post;

    AppSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pin / Unpin
          if (widget.isOwner)
            ListTile(
              leading: Icon(
                post.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                color: primary,
              ),
              title: Text(
                post.isPinned
                    ? l10n.translate('gym.community_unpin')
                    : l10n.translate('gym.community_pin'),
                style: AppText.of(context)
                    .bodyM
                    .copyWith(color: palette.textPrimary),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                try {
                  await GymPostService()
                      .togglePin(widget.gymId, post.id, post.isPinned);
                } catch (_) {
                  if (mounted) {
                    AppSnackBar.error(context, 'Could not update post.');
                  }
                }
              },
            ),
          // Mark / Unmark announcement
          if (widget.isOwner)
            ListTile(
              leading: Icon(
                post.isAnnouncement
                    ? Icons.campaign_outlined
                    : Icons.campaign_rounded,
                color: palette.info,
              ),
              title: Text(
                post.isAnnouncement
                    ? l10n.translate('gym.community_unmark_announcement')
                    : l10n.translate('gym.community_mark_announcement'),
                style: AppText.of(context)
                    .bodyM
                    .copyWith(color: palette.textPrimary),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                try {
                  await GymPostService().toggleAnnouncement(
                      widget.gymId, post.id, post.isAnnouncement);
                } catch (_) {
                  if (mounted) {
                    AppSnackBar.error(context, 'Could not update post.');
                  }
                }
              },
            ),
          // Delete
          if (widget.isOwner || post.authorUid == widget.currentUid)
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: palette.error),
              title: Text(
                l10n.translate('gym.community_delete_post'),
                style: AppText.of(context)
                    .bodyM
                    .copyWith(color: palette.error),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(
                      l10n.translate('gym.community_delete_post'),
                      style: AppText.of(context).titleM,
                    ),
                    content: Text(
                      l10n.translate('gym.community_delete_confirm'),
                      style: AppText.of(context).bodyM,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(
                          'Delete',
                          style: TextStyle(color: palette.error),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await GymPostService()
                        .deletePost(widget.gymId, post.id);
                    if (mounted) {
                      AppSnackBar.success(
                          context,
                          l10n.translate('gym.community_deleted'));
                    }
                  } catch (_) {
                    if (mounted) {
                      AppSnackBar.error(
                          context, 'Could not delete post.');
                    }
                  }
                }
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context);
    final post = widget.post;
    final canShowMore = widget.isOwner || post.authorUid == widget.currentUid;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ──────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          primary.withValues(alpha: 0.15),
                      backgroundImage: post.authorPhotoUrl != null
                          ? NetworkImage(post.authorPhotoUrl!)
                          : null,
                      child: post.authorPhotoUrl == null
                          ? Text(
                              post.authorName.isNotEmpty
                                  ? post.authorName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  post.authorName,
                                  style: AppText.of(context).bodyM.copyWith(
                                        color: palette.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (post.authorIsOwner) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    l10n.translate(
                                        'gym.community_owner_badge'),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: primary,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            _timeAgo(post.createdAt),
                            style: AppText.of(context).labelS.copyWith(
                                  color: palette.textTertiary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (post.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.push_pin_rounded,
                            size: 16, color: primary),
                      ),
                    if (post.isAnnouncement)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.campaign_rounded,
                            size: 16, color: palette.info),
                      ),
                    if (canShowMore)
                      GestureDetector(
                        onTap: _showMoreOptions,
                        child: Icon(Icons.more_horiz_rounded,
                            color: palette.textSecondary, size: 20),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── Content ─────────────────────────────────────────────────
                Text(
                  post.content,
                  style: AppText.of(context).bodyM.copyWith(
                        color: palette.textPrimary,
                        height: 1.5,
                      ),
                ),

                // ── Image ────────────────────────────────────────────────────
                if (post.imageUrl != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppRadius.sm),
                    child: Image.network(
                      post.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        color: palette.surfaceVariant,
                        child: Icon(Icons.broken_image_outlined,
                            color: palette.textTertiary),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.sm),

                // ── Action row ───────────────────────────────────────────────
                Row(
                  children: [
                    // Like button
                    GestureDetector(
                      onTap: _handleLike,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: AppMotion.fast,
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(
                                    scale: anim, child: child),
                            child: Icon(
                              _likedOptimistic
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              key: ValueKey(_likedOptimistic),
                              color: _likedOptimistic
                                  ? palette.error
                                  : palette.textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_likeCountOptimistic',
                            style: AppText.of(context).labelS.copyWith(
                                  color: palette.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Comment button
                    GestureDetector(
                      onTap: _openComments,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              color: palette.textSecondary, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${post.commentCount}',
                            style: AppText.of(context).labelS.copyWith(
                                  color: palette.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Post composer sheet ───────────────────────────────────────────────────────

class _PostComposerSheet extends StatefulWidget {
  final String gymId;
  final bool isOwner;

  const _PostComposerSheet({
    required this.gymId,
    required this.isOwner,
  });

  @override
  State<_PostComposerSheet> createState() => _PostComposerSheetState();
}

class _PostComposerSheetState extends State<_PostComposerSheet> {
  final _controller = TextEditingController();
  bool _isAnnouncement = false;
  bool _posting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    setState(() => _posting = true);
    try {
      await GymPostService().createPost(
        gymId: widget.gymId,
        content: content,
        isAnnouncement: _isAnnouncement,
        isOwner: widget.isOwner,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not create post. Try again.');
        setState(() => _posting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _controller,
          hintText: l10n.translate('gym.community_post_hint'),
          maxLines: 5,
          minLines: 3,
          autofocus: true,
          textInputAction: TextInputAction.newline,
        ),
        if (widget.isOwner) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.translate('gym.community_is_announcement'),
                  style: AppText.of(context).bodyM.copyWith(
                        color: palette.textPrimary,
                      ),
                ),
              ),
              Switch.adaptive(
                value: _isAnnouncement,
                onChanged: (v) => setState(() => _isAnnouncement = v),
                activeThumbColor: Theme.of(context).primaryColor,
                activeTrackColor:
                    Theme.of(context).primaryColor.withValues(alpha: 0.4),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.translate('gym.community_post_btn'),
          onPressed: _posting ? null : _post,
          icon: Icons.send_rounded,
        ),
      ],
    );
  }
}

// ── Comments sheet ────────────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final String gymId;
  final String postId;
  final String? currentUid;
  final bool isOwner;

  const _CommentsSheet({
    required this.gymId,
    required this.postId,
    required this.currentUid,
    required this.isOwner,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _commentController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await GymPostService().addComment(
        gymId: widget.gymId,
        postId: widget.postId,
        content: text,
      );
      if (mounted) {
        _commentController.clear();
        setState(() => _sending = false);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not send comment.');
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await GymPostService()
          .deleteComment(widget.gymId, widget.postId, commentId);
    } catch (_) {
      if (mounted) AppSnackBar.error(context, 'Could not delete comment.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final primary = Theme.of(context).primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Comment list
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.45,
          ),
          child: StreamBuilder<List<GymCommentModel>>(
            stream: GymPostService()
                .getCommentsStream(widget.gymId, widget.postId),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: AppSkeletonList(itemCount: 3),
                );
              }
              final comments = snap.data ?? [];
              if (comments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: AppEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No comments yet',
                    message: 'Be the first to comment.',
                    compact: true,
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: comments.length,
                itemBuilder: (ctx, i) {
                  final c = comments[i];
                  final canDelete = widget.isOwner ||
                      c.authorUid == widget.currentUid;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              primary.withValues(alpha: 0.15),
                          backgroundImage: c.authorPhotoUrl != null
                              ? NetworkImage(c.authorPhotoUrl!)
                              : null,
                          child: c.authorPhotoUrl == null
                              ? Text(
                                  c.authorName.isNotEmpty
                                      ? c.authorName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    c.authorName,
                                    style: AppText.of(context)
                                        .labelL
                                        .copyWith(
                                          color: palette.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _timeAgo(c.createdAt),
                                    style: AppText.of(context)
                                        .labelS
                                        .copyWith(
                                          color: palette.textTertiary,
                                        ),
                                  ),
                                  if (canDelete) ...[
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () =>
                                          _deleteComment(c.id),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 15,
                                        color: palette.textTertiary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.content,
                                style: AppText.of(context)
                                    .bodyM
                                    .copyWith(
                                      color: palette.textPrimary,
                                      height: 1.4,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Comment input
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _commentController,
                hintText: l10n.translate('gym.community_add_comment'),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendComment(),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: AppMotion.fast,
              child: _sending
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primary,
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _sendComment,
                      icon: Icon(Icons.send_rounded, color: primary),
                      tooltip:
                          l10n.translate('gym.community_comment_btn'),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Time helper ───────────────────────────────────────────────────────────────

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}
