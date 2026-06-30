import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/consent_model.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/consent_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'package:provider/provider.dart';
import '../legal/legal_screen.dart';

/// Single, auditable surface where the user grants/withdraws each consent.
/// Decisions are recorded (timestamp + policy version) via [ConsentService]
/// for KVKK/GDPR accountability.
class ConsentCenterScreen extends StatefulWidget {
  const ConsentCenterScreen({super.key});

  @override
  State<ConsentCenterScreen> createState() => _ConsentCenterScreenState();
}

class _ConsentCenterScreenState extends State<ConsentCenterScreen> {
  final _service = ConsentService();
  final _saving = <ConsentPurpose>{};

  IconData _icon(ConsentPurpose p) => switch (p) {
        ConsentPurpose.healthData => Icons.favorite_rounded,
        ConsentPurpose.location => Icons.location_on_rounded,
        ConsentPurpose.aiProcessing => Icons.auto_awesome_rounded,
        ConsentPurpose.crossBorderTransfer => Icons.public_rounded,
        ConsentPurpose.analytics => Icons.bar_chart_rounded,
        ConsentPurpose.notifications => Icons.notifications_rounded,
        ConsentPurpose.marketing => Icons.campaign_rounded,
      };

  Future<void> _toggle(ConsentModel current, bool next) async {
    if (_saving.contains(current.purpose)) return;
    final l10n = AppLocalizations.of(context);

    // Withdrawing a sensitive consent asks for confirmation.
    if (!next && current.purpose.isSensitive && current.granted) {
      final confirmed = await _confirmWithdraw(l10n);
      if (confirmed != true) return;
    }

    unawaited(HapticFeedback.selectionClick());
    setState(() => _saving.add(current.purpose));
    try {
      await _service.setConsent(current.purpose, next);
      if (!mounted) return;
      AppSnackBar.success(context, l10n.translate('consent.saved'));
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, l10n.translate('consent.save_error'));
    } finally {
      if (mounted) setState(() => _saving.remove(current.purpose));
    }
  }

  Future<bool?> _confirmWithdraw(AppLocalizations l10n) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return AppSheet.show<bool>(
      context: context,
      title: l10n.translate('consent.withdraw_title'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.translate('consent.withdraw_body'),
            style: t.bodyM.copyWith(color: palette.textSecondary, height: 1.5),
          ),
          SizedBox(height: 20.h),
          AppButton(
            label: l10n.translate('consent.confirm_withdraw'),
            variant: AppButtonVariant.destructive,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          SizedBox(height: 8.h),
          AppButton(
            label: l10n.translate('common.cancel'),
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  void _openDocuments() {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    const docs = [
      (LegalDocumentType.privacyPolicy, 'legal.privacy_title'),
      (LegalDocumentType.termsOfUse, 'legal.terms_title'),
      (LegalDocumentType.kvkkClarification, 'legal.kvkk_title'),
      (LegalDocumentType.explicitConsent, 'legal.consent_title'),
    ];
    AppSheet.show<void>(
      context: context,
      title: l10n.translate('consent.view_documents'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (type, key) in docs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.description_outlined,
                  color: palette.textSecondary),
              title: Text(l10n.translate(key), style: t.bodyL),
              trailing: Icon(Icons.chevron_right, color: palette.textTertiary),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LegalScreen(type: type),
                ));
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: palette.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.translate('consent.title'), style: t.titleL),
      ),
      body: StreamBuilder<Map<ConsentPurpose, ConsentModel>>(
        stream: _service.watchConsents(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: EdgeInsets.all(20.w),
              child: const AppSkeletonList(itemCount: 7),
            );
          }
          if (snap.hasError) {
            return AppErrorState(title: l10n.translate('errors.general'));
          }
          final consents = snap.data ?? {};
          return ListView(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
            children: [
              _header(l10n, palette, t),
              SizedBox(height: 16.h),
              for (final purpose in ConsentPurpose.values)
                Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: _ConsentCard(
                    model: consents[purpose] ?? ConsentModel.unset(purpose),
                    icon: _icon(purpose),
                    saving: _saving.contains(purpose),
                    onChanged: (v) => _toggle(
                        consents[purpose] ?? ConsentModel.unset(purpose), v),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(AppLocalizations l10n, AppPalette palette, AppText t) {
    final primary = context.watch<ThemeProvider>().primaryColor;
    return AppGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm.r),
                ),
                child: Icon(Icons.shield_rounded, color: primary, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  l10n.translate('consent.header_title'),
                  style: t.titleM.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            l10n.translate('consent.header_body'),
            style: t.bodyM.copyWith(color: palette.textSecondary, height: 1.5),
          ),
          SizedBox(height: 12.h),
          GestureDetector(
            onTap: _openDocuments,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_rounded, size: 16.sp, color: primary),
                SizedBox(width: 6.w),
                Text(
                  l10n.translate('consent.view_documents'),
                  style: t.labelM
                      .copyWith(color: primary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  final ConsentModel model;
  final IconData icon;
  final bool saving;
  final ValueChanged<bool> onChanged;

  const _ConsentCard({
    required this.model,
    required this.icon,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final p = model.purpose;

    final statusColor = model.isUnset
        ? palette.textTertiary
        : (model.granted ? palette.success : palette.textSecondary);
    final statusText = model.isUnset
        ? l10n.translate('consent.not_set')
        : (model.granted
            ? l10n.translate('consent.granted')
            : l10n.translate('consent.withdrawn'));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38.r,
                height: 38.r,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm.r),
                ),
                child: Icon(icon, color: statusColor, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate(p.titleKey),
                      style: t.titleM.copyWith(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      l10n.translate(p.descKey),
                      style: t.bodyM
                          .copyWith(color: palette.textSecondary, height: 1.45),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              SizedBox(
                width: 52.w,
                child: Align(
                  alignment: Alignment.topRight,
                  child: saving
                      ? SizedBox(
                          width: 20.r,
                          height: 20.r,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                                context.read<ThemeProvider>().primaryColor),
                          ),
                        )
                      : AppToggle(
                          value: model.granted,
                          onChanged: onChanged,
                        ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full.r),
                ),
                child: Text(
                  statusText,
                  style: t.labelS.copyWith(
                      color: statusColor, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(width: 8.w),
              if (!model.isUnset && model.updatedAt != null)
                Expanded(
                  child: Text(
                    l10n.translate('consent.updated_on', variables: {
                      'date': DateFormat.yMMMd(
                              Localizations.localeOf(context).languageCode)
                          .format(model.updatedAt!),
                    }),
                    style: t.labelS.copyWith(color: palette.textTertiary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          if (model.isStale) ...[
            SizedBox(height: 8.h),
            _note(context, palette.warning, Icons.info_outline_rounded,
                l10n.translate('consent.needs_review_note')),
          ] else if (p.isSensitive) ...[
            SizedBox(height: 8.h),
            _note(context, palette.textTertiary, Icons.lock_outline_rounded,
                l10n.translate('consent.required_note')),
          ],
        ],
      ),
    );
  }

  Widget _note(BuildContext context, Color color, IconData icon, String text) {
    final t = AppText.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14.sp, color: color),
        SizedBox(width: 6.w),
        Expanded(
          child:
              Text(text, style: t.labelS.copyWith(color: color, height: 1.4)),
        ),
      ],
    );
  }
}
