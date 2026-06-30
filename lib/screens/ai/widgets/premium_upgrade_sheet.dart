import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/billing_service.dart';
import '../../../core/widgets/ds/ds.dart';

const _gold = Color(0xFFE8A317);
const _goldLight = Color(0xFFF6C453);

/// Premium upgrade paywall bottom sheet.
///
/// Usage: `PremiumUpgradeSheet.show(context)`
class PremiumUpgradeSheet extends StatefulWidget {
  const PremiumUpgradeSheet._();

  static Future<void> show(BuildContext context) {
    return AppSheet.show(
      context: context,
      child: const PremiumUpgradeSheet._(),
    );
  }

  @override
  State<PremiumUpgradeSheet> createState() => _PremiumUpgradeSheetState();
}

class _PremiumUpgradeSheetState extends State<PremiumUpgradeSheet> {
  // 0 = monthly, 1 = yearly
  int _selectedPlan = 1;
  bool _isPurchasing = false;
  bool _isRestoring = false;

  ProductDetails? get _monthlyProduct => BillingService()
      .products
      .where((p) => p.id == BillingProducts.monthly)
      .firstOrNull;

  ProductDetails? get _yearlyProduct => BillingService()
      .products
      .where((p) => p.id == BillingProducts.yearly)
      .firstOrNull;

  String _priceLabel(ProductDetails? product, String fallback) =>
      product?.price ?? fallback;

  Future<void> _handlePurchase(BuildContext context) async {
    if (_isPurchasing) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final palette = AppPalette.of(context);

    if (!BillingService().isAvailable) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.translate('ai.paywall_not_available')),
        backgroundColor: palette.error,
      ));
      return;
    }

    setState(() => _isPurchasing = true);
    try {
      unawaited(HapticFeedback.mediumImpact());
      final ok = _selectedPlan == 0
          ? await BillingService().buyMonthly()
          : await BillingService().buyYearly();
      if (!mounted) return;
      if (ok) navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.translate('ai.credits_topup_failed')),
        backgroundColor: palette.error,
      ));
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    if (_isRestoring) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final palette = AppPalette.of(context);

    setState(() => _isRestoring = true);
    try {
      await BillingService().restorePurchases();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.translate('ai.paywall_restore_success')),
        backgroundColor: palette.success,
      ));
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.translate('ai.paywall_restore_none')),
      ));
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    final features = [
      'ai.paywall_feature1',
      'ai.paywall_feature2',
      'ai.paywall_feature3',
      'ai.paywall_feature4',
      'ai.paywall_feature5',
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Crown badge ──────────────────────────────────────────────────────
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_goldLight, _gold]),
                borderRadius: BorderRadius.circular(AppRadius.full.r),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.45),
                    blurRadius: 20.r,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      size: 18.r, color: Colors.white),
                  SizedBox(width: 6.w),
                  Text(
                    l10n.translate('ai.credits_premium_plan'),
                    style: t.labelL.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 18.h),

          // ── Title + subtitle ─────────────────────────────────────────────────
          Text(
            l10n.translate('ai.paywall_title'),
            style: t.headlineL.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6.h),
          Text(
            l10n.translate('ai.paywall_subtitle'),
            style: t.bodyM.copyWith(color: palette.textSecondary),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 20.h),

          // ── Feature list ─────────────────────────────────────────────────────
          ...features.map((key) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Row(
                  children: [
                    Container(
                      width: 24.r,
                      height: 24.r,
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_rounded,
                          size: 14.r, color: _gold),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        l10n.translate(key),
                        style:
                            t.bodyM.copyWith(color: palette.textPrimary),
                      ),
                    ),
                  ],
                ),
              )),

          SizedBox(height: 22.h),

          // ── Plan selector ────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _PlanCard(
                  label: l10n.translate('ai.paywall_monthly_label'),
                  price: _priceLabel(_monthlyProduct, '—'),
                  period: '/mo',
                  isSelected: _selectedPlan == 0,
                  badge: null,
                  onTap: () => setState(() => _selectedPlan = 0),
                  palette: palette,
                  t: t,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _PlanCard(
                  label: l10n.translate('ai.paywall_yearly_label'),
                  price: _priceLabel(_yearlyProduct, '—'),
                  period: '/yr',
                  isSelected: _selectedPlan == 1,
                  badge: l10n.translate('ai.paywall_yearly_badge'),
                  savingLabel: l10n.translate('ai.paywall_yearly_save'),
                  onTap: () => setState(() => _selectedPlan = 1),
                  palette: palette,
                  t: t,
                ),
              ),
            ],
          ),

          SizedBox(height: 20.h),

          // ── Primary CTA ──────────────────────────────────────────────────────
          _GoldButton(
            label: _isPurchasing
                ? l10n.translate('ai.paywall_processing')
                : l10n.translate('ai.paywall_buy_cta'),
            onPressed: _isPurchasing ? null : () => _handlePurchase(context),
            loading: _isPurchasing,
            t: t,
          ),

          SizedBox(height: 14.h),

          // ── Restore link ─────────────────────────────────────────────────────
          Center(
            child: GestureDetector(
              onTap: _isRestoring ? null : () => _handleRestore(context),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h),
                child: _isRestoring
                    ? SizedBox(
                        width: 18.r,
                        height: 18.r,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.textTertiary,
                        ),
                      )
                    : Text(
                        l10n.translate('ai.paywall_restore'),
                        style: t.labelM.copyWith(
                          color: palette.textTertiary,
                          decoration: TextDecoration.underline,
                          decorationColor: palette.textTertiary,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Plan card ──────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final String label;
  final String price;
  final String period;
  final bool isSelected;
  final String? badge;
  final String? savingLabel;
  final VoidCallback onTap;
  final AppPalette palette;
  final AppText t;

  const _PlanCard({
    required this.label,
    required this.price,
    required this.period,
    required this.isSelected,
    required this.badge,
    this.savingLabel,
    required this.onTap,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? _gold : palette.border;
    final bgColor = isSelected
        ? _gold.withValues(alpha: 0.08)
        : palette.surfaceVariant;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null)
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                margin: EdgeInsets.only(bottom: 8.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_goldLight, _gold]),
                  borderRadius: BorderRadius.circular(AppRadius.full.r),
                ),
                child: Text(
                  badge!,
                  style: t.labelS.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            Text(
              label,
              style: t.labelM.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4.h),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: price,
                    style: t.titleL.copyWith(
                      color: isSelected ? _gold : palette.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: period,
                    style: t.labelS.copyWith(color: palette.textTertiary),
                  ),
                ],
              ),
            ),
            if (savingLabel != null) ...[
              SizedBox(height: 4.h),
              Text(
                savingLabel!,
                style: t.labelS.copyWith(
                  color: _gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Gold CTA button ─────────────────────────────────────────────────────────

class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final AppText t;

  const _GoldButton({
    required this.label,
    required this.onPressed,
    required this.loading,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? null
              : const LinearGradient(
                  colors: [_goldLight, _gold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: onPressed == null
              ? Colors.grey.withValues(alpha: 0.3)
              : null,
          borderRadius: BorderRadius.circular(AppRadius.full.r),
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.4),
                    blurRadius: 14.r,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.full.r),
          splashColor: Colors.white.withValues(alpha: 0.15),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 20.r,
                      height: 20.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded,
                            size: 18.r, color: Colors.white),
                        SizedBox(width: 6.w),
                        Text(
                          label,
                          style: t.labelL.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
