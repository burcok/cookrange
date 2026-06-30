import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/privacy_request_model.dart';
import '../../core/services/admin_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Admin queue for data-subject (DSAR) requests — review and resolve within the
/// statutory period (KVKK 30 days / GDPR 1 month).
class AdminPrivacyRequestsScreen extends StatelessWidget {
  const AdminPrivacyRequestsScreen({super.key});

  Color _statusColor(PrivacyRequestStatus s, AppPalette p) => switch (s) {
        PrivacyRequestStatus.pending => p.warning,
        PrivacyRequestStatus.inProgress => p.info,
        PrivacyRequestStatus.resolved => p.success,
        PrivacyRequestStatus.rejected => p.error,
      };

  Future<void> _resolve(BuildContext context, PrivacyRequestModel req) async {
    final l10n = AppLocalizations.of(context);
    final noteCtrl = TextEditingController();
    PrivacyRequestStatus selected = PrivacyRequestStatus.resolved;

    await AppSheet.show<void>(
      context: context,
      title: l10n.translate(req.type.titleKey),
      child: StatefulBuilder(
        builder: (context, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppChipPicker<PrivacyRequestStatus>(
              options: [
                for (final s in PrivacyRequestStatus.values)
                  AppChipOption(value: s, label: l10n.translate(s.labelKey)),
              ],
              selected: {selected},
              onToggle: (v) => setSheet(() => selected = v),
            ),
            SizedBox(height: 14.h),
            AppTextField(
              controller: noteCtrl,
              labelText: l10n.translate('admin.privacy_note'),
              hintText: l10n.translate('admin.privacy_note_hint'),
              maxLines: 3,
              minLines: 2,
            ),
            SizedBox(height: 16.h),
            AppButton(
              label: l10n.translate('common.save'),
              onPressed: () async {
                await AdminService().updatePrivacyRequest(req, selected,
                    adminNote: noteCtrl.text.trim().isEmpty
                        ? null
                        : noteCtrl.text.trim());
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
        title: Text(l10n.translate('admin.privacy_requests'), style: t.titleL),
      ),
      body: StreamBuilder<List<PrivacyRequestModel>>(
        stream: AdminService().privacyRequestsStream(),
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
              icon: Icons.verified_user_outlined,
              title: l10n.translate('privacy_request.none'),
              message: l10n.translate('privacy_request.none_desc'),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 32.h),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, i) {
              final r = items[i];
              final statusColor = _statusColor(r.status, palette);
              return AppCard(
                onTap: () => _resolve(context, r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(l10n.translate(r.type.titleKey),
                              style: t.titleM
                                  .copyWith(fontWeight: FontWeight.w700)),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.full.r),
                          ),
                          child: Text(l10n.translate(r.status.labelKey),
                              style: t.labelS.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(r.email,
                        style: t.labelM.copyWith(color: palette.textSecondary)),
                    if (r.message.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Text(r.message,
                          style: t.bodyM.copyWith(color: palette.textSecondary),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis),
                    ],
                    if (r.createdAt != null) ...[
                      SizedBox(height: 8.h),
                      Text(
                        DateFormat.yMMMd(
                                Localizations.localeOf(context).languageCode)
                            .add_Hm()
                            .format(r.createdAt!),
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
