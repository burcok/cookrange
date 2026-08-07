import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/chat_prefs_model.dart';
import '../../../core/models/community_group_model.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/community_group_service.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../chat/widgets/media_gallery_screen.dart';
import 'group_members_screen.dart';

/// Faz 5 (Piece A) — WhatsApp-style "group info" screen: reached by tapping
/// the group name/photo in a chat thread's app bar (or, here, from
/// `GroupDetailScreen`'s own header — see that screen's entry-point wiring).
/// A dedicated sub-screen rather than more sections bolted onto
/// `GroupDetailScreen` — that screen is already a dense feed/composer/join-
/// button surface; this one is purely informational + settings, matching
/// the "tap header -> info screen" split the plan describes.
///
/// Every read here reuses an EXISTING service method
/// (`CommunityGroupService`/`ChatService`) — no new Firestore query shapes,
/// so no new composite index is needed.
class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  const GroupInfoScreen({super.key, required this.groupId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _groupService = CommunityGroupService();
  final _chatService = ChatService();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Memoized by uid — a plain FutureBuilder fed a freshly-constructed Future
  // every build would re-issue the lookup on every rebuild (R1).
  String? _creatorNameUid;
  Future<String> _creatorNameFuture = Future.value('');

  Future<String> _resolveCreatorName(String ownerUid) async {
    if (ownerUid.isEmpty) return '';
    if (_creatorNameUid != ownerUid) {
      _creatorNameUid = ownerUid;
      _creatorNameFuture = _chatService
          .getUserDisplayNames([ownerUid]).then((m) => m[ownerUid] ?? '');
    }
    return _creatorNameFuture;
  }

  Future<void> _toggleMute(bool mute) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    unawaited(HapticFeedback.selectionClick());
    try {
      if (mute) {
        await _chatService.muteChat(uid, _chatIdOf(widget.groupId));
      } else {
        await _chatService.unmuteChat(uid, _chatIdOf(widget.groupId));
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, e.toString());
    }
  }

  // The group's chatId == its own id by construction
  // (CommunityGroupModel.chatId's doc comment) — used as a fallback only
  // for the mute toggle, which needs a chatId before the group stream's
  // first snapshot arrives. Every other read below uses the real
  // `group.chatId` off the loaded model.
  String _chatIdOf(String groupId) => groupId;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.translate('community.groups.info.title'),
            style: t.titleL),
      ),
      body: StreamBuilder<CommunityGroupModel?>(
        stream: _groupService.getGroupStream(widget.groupId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final group = snap.data;
          if (group == null) {
            return AppErrorState(
                title: l10n.translate('community.groups.not_found'));
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
            children: [
              _CoverHeader(group: group),
              SizedBox(height: 20.h),
              _AboutCard(group: group, creatorNameFuture: _resolveCreatorName(group.ownerUid)),
              SizedBox(height: 12.h),
              _MembersCard(groupId: widget.groupId, group: group),
              SizedBox(height: 12.h),
              _AdminsCard(groupId: widget.groupId),
              SizedBox(height: 12.h),
              _SharedMediaCard(chatId: group.chatId),
              SizedBox(height: 12.h),
              _MuteCard(
                uid: _uid,
                chatId: group.chatId,
                chatService: _chatService,
                onToggle: _toggleMute,
              ),
              SizedBox(height: 12.h),
              const _SecurityDisclosureCard(),
            ],
          );
        },
      ),
    );
  }
}

