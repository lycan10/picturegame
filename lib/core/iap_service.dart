import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Catalog product definition
class IapProductDef {
  final String id;
  final String title;
  final int rewardAmount;
  final bool isCoins; // true: coins, false: hints

  const IapProductDef({
    required this.id,
    required this.title,
    required this.rewardAmount,
    required this.isCoins,
  });
}

/// Manages native Google Play Billing and Apple StoreKit In-App Purchases.
class IapService extends ChangeNotifier {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _available = false;
  bool get isAvailable => _available;

  bool _loading = false;
  bool get isLoading => _loading;

  final Map<String, ProductDetails> _products = {};
  Map<String, ProductDetails> get products => _products;

  /// Known consumable catalog matching store bundles
  static const Map<String, IapProductDef> catalog = {
    // Coin bundles
    'coins_500': IapProductDef(
      id: 'coins_500',
      title: 'Starter Pack',
      rewardAmount: 500,
      isCoins: true,
    ),
    'coins_1500': IapProductDef(
      id: 'coins_1500',
      title: 'Popular Pack',
      rewardAmount: 1500,
      isCoins: true,
    ),
    'coins_4000': IapProductDef(
      id: 'coins_4000',
      title: 'Mega Pack',
      rewardAmount: 4000,
      isCoins: true,
    ),
    'coins_10000': IapProductDef(
      id: 'coins_10000',
      title: 'Ultimate Pack',
      rewardAmount: 10000,
      isCoins: true,
    ),

    // Hint bundles
    'hints_3': IapProductDef(
      id: 'hints_3',
      title: 'Quick Help',
      rewardAmount: 3,
      isCoins: false,
    ),
    'hints_10': IapProductDef(
      id: 'hints_10',
      title: 'Smart Player',
      rewardAmount: 10,
      isCoins: false,
    ),
    'hints_30': IapProductDef(
      id: 'hints_30',
      title: 'Hint Master',
      rewardAmount: 30,
      isCoins: false,
    ),
  };

  /// Callback executed when a purchase is successfully processed and delivered
  void Function(IapProductDef def)? onPurchaseSuccess;
  void Function(String message)? onPurchaseError;

  Future<void> init() async {
    _available = await _iap.isAvailable();
    if (!_available) {
      debugPrint('[IAP] In-app purchase is not available on this device');
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint('[IAP] Purchase stream error: $error');
        onPurchaseError?.call('Purchase stream error: $error');
      },
    );

    await loadProducts();
  }

  Future<void> loadProducts() async {
    if (!_available) return;
    _loading = true;
    notifyListeners();

    try {
      final response = await _iap.queryProductDetails(catalog.keys.toSet());
      if (response.error != null) {
        debugPrint('[IAP] queryProductDetails error: ${response.error}');
      }

      _products.clear();
      for (final p in response.productDetails) {
        _products[p.id] = p;
      }
      debugPrint('[IAP] Loaded ${_products.length} products from store.');
    } catch (e) {
      debugPrint('[IAP] Error fetching products: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Launch native purchase flow for a catalog product
  Future<bool> buyProduct(String productId) async {
    final product = _products[productId];
    if (product == null) {
      debugPrint('[IAP] Product $productId not found in store listing');
      onPurchaseError?.call('Product currently unavailable in the store.');
      return false;
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      // All our coin and hint bundles are consumable
      return await _iap.buyConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('[IAP] buyConsumable error: $e');
      onPurchaseError?.call('Could not start purchase: $e');
      return false;
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          debugPrint('[IAP] Purchase pending: ${purchase.productID}');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          debugPrint('[IAP] Purchase succeeded: ${purchase.productID}');
          final def = catalog[purchase.productID];
          if (def != null) {
            onPurchaseSuccess?.call(def);
          }
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.error:
          debugPrint('[IAP] Purchase failed: ${purchase.error}');
          onPurchaseError?.call(purchase.error?.message ?? 'Purchase was cancelled or failed.');
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          debugPrint('[IAP] Purchase canceled');
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;
      }
    }
  }

  /// Get formatted localized price or fallback
  String getLocalizedPrice(String productId, String fallback) {
    final p = _products[productId];
    if (p != null && p.price.isNotEmpty) {
      return p.price;
    }
    return fallback;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

