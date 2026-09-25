import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Lightweight, offline-first Google Play Billing service for consumable tips.
///
/// Complies with Google Play In-App Billing policies. Zero remote servers,
/// zero telemetry: purchases are completed directly on the device with
/// Google Play Services.
class BillingService extends ChangeNotifier {
  BillingService._({InAppPurchase? iapInstance})
      : _customIap = iapInstance;

  static BillingService? _defaultInstance;
  static BillingService? _mockInstance;

  static BillingService get instance =>
      _mockInstance ?? (_defaultInstance ??= BillingService._());

  @visibleForTesting
  static void setMockInstance(BillingService? mock) {
    _mockInstance = mock;
  }

  @visibleForTesting
  factory BillingService.custom({required InAppPurchase iapInstance}) {
    return BillingService._(iapInstance: iapInstance);
  }

  final InAppPurchase? _customIap;
  InAppPurchase get _iap => _customIap ?? InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  static const String productCoffeeSingle = 'coffee_single';
  static const String productCoffeeDouble = 'coffee_double';
  static const String productCoffeePot = 'coffee_pot';

  static const String assetCoffeeSingle = 'assets/icon/products/coffee_single_3d.png';
  static const String assetCoffeeDouble = 'assets/icon/products/coffee_double_3d.png';
  static const String assetCoffeePot = 'assets/icon/products/coffee_pot_3d.png';

  static const String assetCoffeeSingleOriginal = 'assets/icon/products/coffee_single.png';
  static const String assetCoffeeDoubleOriginal = 'assets/icon/products/coffee_double.png';
  static const String assetCoffeePotOriginal = 'assets/icon/products/coffee_pot.png';

  /// Resolves the asset image path corresponding to a coffee tip product identifier.
  static String productIconAsset(String productId) {
    if (productId.contains('pot')) {
      return assetCoffeePot;
    } else if (productId.contains('double')) {
      return assetCoffeeDouble;
    }
    return assetCoffeeSingle;
  }

  /// Resolves a user-friendly tagline describing the impact of a coffee tip tier.
  static String productTagline(String productId) {
    if (productId.contains('pot')) {
      return 'Supercharge continuous development & maintenance';
    } else if (productId.contains('double')) {
      return 'Power a new feature & test cycle';
    }
    return 'Fuel a quick bug fix or optimization';
  }

  static const Set<String> productIds = {
    productCoffeeSingle,
    productCoffeeDouble,
    productCoffeePot,
  };

  bool _isAvailable = false;
  bool _isLoading = false;
  bool _purchasePending = false;
  String? _errorMessage;
  List<ProductDetails> _products = [];

  bool get isAvailable => _isAvailable;
  bool get isLoading => _isLoading;
  bool get purchasePending => _purchasePending;
  String? get errorMessage => _errorMessage;
  List<ProductDetails> get products => List.unmodifiable(_products);

  /// Callback when a purchase succeeds and is completed.
  VoidCallback? onPurchaseCompleted;

  @visibleForTesting
  void setTestingState({
    bool? isAvailable,
    bool? isLoading,
    List<ProductDetails>? products,
    String? errorMessage,
  }) {
    if (isAvailable != null) _isAvailable = isAvailable;
    if (isLoading != null) _isLoading = isLoading;
    if (products != null) _products = products;
    if (errorMessage != null) _errorMessage = errorMessage;
    notifyListeners();
  }

  /// Initialize billing connection and query product catalog.
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _isAvailable = await _iap.isAvailable().timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
      if (!_isAvailable) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      _subscription ??= _iap.purchaseStream.listen(
        _onPurchaseStream,
        onDone: () => _subscription?.cancel(),
        onError: (err) {
          _errorMessage = err.toString();
          _purchasePending = false;
          notifyListeners();
        },
      );

      final response = await _iap.queryProductDetails(productIds);
      if (response.error != null) {
        _errorMessage = response.error!.message;
      }
      _products = response.productDetails.toList()
        ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    } catch (e) {
      _isAvailable = false;
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Purchase a consumable coffee tier.
  Future<bool> buyProduct(ProductDetails product) async {
    if (!_isAvailable) return false;

    final purchaseParam = PurchaseParam(productDetails: product);
    _purchasePending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await _iap.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: true,
      );
    } catch (e) {
      _purchasePending = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> _onPurchaseStream(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _purchasePending = true;
      } else {
        _purchasePending = false;
        if (purchaseDetails.status == PurchaseStatus.error) {
          _errorMessage = purchaseDetails.error?.message ?? 'Purchase failed.';
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _errorMessage = null;
          onPurchaseCompleted?.call();
        }

        if (purchaseDetails.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(purchaseDetails);
          } catch (_) {}
        }
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
