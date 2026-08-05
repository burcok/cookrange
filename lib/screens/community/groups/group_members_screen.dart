import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/community_group_model.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/community_group_service.dart';
import '../../../core/services/feature_gate_service.dart';
import '../../../core/widgets/ds/ds.dart';

/// Faz 2 §2.6 — group member list + moderation UI. Wires the already-built
/// `CommunityGroupService.kickMember`/`banMember`/`muteMember`/
/// `unmuteMember`/`unbanMember` (Faz 2 §2.3) into a real screen: every
/// action here already existed as a service method with an immutable
/// `moderation/{autoId}` log entry — this screen is the missing UI layer,
/// not new write logic.
class GroupMembersScreen extends StatefulWidget {
  final String groupId;
  const GroupMembersScreen({super.key, required this.groupId});

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final _service = CommunityGroupService();
  bool _busy = false;
  bool _exporting = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Faz 5 §5.4 — "premium grup admin araçları", gated on
  /// `Entitlements.exportData`. See `CommunityGroupService.exportMembersCsv`'s
  /// class-doc-adjacent comment for why this (not the existing, already-free
  /// kick/ban/mute tools) is the answer to that undefined-scope promise.
  Future<void> _exportMembers(String groupId, String groupName) async {
    if (_exporting) return;
    final l10n = AppLocalizations.of(context);
    if (!await FeatureGateService().check(
      context,
      (e) => e.exportData,
      featureName: l10n.translate('community.groups.export_paywall_title'),
      featureDescription:
          l10n.translate('community.groups.export_paywall_desc'),
    )) {
      return;
    }
    if (!mounted) return;

    setState(() => _exporting = true);
    try {
      final csv = await _service.exportMembersCsv(groupId);
      if (!mounted) return;
      await Share.share(csv, subject: '$groupName — Members Export');
      if (mounted) {
        AppSnackBar.show(context,
            message: l10n.translate('community.groups.export_success'),
            variant: AppSnackBarVariant.success);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context,
            message: l10n.translate('community.groups.export_error'),
            variant: AppSnackBarVariant.error);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      await action();
      unawaited(HapticFeedback.mediumImpact());
      if (mounted) {
        AppSnackBar.show(context,
            message:
                l10n.translate('community.groups.moderation.action_success'),
            variant: AppSnackBarVariant.success);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context,
            message: l10n.translate('community.groups.moderation.action_error'),
            variant: AppSnackBarVariant.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptReason(String title) {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    return AppSheet.show<String?>(
      context: context,
      title: title,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: ctrl,
              labelText:
                  l10n.translate('community.groups.moderation.reason_label'),
              hintText:
                  l10n.translate('community.groups.moderation.reason_hint'),
              maxLines: 3,
              minLines: 2,
            ),
            SizedBox(height: 14.h),
            AppButton(
              label: title,
              variant: AppButtonVariant.destructive,
              onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _muteFlow(
      String groupId, CommunityGroupMemberModel member) async {
    final l10n = AppLocalizations.of(context);
    Duration selected = const Duration(hours: 1);
    final ctrl = TextEditingController();

    final confirmed = await AppSheet.show<bool>(
      context: context,
      title: l10n.translate('community.groups.moderation.mute'),
      child: StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.translate('community.groups.moderation.duration_label'),
                  style: AppText.of(context)
                      .labelM
                      .copyWith(color: AppPalette.of(context).textSecondary)),
              SizedBox(height: 8.h),
              AppChipPicker<Duration>(
                options: [
                  AppChipOption(
                      value: const Duration(hours: 1),
                      label: l10n.translate(
                          'community.groups.moderation.duration_1h')),
                  AppChipOption(
                      value: const Duration(days: 1),
                      label: l10n.translate(
                          'community.groups.moderation.duration_1d')),
                  AppChipOption(
                      value: const Duration(days: 7),
                      label: l10n.translate(
                          'community.groups.moderation.duration_7d')),
                  AppChipOption(
                      value: const Duration(days: 30),
                      label: l10n.translate(
                          'community.groups.moderation.duration_30d')),
                ],
                selected: {selected},
                onToggle: (v) => setSheet(() => selected = v),
              ),
              SizedBox(height: 14.h),
              AppTextField(
                controller: ctrl,
                labelText:
                    l10n.translate('community.groups.moderation.reason_label'),
                hintText:
                    l10n.translate('community.groups.moderation.reason_hint'),
                maxLines: 3,
                minLines: 2,
              ),
              SizedBox(height: 14.h),
              AppButton(
                label: l10n.translate('community.groups.moderation.mute'),
                variant: AppButtonVariant.destructive,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    final reason = ctrl.text.trim();
    await _run(() => _service.muteMember(
          groupId,
          member.uid,
          duration: selected,
          reason: reason.isEmpty ? null : reason,
        ));
  }

  Future<void> _kickFlow(
      String groupId, CommunityGroupMemberModel member) async {
    final l10n = AppLocalizations.of(context);
    final reason =
        await _promptReason(l10n.translate('community.groups.moderation.kick'));
    if (reason == null) return;
    await _run(() => _service.kickMember(groupId, member.uid,
        reason: reason.isEmpty ? null : reason));
  }

  Future<void> _banFlow(
      String groupId, CommunityGroupMemberModel member) async {
    final l10n = AppLocalizations.of(context);
    final reason =
        await _promptReason(l10n.translate('community.groups.moderation.ban'));
    if (reason == null) return;
    await _run(() => _service.banMember(groupId, member.uid,
        reason: reason.isEmpty ? null : reason));
  }

  // Faz 2 §2.3/§2.6 — owner/admin side of the 'request' join_policy queue.
  // `CommunityGroupService.approveJoinRequest`/`declineJoinRequest` already
  // existed (rules-tested) but had no caller anywhere in the app; both go
  // through `_run` exactly like kick/ban/mute above, so they share the same
  // busy-guard + haptic + generic success/error snackbar. Unlike ban/kick,
  // declining needs no reason prompt — the service method takes none, and
  // it's a reversible, non-punitive outcome (the requester can just ask
  // again).
  Future<void> _approveRequest(String groupId, GroupJoinRequestModel req) =>
      _run(() => _service.approveJoinRequest(groupId, req.uid));

  Future<void> _declineRequest(String groupId, GroupJoinRequestModel req) =>
      _run(() => _service.declineJoinRequest(groupId, req.uid));

  Future<void> _showActionsSheet(
    CommunityGroupModel group,
    CommunityGroupMemberModel member,
  ) async {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);

    await AppSheet.show<void>(
      context: context,
      title: member.displayName ??
          l10n.translate('community.groups.moderation.member_fallback'),
      child: Padding(
        padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (member.banned)
              _ActionTile(
                icon: Icons.lock_open_rounded,
                label: l10n.translate('community.groups.moderation.unban'),
                color: palette.success,
                onTap: () {
                  Navigator.of(context).pop();
                  _run(() => _service.unbanMember(group.id, member.uid));
                },
              )
            else ...[
              _ActionTile(
                icon: Icons.block_rounded,
                label: l10n.translate('community.groups.moderation.ban'),
                color: palette.error,
                onTap: () {
                  Navigator.of(context).pop();
                  _banFlow(group.id, member);
                },
              ),
              // Kicking an already-banned member would DELETE their member
              // doc entirely — erasing the `banned` flag and letting them
              // rejoin via the open-join path if the group allows it. Only
              // offer Kick when NOT already banned, so this screen can't be
              // used to accidentally undo a ban via kick.
              _ActionTile(
                icon: Icons.person_remove_rounded,
                label: l10n.translate('community.groups.moderation.kick'),
                color: palette.error,
                onTap: () {
                  Navigator.of(context).pop();
                  _kickFlow(group.id, member);
                },
              ),
              if (member.isMuted)
                _ActionTile(
                  icon: Icons.volume_up_rounded,
                  label: l10n.translate('community.groups.moderation.unmute'),
                  color: palette.success,
                  onTap: () {
                    Navigator.of(context).pop();
                    _run(() => _service.unmuteMember(group.id, member.uid));
                  },
                )
              else
                _ActionTile(
                  icon: Icons.volume_off_rounded,
                  label: l10n.translate('community.groups.moderation.mute'),
                  color: palette.warning,
                  onTap: () {
                    Navigator.of(context).pop();
                    _muteFlow(group.id, member);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showHistorySheet(String groupId) async {
    final l10n = AppLocalizations.of(context);
    await AppSheet.show<void>(
      context: context,
      title: l10n.translate('community.groups.moderation.history_title'),
      child: SizedBox(
        height: 420.h,
        child: StreamBuilder<List<GroupModerationActionModel>>(
          stream: _service.getModerationLogStream(groupId),
          builder: (context, snap) {
            final items = snap.data ?? const <GroupModerationActionModel>[];
            if (snap.connectionState == ConnectionState.waiting) {
              return const AppSkeletonList(itemCount: 3);
            }
            if (items.isEmpty) {
              return AppEmptyState(
                icon: Icons.history_rounded,
                title:
                    l10n.translate('community.groups.moderation.history_empty'),
                compact: true,
              );
            }
            return ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(height: 8.h),
              itemBuilder: (context, i) => _HistoryRow(entry: items[i]),
            );
          },
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  /// Shared by both the plain member `ListView.separated` and the combined
  /// pending-requests-then-members `ListView` below — one row-building
  /// codepath so `showActions`'s self/owner exclusion can't drift between
  /// the two.
  Widget _buildMemberRow(
    CommunityGroupModel group,
    CommunityGroupMemberModel member,
    bool canManage,
  ) {
    final isSelf = member.uid == _uid;
    final showActions =
        canManage && !isSelf && member.role != GroupMemberRole.owner;
    return _MemberRow(
      member: member,
      isSelf: isSelf,
      onMorePressed:
          showActions ? () => _showActionsSheet(group, member) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final isSiteAdmin = context.watch<UserProvider>().isAdmin;

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
        title:
            Text(l10n.translate('community.groups.members'), style: t.titleL),
      ),
      body: StreamBuilder<CommunityGroupModel?>(
        stream: _service.getGroupStream(widget.groupId),
        builder: (context, groupSnap) {
          final group = groupSnap.data;
          if (groupSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (group == null) {
            return AppErrorState(
                title: l10n.translate('community.groups.not_found'));
          }

          return StreamBuilder<List<CommunityGroupMemberModel>>(
            stream: _service.getMembersStream(widget.groupId),
            builder: (context, memSnap) {
              if (memSnap.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: EdgeInsets.all(16.w),
                  child: const AppSkeletonList(),
                );
              }
              final members =
                  memSnap.data ?? const <CommunityGroupMemberModel>[];
              CommunityGroupMemberModel? me;
              for (final m in members) {
                if (m.uid == _uid) me = m;
              }
              final isOwner = group.ownerUid == _uid;
              final isGroupAdmin = me?.role == GroupMemberRole.admin;
              final canManage = isOwner || isGroupAdmin || isSiteAdmin;
              // The pending-requests queue only exists (and is only ever
              // non-empty) for a 'request'-join_policy group — showing it
              // unconditionally for every owner/admin on every group
              // (open/invite alike) would just be a permanently empty
              // section cluttering the far more common case.
              final showRequests =
                  canManage && group.joinPolicy == GroupJoinPolicy.request;

              return Column(
                children: [
                  if (canManage)
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Faz 5 §5.4 — premium "group admin tools" answer
                          // (Entitlements.exportData); see
                          // CommunityGroupService.exportMembersCsv.
                          _exporting
                              ? SizedBox(
                                  width: 18.r,
                                  height: 18.r,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: palette.textSecondary),
                                )
                              : TextButton.icon(
                                  onPressed: () => _exportMembers(
                                      widget.groupId, group.name),
                                  icon: Icon(Icons.ios_share_rounded,
                                      size: 18.r, color: palette.textSecondary),
                                  label: Text(
                                    l10n.translate(
                                        'community.groups.export_csv'),
                                    style: t.labelM
                                        .copyWith(color: palette.textSecondary),
                                  ),
                                ),
                          SizedBox(width: 4.w),
                          TextButton.icon(
                            onPressed: () => _showHistorySheet(widget.groupId),
                            icon: Icon(Icons.history_rounded,
                                size: 18.r, color: palette.textSecondary),
                            label: Text(
                              l10n.translate(
                                  'community.groups.moderation.history_title'),
                              style: t.labelM
                                  .copyWith(color: palette.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: !showRequests
                        ? (members.isEmpty
                            ? AppEmptyState(
                                icon: Icons.groups_outlined,
                                title:
                                    l10n.translate('community.groups.members'),
                              )
                            : ListView.separated(
                                padding:
                                    EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
                                itemCount: members.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: 8.h),
                                itemBuilder: (context, i) => _buildMemberRow(
                                    group, members[i], canManage),
                              ))
                        // Owner/admin of a 'request'-policy group: pending
                        // queue first, member list below, in ONE combined
                        // scroll (never two independently-scrolling lists
                        // stacked in a Column) so an arbitrarily long queue
                        // — capped at 100 by getPendingJoinRequestsStream
                        // itself — can never overflow or squeeze the member
                        // list out.
                        : StreamBuilder<List<GroupJoinRequestModel>>(
                            stream: _service
                                .getPendingJoinRequestsStream(widget.groupId),
                            builder: (context, reqSnap) {
                              final loadingRequests = reqSnap.connectionState ==
                                  ConnectionState.waiting;
                              final requests = reqSnap.data ??
                                  const <GroupJoinRequestModel>[];
                              return ListView(
                                padding:
                                    EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
                                children: [
                                  _SectionHeader(
                                    title: l10n.translate(
                                        'community.groups.moderation.pending_requests_title'),
                                    count: loadingRequests
                                        ? null
                                        : requests.length,
                                  ),
                                  SizedBox(height: 8.h),
                                  if (loadingRequests)
                                    const AppSkeletonList(itemCount: 2)
                                  else if (requests.isEmpty)
                                    AppEmptyState(
                                      compact: true,
                                      icon: Icons.person_add_alt_1_outlined,
                                      title: l10n.translate(
                                          'community.groups.moderation.pending_requests_empty'),
                                      message: l10n.translate(
                                          'community.groups.moderation.pending_requests_empty_desc'),
                                    )
                                  else
                                    for (final req in requests) ...[
                                      _PendingRequestCard(
                                        request: req,
                                        onApprove: () =>
                                            _approveRequest(group.id, req),
                                        onDecline: () =>
                                            _declineRequest(group.id, req),
                                      ),
                                      SizedBox(height: 8.h),
                                    ],
                                  SizedBox(height: 16.h),
                                  _SectionHeader(
                                    title: l10n
                                        .translate('community.groups.members'),
                                    count: members.length,
                                  ),
                                  SizedBox(height: 8.h),
                                  if (members.isEmpty)
                                    AppEmptyState(
                                      compact: true,
                                      icon: Icons.groups_outlined,
                                      title: l10n.translate(
                                          'community.groups.members'),
                                    )
                                  else
                                    for (final member in members) ...[
                                      _buildMemberRow(group, member, canManage),
                                      SizedBox(height: 8.h),
                                    ],
                                ],
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final CommunityGroupMemberModel member;
  final bool isSelf;
  final VoidCallback? onMorePressed;

  const _MemberRow({
    required this.member,
    required this.isSelf,
    this.onMorePressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    return AppCard(
      child: Row(
        children: [
          AppInitialsAvatar(
            photoUrl: member.photoURL,
            name: member.displayName ?? '?',
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.displayName ??
                            l10n.translate(
                                'community.groups.moderation.member_fallback'),
                        style: t.bodyM.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelf) ...[
                      SizedBox(width: 6.w),
                      Text(
                          '· ${l10n.translate('community.groups.moderation.you')}',
                          style:
                              t.labelS.copyWith(color: palette.textTertiary)),
                    ],
                  ],
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    _RoleBadge(role: member.role),
                    if (member.banned) ...[
                      SizedBox(width: 6.w),
                      _StatusChip(
                        label: l10n.translate(
                            'community.groups.moderation.banned_badge'),
                        color: palette.error,
                      ),
                    ] else if (member.isMuted) ...[
                      SizedBox(width: 6.w),
                      _StatusChip(
                        label: l10n.translate(
                            'community.groups.moderation.muted_badge'),
                        color: palette.warning,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (onMorePressed != null)
            IconButton(
              icon: Icon(Icons.more_vert_rounded, color: palette.textSecondary),
              onPressed: onMorePressed,
            ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final GroupMemberRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    if (role == GroupMemberRole.member) return const SizedBox.shrink();
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final color = switch (role) {
      GroupMemberRole.owner => palette.info,
      GroupMemberRole.admin => Theme.of(context).primaryColor,
      GroupMemberRole.moderator => palette.warning,
      GroupMemberRole.member => palette.textTertiary,
    };
    return _StatusChip(
      label: l10n.translate('community.groups.moderation.role_${role.value}'),
      color: color,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full.r),
      ),
      child: Text(label,
          style: t.labelS.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label,
          style: t.bodyM.copyWith(color: color, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final GroupModerationActionModel entry;
  const _HistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    return AppCard(
      padding: EdgeInsets.all(10.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.translate(
                      'community.groups.moderation.action_${entry.action.value}'),
                  style: t.labelM.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (entry.durationMinutes != null)
                Text(
                  l10n
                      .translate('community.groups.moderation.duration_minutes')
                      .replaceAll('{n}', '${entry.durationMinutes}'),
                  style: t.labelS.copyWith(color: palette.textTertiary),
                ),
            ],
          ),
          if (entry.reason != null && entry.reason!.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(entry.reason!,
                style: t.bodyM.copyWith(color: palette.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          SizedBox(height: 4.h),
          Text(
            DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
                .add_Hm()
                .format(entry.createdAt),
            style: t.labelS.copyWith(color: palette.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// "Title (count)" row — separates the pending-requests queue from the
/// member list when both share one scroll (see `showRequests` in `build`).
class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;

  const _SectionHeader({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final primary = Theme.of(context).primaryColor;
    return Row(
      children: [
        Text(title, style: t.titleM.copyWith(fontWeight: FontWeight.w700)),
        if (count != null) ...[
          SizedBox(width: 6.w),
          _StatusChip(label: '$count', color: primary),
        ],
      ],
    );
  }
}

/// One pending `join_requests/{uid}` doc — owner/admin Approve/Decline.
/// Faz 2 §2.3/§2.6: `CommunityGroupService.approveJoinRequest`/
/// `declineJoinRequest` already existed, rules-tested, but had no caller
/// anywhere in the app until this card's buttons.
class _PendingRequestCard extends StatelessWidget {
  final GroupJoinRequestModel request;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  const _PendingRequestCard({
    required this.request,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppInitialsAvatar(
                photoUrl: request.photoURL,
                name: request.displayName ?? '?',
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.displayName ??
                          l10n.translate(
                              'community.groups.moderation.member_fallback'),
                      style: t.bodyM.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      DateFormat.yMMMd(
                              Localizations.localeOf(context).languageCode)
                          .add_Hm()
                          .format(request.requestedAt),
                      style: t.labelS.copyWith(color: palette.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (request.message != null && request.message!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: palette.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.sm.r),
              ),
              child: Text(
                request.message!,
                style: t.bodyM.copyWith(
                  color: palette.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.translate('community.groups.moderation.decline'),
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: onDecline,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: AppButton(
                  label: l10n.translate('community.groups.moderation.approve'),
                  size: AppButtonSize.small,
                  onPressed: onApprove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
