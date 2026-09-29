import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/screens/history_screen.dart';
import 'package:cashflow/services/database_helper.dart';
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

  testWidgets(
    'Activity ledger excludes locks and unlocks from inflow and outflow',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final db = DatabaseHelper.instance;
      await tester.runAsync(() async {
        final accId = await db.createAccount(
          Account(name: 'Checking', balance: 5000.0, type: 'Bank'),
        );
        final catId = await db.createCategory(
          Category(name: 'Groceries', monthlyBudget: 500.0),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Emergency Fund',
            totalTarget: 2000.0,
            targetDate: '2027-01-01',
            currentSaved: 0.0,
          ),
        );

        // 1. Income of 1000 -> Inflow = 1000
        await db.createIncomeTransaction(
          accountId: accId,
          amount: 1000.0,
          date: '2026-09-01',
          note: 'Salary',
        );

        // 2. Expense of 200 -> Outflow = 200
        await db.createExpenseTransaction(
          accountId: accId,
          categoryId: catId,
          amount: 200.0,
          date: '2026-09-02',
          note: 'Groceries purchase',
        );

        // 3. Goal lock of 400 -> Internal reservation: must NOT change inflow or outflow
        await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: accId,
          amount: 400.0,
          date: '2026-09-03',
          note: 'Lock funds for goal',
        );

        // 4. Goal unlock of 150 -> Internal release: must NOT change inflow or outflow
        await db.createGoalUnlockTransaction(
          goalId: goalId,
          accountId: accId,
          amount: 150.0,
          date: '2026-09-04',
          note: 'Unlock partial funds',
        );
      });

      // Build the HistoryScreen
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HistoryScreen())),
      );

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

      // Verify Outflow shows -₹200 (both in header metric card and in the transaction tile)
      expect(find.text('-₹200'), findsNWidgets(2));
      // Verify Inflow shows +₹1.0k in header metric card (compact currency) and +₹1,000 in transaction tile
      expect(find.text('+₹1.0k'), findsOneWidget);
      expect(find.text('+₹1,000'), findsOneWidget);
      // Verify Net Cashflow in header card shows +₹800 (1000 - 200)
      expect(find.text('+₹800'), findsOneWidget);

      // Ensure internal earmarks (lock & unlock) show without '-' or '+' signs in the list
      expect(find.text('₹400'), findsOneWidget);
      expect(find.text('-₹400'), findsNothing);
      expect(find.text('+₹400'), findsNothing);

      expect(find.text('₹150'), findsOneWidget);
      expect(find.text('-₹150'), findsNothing);
      expect(find.text('+₹150'), findsNothing);

      // Ensure transactions render in the list
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Groceries purchase'), findsOneWidget);
      expect(find.text('Lock funds for goal'), findsOneWidget);
      expect(find.text('Unlock partial funds'), findsOneWidget);
    },
  );
}
