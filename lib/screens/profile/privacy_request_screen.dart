import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/privacy_request_model.dart';
import '../../core/services/privacy_request_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Data-subject request (DSAR) channel — file and track privacy requests.
class PrivacyRequestScreen extends StatefulWidget {
  const PrivacyRequestScreen({super.key});

  @override
  State<PrivacyRequestScreen> createState() => _PrivacyRequestScreenState();
}

class _PrivacyRequestScreenState extends State<PrivacyRequestScreen> {
  final _service = PrivacyRequestService();
  final _messageCtrl = TextEditingController();
  PrivacyRequestType _type = PrivacyRequestType.access;
  bool _submitting = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await _service.submit(_type, _messageCtrl.text);
      if (!mounted) return;
      _messageCtrl.clear();
      unawaited(HapticFeedback.mediumImpact());
      AppSnackBar.success(context, l10n.translate('privacy_request.submitted'));
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, l10n.translate('privacy_request.submit_error'));
    } finally {
      if (mounted) setState(() => _submitting = false);
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
        title: Text(l10n.translate('privacy_request.title'), style: t.titleL),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
        children: [
          AppGlassCard(
            child: Text(
              l10n.translate('privacy_request.intro'),
              style: t.bodyM.copyWith(color: palette.textSecondary, height: 1.5),
            ),
          ),
          SizedBox(height: 20.h),

          // ── New request form ──────────────────────────────────────────────
          Text(l10n.translate('privacy_request.new'),
              style: t.titleM.copyWith(fontWeight: FontWeight.w800)),
          SizedBox(height: 10.h),
          Text(l10n.translate('privacy_request.choose_type'),
              style: t.labelM.copyWith(color: palette.textSecondary)),
          SizedBox(height: 8.h),
          AppChipPicker<PrivacyRequestType>(
            options: [
              for (final type in PrivacyRequestType.values)
                AppChipOption(
                  value: type,
                  label: l10n.translate(type.titleKey),
                ),
            ],
            selected: {_type},
            onToggle: (v) => setState(() => _type = v),
          ),
          SizedBox(height: 16.h),
          AppTextField(
            controller: _messageCtrl,
            labelText: l10n.translate('privacy_request.message_label'),
            hintText: l10n.translate('privacy_request.message_hint'),
            maxLines: 4,
            minLines: 3,
          ),
          SizedBox(height: 16.h),
          AppButton(
            label: l10n.translate('privacy_request.submit'),
            onPressed: _submitting ? null : _submit,
            loading: _submitting,
            icon: Icons.send_rounded,
          ),

          SizedBox(height: 28.h),

          // ── My requests ───────────────────────────────────────────────────
          Text(l10n.translate('privacy_request.my_requests'),
              style: t.titleM.copyWith(fontWeight: FontWeight.w800)),
          SizedBox(height: 12.h),
          StreamBuilder<List<PrivacyRequestModel>>(
            stream: _service.myRequestsStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const AppSkeletonList(itemCount: 2);
              }
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return AppEmptyState(
                  icon: Icons.shield_outlined,
                  title: l10n.translate('privacy_request.none'),
                  message: l10n.translate('privacy_request.none_desc'),
                  compact: true,
                );
              }
              return Column(
                children: [
                  for (final r in items)
                    Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: _RequestCard(request: r),
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

class _RequestCard extends StatelessWidget {
  final PrivacyRequestModel request;
  const _RequestCard({required this.request});

  Color _statusColor(AppPalette p) => switch (request.status) {
        PrivacyRequestStatus.pending => p.warning,
        PrivacyRequestStatus.inProgress => p.info,
        PrivacyRequestStatus.resolved => p.success,
        PrivacyRequestStatus.rejected => p.error,
      };

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final statusColor = _statusColor(palette);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.translate(request.type.titleKey),
                  style: t.titleM.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full.r),
                ),
                child: Text(
                  l10n.translate(request.status.labelKey),
                  style: t.labelS
                      .copyWith(color: statusColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (request.message.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(request.message,
                style: t.bodyM.copyWith(color: palette.textSecondary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
          if (request.createdAt != null) ...[
            SizedBox(height: 8.h),
            Text(
              l10n.translate('privacy_request.filed_on', variables: {
                'date': DateFormat.yMMMd(
                        Localizations.localeOf(context).languageCode)
                    .format(request.createdAt!),
              }),
              style: t.labelS.copyWith(color: palette.textTertiary),
            ),
          ],
          if (request.adminNote != null && request.adminNote!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: palette.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.sm.r),
              ),
              child: Text(request.adminNote!,
                  style: t.bodyM.copyWith(color: palette.textSecondary)),
            ),
          ],
        ],
      ),
    );
  }
}
