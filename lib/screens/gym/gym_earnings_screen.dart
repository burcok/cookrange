import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/commission_model.dart';
import '../../core/models/earnings_summary_model.dart';
import '../../core/models/gym_model.dart';
import '../../core/services/commission_service.dart';
import '../../core/widgets/ds/ds.dart';
import '../legal/legal_screen.dart';

/// Gym owner's revenue-share earnings — Faz 6 §6.6. Reuses
/// `AffiliateEarningsScreen`'s exact visual/data pattern (stat row, payout
/// button, commission history, "how to earn" card), scoped to ONLY
/// `CommissionType.gymPremiumShare` entries so a gym owner who also has
/// personal referral/coaching commissions in the same `users/{uid}/
/// commissions` wallet sees just their gym-sourced revenue here (the
/// unfiltered view stays at Settings → My Earnings). Adds the two things
/// the plan calls for that the personal screen doesn't need: a literal
/// "payouts are processed manually" banner (no automated payout rail exists
/// anywhere in this plan — see K1), and a real link to the gym's commission
/// contract terms (closes audit finding C16a: `marketplace_terms_{en,tr}.md`
/// was drafted but never shown anywhere in the app).
class GymEarningsScreen extends StatefulWidget {
  final GymModel gym;

  const GymEarningsScreen({super.key, required this.gym});

  @override
  State<GymEarningsScreen> createState() => _GymEarningsScreenState();
}

class _GymEarningsScreenState extends State<GymEarningsScreen> {
  static const _types = [CommissionType.gymPremiumShare];

  late Future<EarningsSummaryModel> _summaryFuture;
  bool _payoutLoading = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _summaryFuture =
        CommissionService().getEarningsSummary(_uid, types: _types);
  }

  Future<void> _requestPayout(EarningsSummaryModel summary) async {
    if (_payoutLoading) return;
    setState(() => _payoutLoading = true);
    try {
      await CommissionService().requestPayout(_uid);
      if (!mounted) return;
      await AppSheet.show(
        context: context,
        title: AppLocalizations.of(context)
            .translate('settings.earnings.payout_requested'),
        child: _PayoutRecordedContent(pendingAmount: summary.pendingAmount),
      );
      if (!mounted) return;
      setState(() {
        _summaryFuture =
            CommissionService().getEarningsSummary(_uid, types: _types);
      });
    } finally {
      if (mounted) setState(() => _payoutLoading = false);
    }
  }

  void _openContractTerms() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          const LegalScreen(type: LegalDocumentType.marketplaceTerms),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.translate('gym.earnings.title'),
          style: t.titleM.copyWith(color: palette.textPrimary),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<EarningsSummaryModel>(
        future: _summaryFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: EdgeInsets.all(20.w),
              child: const AppSkeletonList(itemCount: 5),
            );
          }
          final summary = snap.data ?? EarningsSummaryModel.empty;
          return _buildBody(context, summary, palette, t, l);
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    EarningsSummaryModel summary,
    AppPalette palette,
    AppText t,
    AppLocalizations l,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary row ──────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: l.translate('settings.earnings.total'),
                  value: '₺${summary.totalEarned.toStringAsFixed(2)}',
                  valueColor: palette.success,
                  palette: palette,
                  t: t,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _StatCard(
                  label: l.translate('settings.earnings.pending'),
                  value: '₺${summary.pendingAmount.toStringAsFixed(2)}',
                  valueColor: palette.warning,
                  palette: palette,
                  t: t,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _StatCard(
                  label: l.translate('settings.earnings.paid_out'),
                  value: '₺${summary.paidAmount.toStringAsFixed(2)}',
                  valueColor: palette.textSecondary,
                  palette: palette,
                  t: t,
                ),
              ),
            ],
          ),

          SizedBox(height: 20.h),

          if (summary.pendingAmount > 0) ...[
            AppButton(
              label:
                  '${l.translate('settings.earnings.request_payout')} ₺${summary.pendingAmount.toStringAsFixed(2)}',
              onPressed: _payoutLoading ? null : () => _requestPayout(summary),
              loading: _payoutLoading,
            ),
            SizedBox(height: 16.h),
          ],

          // ── Mandatory, honest manual-payout banner ────────────────────────
          // Literal per the plan's own wording — this is NOT a "coming soon"
          // framing (a real payout rail is out of scope for this entire
          // plan, K1): today, if a gym gets paid at all, it is arranged by
          // Cookrange directly, not moved automatically.
          AppGlassCard(
            padding: EdgeInsets.all(AppSpacing.md.r),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: palette.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm.r),
                  ),
                  child: Icon(Icons.handshake_rounded,
                      color: palette.warning, size: 20.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.translate('gym.earnings.manual_payout_title'),
                        style: t.labelM.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        l.translate('gym.earnings.manual_payout_body'),
                        style: t.bodyM.copyWith(color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // ── Earnings history ─────────────────────────────────────────────
          Text(
            l.translate('settings.earnings.history_title'),
            style: t.titleM.copyWith(color: palette.textPrimary),
          ),
          SizedBox(height: 12.h),

          StreamBuilder<List<CommissionModel>>(
            stream:
                CommissionService().getCommissionsStream(_uid, types: _types),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const AppSkeletonList(itemCount: 3);
              }
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return AppEmptyState(
                  icon: Icons.qr_code_2_rounded,
                  title: l.translate('gym.earnings.no_earnings'),
                  message: l.translate('gym.earnings.no_earnings_msg'),
                );
              }
              return Column(
                children: items
                    .map((c) =>
                        _CommissionRow(commission: c, palette: palette, t: t))
                    .toList(),
              );
            },
          ),

          SizedBox(height: 28.h),

          // ── Contract terms — closes audit C16a (was drafted, never shown) ──
          AppCard(
            onTap: _openContractTerms,
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
            child: Row(
              children: [
                Icon(Icons.description_outlined,
                    color: palette.textSecondary, size: 20.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    l.translate('gym.earnings.view_contract'),
                    style: t.bodyM.copyWith(color: palette.textPrimary),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: palette.textTertiary, size: 20.sp),
              ],
            ),
          ),

          SizedBox(height: 32.h),
        ],
      ),
    );
  }
}

