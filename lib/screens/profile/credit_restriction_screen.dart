import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/credit_restriction_model.dart';
import '../../core/models/moderation_appeal_model.dart';
import '../../core/services/engagement_credit_service.dart';
import '../../core/services/moderation_appeal_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Faz 5 §5.2 — this account's shadow-restriction state for the received-
/// engagement credit system. Being restricted has NO effect on this
/// account's own posts/comments being visible to anyone else — it only
/// means received-engagement credit has stopped accumulating (see
/// `CreditRestrictionModel`'s doc comment). When restricted, offers a real
/// appeal path that reuses Faz 2 §2.6's exact `moderation_appeals`
/// mechanism end to end (same collection, same admin review queue, same
/// pending/upheld/denied lifecycle, same rate limiter) — see
/// `ModerationAppealService.fileCreditRestrictionAppeal` and
/// `AdminService.resolveModerationAppeal`'s credit-restriction branch.
///
/// Mirrors `ModerationAppealScreen`'s shape deliberately (same DS
/// components, same sheet-based filing flow) — always shown from Settings,
/// same "good standing" vs "restricted" split `ModerationAppealScreen`
/// makes between "none" and "has history".
class CreditRestrictionScreen extends StatefulWidget {
  const CreditRestrictionScreen({super.key});

  @override
  State<CreditRestrictionScreen> createState() =>
      _CreditRestrictionScreenState();
}

class _CreditRestrictionScreenState extends State<CreditRestrictionScreen> {
  final _service = EngagementCreditService();
  final _appealService = ModerationAppealService();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _fileAppeal(String entryId) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();

    final submitted = await AppSheet.show<bool>(
      context: context,
      title: l10n.translate('credit_restriction.appeal_title'),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.translate('credit_restriction.appeal_intro'),
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
      await _appealService.fileCreditRestrictionAppeal(
        creditModerationEntryId: entryId,
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
        title:
            Text(l10n.translate('credit_restriction.title'), style: t.titleL),
      ),
      body: StreamBuilder<CreditRestrictionModel>(
        stream: _service.watchRestrictionState(_uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: EdgeInsets.all(20.w),
              child: const AppSkeletonList(itemCount: 1),
            );
          }
          final state = snap.data ?? const CreditRestrictionModel();

          if (!state.isShadowRestricted) {
            return ListView(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
              children: [
                AppEmptyState(
                  icon: Icons.verified_outlined,
                  title:
                      l10n.translate('credit_restriction.good_standing_title'),
                  message:
                      l10n.translate('credit_restriction.good_standing_desc'),
                  compact: true,
                ),
              ],
            );
          }

          final entryId = state.latestEntryId;
          return ListView(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
            children: [
              AppGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, color: palette.warning),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            l10n.translate(
                                'credit_restriction.restricted_title'),
                            style:
                                t.titleM.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      l10n.translate('credit_restriction.restricted_desc'),
                      style: t.bodyM
                          .copyWith(color: palette.textSecondary, height: 1.5),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              if (entryId != null)
                StreamBuilder<ModerationAppealModel?>(
                  stream: _appealService.watchAppeal(entryId),
                  builder: (context, appealSnap) {
                    final appeal = appealSnap.data;
                    if (appeal == null) {
                      return AppButton(
                        label: l10n.translate('moderation_appeal.appeal_cta'),
                        onPressed: () => _fileAppeal(entryId),
                      );
                    }
                    final color = switch (appeal.status) {
                      ModerationAppealStatus.pending => palette.warning,
                      ModerationAppealStatus.upheld => palette.success,
                      ModerationAppealStatus.denied => palette.error,
                    };
                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full.r),
                            ),
                            child: Text(l10n.translate(appeal.status.labelKey),
                                style: t.labelS.copyWith(
                                    color: color, fontWeight: FontWeight.w700)),
                          ),
                          if (appeal.adminNote != null &&
                              appeal.adminNote!.isNotEmpty) ...[
                            SizedBox(height: 6.h),
                            Text(
                              l10n.translate(
                                  'moderation_appeal.admin_note_label'),
                              style: t.labelS
                                  .copyWith(color: palette.textTertiary),
                            ),
                            Text(appeal.adminNote!,
                                style: t.bodyM
                                    .copyWith(color: palette.textSecondary)),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
