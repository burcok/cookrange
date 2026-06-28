import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/ai_credit_model.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/ai_credit_service.dart';
import '../../../core/services/billing_service.dart';
import '../../../core/widgets/ds/ds.dart';

/// Modal bottom sheet showing the user's daily AI credit status, reset
/// countdown, and upgrade/purchase CTAs.
///
/// Usage: `AiCreditsSheet.show(context, uid: uid, isPremium: isPremium)`
class AiCreditsSheet extends StatelessWidget {
  final String uid;
  final bool isPremium;

  const AiCreditsSheet._({required this.uid, required this.isPremium});

  static Future<void> show(
    BuildContext context, {
    required String uid,
    required bool isPremium,
  }) {
    return AppSheet.show(
      context: context,
      child: AiCreditsSheet._(uid: uid, isPremium: isPremium),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<AiCreditModel>(
      stream: AiCreditService()
          .getCreditsStream(uid, isPremium: isPremium),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Padding(
            padding: EdgeInsets.all(24.r),
            child: const AppSkeletonList(itemCount: 3),
          );
        }
        final credits = snapshot.data!;
        return _SheetContent(
          uid: uid,
          credits: credits,
          isPremium: isPremium,
          l10n: l10n,
        );
      },
    );
  }
}

class _SheetContent extends StatefulWidget {
  final String uid;
  final AiCreditModel credits;
  final bool isPremium;
  final AppLocalizations l10n;

  const _SheetContent({
    required this.uid,
    required this.credits,
    required this.isPremium,
    required this.l10n,
  });

  @override
  State<_SheetContent> createState() => _SheetContentState();
}

class _SheetContentState extends State<_SheetContent> {
  late Timer _ticker;
  late int _minutesLeft;
  bool _buyingCredits = false;

