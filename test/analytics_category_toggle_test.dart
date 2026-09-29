import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/screens/analytics_screen.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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

  testWidgets('Category donut chart allows hiding and resetting categories', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final db = DatabaseHelper.instance;
    await tester.runAsync(() async {
      final accId = await db.createAccount(
        Account(name: 'Checking', balance: 50000.0, type: 'Bank'),
      );
      final rentId = await db.createCategory(
        Category(name: 'Rent', monthlyBudget: 25000.0),
      );
      final groceriesId = await db.createCategory(
        Category(name: 'Groceries', monthlyBudget: 5000.0),
      );

      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T12:00:00.000';

      await db.createExpenseTransaction(
        accountId: accId,
        categoryId: rentId,
        amount: 20000.0,
        date: todayStr,
      );

      await db.createExpenseTransaction(
        accountId: accId,
        categoryId: groceriesId,
        amount: 5000.0,
        date: todayStr,
      );
    });

    await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
    await pumpUntilLoaded(tester);

    // Verify initial total includes both categories (20000 + 5000 = 25000)
    expect(find.text('Spending by Category'), findsOneWidget);
    expect(
      find.text('Total: ${AppFormatters.currency(25000.0)}'),
      findsOneWidget,
    );
    expect(find.text('Reset'), findsNothing);

    // Tap 'Rent' category row to hide it
    await tester.tap(find.text('Rent'));
    await tester.pump();

    // Now Rent should be hidden, visible total should be Groceries only (5000.0)
    expect(
      find.text('Total: ${AppFormatters.currency(5000.0)}'),
      findsOneWidget,
    );
    expect(find.text('Reset'), findsOneWidget);

    // Tap 'Reset' button to restore all categories
    await tester.tap(find.text('Reset'));
    await tester.pump();

    // Total should be back to 25000.0
    expect(
      find.text('Total: ${AppFormatters.currency(25000.0)}'),
      findsOneWidget,
    );
    expect(find.text('Reset'), findsNothing);
  });

  testWidgets(
    'Monthly spending trends displays controls, baseline cap, and category filter',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final db = DatabaseHelper.instance;
      int rentId = 0;
      int groceriesId = 0;

      await tester.runAsync(() async {
        final accId = await db.createAccount(
          Account(name: 'Checking', balance: 50000.0, type: 'Bank'),
        );
        rentId = await db.createCategory(
          Category(name: 'Rent', monthlyBudget: 25000.0),
        );
        groceriesId = await db.createCategory(
          Category(name: 'Groceries', monthlyBudget: 5000.0),
        );

        final now = DateTime.now();
        final todayStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T12:00:00.000';

        await db.createExpenseTransaction(
          accountId: accId,
          categoryId: rentId,
          amount: 20000.0,
          date: todayStr,
        );

        await db.createExpenseTransaction(
          accountId: accId,
          categoryId: groceriesId,
          amount: 6000.0,
          date: todayStr,
        );
      });

      await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
      await pumpUntilLoaded(tester);

      // Verify Monthly Spending Trends exists
      expect(find.text('Monthly Spending Trends'), findsOneWidget);

      // Duration selector pills (3M, 6M, 12M)
      expect(find.text('3M'), findsOneWidget);
      expect(find.text('6M'), findsOneWidget);
      expect(find.text('12M'), findsOneWidget);

      // All Categories initial budget cap = 25000 + 5000 = 30000
      expect(
        find.text('Cap: ${AppFormatters.compactCurrency(30000.0)}'),
        findsOneWidget,
      );

      // Switch duration to 12M
      await tester.tap(find.text('12M'));
      await pumpUntilLoaded(tester);

      // Open category dropdown and select 'Groceries'
      await tester.tap(find.text('All Categories'));
      await pumpUntilLoaded(tester);

      // Tap Groceries item in dropdown popup
      await tester.tap(find.text('Groceries').last);
      await pumpUntilLoaded(tester);

      // Baseline should update to Groceries budget cap (5000.0)
      expect(
        find.text('Cap: ${AppFormatters.compactCurrency(5000.0)}'),
        findsOneWidget,
      );
      // Since Groceries spent 6000 vs budget 5000, verify over budget indicator
      expect(find.textContaining('over budget'), findsOneWidget);

      // Verify X-axis shows 3-letter month abbreviation (e.g. Sep)
      final currentMonthAbbr = DateFormat('MMM').format(DateTime.now());
      expect(find.text(currentMonthAbbr), findsWidgets);
    },
  );
}
