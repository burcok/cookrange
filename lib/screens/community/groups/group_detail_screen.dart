import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/community_group_model.dart';
import '../../../core/models/community_post.dart';
import '../../../core/services/community_group_service.dart';
import '../../../core/services/community_service.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/widgets/ds/ds.dart';
import '../post_detail_screen.dart';
import '../widgets/glass_post_card.dart';
import 'group_info_screen.dart';
import 'group_leaderboard_screen.dart';
import 'group_members_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _groupService = CommunityGroupService();
  final _postService = CommunityService();
  final _composerCtrl = TextEditingController();
  bool _posting = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _composerCtrl.dispose();
    super.dispose();
  }

  // Joining is join_policy-aware (open/request/invite) and lives in
  // _HeaderState now, mirroring active_groups_section.dart's _handleJoin —
  // leaving has no policy branch, so it stays here.
  Future<void> _leaveGroup() async {
    try {
      await _groupService.leaveGroup(widget.groupId);
    } catch (e) {
      if (mounted) AppSnackBar.error(context, e.toString());
    }
  }

  Future<void> _post() async {
    final text = _composerCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      await _postService.createPost(
        text,
        const [],
        const ['group'],
        groupId: widget.groupId,
      );
      await _groupService.touchActivity(widget.groupId);
      if (!mounted) return;
      _composerCtrl.clear();
      FocusScope.of(context).unfocus();
      unawaited(HapticFeedback.lightImpact());
    } catch (e) {
      if (mounted) AppSnackBar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: StreamBuilder<CommunityGroupModel?>(
        stream: _groupService.getGroupStream(widget.groupId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _scaffoldFrame(
                palette, const Center(child: CircularProgressIndicator()));
          }
          final group = snap.data;
          if (group == null) {
            return _scaffoldFrame(
              palette,
              AppErrorState(
                title: l10n.translate('community.groups.not_found'),
              ),
            );
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: palette.background,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_rounded,
                      color: palette.textPrimary, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // Faz 5 (Piece A) — WhatsApp-style "tap header -> group
                // info" entry point. `GroupInfoScreen` owns everything the
                // plan asks for beyond what this feed screen already shows
                // (creation date/creator/admin list/shared media/mute
                // toggle/security disclosure) — a dedicated sub-screen
                // rather than more sections on this already-dense feed.
                title: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.push(
                    context,
                    AppTransitions.slideRight(
                        GroupInfoScreen(groupId: widget.groupId)),
                  ),
                  child: Text(group.name,
                      style: t.titleM.copyWith(fontWeight: FontWeight.w800)),
                ),
                // Faz 2 §2.6 — member list + moderation entry point. Purely
                // additive (a new app-bar action); the join/leave button
                // below is join_policy-aware (_HeaderState).
                actions: [
                  // Faz 5 §5.3 — group contribution leaderboard entry
                  // point, same additive pattern as the member-list action
                  // beside it.
                  IconButton(
                    icon: Icon(Icons.emoji_events_outlined,
                        color: palette.textPrimary, size: 22),
                    tooltip: l10n
                        .translate('community.groups.leaderboard_nav_tooltip'),
                    onPressed: () => Navigator.push(
                      context,
                      AppTransitions.slideRight(GroupLeaderboardScreen(
                        groupId: widget.groupId,
                        groupName: group.name,
                      )),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.people_alt_outlined,
                        color: palette.textPrimary, size: 22),
                    onPressed: () => Navigator.push(
                      context,
                      AppTransitions.slideRight(
                          GroupMembersScreen(groupId: widget.groupId)),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: _Header(
                  group: group,
                  uid: _uid,
                  service: _groupService,
                  onLeave: _leaveGroup,
                ),
              ),
              // Composer (members only)
              SliverToBoxAdapter(
                child: StreamBuilder<bool>(
                  stream: _groupService.isMemberStream(widget.groupId, _uid),
                  builder: (context, m) {
                    if (m.data != true) return const SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
                      child: AppCard(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _composerCtrl,
                                hintText: l10n
                                    .translate('community.groups.post_hint'),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            AppButton(
                              label:
                                  l10n.translate('community.groups.post_btn'),
                              size: AppButtonSize.small,
                              expand: false,
                              loading: _posting,
                              onPressed: _posting ? null : _post,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              _FeedSliver(groupId: widget.groupId, service: _postService),
              SliverToBoxAdapter(child: SizedBox(height: 40.h)),
            ],
          );
        },
      ),
    );
  }

  Widget _scaffoldFrame(AppPalette palette, Widget body) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded,
                color: palette.textPrimary, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Header extends StatefulWidget {
  final CommunityGroupModel group;
  final String uid;
  final CommunityGroupService service;
  final VoidCallback onLeave;

  const _Header({
    required this.group,
    required this.uid,
    required this.service,
    required this.onLeave,
  });

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _busy = false;

  CommunityGroupModel get group => widget.group;

  /// join_policy-aware (Faz 2 §2.3) — mirrors
  /// active_groups_section.dart's _ActiveGroupCardState._handleJoin exactly,
  /// since that's this app's one other join-button caller: 'open' joins
  /// immediately; 'request' opens the same request-sheet →
  /// CommunityGroupService.requestToJoin flow; 'invite' has no direct-join
  /// path at all (a code is required, functions/groups.js:redeemGroupInvite)
  /// — the button in that case shows an informational state instead of
  /// attempting (and failing) a join.
  Future<void> _handleJoin() async {
    final l10n = AppLocalizations.of(context);

    if (group.joinPolicy == GroupJoinPolicy.request) {
      final message = await _showRequestSheet(context, l10n);
      if (message == null) return; // cancelled
      setState(() => _busy = true);
      try {
        await widget.service.requestToJoin(
          group.id,
          message: message.isEmpty ? null : message,
        );
        if (mounted) {
          unawaited(HapticFeedback.mediumImpact());
          AppSnackBar.success(
              context, l10n.translate('community.groups.request_sent'));
        }
      } catch (e) {
        if (mounted) AppSnackBar.error(context, e.toString());
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.service.joinGroup(group.id);
      if (mounted) {
        unawaited(HapticFeedback.mediumImpact());
        AppSnackBar.success(
          context,
          l10n
              .translate('community.groups.join_success')
              .replaceAll('{group}', group.name),
        );
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _showRequestSheet(
      BuildContext context, AppLocalizations l10n) {
    final ctrl = TextEditingController();
    return AppSheet.show<String>(
      context: context,
      title: l10n.translate('community.groups.request_dialog_title'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: ctrl,
              hintText: l10n.translate('community.groups.request_dialog_hint'),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: l10n.translate('community.groups.request_dialog_send'),
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).primaryColor;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56.r,
                height: 56.r,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.groups_rounded, color: primary, size: 28.r),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (group.locationDisplay.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 13.r, color: palette.textSecondary),
                          SizedBox(width: 3.w),
                          Flexible(
                            child: Text(group.locationDisplay,
                                style: t.labelM
                                    .copyWith(color: palette.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    SizedBox(height: 2.h),
                    Text(
                      l10n
                          .translate('community.groups.members_count')
                          .replaceAll('{n}', '${group.memberCount}'),
                      style: t.labelS.copyWith(color: palette.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // Join / leave — join_policy-aware, see _handleJoin's doc comment.
          StreamBuilder<bool>(
            stream: widget.service.isMemberStream(group.id, widget.uid),
            builder: (context, snap) {
              final isMember = snap.data ?? false;
              if (isMember) {
                return AppButton(
                  label: l10n.translate('community.groups.leave'),
                  icon: Icons.check_rounded,
                  variant: AppButtonVariant.secondary,
                  loading: _busy,
                  onPressed: _busy ? null : widget.onLeave,
                );
              }
              if (group.joinPolicy == GroupJoinPolicy.invite) {
                return AppButton(
                  label: l10n.translate('community.groups.invite_only'),
                  icon: Icons.lock_outline_rounded,
                  variant: AppButtonVariant.secondary,
                  onPressed: null,
                );
              }
              return AppButton(
                label: l10n.translate(
                    group.joinPolicy == GroupJoinPolicy.request
                        ? 'community.groups.request_join'
                        : 'community.groups.join'),
                icon: Icons.group_add_rounded,
                loading: _busy,
                onPressed: _busy ? null : _handleJoin,
              );
            },
          ),
          if (group.description != null && group.description!.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Text(l10n.translate('community.groups.about'),
                style: t.titleM.copyWith(fontWeight: FontWeight.w700)),
            SizedBox(height: 6.h),
            Text(group.description!,
                style: t.bodyM.copyWith(color: palette.textSecondary)),
          ],
          if (group.tags.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: group.tags
                  .map((tag) => Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.full.r),
                        ),
                        child: Text('#$tag',
                            style: t.labelS.copyWith(
                                color: primary, fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
            ),
          ],
          SizedBox(height: 16.h),
          Text(l10n.translate('community.groups.feed'),
              style: t.titleM.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _FeedSliver extends StatelessWidget {
  final String groupId;
  final CommunityService service;
  const _FeedSliver({required this.groupId, required this.service});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<List<CommunityPost>>(
      stream: service.getGroupFeedStream(groupId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: AppSkeletonList(itemCount: 3),
            ),
          );
        }
        final posts = snap.data ?? const <CommunityPost>[];
        if (posts.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: AppEmptyState(
                icon: Icons.forum_rounded,
                title: l10n.translate('community.groups.feed_empty_title'),
                message: l10n.translate('community.groups.feed_empty_msg'),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final post = posts[i];
                return RepaintBoundary(
                  child: GlassPostCard(
                    post: post,
                    onTap: () => Navigator.push(
                        context,
                        AppTransitions.slideUp(
                            PostDetailScreen(postId: post.id))),
                    onLike: () => service.likePost(post.id),
                    onComment: () => Navigator.push(
                        context,
                        AppTransitions.slideUp(
                            PostDetailScreen(postId: post.id))),
                    onShare: () {
                      final box = context.findRenderObject() as RenderBox?;
                      final rect = box != null
                          ? box.localToGlobal(Offset.zero) & box.size
                          : null;
                      SharingService().sharePost(
                        context,
                        caption: post.content,
                        authorName: post.author.name,
                        sharePositionOrigin: rect,
                      );
                    },
                    onReaction: (emoji) =>
                        service.toggleReaction(postId: post.id, emoji: emoji),
                  ),
                );
              },
              childCount: posts.length,
            ),
          ),
        );
      },
    );
  }
}
