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

  Future<void> _toggleMembership(bool isMember, String groupName) async {
    final l10n = AppLocalizations.of(context);
    try {
      if (isMember) {
        await _groupService.leaveGroup(widget.groupId);
      } else {
        await _groupService.joinGroup(widget.groupId);
        if (mounted) {
          unawaited(HapticFeedback.mediumImpact());
          AppSnackBar.success(
            context,
            l10n
                .translate('community.groups.join_success')
                .replaceAll('{group}', groupName),
          );
        }
      }
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
            return _scaffoldFrame(palette,
                const Center(child: CircularProgressIndicator()));
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
                title: Text(group.name,
                    style: t.titleM.copyWith(fontWeight: FontWeight.w800)),
              ),
              SliverToBoxAdapter(
                child: _Header(
                  group: group,
                  uid: _uid,
                  service: _groupService,
                  onToggle: (isMember) =>
                      _toggleMembership(isMember, group.name),
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
                              label: l10n.translate('community.groups.post_btn'),
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

class _Header extends StatelessWidget {
  final CommunityGroupModel group;
  final String uid;
  final CommunityGroupService service;
  final ValueChanged<bool> onToggle;

  const _Header({
    required this.group,
    required this.uid,
    required this.service,
    required this.onToggle,
  });

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
                                style: t.labelM.copyWith(
                                    color: palette.textSecondary),
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
                      style:
                          t.labelS.copyWith(color: palette.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // Join / leave
          StreamBuilder<bool>(
            stream: service.isMemberStream(group.id, uid),
            builder: (context, snap) {
              final isMember = snap.data ?? false;
              return AppButton(
                label: l10n.translate(
                    isMember ? 'community.groups.leave' : 'community.groups.join'),
                icon: isMember
                    ? Icons.check_rounded
                    : Icons.group_add_rounded,
                variant: isMember
                    ? AppButtonVariant.secondary
                    : AppButtonVariant.primary,
                onPressed: () => onToggle(isMember),
              );
            },
          ),
          if (group.description != null &&
              group.description!.isNotEmpty) ...[
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
                                color: primary,
                                fontWeight: FontWeight.w600)),
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
                    onTap: () => Navigator.push(context,
                        AppTransitions.slideUp(PostDetailScreen(postId: post.id))),
                    onLike: () => service.likePost(post.id),
                    onComment: () => Navigator.push(context,
                        AppTransitions.slideUp(PostDetailScreen(postId: post.id))),
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
