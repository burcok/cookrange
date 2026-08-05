import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/meal_plan_template_model.dart';
import '../../core/services/crashlytics_service.dart';
import '../../core/services/plan_offer_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Faz 3 §3.5 — final step of the send flow: "mesaj yaz → gönder". Sends via
/// `PlanOfferService.sendOffer`, which invokes the `sendPlanOffer` callable
/// once for every recipient in [recipientUids] (bulk send = one call, one
/// `plan_offer` doc per recipient server-side — not a client-side loop of N
/// separate calls).
class PlanOfferComposeScreen extends StatefulWidget {
  final MealPlanTemplate template;
  final List<String> recipientUids;
  final Map<String, String> recipientNames;

  const PlanOfferComposeScreen({
    super.key,
    required this.template,
    required this.recipientUids,
    required this.recipientNames,
  });

  @override
  State<PlanOfferComposeScreen> createState() => _PlanOfferComposeScreenState();
}

class _PlanOfferComposeScreenState extends State<PlanOfferComposeScreen> {
  static const _maxMessageLength = 500; // mirrors sendPlanOffer's own cap
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    final l10n = AppLocalizations.of(context);
    try {
      await PlanOfferService().sendOffer(
        templateId: widget.template.id,
        toUids: widget.recipientUids,
        message: _messageCtrl.text.trim(),
      );
      if (!mounted) return;
      AppSnackBar.success(
        context,
        l10n.translate('plan_offer.compose.send_success',
            variables: {'n': '${widget.recipientUids.length}'}),
      );
      Navigator.of(context)
        ..pop()
        ..pop(); // compose + recipient picker, back to the dashboard
    } on FirebaseFunctionsException catch (e, st) {
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'PlanOfferComposeScreen._send code=${e.code}'));
      if (!mounted) return;
      setState(() => _sending = false);
      AppSnackBar.error(context, _errorMessage(l10n, e));
    } catch (e, st) {
      unawaited(CrashlyticsService()
          .recordError(e, st, reason: 'PlanOfferComposeScreen._send'));
      if (!mounted) return;
      setState(() => _sending = false);
      AppSnackBar.error(
          context, l10n.translate('plan_offer.compose.send_error'));
    }
  }

  String _errorMessage(AppLocalizations l10n, FirebaseFunctionsException e) {
    if (e.message?.startsWith('recipient_not_eligible') ?? false) {
      return l10n.translate('plan_offer.compose.error_recipient_ineligible');
    }
    return l10n.translate('plan_offer.compose.send_error');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final names = widget.recipientNames.values
        .where((n) => n.isNotEmpty)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: Text(l10n.translate('plan_offer.compose.title'))),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.lg.r),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.menu_book_rounded,
                        size: 18.r, color: Theme.of(context).primaryColor),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        widget.template.name.isEmpty
                            ? l10n
                                .translate('template_builder.library.untitled')
                            : widget.template.name,
                        style: t.titleM,
                      ),
                    ),
                  ],
                ),
                if (widget.template.targetCalories > 0) ...[
                  SizedBox(height: 4.h),
                  Text('${widget.template.targetCalories.round()} kcal · '
                      '${l10n.translate('template_builder.library.day_count', variables: {
                        'n': '${widget.template.days.length}'
                      })}'),
                ],
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg.h),
          Text(
            l10n.translate('plan_offer.compose.recipients_label',
                variables: {'n': '${widget.recipientUids.length}'}),
            style: t.labelL,
          ),
          SizedBox(height: 8.h),
          if (names.isNotEmpty)
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: names
                  .map((n) => Chip(
                        label: Text(n),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: palette.surfaceVariant,
                      ))
                  .toList(),
            ),
          SizedBox(height: AppSpacing.lg.h),
          Text(l10n.translate('plan_offer.compose.message_label'),
              style: t.labelL),
          SizedBox(height: 6.h),
          AppTextField(
            controller: _messageCtrl,
            hintText: l10n.translate('plan_offer.compose.message_hint'),
            maxLines: 4,
            minLines: 3,
            maxLength: _maxMessageLength,
          ),
          SizedBox(height: AppSpacing.xl.h),
          AppButton(
            label: l10n.translate('plan_offer.compose.send_btn'),
            onPressed: _sending ? null : _send,
            loading: _sending,
          ),
        ],
      ),
    );
  }
}
