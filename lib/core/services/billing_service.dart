import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Product IDs — must match what you register in App Store Connect + Google Play.
class BillingProducts {
  static const String monthly = 'com.cookrange.premium.monthly';
  static const String yearly = 'com.cookrange.premium.yearly';

  /// Consumable: +10 AI credits one-time top-up.
  /// TODO: register this product in App Store Connect + Google Play Console
  /// before releasing (set as Consumable type in both stores).
  static const String aiCreditsTopUp10 = 'cookrange_ai_credits_10';

  static const Set<String> ids = {monthly, yearly, aiCreditsTopUp10};
}

enum BillingStatus { idle, loading, purchasing, error, notAvailable }

class BillingService {
  static final BillingService _instance = BillingService._internal();
  factory BillingService() => _instance;
  BillingService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];

  final ValueNotifier<BillingStatus> statusNotifier =
      ValueNotifier(BillingStatus.idle);

  List<ProductDetails> get products => List.unmodifiable(_products);

  bool get isAvailable => _products.isNotEmpty;

  /// Call once during app start (e.g. in splash screen). Idempotent.
  Future<void> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) {
      statusNotifier.value = BillingStatus.notAvailable;
      return;
    }

    unawaited(_subscription?.cancel());
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e) {
        debugPrint('BillingService: purchaseStream error: $e');
      },
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(BillingProducts.ids);
      _products = response.productDetails;
      debugPrint('BillingService: loaded ${_products.length} products, '
          'notFound=${response.notFoundIDs}');
    } catch (e) {
      debugPrint('BillingService: _loadProducts error: $e');
    }
  }

  /// Initiate a purchase for the given [productId].
  /// Returns `false` if the store is unavailable or the product wasn't found.
  Future<bool> purchase(String productId) async {
    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw StateError('Product $productId not found'),
    );

    statusNotifier.value = BillingStatus.purchasing;
    try {
      final param = PurchaseParam(productDetails: product);
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      debugPrint('BillingService.purchase error: $e');
      statusNotifier.value = BillingStatus.error;
      return false;
    }
  }

  /// Convenience: buy the monthly subscription.
  Future<bool> buyMonthly() => purchase(BillingProducts.monthly);

  /// Convenience: buy the yearly subscription.
  Future<bool> buyYearly() => purchase(BillingProducts.yearly);

  /// Purchase the +10 AI credits consumable top-up for [uid].
  ///
  /// Returns `true` when the purchase flow was successfully initiated (the
  /// actual credit grant happens in [_handlePurchase] upon confirmed delivery).
  /// Returns `false` when the store is unavailable or the product isn't loaded.
  ///
  /// NOTE: The product ID [BillingProducts.aiCreditsTopUp10] must be registered
  /// as a Consumable in App Store Connect and Google Play Console before this
  /// can complete successfully in production.
  Future<bool> buyAiCreditsTopUp(String uid) async {
    final product = _products.firstWhere(
      (p) => p.id == BillingProducts.aiCreditsTopUp10,
      orElse: () {
        debugPrint('BillingService.buyAiCreditsTopUp: product '
            '${BillingProducts.aiCreditsTopUp10} not found — '
            'ensure it is registered in App Store Connect / Play Console');
        throw StateError(
            'Product ${BillingProducts.aiCreditsTopUp10} not found');
      },
    );

    statusNotifier.value = BillingStatus.purchasing;
    try {
      final param = PurchaseParam(productDetails: product);
      // Consumable products must use buyConsumable so they can be purchased
      // multiple times on the same account.
      return await _iap.buyConsumable(purchaseParam: param);
    } catch (e) {
      debugPrint('BillingService.buyAiCreditsTopUp error: $e');
      statusNotifier.value = BillingStatus.error;
      return false;
    }
  }

  /// Ask the store to restore previously completed purchases.
  Future<void> restorePurchases() async {
    statusNotifier.value = BillingStatus.loading;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('BillingService.restorePurchases error: $e');
      statusNotifier.value = BillingStatus.error;
    }
  }

  void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.pending) {
      statusNotifier.value = BillingStatus.purchasing;
      return;
    }

    if (purchase.status == PurchaseStatus.error) {
      debugPrint('BillingService: purchase error: ${purchase.error}');
      statusNotifier.value = BillingStatus.error;
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      return;
    }

    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      // Entitlement is granted SERVER-SIDE only after the store validates the
      // receipt (Cloud Function `validatePurchase`). The client NEVER writes
      // premium/credits itself — see audit C7. The server mirrors the resulting
      // tier onto the user doc, which the app's UI reads.
      await _validatePurchaseServerSide(purchase);
    }

    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }

    statusNotifier.value = BillingStatus.idle;
  }

  /// Sends the purchase to the server for receipt validation + entitlement
  /// granting. Throws nothing fatal — surfaces an error status on failure.
  Future<void> _validatePurchaseServerSide(PurchaseDetails purchase) async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    final payload = <String, dynamic>{
      'platform': platform,
      'productId': purchase.productID,
    };
    if (platform == 'ios') {
      // App Store Server API resolves the entitlement from the transaction id.
      payload['transactionId'] = purchase.purchaseID;
    } else {
      payload['purchaseToken'] =
          purchase.verificationData.serverVerificationData;
    }
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('validatePurchase')
          .call(payload);
      debugPrint('BillingService: validatePurchase → ${res.data}');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('BillingService: validatePurchase failed: '
          '${e.code} ${e.message}');
      statusNotifier.value = BillingStatus.error;
    } catch (e) {
      debugPrint('BillingService: validatePurchase error: $e');
      statusNotifier.value = BillingStatus.error;
    }
  }

  void dispose() {
    _subscription?.cancel();
    statusNotifier.dispose();
  }
}
