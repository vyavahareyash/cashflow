import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cashflow/config/app_config.dart';
import 'package:cashflow/screens/backup_restore_screen.dart';
import 'package:cashflow/services/billing_service.dart';
import 'package:cashflow/services/database_helper.dart';

class FakeBillingService extends ChangeNotifier implements BillingService {
  @override
  bool isAvailable = false;

  @override
  bool isLoading = false;

  @override
  bool purchasePending = false;

  @override
  String? errorMessage;

  @override
  List<ProductDetails> products = [];

  @override
  VoidCallback? onPurchaseCompleted;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> buyProduct(ProductDetails product) async => true;

  @override
  void setTestingState({
    bool? isAvailable,
    bool? isLoading,
    List<ProductDetails>? products,
    String? errorMessage,
  }) {
    if (isAvailable != null) this.isAvailable = isAvailable;
    if (isLoading != null) this.isLoading = isLoading;
    if (products != null) this.products = products;
    if (errorMessage != null) this.errorMessage = errorMessage;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
  const databaseFileName = 'money_tracker.db';
  late FakeBillingService fakeBilling;

  setUp(() async {
    fakeBilling = FakeBillingService();
    BillingService.setMockInstance(fakeBilling);
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
  });

  tearDown(() async {
    AppConfig.setOverrideEnableExternalDonations(null);
    AppConfig.setOverrideEnablePlayStoreTips(null);
    BillingService.setMockInstance(null);
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
  });

  group('AppConfig compile-time and runtime flag tests', () {
    test('Default donations flag enables in debug mode for previewing', () {
      AppConfig.setOverrideEnableExternalDonations(null);
      AppConfig.setOverrideEnablePlayStoreTips(null);
      expect(AppConfig.enableExternalDonations, isTrue);
      expect(AppConfig.buyMeACoffeeUrl, contains('buymeacoffee.com'));
      expect(AppConfig.gitHubUrl, contains('github.com'));
      expect(AppConfig.linkedInUrl, contains('linkedin.com'));
      expect(AppConfig.developerName, equals('Yash Vyavahare'));
    });

    test('Override flag toggles donations and Play Store tips properly', () {
      AppConfig.setOverrideEnableExternalDonations(true);
      expect(AppConfig.enableExternalDonations, isTrue);

      AppConfig.setOverrideEnableExternalDonations(false);
      expect(AppConfig.enableExternalDonations, isFalse);
      expect(AppConfig.enablePlayStoreTips, isTrue);

      AppConfig.setOverrideEnablePlayStoreTips(false);
      expect(AppConfig.enablePlayStoreTips, isFalse);
    });
  });

  group('BackupRestoreScreen Support Development Card', () {
    testWidgets('Support card is hidden when both external donations and Play Store tips are false', (tester) async {
      AppConfig.setOverrideEnableExternalDonations(false);
      AppConfig.setOverrideEnablePlayStoreTips(false);

      await tester.pumpWidget(
        const MaterialApp(
          home: BackupRestoreScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Support & Open Source'), findsNothing);
      expect(find.byKey(const Key('buy_me_a_coffee_button')), findsNothing);
    });

    testWidgets('Support card displays Buy Me a Coffee button when enableExternalDonations is true', (tester) async {
      AppConfig.setOverrideEnableExternalDonations(true);
      AppConfig.setOverrideEnablePlayStoreTips(false);

      await tester.pumpWidget(
        const MaterialApp(
          home: BackupRestoreScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Support & Open Source'), findsOneWidget);
      expect(find.text('Support Development'), findsOneWidget);
      expect(find.byKey(const Key('buy_me_a_coffee_button')), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('Support card displays Play Store Tip Jar UI when enablePlayStoreTips is true', (tester) async {
      AppConfig.setOverrideEnableExternalDonations(false);
      AppConfig.setOverrideEnablePlayStoreTips(true);
      fakeBilling.isAvailable = false;
      fakeBilling.isLoading = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: BackupRestoreScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Support & Open Source'), findsOneWidget);
      expect(find.text('Support Development'), findsOneWidget);
      expect(find.byKey(const Key('buy_me_a_coffee_button')), findsNothing);
      expect(find.byKey(const Key('retry_billing_button')), findsOneWidget);
    });

    testWidgets('Support card displays product tip buttons when products are available', (tester) async {
      AppConfig.setOverrideEnableExternalDonations(false);
      AppConfig.setOverrideEnablePlayStoreTips(true);
      fakeBilling.isAvailable = true;
      fakeBilling.isLoading = false;
      fakeBilling.products = [
        ProductDetails(
          id: 'coffee_single',
          title: '1 Coffee',
          description: 'Single coffee',
          price: '₹89.00',
          rawPrice: 89.0,
          currencyCode: 'INR',
        ),
        ProductDetails(
          id: 'coffee_double',
          title: '2 Coffees',
          description: 'Double coffee',
          price: '₹249.00',
          rawPrice: 249.0,
          currencyCode: 'INR',
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: BackupRestoreScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Support & Open Source'), findsOneWidget);
      expect(find.byKey(const Key('play_store_buy_coffee_button')), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('play_store_buy_coffee_button')),
        300,
      );
      await tester.tap(find.byKey(const Key('play_store_buy_coffee_button')));
      await tester.pumpAndSettle();

      expect(find.text('Buy Me a Coffee'), findsOneWidget);
      expect(find.byKey(const Key('tip_button_coffee_single')), findsOneWidget);
      expect(find.byKey(const Key('tip_button_coffee_double')), findsOneWidget);
      expect(find.text('Fuel a quick bug fix or optimization'), findsOneWidget);
      expect(find.text('Power a new feature & test cycle'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('tip_button_coffee_single')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('tip_button_coffee_double')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Developer & Community footer displays correctly with GitHub and LinkedIn buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BackupRestoreScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Created by Yash Vyavahare'), findsOneWidget);
      expect(find.text('Open Source & Offline-First'), findsOneWidget);
      expect(find.byKey(const Key('developer_github_button')), findsOneWidget);
      expect(find.byKey(const Key('developer_linkedin_button')), findsOneWidget);
    });
  });
}
