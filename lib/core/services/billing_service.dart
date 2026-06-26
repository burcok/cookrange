import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Product IDs — must match what you register in App Store Connect + Google Play.
class BillingProducts {
  static const String monthly = 'com.cookrange.premium.monthly';
  static const String yearly = 'com.cookrange.premium.yearly';
  static const Set<String> ids = {monthly, yearly};
}

enum BillingStatus { idle, loading, purchasing, error, notAvailable }

class BillingService {
  static final BillingService _instance = BillingService._internal();
  factory BillingService() => _instance;
  BillingService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
      debugPrint(
          'BillingService: loaded ${_products.length} products, '
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
      await _grantPremium(purchase);
    }

    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }

    statusNotifier.value = BillingStatus.idle;
  }

  Future<void> _grantPremium(PurchaseDetails purchase) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Determine expiry based on product.
    // In production: verify receipt server-side (use your Cloud Function or
    // RevenueCat webhook) before writing to Firestore.
    final expiryDays = purchase.productID == BillingProducts.yearly ? 365 : 31;
    final expiresAt = DateTime.now().add(Duration(days: expiryDays));

    try {
      await _db.collection('users').doc(uid).update({
        'subscription_tier': 'premium',
        'subscription_product_id': purchase.productID,
        'subscription_expires_at': Timestamp.fromDate(expiresAt),
        'subscription_purchase_token':
            purchase.verificationData.serverVerificationData,
      });
      debugPrint(
          'BillingService: granted premium to $uid until $expiresAt');
    } catch (e) {
      debugPrint('BillingService._grantPremium Firestore error: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
    statusNotifier.dispose();
  }
}
