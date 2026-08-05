import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/plan_offer_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/plan_offer_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'offer_preview_screen.dart';

/// Faz 3 §3.5 — "teklif kutusu". Pending offers first (newest first),
/// backed by the new `plan_offers (status ASC, created_at DESC)` composite
/// index; resolved offers (accepted/declined/expired) below, from a plain
/// reverse-chronological listing filtered client-side — see
/// `PlanOfferService.streamOfferHistory`'s doc comment for why that split
/// avoids needing a second composite index for a rarely-viewed history list.
///
/// A `StatefulWidget` with two owned subscriptions (rather than two nested
/// `StreamBuilder`s) — the empty state needs to know BOTH lists are empty at
/// once, which two independent `StreamBuilder`s can't answer without one
/// reaching into the other's snapshot.
class PlanOfferInboxScreen extends StatefulWidget {
  const PlanOfferInboxScreen({super.key});

  @override
  State<PlanOfferInboxScreen> createState() => _PlanOfferInboxScreenState();
}

class _PlanOfferInboxScreenState extends State<PlanOfferInboxScreen> {
  StreamSubscription<List<PlanOffer>>? _pendingSub;
  StreamSubscription<List<PlanOffer>>? _historySub;
  List<PlanOffer>? _pending;
  List<PlanOffer>? _history;
  String? _subscribedUid;

  void _subscribe(String uid) {
    if (_subscribedUid == uid) return;
    _subscribedUid = uid;
    _pendingSub?.cancel();
    _historySub?.cancel();
    _pendingSub = PlanOfferService().streamPendingOffers(uid).listen((v) {
      if (mounted) setState(() => _pending = v);
    });
    _historySub = PlanOfferService().streamOfferHistory(uid).listen((v) {
      if (mounted) setState(() => _history = v);
    });
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    _historySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final uid = context.watch<UserProvider>().user?.uid ?? '';
    if (uid.isNotEmpty) _subscribe(uid);

    final loading = _pending == null || _history == null;
    final pending = _pending ?? const <PlanOffer>[];
    final history = _history ?? const <PlanOffer>[];

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: Text(l10n.translate('plan_offer.inbox.title'))),
      body: loading
          ? const AppSkeletonList(itemCount: 4)
          : (pending.isEmpty && history.isEmpty)
              ? AppEmptyState(
                  icon: Icons.mail_outline_rounded,
                  title: l10n.translate('plan_offer.inbox.empty_title'),
                  message: l10n.translate('plan_offer.inbox.empty_message'),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.md.h,
                      AppSpacing.lg.w, AppSpacing.xl.h),
                  children: [
                    if (pending.isNotEmpty) ...[
                      _SectionHeader(
                          title: l10n
                              .translate('plan_offer.inbox.pending_section'),
                          palette: palette),
                      SizedBox(height: AppSpacing.sm.h),
                      ...pending.map((o) => _OfferTile(offer: o)),
                      SizedBox(height: AppSpacing.lg.h),
                    ],
                    if (history.isNotEmpty) ...[
                      _SectionHeader(
                          title: l10n
                              .translate('plan_offer.inbox.history_section'),
                          palette: palette),
                      SizedBox(height: AppSpacing.sm.h),
                      ...history.map((o) => _OfferTile(offer: o)),
                    ],
                  ],
                ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final AppPalette palette;
  const _SectionHeader({required this.title, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: AppText.of(context).overline.copyWith(
          color: palette.textSecondary.withValues(alpha: 0.7),
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700),
    );
  }
}

class _OfferTile extends StatelessWidget {
  final PlanOffer offer;
  const _OfferTile({required this.offer});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final templateName = offer.templateSnapshot['name']?.toString() ?? '';
    final targetCalories =
        (offer.templateSnapshot['target_calories'] as num?)?.round() ?? 0;

    final (statusColor, statusKey) = switch (offer.status) {
      'accepted' => (palette.success, 'plan_offer.inbox.status_accepted'),
      'declined' => (palette.textTertiary, 'plan_offer.inbox.status_declined'),
      'expired' => (palette.warning, 'plan_offer.inbox.status_expired'),
      _ => (Theme.of(context).primaryColor, 'plan_offer.inbox.status_pending'),
    };

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
      child: AppCard(
        onTap: () => Navigator.of(context)
            .push(AppTransitions.slideUp(PlanOfferPreviewScreen(offer: offer))),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm.r),
              ),
              child: Icon(Icons.menu_book_rounded,
                  color: Theme.of(context).primaryColor, size: 20.r),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    templateName.isEmpty
                        ? l10n.translate('template_builder.library.untitled')
                        : templateName,
                    style: t.bodyM.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    l10n.translate('plan_offer.inbox.from_line',
                        variables: {'name': offer.fromName}),
                    style: t.labelS.copyWith(color: palette.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (targetCalories > 0)
                    Text('$targetCalories kcal',
                        style: t.labelS.copyWith(color: palette.textTertiary)),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full.r),
              ),
              child: Text(
                l10n.translate(statusKey),
                style: t.labelS
                    .copyWith(color: statusColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
