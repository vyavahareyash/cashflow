import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' hide equals;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/components/walkthrough/walkthrough_concept_carousel.dart';
import 'package:cashflow/components/walkthrough/walkthrough_spotlight_overlay.dart';
import 'package:cashflow/components/walkthrough/walkthrough_controller.dart';
import 'package:cashflow/screens/backup_restore_screen.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/config/app_config.dart';
import 'package:cashflow/main.dart';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cashflow/services/billing_service.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  FakePathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;

  @override
  Future<String?> getTemporaryPath() async => tempDir.path;
}

class FakeBillingService extends ChangeNotifier implements BillingService {
  @override
  bool isAvailable = true;
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
  }) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.setTestDatabaseName(inMemoryDatabasePath);
  const databaseFileName = 'money_tracker.db';
  late Directory tempDir;

  setUp(() async {
    AppConfig.setOverrideEnableExternalDonations(false);
    AppConfig.setOverrideEnablePlayStoreTips(false);
    BillingService.setMockInstance(FakeBillingService());
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
    try {
      final f = File(join(dbPath, 'walkthrough_snapshot.json'));
      if (await f.exists()) await f.delete();
    } catch (_) {}
    tempDir = await Directory.systemTemp.createTemp(
      'cashflow_walkthrough_test_',
    );
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
  });

  tearDown(() async {
    AppConfig.setOverrideEnableExternalDonations(null);
    AppConfig.setOverrideEnablePlayStoreTips(null);
    BillingService.setMockInstance(null);
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
    try {
      final f = File(join(dbPath, 'walkthrough_snapshot.json'));
      if (await f.exists()) await f.delete();
    } catch (_) {}
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Walkthrough DatabaseHelper Operations', () {
    test(
      'getWalkthroughCompleted defaults to false and persists updates',
      () async {
        final db = DatabaseHelper.instance;
        expect(await db.getWalkthroughCompleted(), isFalse);

        await db.setWalkthroughCompleted(completed: true);
        expect(await db.getWalkthroughCompleted(), isTrue);

        await db.setWalkthroughCompleted(completed: false);
        expect(await db.getWalkthroughCompleted(), isFalse);
      },
    );

    test('enterWalkthroughDemoMode snapshots user data and exitWalkthroughDemoMode restores it', () async {
      final db = DatabaseHelper.instance;

      // 1. Create a distinct user account
      await db.seedDatabase();
      final userAccId = await db.createAccount(
        Account(
          name: 'My Personal Real Account',
          balance: 42000.0,
          type: 'Savings',
        ),
      );
      final preAccounts = await db.readAllAccounts();
      expect(preAccounts.any((a) => a.id == userAccId), isTrue);
      expect(
        preAccounts.any((a) => a.name == 'My Personal Real Account'),
        isTrue,
      );

      // 2. Enter demo mode
      await db.enterWalkthroughDemoMode();
      expect(db.isWalkthroughDemoMode, isTrue);
      expect(DatabaseHelper.walkthroughDemoModeNotifier.value, isTrue);

      // Check that demo data is now active (Salary Account HDFC exists from seedSampleData)
      final demoAccounts = await db.readAllAccounts();
      expect(
        demoAccounts.any((a) => a.name.contains('Salary Account (HDFC)')),
        isTrue,
      );
      expect(
        demoAccounts.any((a) => a.name == 'My Personal Real Account'),
        isFalse,
      );

      // 3. Exit demo mode
      await db.exitWalkthroughDemoMode();
      expect(db.isWalkthroughDemoMode, isFalse);
      expect(DatabaseHelper.walkthroughDemoModeNotifier.value, isFalse);

      // 4. Verify user data is completely restored
      final restoredAccounts = await db.readAllAccounts();
      expect(
        restoredAccounts.any((a) => a.name == 'My Personal Real Account'),
        isTrue,
      );
      expect(
        restoredAccounts.any((a) => a.name.contains('Salary Account (HDFC)')),
        isFalse,
      );
    });

    test('recoverWalkthroughDemoModeIfNeeded restores snapshot if app restarted mid-demo', () async {
      final db = DatabaseHelper.instance;

      await db.seedDatabase();
      await db.createAccount(
        Account(name: 'Precious Real Savings', balance: 99999.0, type: 'Bank'),
      );

      // Enter demo mode
      await db.enterWalkthroughDemoMode();
      expect(db.isWalkthroughDemoMode, isTrue);

      // Simulate app kill: close connection without calling exitWalkthroughDemoMode
      await db.close();

      // Trigger startup recovery
      await db.recoverWalkthroughDemoModeIfNeeded();

      // Verify restored
      final accounts = await db.readAllAccounts();
      expect(accounts.any((a) => a.name == 'Precious Real Savings'), isTrue);
      expect(
        accounts.any((a) => a.name.contains('Salary Account (HDFC)')),
        isFalse,
      );
    });
  });

  group('WalkthroughConceptCarousel Widget Tests', () {
    testWidgets(
      'renders all 5 concept slides and allows forward/backward paging',
      (tester) async {
        bool tourRequested = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WalkthroughConceptCarousel(
                onTakeTour: () => tourRequested = true,
                onFinish: () {},
                onSkip: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Slide 1: 100% Offline & Private
        expect(find.text('100% Offline & Private'), findsOneWidget);
        expect(find.text('OFFLINE-FIRST PRIVACY'), findsOneWidget);
        expect(
          find.byKey(const Key('walkthrough_skip_button')),
          findsOneWidget,
        );

        // Tap Next to Slide 2
        await tester.tap(find.byKey(const Key('walkthrough_next_button')));
        await tester.pumpAndSettle();
        expect(find.text('Safe-to-Spend Usable Balance'), findsOneWidget);

        // Tap Next to Slide 3
        await tester.tap(find.byKey(const Key('walkthrough_next_button')));
        await tester.pumpAndSettle();
        expect(find.text('Virtual Goal Locks'), findsOneWidget);

        // Tap Next to Slide 4
        await tester.tap(find.byKey(const Key('walkthrough_next_button')));
        await tester.pumpAndSettle();
        expect(find.text('Payday Cycle & Daily Burn'), findsOneWidget);

        // Tap Next to Slide 5 (Final)
        await tester.tap(find.byKey(const Key('walkthrough_next_button')));
        await tester.pumpAndSettle();
        expect(find.text('Private Voice Journaling'), findsOneWidget);

        // Final slide has both 'Explore App' and 'Screen Tour'
        expect(
          find.byKey(const Key('walkthrough_explore_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('walkthrough_take_tour_button')),
          findsOneWidget,
        );

        // Tap Screen Tour
        await tester.tap(find.byKey(const Key('walkthrough_take_tour_button')));
        await tester.pumpAndSettle();
        expect(tourRequested, isTrue);
      },
    );

    testWidgets('skip button triggers onSkip', (tester) async {
      bool skipRequested = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WalkthroughConceptCarousel(
              onTakeTour: () {},
              onFinish: () {},
              onSkip: () => skipRequested = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('walkthrough_skip_button')));
      await tester.pumpAndSettle();
      expect(skipRequested, isTrue);
    });
  });

  group('WalkthroughSpotlightOverlay Widget Tests', () {
    testWidgets('renders demo banner and navigates through steps', (
      tester,
    ) async {
      int currentStep = 0;
      bool exitTriggered = false;
      bool finishTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return WalkthroughSpotlightOverlay(
                  currentStepIndex: currentStep,
                  onNext: () {
                    setState(() => currentStep++);
                  },
                  onPrevious: () {
                    setState(() => currentStep--);
                  },
                  onExit: () => exitTriggered = true,
                  onFinish: () => finishTriggered = true,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Banner text exists
      expect(
        find.text('Walkthrough Demo Mode — Your data is preserved'),
        findsOneWidget,
      );

      // Step 1: Safe-to-Spend Balance Card
      expect(find.text('Safe-to-Spend Balance Card'), findsOneWidget);

      // Tap Next
      await tester.tap(find.byKey(const Key('walkthrough_tour_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Step 2: Privacy Mode Toggle
      expect(find.text('Privacy Mode Toggle'), findsOneWidget);

      // Tap Next to Step 3
      await tester.tap(find.byKey(const Key('walkthrough_tour_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('AI Voice Journaling & Quick Add'), findsOneWidget);

      // Tap Next to Step 4
      await tester.tap(find.byKey(const Key('walkthrough_tour_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Sinking Funds & Goal Locks'), findsOneWidget);

      // Tap Next to Step 5 (Final)
      await tester.tap(find.byKey(const Key('walkthrough_tour_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Accounts & Physical Cash'), findsOneWidget);
      expect(
        find.byKey(const Key('walkthrough_tour_finish_button')),
        findsOneWidget,
      );

      // Tap Finish Tour
      await tester.tap(find.byKey(const Key('walkthrough_tour_finish_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(finishTriggered, isTrue);

      // Exit button works
      await tester.tap(find.byKey(const Key('walkthrough_exit_banner_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(exitTriggered, isTrue);
    });
  });

  group('Settings & Data Screen Walkthrough Section', () {
    testWidgets('renders App Walkthrough & Concepts section with 3 tiles', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MaterialApp(home: BackupRestoreScreen()));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();

      // Section title
      final titleFinder = find.text('App Walkthrough & Concepts');
      await tester.ensureVisible(titleFinder);
      expect(titleFinder, findsOneWidget);

      // 3 Tiles
      expect(
        find.byKey(const Key('settings_full_walkthrough_tile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings_review_concepts_tile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings_screen_tour_tile')),
        findsOneWidget,
      );
    });
  });

  group('MainNavigationScreen Walkthrough First-Install & Tour Flow', () {
    testWidgets(
      'automatically prompts concept carousel on first install and launches spotlight tour',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        bool initialCompleted = true;
        await tester.runAsync(() async {
          final db = DatabaseHelper.instance;
          await db.seedDatabase();
          initialCompleted = await db.getWalkthroughCompleted();
        });
        expect(initialCompleted, isFalse);

        await tester.pumpWidget(
          MaterialApp(home: MainNavigationScreen(onThemeToggle: () {})),
        );
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 400));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Concept dialog is automatically shown on first install
        expect(find.text('100% Offline & Private'), findsOneWidget);

        // Fast forward to final slide
        for (int i = 0; i < 4; i++) {
          await tester.tap(find.byKey(const Key('walkthrough_next_button')));
          for (int frame = 0; frame < 10; frame++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
        }

        // Final slide: tap Screen Tour
        expect(
          find.byKey(const Key('walkthrough_take_tour_button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('walkthrough_take_tour_button')));
        await tester.pump();
        for (int i = 0; i < 200; i++) {
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (WalkthroughController.instance.isTourActive) break;
        }
        await tester.pump(const Duration(milliseconds: 100));

        // Spotlight overlay is active and demo mode banner is displayed
        expect(
          find.text('Walkthrough Demo Mode — Your data is preserved'),
          findsOneWidget,
        );
        expect(DatabaseHelper.instance.isWalkthroughDemoMode, isTrue);

        // Step through all spotlight steps
        for (int i = 0; i < 4; i++) {
          expect(
            find.byKey(const Key('walkthrough_tour_next_button')),
            findsOneWidget,
          );
          await tester.tap(
            find.byKey(const Key('walkthrough_tour_next_button')),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Last step: Finish Tour
        expect(
          find.byKey(const Key('walkthrough_tour_finish_button')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('walkthrough_tour_finish_button')),
        );
        await tester.pump();
        for (int i = 0; i < 200; i++) {
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (!DatabaseHelper.instance.isWalkthroughDemoMode) break;
        }
        await tester.pump(const Duration(milliseconds: 100));

        // Spotlight is closed, demo mode reverted, walkthrough marked completed
        expect(
          find.text('Walkthrough Demo Mode — Your data is preserved'),
          findsNothing,
        );
        expect(DatabaseHelper.instance.isWalkthroughDemoMode, isFalse);

        bool finalCompleted = false;
        await tester.runAsync(() async {
          finalCompleted = await DatabaseHelper.instance
              .getWalkthroughCompleted();
        });
        expect(finalCompleted, isTrue);

        // Allow remaining async screen refresh queries to settle cleanly before teardown
        for (int i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
    );
  });
}
