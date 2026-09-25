import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/goal_model.dart';
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

  Future<Account> getAccount(DatabaseHelper db, int id) async {
    final accounts = await db.readAllAccounts();
    return accounts.firstWhere((a) => a.id == id);
  }

  Future<Goal> getGoal(DatabaseHelper db, int id) async {
    final goals = await db.readAllGoals();
    return goals.firstWhere((g) => g.id == id);
  }

  Future<List<Map<String, dynamic>>> getLocks(
    DatabaseHelper db,
    int goalId,
  ) async {
    final rawDb = await db.database;
    return await rawDb.query(
      'locked_allocations',
      where: 'goal_id = ?',
      whereArgs: [goalId],
    );
  }

  group('Transaction deletion atomic rollbacks', () {
    test('expense deletion restores account balance', () async {
      final db = DatabaseHelper.instance;
      final accId = await db.createAccount(
        Account(name: 'Checking', balance: 500.0, type: 'Bank'),
      );
      final catId = await db.createCategory(
        Category(name: 'Food', monthlyBudget: 200.0),
      );

      final txId = await db.createExpenseTransaction(
        accountId: accId,
        categoryId: catId,
        amount: 50.0,
        date: '2026-09-01',
      );

      var acc = await getAccount(db, accId);
      expect(acc.balance, 450.0);

      await db.deleteTransaction(txId);

      acc = await getAccount(db, accId);
      expect(acc.balance, 500.0);
      final history = await db.getTransactionHistory();
      expect(history, isEmpty);
    });

    test('income deletion deducts deposited amount from account', () async {
      final db = DatabaseHelper.instance;
      final accId = await db.createAccount(
        Account(name: 'Checking', balance: 500.0, type: 'Bank'),
      );

      final txId = await db.createIncomeTransaction(
        accountId: accId,
        amount: 200.0,
        date: '2026-09-02',
      );

      var acc = await getAccount(db, accId);
      expect(acc.balance, 700.0);

      await db.deleteTransaction(txId);

      acc = await getAccount(db, accId);
      expect(acc.balance, 500.0);
    });

    test(
      'transfer deletion rolls back both source and destination accounts',
      () async {
        final db = DatabaseHelper.instance;
        final srcId = await db.createAccount(
          Account(name: 'Checking', balance: 500.0, type: 'Bank'),
        );
        final destId = await db.createAccount(
          Account(name: 'Savings', balance: 100.0, type: 'Bank'),
        );

        final txId = await db.createTransferTransaction(
          sourceAccountId: srcId,
          destinationAccountId: destId,
          amount: 150.0,
          date: '2026-09-03',
        );

        var src = await getAccount(db, srcId);
        var dest = await getAccount(db, destId);
        expect(src.balance, 350.0);
        expect(dest.balance, 250.0);

        await db.deleteTransaction(txId);

        src = await getAccount(db, srcId);
        dest = await getAccount(db, destId);
        expect(src.balance, 500.0);
        expect(dest.balance, 100.0);
      },
    );

    test(
      'goal_lock deletion reverses locked allocation and goal currentSaved',
      () async {
        final db = DatabaseHelper.instance;
        final accId = await db.createAccount(
          Account(name: 'Checking', balance: 500.0, type: 'Bank'),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Vacation',
            totalTarget: 1000.0,
            targetDate: '2027-01-01',
            currentSaved: 0.0,
          ),
        );

        final txId = await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: accId,
          amount: 200.0,
          date: '2026-09-04',
        );

        var goal = await getGoal(db, goalId);
        var locked = await getLocks(db, goalId);
        expect(goal.currentSaved, 200.0);
        expect(locked.first['amount'], 200.0);

        await db.deleteTransaction(txId);

        goal = await getGoal(db, goalId);
        locked = await getLocks(db, goalId);
        expect(goal.currentSaved, 0.0);
        expect(locked, isEmpty);
      },
    );

    test(
      'goal_unlock deletion restores locked allocation and goal currentSaved',
      () async {
        final db = DatabaseHelper.instance;
        final accId = await db.createAccount(
          Account(name: 'Checking', balance: 500.0, type: 'Bank'),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Vacation',
            totalTarget: 1000.0,
            targetDate: '2027-01-01',
            currentSaved: 0.0,
          ),
        );

        await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: accId,
          amount: 200.0,
          date: '2026-09-04',
        );

        final unlockTxId = await db.createGoalUnlockTransaction(
          goalId: goalId,
          accountId: accId,
          amount: 50.0,
          date: '2026-09-05',
        );

        var goal = await getGoal(db, goalId);
        var locked = await getLocks(db, goalId);
        expect(goal.currentSaved, 150.0);
        expect(locked.first['amount'], 150.0);

        await db.deleteTransaction(unlockTxId);

        goal = await getGoal(db, goalId);
        locked = await getLocks(db, goalId);
        expect(goal.currentSaved, 200.0);
        expect(locked.first['amount'], 200.0);
      },
    );

    test('goal_payment deletion restores account balance, locked allocation, and goal', () async {
      final db = DatabaseHelper.instance;
      final accId = await db.createAccount(
        Account(name: 'Checking', balance: 500.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Laptop',
          totalTarget: 1000.0,
          targetDate: '2027-01-01',
          currentSaved: 0.0,
        ),
      );

      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accId,
        amount: 300.0,
        date: '2026-09-04',
      );

      final payTxId = await db.createGoalPaymentTransaction(
        goalId: goalId,
        accountId: accId,
        amount: 100.0,
        date: '2026-09-06',
      );

      var acc = await getAccount(db, accId);
      var goal = await getGoal(db, goalId);
      var locked = await getLocks(db, goalId);
      expect(acc.balance, 400.0);
      expect(goal.currentSaved, 200.0);
      expect(locked.first['amount'], 200.0);

      await db.deleteTransaction(payTxId);

      acc = await getAccount(db, accId);
      goal = await getGoal(db, goalId);
      locked = await getLocks(db, goalId);
      expect(acc.balance, 500.0);
      expect(goal.currentSaved, 300.0);
      expect(locked.first['amount'], 300.0);
    });
  });

  group('Transaction update logic', () {
    test(
      'expense update adjusts balance on amount and account change',
      () async {
        final db = DatabaseHelper.instance;
        final acc1 = await db.createAccount(
          Account(name: 'Checking', balance: 500.0, type: 'Bank'),
        );
        final acc2 = await db.createAccount(
          Account(name: 'Wallet', balance: 200.0, type: 'Cash'),
        );
        final cat1 = await db.createCategory(
          Category(name: 'Food', monthlyBudget: 100.0),
        );
        final cat2 = await db.createCategory(
          Category(name: 'Transport', monthlyBudget: 100.0),
        );

        final txId = await db.createExpenseTransaction(
          accountId: acc1,
          categoryId: cat1,
          amount: 50.0,
          date: '2026-09-01',
        );

        await db.updateTransaction(
          id: txId,
          amount: 80.0,
          date: '2026-09-01',
          accountId: acc1,
          categoryId: cat2,
          note: 'Updated dinner',
        );

        var a1 = await getAccount(db, acc1);
        expect(a1.balance, 420.0);
        final tx = (await db.getTransactionHistory()).first;
        expect(tx['amount'], 80.0);
        expect(tx['category_name'], 'Transport');
        expect(tx['note'], 'Updated dinner');

        await db.updateTransaction(
          id: txId,
          amount: 80.0,
          date: '2026-09-01',
          accountId: acc2,
          categoryId: cat2,
        );

        a1 = await getAccount(db, acc1);
        final a2 = await getAccount(db, acc2);
        expect(a1.balance, 500.0);
        expect(a2.balance, 120.0);
      },
    );

    test(
      'income update adjusts balance on amount and account change',
      () async {
        final db = DatabaseHelper.instance;
        final acc1 = await db.createAccount(
          Account(name: 'Checking', balance: 500.0, type: 'Bank'),
        );
        final acc2 = await db.createAccount(
          Account(name: 'Savings', balance: 1000.0, type: 'Bank'),
        );

        final txId = await db.createIncomeTransaction(
          accountId: acc1,
          amount: 100.0,
          date: '2026-09-01',
        );
        expect((await getAccount(db, acc1)).balance, 600.0);

        await db.updateTransaction(
          id: txId,
          amount: 150.0,
          date: '2026-09-01',
          accountId: acc1,
        );
        expect((await getAccount(db, acc1)).balance, 650.0);

        await db.updateTransaction(
          id: txId,
          amount: 150.0,
          date: '2026-09-01',
          accountId: acc2,
        );
        expect((await getAccount(db, acc1)).balance, 500.0);
        expect((await getAccount(db, acc2)).balance, 1150.0);
      },
    );

    test('transfer update shifts source, destination, and amount', () async {
      final db = DatabaseHelper.instance;
      final acc1 = await db.createAccount(
        Account(name: 'A', balance: 500.0, type: 'Bank'),
      );
      final acc2 = await db.createAccount(
        Account(name: 'B', balance: 500.0, type: 'Bank'),
      );
      final acc3 = await db.createAccount(
        Account(name: 'C', balance: 500.0, type: 'Bank'),
      );

      final txId = await db.createTransferTransaction(
        sourceAccountId: acc1,
        destinationAccountId: acc2,
        amount: 100.0,
        date: '2026-09-01',
      );
      expect((await getAccount(db, acc1)).balance, 400.0);
      expect((await getAccount(db, acc2)).balance, 600.0);
      expect((await getAccount(db, acc3)).balance, 500.0);

      await db.updateTransaction(
        id: txId,
        amount: 200.0,
        date: '2026-09-01',
        accountId: acc1,
        destinationAccountId: acc3,
      );

      expect((await getAccount(db, acc1)).balance, 300.0);
      expect((await getAccount(db, acc2)).balance, 500.0);
      expect((await getAccount(db, acc3)).balance, 700.0);
    });
  });

  group('Transaction ledger filtering and summary aggregation', () {
    test('computes correct period outflow, inflow, and net cashflow', () async {
      final db = DatabaseHelper.instance;
      final accId = await db.createAccount(
        Account(name: 'Checking', balance: 1000.0, type: 'Bank'),
      );
      final catId = await db.createCategory(
        Category(name: 'Food', monthlyBudget: 300.0),
      );

      await db.createExpenseTransaction(
        accountId: accId,
        categoryId: catId,
        amount: 60.0,
        date: '2026-09-10',
      );
      await db.createIncomeTransaction(
        accountId: accId,
        amount: 200.0,
        date: '2026-09-15',
      );
      await db.createExpenseTransaction(
        accountId: accId,
        categoryId: catId,
        amount: 40.0,
        date: '2026-08-15',
      );

      final sepHistory = await db.getTransactionHistory(month: 9, year: 2026);
      expect(sepHistory, hasLength(2));

      double outflow = 0;
      double inflow = 0;
      for (final tx in sepHistory) {
        final amt = (tx['amount'] as num).toDouble();
        final type = tx['type'] as String;
        if (type == 'expense' ||
            type == 'goal_payment' ||
            type == 'goal_lock') {
          outflow += amt;
        } else if (type == 'income' || type == 'goal_unlock') {
          inflow += amt;
        }
      }

      expect(outflow, 60.0);
      expect(inflow, 200.0);
      expect(inflow - outflow, 140.0);
    });

    testWidgets('renders period summary card with outflow, inflow, and net', (
      tester,
    ) async {
      const totalOutflow = 1500.0;
      const totalInflow = 4000.0;
      const netCashflow = totalInflow - totalOutflow;
      const txCount = 12;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              key: const Key('activity_ledger_period_card'),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      const Column(children: [Text('Outflow'), Text('-₹1.5k')]),
                      const Column(children: [Text('Inflow'), Text('+₹4.0k')]),
                      Column(
                        children: [
                          const Text('Net'),
                          Text(
                            '+${AppFormatters.compactCurrency(netCashflow)}',
                          ),
                        ],
                      ),
                      const Column(children: [Text('Count'), Text('$txCount')]),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('activity_ledger_period_card')),
        findsOneWidget,
      );
      expect(find.text('Outflow'), findsOneWidget);
      expect(find.text('-₹1.5k'), findsOneWidget);
      expect(find.text('Inflow'), findsOneWidget);
      expect(find.text('+₹4.0k'), findsOneWidget);
      expect(find.text('Net'), findsOneWidget);
      expect(find.text('+₹2.5k'), findsOneWidget);
      expect(find.text('Count'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });
  });
}
