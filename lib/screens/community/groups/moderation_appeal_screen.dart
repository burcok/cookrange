import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/community_group_model.dart';
import '../../../core/models/moderation_appeal_model.dart';
import '../../../core/services/community_group_service.dart';
import '../../../core/services/moderation_appeal_service.dart';
import '../../../core/widgets/ds/ds.dart';

/// Faz 2 §2.6 — "itiraz yolu": a member's own moderation history across
/// every group, with an inline appeal path for anything appealable
/// (mute/kick/ban). Mirrors `PrivacyRequestScreen`'s shape deliberately (see
/// `docs/COMPLIANCE.md` §7 — this is the same DSAR-style "file your own
/// record, admin reviews later" pattern, just for a different kind of
/// grievance).
class ModerationAppealScreen extends StatefulWidget {
  const ModerationAppealScreen({super.key});

  @override
  State<ModerationAppealScreen> createState() => _ModerationAppealScreenState();
}

class _ModerationAppealScreenState extends State<ModerationAppealScreen> {
  final _groupService = CommunityGroupService();
  final _appealService = ModerationAppealService();

  // Caches the FUTURE itself (not just the resolved value) so a widget
  // rebuild (e.g. the outer StreamBuilder re-emitting) passes the SAME
  // Future instance back into FutureBuilder for an already-resolved
  // groupId — FutureBuilder resets to its "waiting" state on every new
  // Future identity, even when the eventual value is unchanged, so a plain
  // "cache the value, still call an async function inline" pattern would
  // still cause a brief flicker on every rebuild (R1).
  final Map<String, Future<CommunityGroupModel?>> _groupCache = {};

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _isAppealable(GroupModerationAction action) =>
      action == GroupModerationAction.mute ||
      action == GroupModerationAction.kick ||
      action == GroupModerationAction.ban;

  Future<CommunityGroupModel?> _resolveGroup(String groupId) {
    return _groupCache.putIfAbsent(
        groupId, () => _groupService.getGroupStream(groupId).first);
  }

  Future<void> _fileAppeal({
    required GroupModerationActionModel action,
    required String groupId,
    required String groupName,
  }) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();

    final submitted = await AppSheet.show<bool>(
      context: context,
      title: l10n.translate('moderation_appeal.title'),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.translate(
                  'community.groups.moderation.action_${action.action.value}'),
              style: AppText.of(context)
                  .titleM
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4.h),
            Text(
              action.reason?.isNotEmpty == true
                  ? '${l10n.translate('moderation_appeal.reason_from_moderator')}: ${action.reason}'
                  : l10n.translate('moderation_appeal.no_reason_given'),
              style: AppText.of(context)
                  .bodyM
                  .copyWith(color: AppPalette.of(context).textSecondary),
            ),
            SizedBox(height: 14.h),
            AppTextField(
              controller: ctrl,
              labelText: l10n.translate('moderation_appeal.message_label'),
              hintText: l10n.translate('moderation_appeal.message_hint'),
              maxLines: 4,
              minLines: 3,
            ),
            SizedBox(height: 16.h),
            AppButton(
              label: l10n.translate('moderation_appeal.submit'),
              onPressed: () => Navigator.of(context).pop(true),
              icon: Icons.send_rounded,
            ),
          ],
        ),
      ),
    );

    if (submitted != true) return;
    try {
      await _appealService.file(
        groupId: groupId,
        groupName: groupName,
        moderationActionId: action.id,
        action: action.action,
        message: ctrl.text,
      );
      if (mounted) {
        AppSnackBar.success(
            context, l10n.translate('moderation_appeal.submitted'));
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
            context, l10n.translate('moderation_appeal.submit_error'));
      }
    }
  }

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
          icon: Icon(Icons.arrow_back, color: palette.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.translate('moderation_appeal.title'), style: t.titleL),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
        children: [
          AppGlassCard(
            child: Text(
              l10n.translate('moderation_appeal.intro'),
              style:
                  t.bodyM.copyWith(color: palette.textSecondary, height: 1.5),
            ),
          ),
          SizedBox(height: 20.h),
          StreamBuilder<
              List<({GroupModerationActionModel action, String groupId})>>(
            stream: _groupService.getMyModerationHistoryStream(_uid),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const AppSkeletonList(itemCount: 2);
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return AppEmptyState(
                  icon: Icons.shield_outlined,
                  title: l10n.translate('moderation_appeal.none'),
                  message: l10n.translate('moderation_appeal.none_desc'),
                  compact: true,
                );
              }
              return Column(
                children: [
                  for (final item in items)
                    Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: FutureBuilder<CommunityGroupModel?>(
                        future: _resolveGroup(item.groupId),
                        builder: (context, groupSnap) {
                          final groupName = groupSnap.data?.name ?? '';
                          return _HistoryCard(
                            action: item.action,
                            groupName: groupName,
                            appealable: _isAppealable(item.action.action),
                            onAppeal: groupName.isEmpty
                                ? null
                                : () => _fileAppeal(
                                      action: item.action,
                                      groupId: item.groupId,
                                      groupName: groupName,
                                    ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final GroupModerationActionModel action;
  final String groupName;
  final bool appealable;
  final VoidCallback? onAppeal;

  const _HistoryCard({
    required this.action,
    required this.groupName,
    required this.appealable,
    required this.onAppeal,
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
            children: [
              Expanded(
                child: Text(
                  l10n.translate(
                      'community.groups.moderation.action_${action.action.value}'),
                  style: t.titleM.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(groupName,
                  style: t.labelM.copyWith(color: palette.textSecondary)),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            action.reason?.isNotEmpty == true
                ? action.reason!
                : l10n.translate('moderation_appeal.no_reason_given'),
            style: t.bodyM.copyWith(color: palette.textSecondary),
          ),
          SizedBox(height: 6.h),
          Text(
            DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
                .format(action.createdAt),
            style: t.labelS.copyWith(color: palette.textTertiary),
          ),
          if (appealable) ...[
            SizedBox(height: 10.h),
            StreamBuilder<ModerationAppealModel?>(
              stream: ModerationAppealService().watchAppeal(action.id),
              builder: (context, appealSnap) {
                final appeal = appealSnap.data;
                if (appeal == null) {
                  return AppButton(
                    label: l10n.translate('moderation_appeal.appeal_cta'),
                    size: AppButtonSize.small,
                    expand: false,
                    variant: AppButtonVariant.secondary,
                    onPressed: onAppeal,
                  );
                }
                final color = switch (appeal.status) {
                  ModerationAppealStatus.pending => palette.warning,
                  ModerationAppealStatus.upheld => palette.success,
                  ModerationAppealStatus.denied => palette.error,
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.full.r),
                      ),
                      child: Text(l10n.translate(appeal.status.labelKey),
                          style: t.labelS.copyWith(
                              color: color, fontWeight: FontWeight.w700)),
                    ),
                    if (appeal.adminNote != null &&
                        appeal.adminNote!.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Text(
                        l10n.translate('moderation_appeal.admin_note_label'),
                        style: t.labelS.copyWith(color: palette.textTertiary),
                      ),
                      Text(appeal.adminNote!,
                          style:
                              t.bodyM.copyWith(color: palette.textSecondary)),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