class _CoverHeader extends StatelessWidget {
  final CommunityGroupModel group;
  const _CoverHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).primaryColor;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg.r),
          child: group.coverImageUrl != null && group.coverImageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: group.coverImageUrl!,
                  width: 96.r,
                  height: 96.r,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                      width: 96.r, height: 96.r, color: palette.shimmerBase),
                  errorWidget: (_, __, ___) => Container(
                    width: 96.r,
                    height: 96.r,
                    color: primary.withValues(alpha: 0.12),
                    child: Icon(Icons.groups_rounded, color: primary, size: 44.r),
                  ),
                )
              : Container(
                  width: 96.r,
                  height: 96.r,
                  color: primary.withValues(alpha: 0.12),
                  child: Icon(Icons.groups_rounded, color: primary, size: 44.r),
                ),
        ),
        SizedBox(height: 12.h),
        Text(group.name,
            textAlign: TextAlign.center,
            style: t.titleL.copyWith(fontWeight: FontWeight.w800)),
        SizedBox(height: 4.h),
        Text(
          l10n
              .translate('community.groups.members_count')
              .replaceAll('{n}', '${group.memberCount}'),
          style: t.labelM.copyWith(color: palette.textSecondary),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  const _SectionCard({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppPalette.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!,
                style: t.labelM.copyWith(
                    color: palette.textSecondary, fontWeight: FontWeight.w700)),
            SizedBox(height: 8.h),
          ],
          child,
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final CommunityGroupModel group;
  final Future<String> creatorNameFuture;
  const _AboutCard({required this.group, required this.creatorNameFuture});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final dateFmt =
        DateFormat.yMMMd(Localizations.localeOf(context).languageCode);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.description != null && group.description!.isNotEmpty) ...[
            Text(l10n.translate('community.groups.about'),
                style: t.bodyM.copyWith(fontWeight: FontWeight.w700)),
            SizedBox(height: 4.h),
            Text(group.description!,
                style: t.bodyM.copyWith(color: palette.textSecondary)),
            SizedBox(height: 12.h),
          ],
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            label: l10n.translate('community.groups.info.created_label'),
            value: dateFmt.format(group.createdAt),
          ),
          SizedBox(height: 10.h),
          FutureBuilder<String>(
            future: creatorNameFuture,
            builder: (context, snap) {
              final name = snap.data;
              return _InfoRow(
                icon: Icons.person_outline_rounded,
                label: l10n.translate('community.groups.info.creator_label'),
                value: (name == null || name.isEmpty)
                    ? l10n.translate('community.groups.moderation.member_fallback')
                    : name,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return Row(
      children: [
        Icon(icon, size: 18.r, color: palette.textTertiary),
        SizedBox(width: 10.w),
        Text(label, style: t.labelM.copyWith(color: palette.textSecondary)),
        const Spacer(),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodyM.copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _MembersCard extends StatelessWidget {
  final String groupId;
  final CommunityGroupModel group;
  const _MembersCard({required this.groupId, required this.group});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    return _SectionCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        onTap: () => Navigator.push(context,
            AppTransitions.slideRight(GroupMembersScreen(groupId: groupId))),
        child: Row(
          children: [
            Icon(Icons.groups_outlined, size: 20.r, color: palette.textSecondary),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                l10n.translate('community.groups.info.view_all_members'),
                style: t.bodyM.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text('${group.memberCount}',
                style: t.labelM.copyWith(color: palette.textTertiary)),
            SizedBox(width: 4.w),
            Icon(Icons.chevron_right_rounded,
                size: 20.r, color: palette.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// A capped (≤100 — `CommunityGroupService.getMembersStream`'s own limit),
/// client-side filter to owner/admin — no new query shape, and a group's
/// admin roster is realistically small even at that cap.
class _AdminsCard extends StatelessWidget {
  final String groupId;
  const _AdminsCard({required this.groupId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<List<CommunityGroupMemberModel>>(
      stream: CommunityGroupService().getMembersStream(groupId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _SectionCard(
            title: l10n.translate('community.groups.info.admins_section'),
            child: const AppSkeletonList(itemCount: 2),
          );
        }
        final admins = (snap.data ?? const <CommunityGroupMemberModel>[])
            .where((m) =>
                m.role == GroupMemberRole.owner ||
                m.role == GroupMemberRole.admin)
            .toList();
        if (admins.isEmpty) return const SizedBox.shrink();

        return _SectionCard(
          title: l10n.translate('community.groups.info.admins_section'),
          child: Column(
            children: [
              for (var i = 0; i < admins.length; i++) ...[
                if (i > 0) SizedBox(height: 8.h),
                _AdminRow(member: admins[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AdminRow extends StatelessWidget {
  final CommunityGroupMemberModel member;
  const _AdminRow({required this.member});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).primaryColor;

    return Row(
      children: [
        AppInitialsAvatar(
          photoUrl: member.photoURL,
          name: member.displayName ?? '?',
          size: 32.r,
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            member.displayName ??
                l10n.translate('community.groups.moderation.member_fallback'),
            style: t.bodyM.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: (member.role == GroupMemberRole.owner
                    ? palette.info
                    : primary)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.full.r),
          ),
          child: Text(
            l10n.translate('community.groups.moderation.role_${member.role.value}'),
            style: t.labelS.copyWith(
              color: member.role == GroupMemberRole.owner ? palette.info : primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Faz 5 — shared-media preview, reusing `ChatService.getChatMediaPage` (the
/// SAME composite-indexed query `MediaGalleryScreen` itself pages through) —
/// no new Firestore query shape, just a small (9-item) one-shot fetch for a
/// preview grid, with "View all" pushing the existing full gallery screen.
class _SharedMediaCard extends StatefulWidget {
  final String chatId;
  const _SharedMediaCard({required this.chatId});

  @override
  State<_SharedMediaCard> createState() => _SharedMediaCardState();
}

class _SharedMediaCardState extends State<_SharedMediaCard> {
  static const int _previewCount = 9;
  late final Future<List<AppMediaGridItem>> _future = _load();

  Future<List<AppMediaGridItem>> _load() async {
    final page = await ChatService()
        .getChatMediaPage(widget.chatId, limit: _previewCount);
    final out = <AppMediaGridItem>[];
    for (final m in page.media) {
      for (var i = 0; i < m.attachments.length; i++) {
        out.add(AppMediaGridItem(
            attachment: m.attachments[i], sourceMessage: m, attachmentIndex: i));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return FutureBuilder<List<AppMediaGridItem>>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final items = snap.data ?? const <AppMediaGridItem>[];

        return _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md.r),
                onTap: () => Navigator.push(
                    context,
                    AppTransitions.slideRight(
                        MediaGalleryScreen(chatId: widget.chatId))),
                child: Row(
                  children: [
                    Icon(Icons.photo_library_outlined,
                        size: 20.r, color: palette.textSecondary),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        l10n.translate('community.groups.info.media_section'),
                        style: t.bodyM.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (!loading && items.isNotEmpty)
                      Text(l10n.translate('community.groups.info.media_view_all'),
                          style: t.labelM.copyWith(color: Theme.of(context).primaryColor)),
                    SizedBox(width: 4.w),
                    Icon(Icons.chevron_right_rounded,
                        size: 20.r, color: palette.textTertiary),
                  ],
                ),
              ),
              if (loading) ...[
                SizedBox(height: 10.h),
                const AppSkeletonStatGrid(itemCount: 6, crossAxisCount: 3),
              ] else if (items.isEmpty) ...[
                SizedBox(height: 10.h),
                Text(l10n.translate('community.groups.info.media_empty'),
                    style: t.labelM.copyWith(color: palette.textTertiary)),
              ] else ...[
                SizedBox(height: 10.h),
                // A non-scrolling preview grid (NeverScrollableScrollPhysics,
                // shrinkWrap) rather than the full interactive `AppMediaGrid`
                // — this card already lives inside the screen's own
                // scrolling `ListView`, and `AppMediaGrid` has no physics
                // override to avoid a same-axis nested-scroll fight.
                // `ChatAttachmentImage` is the same resolve-point `AppMediaGrid`
                // itself uses per cell, so both stay visually/behaviorally
                // identical for the legacy-vs-scoped attachment split.
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2.w,
                    mainAxisSpacing: 2.h,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        AppTransitions.slideRight(
                            MediaGalleryScreen(chatId: widget.chatId))),
                    child: ChatAttachmentImage(
                      attachment: items[i].attachment,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Notification-mute toggle. Surfaces `ChatService.muteChat`/`unmuteChat` —
/// per this file's audit, that pair already covers exactly this ("chat_prefs
/// muteChat/unmuteChat likely already covers this — just surface it").
class _MuteCard extends StatelessWidget {
  final String uid;
  final String chatId;
  final ChatService chatService;
  final ValueChanged<bool> onToggle;

  const _MuteCard({
    required this.uid,
    required this.chatId,
    required this.chatService,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _SectionCard(
      child: StreamBuilder<ChatPrefsModel>(
        stream: chatService.getChatPrefsStream(uid),
        builder: (context, snap) {
          final prefs = snap.data ?? ChatPrefsModel.empty;
          return AppToggle(
            value: prefs.isMuted(chatId),
            label: l10n.translate('community.groups.info.mute_notifications'),
            onChanged: onToggle,
          );
        },
      ),
    );
  }
}

/// Faz 5 — mandatory, truthful security disclosure. A KVKK/consumer-
/// protection matter for a Turkey-primary market (CLAUDE.md §6), not
/// marketing copy: encrypted-in-transit/at-rest is real; end-to-end
/// encryption is explicitly NOT offered, and the reason (server-side
/// moderation needs to read content) is stated plainly rather than glossed
/// over. Rendered as a real section — bordered, iconed, its own card — never
/// a footnote.
class _SecurityDisclosureCard extends StatelessWidget {
  const _SecurityDisclosureCard();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: EdgeInsets.all(AppSpacing.md.r),
      decoration: BoxDecoration(
        color: palette.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 18.r, color: palette.textSecondary),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  l10n.translate('community.groups.info.security_section_title'),
                  style: t.labelM.copyWith(
                      color: palette.textSecondary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            l10n.translate('community.groups.info.security_body'),
            style: t.labelM.copyWith(color: palette.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