// ── Stat card (mirrors AffiliateEarningsScreen's exact widget) ────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final AppPalette palette;
  final AppText t;

  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: t.headlineS.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: t.labelS.copyWith(color: palette.textSecondary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Commission row (mirrors AffiliateEarningsScreen's exact widget) ──────────

class _CommissionRow extends StatelessWidget {
  final CommissionModel commission;
  final AppPalette palette;
  final AppText t;

  const _CommissionRow({
    required this.commission,
    required this.palette,
    required this.t,
  });

  Color _statusColor(AppPalette p) => switch (commission.status) {
        CommissionStatus.pending => p.warning,
        CommissionStatus.approved => p.info,
        CommissionStatus.paid => p.success,
        CommissionStatus.rejected => p.error,
      };

  String _statusLabel(AppLocalizations l) => switch (commission.status) {
        CommissionStatus.pending => 'Pending',
        CommissionStatus.approved => 'Approved',
        CommissionStatus.paid => 'Paid',
        CommissionStatus.rejected => 'Rejected',
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final statusColor = _statusColor(palette);

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: AppCard(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: palette.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(Icons.qr_code_2_rounded,
                  color: palette.success, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.translate('gym.earnings.row_title'),
                    style: t.bodyM.copyWith(color: palette.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    _formatDate(commission.createdAt),
                    style: t.labelS.copyWith(color: palette.textSecondary),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  // Faz 6 §6.6 follow-up: a reversed PAID commission gets a
                  // negative-amount offsetting entry (see
                  // entitlements.js's reverseCommissionsForPurchase) — a
                  // hardcoded '+' would render that as the nonsensical
                  // "+₺-15.00"; sign the string from the actual amount instead.
                  '${commission.amount < 0 ? '-' : '+'}₺${commission.amount.abs().toStringAsFixed(2)}',
                  style: t.bodyM.copyWith(
                    color: palette.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    _statusLabel(l),
                    style: t.labelS.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}';
  }
}

// ── Payout-recorded sheet content (mirrors AffiliateEarningsScreen's) ────────

class _PayoutRecordedContent extends StatelessWidget {
  final double pendingAmount;

  const _PayoutRecordedContent({required this.pendingAmount});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              color: palette.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline_rounded,
                color: palette.success, size: 32.sp),
          ),
          SizedBox(height: 16.h),
          Text(
            l.translate('settings.earnings.payout_recorded'),
            style: t.bodyM.copyWith(color: palette.textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          AppButton(
            label: l.translate('settings.earnings.got_it'),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}
