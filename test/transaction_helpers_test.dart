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
    final path = join(dbPath, databaseFileName);
    await DatabaseHelper.instance.close();
    await deleteDatabase(path);
  });

  tearDown(() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, databaseFileName);
    await DatabaseHelper.instance.close();
    await deleteDatabase(path);
  });

  test('returns zero when no physical or locked funds exist', () async {
    final db = DatabaseHelper.instance;

    expect(await db.calculateUsableBalance(), 0.0);
  });

  test('subtracts locked funds but not tracking-only budgets', () async {
    final db = DatabaseHelper.instance;
    final sourceId = await db.createAccount(
      Account(name: 'Checking', balance: 100.0, type: 'Bank'),
    );
    final destinationId = await db.createAccount(
      Account(name: 'Savings', balance: 50.0, type: 'Bank'),
    );
    final budgetedCategoryId = await db.createCategory(
      Category(name: 'Food', monthlyBudget: 30.0),
    );
    await db.createCategory(Category(name: 'Flexible'));
    final goalId = await db.createGoal(
      Goal(
        name: 'Emergency fund',
        totalTarget: 200.0,
        targetDate: '2027-01-01',
        currentSaved: 0.0,
      ),
    );

    await db.createTransferTransaction(
      sourceAccountId: sourceId,
      destinationAccountId: destinationId,
      amount: 25.0,
      date: '2026-09-08',
    );
    await db.createGoalLockTransaction(
      goalId: goalId,
      accountId: destinationId,
      amount: 40.0,
      date: '2026-09-08',
    );

    expect(await db.calculateUsableBalance(), 110.0);
    expect(
      (await db.readAllAccounts()).fold<double>(
        0.0,
        (total, account) => total + account.balance,
      ),
      150.0,
    );
    expect(
      await db.getCategorySpendingForCurrentMonth(budgetedCategoryId),
      0.0,
    );
  });

  test('keeps budget limits out of usable cash', () async {
    final db = DatabaseHelper.instance;
    await db.createAccount(
      Account(name: 'Checking', balance: 100.0, type: 'Bank'),
    );
    final categoryId = await db.createCategory(
      Category(name: 'Rent', monthlyBudget: 150.0),
    );
    expect(await db.calculateUsableBalance(), 100.0);
    expect((await db.readAllAccounts()).single.balance, 100.0);
    expect(await db.getCategorySpendingForCurrentMonth(categoryId), 0.0);
  });

  test(
    'creates expense and income transactions with balance updates',
    () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Checking', balance: 100.0, type: 'Bank'),
      );
      final categoryId = await db.createCategory(
        Category(name: 'Food', monthlyBudget: 200.0),
      );

      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: categoryId,
        amount: 25.0,
        date: '2026-09-08',
      );
      await db.createIncomeTransaction(
        accountId: accountId,
        amount: 50.0,
        date: '2026-09-08',
      );

      final account = (await db.readAllAccounts()).single;
      expect(account.balance, 125.0);
      final transactions = await (await db.database).query('transactions');
      expect(
        transactions.map((row) => row['type']),
        containsAll(['expense', 'income']),
      );
    },
  );

  test('creates a transfer without changing total physical balance', () async {
    final db = DatabaseHelper.instance;
    final sourceId = await db.createAccount(
      Account(name: 'Checking', balance: 100.0, type: 'Bank'),
    );
    final destinationId = await db.createAccount(
      Account(name: 'Savings', balance: 25.0, type: 'Bank'),
    );

    await db.createTransferTransaction(
      sourceAccountId: sourceId,
      destinationAccountId: destinationId,
      amount: 40.0,
      date: '2026-09-08',
    );

    final accounts = await db.readAllAccounts();
    expect(
      accounts.firstWhere((account) => account.id == sourceId).balance,
      60.0,
    );
    expect(
      accounts.firstWhere((account) => account.id == destinationId).balance,
      65.0,
    );
    final transaction = (await (await db.database).query('transactions'))
        .single;
    expect(transaction['type'], 'transfer');
    expect(transaction['destination_account_id'], destinationId);
  });

  test('creates, unlocks, and pays a goal allocation atomically', () async {
    final db = DatabaseHelper.instance;
    final accountId = await db.createAccount(
      Account(name: 'Checking', balance: 100.0, type: 'Bank'),
    );
    final goalId = await db.createGoal(
      Goal(
        name: 'Emergency fund',
        totalTarget: 200.0,
        targetDate: '2027-01-01',
        currentSaved: 0.0,
      ),
    );

    await db.createGoalLockTransaction(
      goalId: goalId,
      accountId: accountId,
      amount: 60.0,
      date: '2026-09-08',
    );
    expect((await db.readAllAccounts()).single.balance, 100.0);
    expect((await db.readAllGoals()).single.currentSaved, 60.0);

    await db.createGoalUnlockTransaction(
      goalId: goalId,
      accountId: accountId,
      amount: 10.0,
      date: '2026-09-08',
    );
    expect((await db.readAllGoals()).single.currentSaved, 50.0);

    await db.createGoalPaymentTransaction(
      goalId: goalId,
      accountId: accountId,
      amount: 25.0,
      date: '2026-09-08',
    );
    expect((await db.readAllAccounts()).single.balance, 75.0);
    expect((await db.readAllGoals()).single.currentSaved, 25.0);

    final types = (await (await db.database).query('transactions'))
        .map((row) => row['type']);
    expect(types, containsAll(['goal_lock', 'goal_unlock', 'goal_payment']));
  });

  test('rolls back a transfer when an account is missing', () async {
    final db = DatabaseHelper.instance;
    final accountId = await db.createAccount(
      Account(name: 'Checking', balance: 100.0, type: 'Bank'),
    );

    expect(
      () => db.createTransferTransaction(
        sourceAccountId: accountId,
        destinationAccountId: 999,
        amount: 40.0,
        date: '2026-09-08',
      ),
      throwsStateError,
    );

    expect((await db.readAllAccounts()).single.balance, 100.0);
    expect((await (await db.database).query('transactions')), isEmpty);
  });
}