  @override
  void initState() {
    super.initState();
    _minutesLeft = widget.credits.minutesUntilReset;
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _minutesLeft--);
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Future<void> _handleBuyCredits(BuildContext context) async {
    if (_buyingCredits) return;

    // Capture context-dependent values before the async gap.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final palette = AppPalette.of(context);
    final successMsg = widget.l10n.translate('ai.credits_topup_success');
    final failedMsg = widget.l10n.translate('ai.credits_topup_failed');

    setState(() => _buyingCredits = true);
    try {
      final ok = await BillingService().buyAiCreditsTopUp(widget.uid);
      if (!mounted) return;
      if (ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: palette.success,
          ),
        );
        navigator.pop();
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(failedMsg),
            backgroundColor: palette.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(failedMsg),
          backgroundColor: palette.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _buyingCredits = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final credits = widget.credits;
    final palette = AppPalette.of(context);
    final textTheme = AppText.of(context);
    final primaryColor = context.watch<ThemeProvider>().primaryColor;

    final limit = credits.isPremium
        ? AiCreditModel.premiumDailyLimit
        : AiCreditModel.freeDailyLimit;
    final used = credits.used.clamp(0, limit + credits.bonus);
    final remaining = credits.remaining;
    final exhausted = credits.isExhausted;

    // Reset countdown text
    final h = (_minutesLeft ~/ 60).clamp(0, 23);
    final m = (_minutesLeft % 60).clamp(0, 59);
    final resetText = l10n
        .translate('ai.credits_reset_in')
        .replaceAll('{h}', '$h')
        .replaceAll('{m}', m.toString().padLeft(2, '0'));

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.bolt_rounded, color: primaryColor, size: 22.r),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('ai.credits_sheet_title'),
                      style: textTheme.titleM
                          .copyWith(color: palette.textPrimary),
                    ),
                    Text(
                      credits.isPremium
                          ? l10n.translate('ai.credits_premium_plan')
                          : l10n.translate('ai.credits_free_plan'),
                      style:
                          textTheme.labelS.copyWith(color: palette.textTertiary),
                    ),
                  ],
                ),
              ),
              _PlanChip(isPremium: credits.isPremium),
            ],
          ),

          SizedBox(height: 24.h),

          // ── Usage bar ───────────────────────────────────────────────────────
          Text(
            l10n.translate('ai.credits_daily_usage'),
            style: textTheme.labelS.copyWith(color: palette.textTertiary),
          ),
          SizedBox(height: 8.h),
          Semantics(
            label: '$used of ${limit + credits.bonus} AI credits used today',
            child: _UsageBar(
              used: used,
              limit: limit + credits.bonus,
              exhausted: exhausted,
              primaryColor: primaryColor,
              palette: palette,
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n
                    .translate('ai.credits_daily_free')
                    .replaceAll('{used}', '$used')
                    .replaceAll('{limit}', '${limit + credits.bonus}'),
                style:
                    textTheme.labelS.copyWith(color: palette.textSecondary),
              ),
              Text(
                resetText,
                style:
                    textTheme.labelS.copyWith(color: palette.textTertiary),
              ),
            ],
          ),

          if (credits.bonus > 0) ...[
            SizedBox(height: 8.h),
            _BonusBadge(
              bonus: credits.bonus,
              l10n: l10n,
              textTheme: textTheme,
              palette: palette,
            ),
          ],

          SizedBox(height: 20.h),

          // ── Remaining display ────────────────────────────────────────────────
          Semantics(
            label: exhausted
                ? l10n.translate('ai.credits_exhausted_title')
                : '$remaining ${l10n.translate('ai.credits_sheet_title')} remaining',
            child: Center(
              child: Column(
                children: [
                  Text(
                    exhausted ? '0' : '$remaining',
                    style: textTheme.displayL.copyWith(
                      color: exhausted
                          ? palette.error
                          : remaining <= 1
                              ? palette.warning
                              : primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    exhausted
                        ? l10n.translate('ai.credits_exhausted_title')
                        : (remaining == 1
                            ? '1 ${l10n.translate('ai.credits_sheet_title')}'
                            : '$remaining ${l10n.translate('ai.credits_sheet_title')}'),
                    style:
                        textTheme.bodyM.copyWith(color: palette.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 24.h),

          if (!credits.isPremium) ...[
            // ── Premium upsell ─────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withValues(alpha: 0.15),
                    primaryColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.card.r),
                border:
                    Border.all(color: primaryColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.workspace_premium_rounded,
                          color: primaryColor, size: 20.r),
                      SizedBox(width: 8.w),
                      Text(
                        l10n.translate('ai.credits_premium_plan'),
                        style: textTheme.titleM
                            .copyWith(color: palette.textPrimary),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    l10n.translate('ai.credits_premium_perks'),
                    style: textTheme.labelS
                        .copyWith(color: palette.textSecondary),
                  ),
                  SizedBox(height: 14.h),
                  AppButton(
                    label: l10n.translate('ai.credits_upgrade_cta'),
                    onPressed: () => Navigator.pop(context),
                    icon: Icons.workspace_premium_rounded,
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
          ],

          // ── Buy more button (always shown) ───────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                label: l10n.translate('ai.credits_topup_title'),
                onPressed: _buyingCredits
                    ? null
                    : () => _handleBuyCredits(context),
                variant: AppButtonVariant.tonal,
                icon: Icons.add_rounded,
                loading: _buyingCredits,
              ),
              SizedBox(height: 4.h),
              Center(
                child: Text(
                  l10n.translate('ai.credits_topup_price'),
                  style: textTheme.labelS
                      .copyWith(color: palette.textTertiary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _PlanChip extends StatelessWidget {
  final bool isPremium;
  const _PlanChip({required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textTheme = AppText.of(context);
    final color = isPremium ? palette.success : palette.info;
    final label = isPremium ? 'Premium' : 'Free';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: textTheme.labelS.copyWith(
            color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final int used;
  final int limit;
  final bool exhausted;
  final Color primaryColor;
  final AppPalette palette;

  const _UsageBar({
    required this.used,
    required this.limit,
    required this.exhausted,
    required this.primaryColor,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 1.0;
    final color =
        exhausted ? palette.error : fraction >= 0.75 ? palette.warning : primaryColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full.r),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 8.h,
        backgroundColor: palette.surfaceVariant,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class _BonusBadge extends StatelessWidget {
  final int bonus;
  final AppLocalizations l10n;
  final AppText textTheme;
  final AppPalette palette;

  const _BonusBadge({
    required this.bonus,
    required this.l10n,
    required this.textTheme,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.card_giftcard_rounded,
            color: palette.success, size: 14.r),
        SizedBox(width: 4.w),
        Text(
          l10n
              .translate('ai.credits_bonus_pool')
              .replaceAll('{n}', '$bonus'),
          style: textTheme.labelS.copyWith(color: palette.success),
        ),
      ],
    );
  }
}
