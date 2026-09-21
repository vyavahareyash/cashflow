import 'dart:io';

import 'package:cashflow/screens/backup_restore_screen.dart';
import 'package:cashflow/screens/dashboard_screen.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
  const databaseFileName = 'money_tracker.db';

  late Directory tempDir;

  setUp(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
    tempDir = await Directory.systemTemp.createTemp('cashflow_privacy_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
  });

  tearDown(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('DatabaseHelper App Settings & Privacy Persistence', () {
    test('getSetting returns default when key does not exist', () async {
      final db = DatabaseHelper.instance;
      final val = await db.getSetting('non_existent_key', defaultValue: 'default_val');
      expect(val, 'default_val');
    });

    test('setSetting persists and overrides setting value', () async {
      final db = DatabaseHelper.instance;
      await db.setSetting('theme_preference', 'dark');
      expect(await db.getSetting('theme_preference'), 'dark');

      await db.setSetting('theme_preference', 'light');
      expect(await db.getSetting('theme_preference'), 'light');
    });

    test('getPrivacyMode defaults to false and setPrivacyMode toggles it', () async {
      final db = DatabaseHelper.instance;
      expect(await db.getPrivacyMode(), isFalse);

      await db.setPrivacyMode(true);
      expect(await db.getPrivacyMode(), isTrue);

      await db.setPrivacyMode(false);
      expect(await db.getPrivacyMode(), isFalse);
    });

    test('getStartInPrivacyMode defaults to false and setStartInPrivacyMode toggles it', () async {
      final db = DatabaseHelper.instance;
      expect(await db.getStartInPrivacyMode(), isFalse);

      await db.setStartInPrivacyMode(true);
      expect(await db.getStartInPrivacyMode(), isTrue);

      await db.setStartInPrivacyMode(false);
      expect(await db.getStartInPrivacyMode(), isFalse);
    });

    test('initStartupPrivacyMode sets privacy to true when start_in_privacy_mode is enabled', () async {
      final db = DatabaseHelper.instance;
      // Default: disabled -> init sets privacyMode to false
      await db.setPrivacyMode(true);
      await db.initStartupPrivacyMode();
      expect(await db.getPrivacyMode(), isFalse);

      // When enabled -> init sets privacyMode to true
      await db.setStartInPrivacyMode(true);
      await db.setPrivacyMode(false);
      await db.initStartupPrivacyMode();
      expect(await db.getPrivacyMode(), isTrue);
    });
  });

  group('Dashboard Privacy Masking & UI Formatting Tests', () {
    test('AppFormatters masks all currency types when private', () {
      // Main balance
      expect(AppFormatters.currency(50000, isPrivate: false), '₹50,000');
      expect(AppFormatters.currency(50000, isPrivate: true), '••••••');

      // Compact currency (formula pills, goal amounts, budget caps)
      expect(AppFormatters.compactCurrency(15000, isPrivate: false), '₹15.0k');
      expect(AppFormatters.compactCurrency(15000, isPrivate: true), '••••');

      expect(AppFormatters.compactCurrency(250000, isPrivate: false), '₹2.5L');
      expect(AppFormatters.compactCurrency(250000, isPrivate: true), '••••');

      expect(AppFormatters.compactCurrency(15000000, isPrivate: false), '₹1.5Cr');
      expect(AppFormatters.compactCurrency(15000000, isPrivate: true), '••••');
    });

    testWidgets('renders masked budget snapshot and goal targets when isPrivate is true',
        (tester) async {
      const isPrivate = true;
      const daysLeft = 17;
      const perDayLeft = 450.0;
      const remainingBudget = 7650.0;
      const totalBudgetLimit = 25000.0;
      const goalSaved = 15000.0;
      const goalTarget = 50000.0;

      final budgetSubtitle =
          '$daysLeft days left (${AppFormatters.compactCurrency(perDayLeft, isPrivate: isPrivate)}/day)';
      final budgetRemaining =
          '${AppFormatters.compactCurrency(remainingBudget, isPrivate: isPrivate)} left of ${AppFormatters.compactCurrency(totalBudgetLimit, isPrivate: isPrivate)}';
      final goalAmount =
          '${AppFormatters.compactCurrency(goalSaved, isPrivate: isPrivate)} / ${AppFormatters.compactCurrency(goalTarget, isPrivate: isPrivate)}';

      expect(budgetSubtitle, '17 days left (••••/day)');
      expect(budgetRemaining, '•••• left of ••••');
      expect(goalAmount, '•••• / ••••');

      // Widget test verifying rendering of masked text elements
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text(budgetSubtitle),
                Text(budgetRemaining),
                Text(goalAmount),
              ],
            ),
          ),
        ),
      );

      expect(find.text('17 days left (••••/day)'), findsOneWidget);
      expect(find.text('•••• left of ••••'), findsOneWidget);
      expect(find.text('•••• / ••••'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing);
    });

    testWidgets('renders unmasked budget snapshot and goal targets when isPrivate is false',
        (tester) async {
      const isPrivate = false;
      const daysLeft = 17;
      const perDayLeft = 450.0;
      const remainingBudget = 7650.0;
      const totalBudgetLimit = 25000.0;
      const goalSaved = 15000.0;
      const goalTarget = 50000.0;

      final budgetSubtitle =
          '$daysLeft days left (${AppFormatters.compactCurrency(perDayLeft, isPrivate: isPrivate)}/day)';
      final budgetRemaining =
          '${AppFormatters.compactCurrency(remainingBudget, isPrivate: isPrivate)} left of ${AppFormatters.compactCurrency(totalBudgetLimit, isPrivate: isPrivate)}';
      final goalAmount =
          '${AppFormatters.compactCurrency(goalSaved, isPrivate: isPrivate)} / ${AppFormatters.compactCurrency(goalTarget, isPrivate: isPrivate)}';

      expect(budgetSubtitle, '17 days left (₹450/day)');
      expect(budgetRemaining, '₹7.7k left of ₹25.0k');
      expect(goalAmount, '₹15.0k / ₹50.0k');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text(budgetSubtitle),
                Text(budgetRemaining),
                Text(goalAmount),
              ],
            ),
          ),
        ),
      );

      expect(find.text('17 days left (₹450/day)'), findsOneWidget);
      expect(find.text('₹7.7k left of ₹25.0k'), findsOneWidget);
      expect(find.text('₹15.0k / ₹50.0k'), findsOneWidget);
      expect(find.textContaining('••••'), findsNothing);
    });
  });

  group('Settings Screen Startup Privacy Preference UI Tests', () {
    testWidgets('renders start in privacy mode switch and toggling persists value', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: BackupRestoreScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byKey(const Key('start_in_privacy_mode_switch'));
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      bool persistedValue = false;
      await tester.runAsync(() async {
        persistedValue = await DatabaseHelper.instance.getStartInPrivacyMode();
      });
      expect(persistedValue, isTrue);
    });
  });

  group('App Startup Privacy Mode Initialization Tests', () {
    testWidgets('DashboardScreen launches with unmasked balances when start_in_privacy_mode is disabled', (tester) async {
      DashboardScreen.resetStartupPrivacyFlag();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.runAsync(() async {
        final db = DatabaseHelper.instance;
        await db.setStartInPrivacyMode(false);
        await db.setPrivacyMode(true); // Leftover from previous session
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }

      expect(find.byTooltip('Hide Balance'), findsOneWidget);
      expect(find.byTooltip('Show Balance'), findsNothing);
    });

    testWidgets('DashboardScreen launches with masked balances when start_in_privacy_mode is enabled', (tester) async {
      DashboardScreen.resetStartupPrivacyFlag();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.runAsync(() async {
        final db = DatabaseHelper.instance;
        await db.setStartInPrivacyMode(true);
        await db.setPrivacyMode(false); // Leftover from previous session
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }

      expect(find.byTooltip('Show Balance'), findsOneWidget);
      expect(find.byTooltip('Hide Balance'), findsNothing);
    });

    testWidgets('DashboardScreen re-masks balances when resuming from background if start_in_privacy_mode is enabled', (tester) async {
      DashboardScreen.resetStartupPrivacyFlag();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.runAsync(() async {
        final db = DatabaseHelper.instance;
        await db.setStartInPrivacyMode(true);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }

      // Starts masked
      expect(find.byTooltip('Show Balance'), findsOneWidget);

      // User reveals balance during session
      await tester.tap(find.byTooltip('Show Balance'));
      await tester.pump();
      expect(find.byTooltip('Hide Balance'), findsOneWidget);

      // App transitions to background and resumes
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      for (int i = 0; i < 10; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Must be re-masked
      expect(find.byTooltip('Show Balance'), findsOneWidget);
      expect(find.byTooltip('Hide Balance'), findsNothing);
    });

    testWidgets('DashboardScreen preserves unmasked balances when resuming from background if start_in_privacy_mode is disabled', (tester) async {
      DashboardScreen.resetStartupPrivacyFlag();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.runAsync(() async {
        final db = DatabaseHelper.instance;
        await db.setStartInPrivacyMode(false);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }

      // Starts unmasked
      expect(find.byTooltip('Hide Balance'), findsOneWidget);

      // App transitions to background and resumes
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      for (int i = 0; i < 10; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Stays unmasked
      expect(find.byTooltip('Hide Balance'), findsOneWidget);
      expect(find.byTooltip('Show Balance'), findsNothing);
    });
  });
}
