import 'dart:io';

import 'package:cashflow/components/app_dialogs.dart';
import 'package:cashflow/components/custom_button.dart';
import 'package:cashflow/components/custom_card.dart';
import 'package:cashflow/main.dart';
import 'package:cashflow/screens/dashboard_screen.dart';
import 'package:cashflow/screens/history_screen.dart';
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
  DatabaseHelper.setTestDatabaseName(inMemoryDatabasePath);
  const databaseFileName = 'money_tracker.db';

  late Directory tempDir;

  Future<void> settleApp(WidgetTester tester) async {
    await tester.pump();
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  setUp(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
    tempDir = await Directory.systemTemp.createTemp('cashflow_resp_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
    await DatabaseHelper.instance.seedDatabase();
    await DatabaseHelper.instance.setWalkthroughCompleted(completed: true);
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

  group('Issue #151: AppBreakpoints Specification', () {
    test('defines correct breakpoint dimensions and helper functions', () {
      expect(AppBreakpoints.compactMaxWidth, 640.0);
      expect(AppBreakpoints.mediumMaxWidth, 1024.0);
      expect(AppBreakpoints.maxDialogWidth, 560.0);
      expect(AppBreakpoints.maxModalSheetWidth, 640.0);
      expect(AppBreakpoints.maxContentWidth, 1200.0);

      expect(AppBreakpoints.isCompactWidth(390.0), isTrue);
      expect(AppBreakpoints.isCompactWidth(639.9), isTrue);
      expect(AppBreakpoints.isCompactWidth(640.0), isFalse);
      expect(AppBreakpoints.isCompactWidth(1024.0), isFalse);

      expect(AppBreakpoints.isWideWidth(390.0), isFalse);
      expect(AppBreakpoints.isWideWidth(639.9), isFalse);
      expect(AppBreakpoints.isWideWidth(640.0), isTrue);
      expect(AppBreakpoints.isWideWidth(1280.0), isTrue);
    });

    testWidgets('evaluates context correctly for compact and wide screens', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool? isCompactResult;
      bool? isWideResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isCompactResult = AppBreakpoints.isCompact(context);
              isWideResult = AppBreakpoints.isWide(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(isCompactResult, isTrue);
      expect(isWideResult, isFalse);

      // Now resize to wide viewport
      tester.view.physicalSize = const Size(900, 800);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isCompactResult = AppBreakpoints.isCompact(context);
              isWideResult = AppBreakpoints.isWide(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(isCompactResult, isFalse);
      expect(isWideResult, isTrue);
    });
  });

  group('Issue #151: MainNavigationScreen Adaptive Navigation', () {
    testWidgets('renders bottom navigation bar on compact viewport (<640px)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(home: MainNavigationScreen(onThemeToggle: () {})),
      );
      await settleApp(tester);

      // NavigationRail should NOT be present on compact
      expect(find.byType(NavigationRail), findsNothing);

      // Floating bottom navigation bar items should exist
      expect(find.byKey(const Key('nav_item_0')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_1')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_2')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_3')), findsOneWidget);
    });

    testWidgets('renders NavigationRail on wide desktop viewport (>=640px)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(home: MainNavigationScreen(onThemeToggle: () {})),
      );
      await settleApp(tester);

      // NavigationRail should be present
      expect(find.byType(NavigationRail), findsOneWidget);

      // Voice entry button should be present in NavigationRail leading area
      expect(
        find.byKey(const Key('dashboard_voice_entry_fab')),
        findsOneWidget,
      );

      // Destination icons should be present
      expect(find.byKey(const Key('nav_item_0')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_1')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_2')), findsOneWidget);
      expect(find.byKey(const Key('nav_item_3')), findsOneWidget);

      // Switching destination works via NavigationRail
      await tester.tap(find.byKey(const Key('nav_item_1')));
      await settleApp(tester);

      expect(find.text('Activity Ledger'), findsWidgets);
    });
  });

  group('Issue #151: Dashboard Multi-Column Layout', () {
    testWidgets('renders single column layout on compact viewports (<640px)', (
      tester,
    ) async {
      DashboardScreen.resetStartupPrivacyFlag();
      tester.view.physicalSize = const Size(480, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardScreen(onNavigateTab: (_, {subTabIndex}) {}),
          ),
        ),
      );
      await settleApp(tester);

      // In compact view, main content renders
      expect(
        find.byKey(const Key('dashboard_log_transaction_action')),
        findsOneWidget,
      );
      expect(find.text('Monthly Budget Pace'), findsOneWidget);
      expect(find.text('Physical Accounts'), findsOneWidget);
    });

    testWidgets('renders 2-column layout on wide viewports (>=640px)', (
      tester,
    ) async {
      DashboardScreen.resetStartupPrivacyFlag();
      tester.view.physicalSize = const Size(960, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardScreen(onNavigateTab: (_, {subTabIndex}) {}),
          ),
        ),
      );
      await settleApp(tester);

      // Both left and right column elements should be visible
      expect(
        find.byKey(const Key('dashboard_log_transaction_action')),
        findsOneWidget,
      );
      expect(find.text('Monthly Budget Pace'), findsOneWidget);
      expect(find.text('Physical Accounts'), findsOneWidget);
      expect(find.text('Sinking Funds & Goals'), findsOneWidget);
    });
  });

  group('Issue #151: History Screen Multi-Column Layout', () {
    testWidgets('renders 2-column layout on wide viewports without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(960, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HistoryScreen())),
      );
      await settleApp(tester);

      expect(
        find.byKey(const Key('activity_ledger_search_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('activity_ledger_pick_period_btn')),
        findsOneWidget,
      );
    });
  });

  group('Issue #151: Modal Constraints & Mouse Cursors', () {
    testWidgets('AppDialogs.showWarning constrains width to maxDialogWidth', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AppDialogs.showWarning(
                  context,
                  title: 'Wide Test',
                  message: 'Constraint verification',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Check rendered dialog size
      final alertDialogFinder = find.byType(AlertDialog);
      expect(alertDialogFinder, findsOneWidget);
      final size = tester.getSize(alertDialogFinder);
      expect(size.width, lessThanOrEqualTo(AppBreakpoints.maxDialogWidth));
    });

    testWidgets('CustomCard and CustomButton provide click mouse cursor', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CustomCard(onTap: () {}, child: const Text('Card with Tap')),
                CustomButton(label: 'Action', onPressed: () {}),
              ],
            ),
          ),
        ),
      );

      final inkWellFinder = find.byWidgetPredicate(
        (w) => w is InkWell && w.mouseCursor == SystemMouseCursors.click,
      );
      expect(inkWellFinder, findsWidgets);
    });
  });
}
