import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/screens/accounts_screen.dart';
import 'package:cashflow/screens/budget_screen.dart';
import 'package:cashflow/screens/dashboard_screen.dart';
import 'package:cashflow/screens/goals_screen.dart';
import 'package:cashflow/services/database_helper.dart';
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

  setUp(() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, databaseFileName);
    await DatabaseHelper.instance.close();
    await deleteDatabase(path);
    tempDir = await Directory.systemTemp.createTemp(
      'cashflow_accounts_tab_test_',
    );
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
  });

  tearDown(() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, databaseFileName);
    await DatabaseHelper.instance.close();
    await deleteDatabase(path);
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  Future<void> pumpUntilLoaded(WidgetTester tester) async {
    await tester.pump();
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
  }

  group('AccountsScreen Tabs and Header Action Pill Tests', () {
    testWidgets(
      'renders segmented tabs, empty state action pill, and no FloatingActionButton',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: AccountsScreen()));
        await pumpUntilLoaded(tester);

        expect(
          find.byKey(const Key('accounts_page_segmented_tabs')),
          findsOneWidget,
        );
        expect(find.text('Accounts'), findsOneWidget);
        expect(find.text('Budgets'), findsOneWidget);
        expect(find.text('Goals'), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(
          find.byKey(const Key('accounts_empty_add_pill_btn')),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('renders section header action pill when accounts exist', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await DatabaseHelper.instance.createAccount(
          Account(name: 'Main Bank', balance: 5000.0, type: 'Bank'),
        );
      });

      await tester.pumpWidget(const MaterialApp(home: AccountsScreen()));
      await pumpUntilLoaded(tester);

      expect(find.byKey(const Key('accounts_add_pill_btn')), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('respects initialTabIndex and shows budget tab without FAB', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: AccountsScreen(initialTabIndex: 1)),
      );
      await pumpUntilLoaded(tester);

      expect(
        find.byKey(const Key('budget_tab_segmented_button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('budget_add_pill_btn')), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('respects initialTabIndex and shows goals tab without FAB', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: AccountsScreen(initialTabIndex: 2)),
      );
      await pumpUntilLoaded(tester);

      expect(find.byKey(const Key('goals_add_pill_btn')), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('BudgetScreen embedded and standalone does not show FAB', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: BudgetScreen()));
      await pumpUntilLoaded(tester);

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byKey(const Key('budget_add_pill_btn')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('GoalsScreen embedded and standalone does not show FAB', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: GoalsScreen()));
      await pumpUntilLoaded(tester);

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byKey(const Key('goals_add_pill_btn')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('Dashboard quick actions display Goals and Budgets buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DashboardScreen())),
      );
      await pumpUntilLoaded(tester);

      final goalsAction = find.byKey(const Key('dashboard_lock_goal_action'));
      expect(goalsAction, findsOneWidget);
      expect(
        find.descendant(of: goalsAction, matching: find.text('Goals')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: goalsAction,
          matching: find.byIcon(Icons.savings_rounded),
        ),
        findsOneWidget,
      );

      final budgetsAction = find.byKey(
        const Key('dashboard_add_budget_action'),
      );
      expect(budgetsAction, findsOneWidget);
      expect(
        find.descendant(of: budgetsAction, matching: find.text('Budgets')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
      'AccountsScreen resets to Accounts tab (0) when initialTabIndex becomes 0',
      (tester) async {
        int activeTab = 2; // Initially on Goals tab (2)
        late StateSetter setStateCallback;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                setStateCallback = setState;
                return Scaffold(
                  body: AccountsScreen(
                    initialTabIndex: activeTab,
                    onTabChanged: (newTab) => activeTab = newTab,
                  ),
                );
              },
            ),
          ),
        );
        await pumpUntilLoaded(tester);

        expect(find.byKey(const Key('goals_add_pill_btn')), findsOneWidget);

        // Reset to Accounts sub-tab 0
        setStateCallback(() {
          activeTab = 0;
        });
        await tester.pump();
        await pumpUntilLoaded(tester);

        expect(
          find.byKey(const Key('accounts_empty_add_pill_btn')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('goals_add_pill_btn')), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'GoalsScreen shows combined total recommended monthly contribution for next month',
      (tester) async {
        final now = DateTime.now();
        final targetDate1 = DateTime(
          now.year,
          now.month + 2,
          now.day,
        ).toIso8601String().substring(0, 10);
        final targetDate2 = DateTime(
          now.year,
          now.month + 3,
          now.day,
        ).toIso8601String().substring(0, 10);

        final goal1 = Goal(
          name: 'Emergency Fund',
          totalTarget: 6000.0,
          currentSaved: 0.0,
          targetDate: targetDate1,
        );
        final goal2 = Goal(
          name: 'Vacation',
          totalTarget: 9000.0,
          currentSaved: 0.0,
          targetDate: targetDate2,
        );

        await tester.runAsync(() async {
          await DatabaseHelper.instance.createGoal(goal1);
          await DatabaseHelper.instance.createGoal(goal2);
        });

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: GoalsScreen())),
        );
        await pumpUntilLoaded(tester);

        expect(
          find.byKey(const Key('goals_total_recommended_monthly_contribution')),
          findsOneWidget,
        );
        expect(
          find.text('Total Recommended Monthly Contribution'),
          findsOneWidget,
        );
        expect(
          find.text('Combined next month recommendation across goals'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });
}
