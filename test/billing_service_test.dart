import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:cashflow/services/billing_service.dart';

class FakeInAppPurchase implements InAppPurchase {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return ProductDetailsResponse(productDetails: [], notFoundIDs: []);
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async => true;

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      true;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}

  @override
  Future<String> countryCode() async => 'IN';

  @override
  T getPlatformAddition<T extends InAppPurchasePlatformAddition?>() =>
      null as T;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeInAppPurchase fakeIap;

  setUp(() {
    fakeIap = FakeInAppPurchase();
    BillingService.setMockInstance(BillingService.custom(iapInstance: fakeIap));
  });

  tearDown(() {
    BillingService.setMockInstance(null);
  });

  group('BillingService product definitions and initial state', () {
    test(
      'Product identifiers and icon asset paths are defined for coffee tiers',
      () {
        expect(BillingService.productCoffeeSingle, equals('coffee_single'));
        expect(BillingService.productCoffeeDouble, equals('coffee_double'));
        expect(BillingService.productCoffeePot, equals('coffee_pot'));
        expect(
          BillingService.productIds,
          containsAll(['coffee_single', 'coffee_double', 'coffee_pot']),
        );
        expect(
          BillingService.assetCoffeeSingle,
          equals('assets/icon/products/coffee_single_3d.png'),
        );
        expect(
          BillingService.assetCoffeeDouble,
          equals('assets/icon/products/coffee_double_3d.png'),
        );
        expect(
          BillingService.assetCoffeePot,
          equals('assets/icon/products/coffee_pot_3d.png'),
        );
        expect(
          BillingService.assetCoffeeSingleOriginal,
          equals('assets/icon/products/coffee_single.png'),
        );
        expect(
          BillingService.assetCoffeeDoubleOriginal,
          equals('assets/icon/products/coffee_double.png'),
        );
        expect(
          BillingService.assetCoffeePotOriginal,
          equals('assets/icon/products/coffee_pot.png'),
        );
        expect(
          BillingService.productIconAsset('coffee_single'),
          equals(BillingService.assetCoffeeSingle),
        );
        expect(
          BillingService.productIconAsset('coffee_double'),
          equals(BillingService.assetCoffeeDouble),
        );
        expect(
          BillingService.productIconAsset('coffee_pot'),
          equals(BillingService.assetCoffeePot),
        );
        expect(
          BillingService.productTagline('coffee_single'),
          equals('Fuel a quick bug fix or optimization'),
        );
        expect(
          BillingService.productTagline('coffee_double'),
          equals('Power a new feature & test cycle'),
        );
        expect(
          BillingService.productTagline('coffee_pot'),
          equals('Supercharge continuous development & maintenance'),
        );
      },
    );

    test('Initial instance state has default empty values', () {
      final billing = BillingService.instance;
      expect(billing.isLoading, isFalse);
      expect(billing.purchasePending, isFalse);
      expect(billing.errorMessage, isNull);
    });

    test('initialize loads products from IAP instance', () async {
      final billing = BillingService.instance;
      await billing.initialize();

      expect(billing.isAvailable, isTrue);
      expect(billing.isLoading, isFalse);
    });

    test('setTestingState updates state and notifies listeners', () {
      final billing = BillingService.instance;
      int notifications = 0;
      void listener() => notifications++;
      billing.addListener(listener);

      final dummyProduct = ProductDetails(
        id: 'coffee_single',
        title: '1 Coffee',
        description: 'Single coffee',
        price: '₹89.00',
        rawPrice: 89.0,
        currencyCode: 'INR',
      );

      billing.setTestingState(
        isAvailable: true,
        isLoading: false,
        products: [dummyProduct],
        errorMessage: 'Custom error',
      );

      expect(billing.isAvailable, isTrue);
      expect(billing.isLoading, isFalse);
      expect(billing.products, contains(dummyProduct));
      expect(billing.errorMessage, equals('Custom error'));
      expect(notifications, greaterThan(0));

      billing.removeListener(listener);
    });
  });
}
