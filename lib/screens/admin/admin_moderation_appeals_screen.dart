import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/community_group_model.dart'
    show GroupModerationActionX;
import '../../core/models/moderation_appeal_model.dart';
import '../../core/services/admin_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Faz 2 §2.6 admin queue for moderation appeals — mirrors
/// `AdminPrivacyRequestsScreen` (same DSAR-style review pattern). Resolving
/// as "upheld" also reverses a mute/ban via `AdminService
/// .resolveModerationAppeal` and always notifies the appellant.
class AdminModerationAppealsScreen extends StatelessWidget {
  const AdminModerationAppealsScreen({super.key});

  Color _statusColor(ModerationAppealStatus s, AppPalette p) => switch (s) {
        ModerationAppealStatus.pending => p.warning,
        ModerationAppealStatus.upheld => p.success,
        ModerationAppealStatus.denied => p.error,
      };

  // Faz 5 §5.2: `appeal.action.value` is a meaningless placeholder for a
  // credit-restriction appeal (see ModerationAppealModel's doc comment) —
  // branch on `isCreditRestriction`/`rawAction` for the correct label.
  String _actionLabelKey(ModerationAppealModel appeal) =>
      appeal.isCreditRestriction
          ? 'moderation_appeal.action_credit_restriction'
          : 'community.groups.moderation.action_${appeal.action.value}';

  Future<void> _resolve(
      BuildContext context, ModerationAppealModel appeal) async {
    final l10n = AppLocalizations.of(context);
    final noteCtrl = TextEditingController();
    ModerationAppealStatus selected = ModerationAppealStatus.upheld;

    await AppSheet.show<void>(
      context: context,
      title: l10n.translate(_actionLabelKey(appeal)),
      child: StatefulBuilder(
        builder: (context, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(appeal.message,
                style: AppText.of(context)
                    .bodyM
                    .copyWith(color: AppPalette.of(context).textSecondary)),
            SizedBox(height: 14.h),
            AppChipPicker<ModerationAppealStatus>(
              options: [
                AppChipOption(
                    value: ModerationAppealStatus.upheld,
                    label: l10n.translate('moderation_appeal.status.upheld')),
                AppChipOption(
                    value: ModerationAppealStatus.denied,
                    label: l10n.translate('moderation_appeal.status.denied')),
              ],
              selected: {selected},
              onToggle: (v) => setSheet(() => selected = v),
            ),
            SizedBox(height: 14.h),
            AppTextField(
              controller: noteCtrl,
              labelText: l10n.translate('admin.moderation_appeal_note'),
              hintText: l10n.translate('admin.moderation_appeal_note_hint'),
              maxLines: 3,
              minLines: 2,
            ),
            SizedBox(height: 16.h),
            AppButton(
              label: l10n.translate('common.save'),
              onPressed: () async {
                final upheld = selected == ModerationAppealStatus.upheld;
                await AdminService().resolveModerationAppeal(
                  appeal,
                  selected,
                  adminNote: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                  notifyTitle: l10n.translate(upheld
                      ? 'admin.moderation_appeal_notify_upheld_title'
                      : 'admin.moderation_appeal_notify_denied_title'),
                  // Faz 5 §5.2: a credit-restriction appeal has no group at
                  // all (groupName is always '') — a separate, group-free
                  // notify body rather than interpolating an empty string
                  // into the existing group-shaped message.
                  notifyBody: appeal.isCreditRestriction
                      ? l10n.translate(upheld
                          ? 'admin.credit_restriction_appeal_notify_upheld_body'
                          : 'admin.credit_restriction_appeal_notify_denied_body')
                      : l10n.translate(
                          upheld
                              ? 'admin.moderation_appeal_notify_upheld_body'
                              : 'admin.moderation_appeal_notify_denied_body',
                          variables: {'group': appeal.groupName},
                        ),
                );
                if (context.mounted) Navigator.of(context).pop();
              },
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

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: palette.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title:
            Text(l10n.translate('admin.moderation_appeals'), style: t.titleL),
      ),
      body: StreamBuilder<List<ModerationAppealModel>>(
        stream: AdminService().pendingModerationAppealsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: EdgeInsets.all(20.w),
              child: const AppSkeletonList(itemCount: 4),
            );
          }
          if (snap.hasError) {
            return AppErrorState(title: l10n.translate('errors.general'));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return AppEmptyState(
              icon: Icons.gavel_outlined,
              title: l10n.translate('admin.moderation_appeals_empty'),
              message: l10n.translate('admin.moderation_appeals_empty_desc'),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 32.h),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, i) {
              final a = items[i];
              final statusColor = _statusColor(a.status, palette);
              return AppCard(
                onTap: () => _resolve(context, a),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.translate(_actionLabelKey(a)),
                            style:
                                t.titleM.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.full.r),
                          ),
                          child: Text(l10n.translate(a.status.labelKey),
                              style: t.labelS.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    // Faz 5 §5.2: a credit-restriction appeal has no group
                    // at all — groupName is always '', so skip the row
                    // instead of rendering a blank line.
                    if (a.groupName.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(a.groupName,
                          style:
                              t.labelM.copyWith(color: palette.textSecondary)),
                    ],
                    if (a.message.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Text(a.message,
                          style: t.bodyM.copyWith(color: palette.textSecondary),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis),
                    ],
                    if (a.createdAt != null) ...[
                      SizedBox(height: 8.h),
                      Text(
                        DateFormat.yMMMd(
                                Localizations.localeOf(context).languageCode)
                            .add_Hm()
                            .format(a.createdAt!),
                        style: t.labelS.copyWith(color: palette.textTertiary),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
