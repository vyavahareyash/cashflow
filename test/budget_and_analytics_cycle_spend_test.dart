import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/screens/analytics_screen.dart';
import 'package:cashflow/screens/budget_screen.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.setTestDatabaseName(inMemoryDatabasePath);
  const databaseFileName = 'money_tracker.db';

  setUp(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
  });

  tearDown(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
  });

  Future<void> pumpUntilLoaded(WidgetTester tester) async {
    for (int i = 0; i < 30; i++) {
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    await tester.pump();
  }

  testWidgets(
    'BudgetScreen displays budgeted, unbudgeted, and total cycle spend chips',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final db = DatabaseHelper.instance;
      await tester.runAsync(() async {
        final accId = await db.createAccount(
          Account(name: 'Checking', balance: 50000.0, type: 'Bank'),
        );
        final budgetedCatId = await db.createCategory(
          Category(name: 'Groceries', monthlyBudget: 10000.0),
        );
        final unbudgetedCatId = await db.createCategory(
          Category(name: 'Ad-hoc Gifts', monthlyBudget: null),
        );

        final now = DateTime.now();
        final todayStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T12:00:00.000';

        await db.createExpenseTransaction(
          accountId: accId,
          categoryId: budgetedCatId,
          amount: 3000.0,
          date: todayStr,
        );

        await db.createExpenseTransaction(
          accountId: accId,
          categoryId: unbudgetedCatId,
          amount: 1500.0,
          date: todayStr,
        );
      });

      await tester.pumpWidget(const MaterialApp(home: BudgetScreen()));
      await pumpUntilLoaded(tester);

      // Header card "Spent so far" only has budgeted spend
      expect(find.text('Spent so far'), findsOneWidget);
      expect(find.text(AppFormatters.currency(3000.0)), findsWidgets);

      // Summary chips display Budgeted, Unbudgeted, and Total Cycle Outflow
      expect(find.text('Budgeted: '), findsOneWidget);
      expect(find.text('Unbudgeted: '), findsOneWidget);
      expect(find.text('Total Cycle Outflow: '), findsOneWidget);

      // Unbudgeted chip shows 1,500 and Total Cycle Outflow shows 4,500
      expect(find.text(AppFormatters.currency(1500.0)), findsWidgets);
      expect(find.text(AppFormatters.currency(4500.0)), findsOneWidget);
    },
  );

  testWidgets(
    'AnalyticsScreen defaults to Current Cycle tab and switches between tabs',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final db = DatabaseHelper.instance;
      await tester.runAsync(() async {
        final accId = await db.createAccount(
          Account(name: 'Checking', balance: 50000.0, type: 'Bank'),
        );
        final catId = await db.createCategory(
          Category(name: 'Dining', monthlyBudget: 5000.0),
        );

        final now = DateTime.now();
        final todayStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T12:00:00.000';

        await db.createExpenseTransaction(
          accountId: accId,
          categoryId: catId,
          amount: 2500.0,
          date: todayStr,
        );
      });

      await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
      await pumpUntilLoaded(tester);

      // Verify 3 tabs exist
      expect(find.text('Current Cycle'), findsOneWidget);
      expect(find.text('Custom Range'), findsOneWidget);
      expect(find.text('Year-to-Date (YTD)'), findsOneWidget);

      // Verify initial mode is Current Cycle
      expect(find.text('Active Salary Cycle'), findsOneWidget);
      expect(find.text('Day 1 Anchor'), findsOneWidget);
      expect(
        find.text('Total: ${AppFormatters.currency(2500.0)}'),
        findsOneWidget,
      );

      // Switch to Custom Range
      await tester.tap(find.text('Custom Range'));
      await pumpUntilLoaded(tester);

      expect(find.text('Custom Spending Period'), findsOneWidget);
      expect(find.byIcon(Icons.date_range_rounded), findsOneWidget);

      // Switch to YTD
      await tester.tap(find.text('Year-to-Date (YTD)'));
      await pumpUntilLoaded(tester);

      expect(find.text('Cumulative Period'), findsOneWidget);
      expect(find.text('YTD Cashflow Summary'), findsOneWidget);
    },
  );
}
