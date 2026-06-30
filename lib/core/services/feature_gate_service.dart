import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/subscription_model.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import 'analytics_service.dart';
import 'billing_service.dart';

/// Checks whether the current user has access to a feature and shows a
/// paywall bottom sheet when they don't.
class FeatureGateService {
  static final FeatureGateService _instance = FeatureGateService._internal();
  factory FeatureGateService() => _instance;
  FeatureGateService._internal();

  /// Returns `true` if the user has access; `false` + shows paywall if not.
  ///
  /// Usage:
  /// ```dart
  /// if (!await FeatureGateService().check(context, (e) => e.advancedTrends)) return;
  /// // ... proceed with feature
  /// ```
  Future<bool> check(
    BuildContext context,
    bool Function(Entitlements) gate, {
    String? featureName,
    String? featureDescription,
  }) async {
    final user = context.read<UserProvider>().user;
    if (user == null) return false;

    final entitlements = user.entitlements;
    if (gate(entitlements)) return true;

    await showPaywall(
      context,
      featureName: featureName,
      featureDescription: featureDescription,
    );
    return false;
  }

  Future<void> showPaywall(
    BuildContext context, {
    String? featureName,
    String? featureDescription,
  }) {
    unawaited(AnalyticsService().logEvent(
      name: 'paywall_shown',
      parameters: {'feature': featureName ?? 'unknown'},
    ));
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaywallSheet(
        featureName: featureName,
        featureDescription: featureDescription,
      ),
    );
  }
}

class _PaywallSheet extends StatefulWidget {
  final String? featureName;
  final String? featureDescription;

  const _PaywallSheet({this.featureName, this.featureDescription});

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  final _billing = BillingService();
  bool _isPurchasing = false;
  String? _errorText;

  Future<void> _buyMonthly() async {
    if (!_billing.isAvailable) {
      setState(() => _errorText =
          AppLocalizations.of(context).translate('billing.unavailable'));
      return;
    }
    setState(() {
      _isPurchasing = true;
      _errorText = null;
    });
    try {
      await _billing.buyMonthly();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _errorText = e.toString();
        });
      }
    }
  }

  Future<void> _buyYearly() async {
    if (!_billing.isAvailable) {
      setState(() => _errorText =
          AppLocalizations.of(context).translate('billing.unavailable'));
      return;
    }
    setState(() {
      _isPurchasing = true;
      _errorText = null;
    });
    try {
      await _billing.buyYearly();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _errorText = e.toString();
        });
      }
    }
  }

  Future<void> _restore() async {
    setState(() {
      _isPurchasing = true;
      _errorText = null;
    });
    try {
      await _billing.restorePurchases();
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = context.watch<ThemeProvider>().primaryColor;

    final monthlyProduct = _billing.products
        .where((p) => p.id == BillingProducts.monthly)
        .firstOrNull;
    final yearlyProduct = _billing.products
        .where((p) => p.id == BillingProducts.yearly)
        .firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2333) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36.w,
            height: 4.h,
            margin: EdgeInsets.only(bottom: 24.h),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.workspace_premium, color: Colors.white, size: 36.sp),
          ),
          SizedBox(height: 16.h),
          Text(
            widget.featureName ?? l10n.translate('premium.paywall_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF2E3A59),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            widget.featureDescription ??
                l10n.translate('premium.paywall_subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: isDark
                  ? Colors.white54
                  : const Color(0xFF2E3A59).withAlpha(140),
            ),
          ),
          SizedBox(height: 24.h),
          _PerksRow(primary: primary, isDark: isDark, l10n: l10n),
          SizedBox(height: 24.h),
          if (_errorText != null)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Text(
                _errorText!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.sp, color: Colors.red.shade400),
              ),
            ),
          if (_isPurchasing)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: CircularProgressIndicator(color: primary),
            )
          else ...[
            if (yearlyProduct != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _buyYearly,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r)),
                  ),
                  child: Text(
                    '${l10n.translate('billing.yearly')} — ${yearlyProduct.price}',
                    style:
                        TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (yearlyProduct != null) SizedBox(height: 10.h),
            if (monthlyProduct != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _buyMonthly,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(color: primary),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r)),
                  ),
                  child: Text(
                    '${l10n.translate('billing.monthly')} — ${monthlyProduct.price}',
                    style: TextStyle(fontSize: 14.sp),
                  ),
                ),
              ),
            if (yearlyProduct == null && monthlyProduct == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r)),
                  ),
                  child: Text(
                    l10n.translate('premium.upgrade_btn'),
                    style:
                        TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l10n.translate('premium.maybe_later'),
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
              TextButton(
                onPressed: _restore,
                child: Text(
                  l10n.translate('billing.restore'),
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerksRow extends StatelessWidget {
  final Color primary;
  final bool isDark;
  final AppLocalizations l10n;

  const _PerksRow(
      {required this.primary, required this.isDark, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final perks = [
      (Icons.restaurant_menu, l10n.translate('premium.perk_meal_plans')),
      (Icons.smart_toy_outlined, l10n.translate('premium.perk_ai_chat')),
      (Icons.bar_chart, l10n.translate('premium.perk_analytics')),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: perks
          .map((p) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(p.$1, size: 22.sp, color: primary),
                  ),
                  SizedBox(height: 6.h),
                  SizedBox(
                    width: 80.w,
                    child: Text(
                      p.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color:
                            isDark ? Colors.white70 : const Color(0xFF2E3A59),
                      ),
                    ),
                  ),
                ],
              ))
          .toList(),
    );
  }
}
