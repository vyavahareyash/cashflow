import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
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

  test(
    'returns all transaction types and related details in date order',
    () async {
      final db = DatabaseHelper.instance;
      final checkingId = await db.createAccount(
        Account(name: 'Checking', balance: 1000.0, type: 'Bank'),
      );
      final savingsId = await db.createAccount(
        Account(name: 'Savings', balance: 200.0, type: 'Bank'),
      );
      final categoryId = await db.createCategory(
        Category(name: 'Food', monthlyBudget: 300.0),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Emergency fund',
          totalTarget: 2000.0,
          targetDate: '2027-01-01',
          currentSaved: 0.0,
        ),
      );

      await db.createExpenseTransaction(
        accountId: checkingId,
        categoryId: categoryId,
        amount: 25.0,
        date: '2026-09-01',
      );
      await db.createIncomeTransaction(
        accountId: checkingId,
        amount: 100.0,
        date: '2026-09-02',
      );
      await db.createTransferTransaction(
        sourceAccountId: checkingId,
        destinationAccountId: savingsId,
        amount: 50.0,
        date: '2026-09-03',
      );
      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: checkingId,
        amount: 40.0,
        date: '2026-09-04',
      );
      await db.createGoalUnlockTransaction(
        goalId: goalId,
        accountId: checkingId,
        amount: 10.0,
        date: '2026-09-05',
      );
      await db.createGoalPaymentTransaction(
        goalId: goalId,
        accountId: checkingId,
        amount: 5.0,
        date: '2026-09-06',
      );

      final history = await db.getTransactionHistory();

      expect(history, hasLength(6));
      expect(history.map((row) => row['type']).toList(), [
        'goal_payment',
        'goal_unlock',
        'goal_lock',
        'transfer',
        'income',
        'expense',
      ]);
      expect(history[0]['account_name'], 'Checking');
      expect(history[0]['goal_name'], 'Emergency fund');
      expect(history[3]['destination_account_name'], 'Savings');
      expect(history[5]['category_name'], 'Food');
    },
  );

  test('filters history by type, month, year, and combined criteria', () async {
    final db = DatabaseHelper.instance;
    final accountId = await db.createAccount(
      Account(name: 'Checking', balance: 1000.0, type: 'Bank'),
    );
    final categoryId = await db.createCategory(
      Category(name: 'Food', monthlyBudget: 300.0),
    );

    await db.createExpenseTransaction(
      accountId: accountId,
      categoryId: categoryId,
      amount: 25.0,
      date: '2025-09-01',
    );
    await db.createExpenseTransaction(
      accountId: accountId,
      categoryId: categoryId,
      amount: 30.0,
      date: '2026-08-01',
    );
    await db.createIncomeTransaction(
      accountId: accountId,
      amount: 100.0,
      date: '2026-09-02',
    );

    expect(
      await db.getTransactionHistory(type: 'expense', month: 9, year: 2025),
      hasLength(1),
    );
    expect(await db.getTransactionHistory(month: 8, year: 2026), hasLength(1));
    expect(
      (await db.getTransactionHistory(year: 2026))
          .map((row) => row['type'])
          .toList(),
      ['income', 'expense'],
    );
    expect(
      await db.getTransactionHistory(type: 'transfer', year: 2026),
      isEmpty,
    );
  });

  test('keeps transactions with nullable related records', () async {
    final db = DatabaseHelper.instance;
    final accountId = await db.createAccount(
      Account(name: 'Checking', balance: 100.0, type: 'Bank'),
    );

    await db.createIncomeTransaction(
      accountId: accountId,
      amount: 25.0,
      date: '2026-09-08',
    );

    final history = await db.getTransactionHistory();

    expect(history, hasLength(1));
    expect(history.single['category_name'], isNull);
    expect(history.single['destination_account_name'], isNull);
    expect(history.single['goal_name'], isNull);
  });

  test('filters history by an inclusive date range', () async {
    final db = DatabaseHelper.instance;
    final accountId = await db.createAccount(
      Account(name: 'Checking', balance: 100.0, type: 'Bank'),
    );
    final categoryId = await db.createCategory(
      Category(name: 'Food', monthlyBudget: 300.0),
    );

    await db.createExpenseTransaction(
      accountId: accountId,
      categoryId: categoryId,
      amount: 10.0,
      date: '2026-09-01T09:00:00.000',
    );
    await db.createExpenseTransaction(
      accountId: accountId,
      categoryId: categoryId,
      amount: 20.0,
      date: '2026-09-15T12:00:00.000',
    );
    await db.createExpenseTransaction(
      accountId: accountId,
      categoryId: categoryId,
      amount: 30.0,
      date: '2026-10-01T09:00:00.000',
    );

    final history = await db.getTransactionHistory(
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 30),
    );

    expect(history, hasLength(2));
    expect(history.map((row) => row['amount']), [20.0, 10.0]);
  });

  test('calculates category spending for an inclusive date range', () async {
    final db = DatabaseHelper.instance;
    final accountId = await db.createAccount(
      Account(name: 'Checking', balance: 100.0, type: 'Bank'),
    );
    final categoryId = await db.createCategory(
      Category(name: 'Food', monthlyBudget: 300.0),
    );

    await db.createExpenseTransaction(
      accountId: accountId,
      categoryId: categoryId,
      amount: 10.0,
      date: '2026-09-15T12:00:00.000',
    );
    await db.createExpenseTransaction(
      accountId: accountId,
      categoryId: categoryId,
      amount: 20.0,
      date: '2026-10-01T12:00:00.000',
    );

    final spending = await db.getSpendingByCategoryForDateRange(
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 30),
    );

    expect(spending, {'Food': 10.0});
  });
}
