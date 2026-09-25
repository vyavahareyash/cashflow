import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/services/database_helper.dart';
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

  group('goal unlock transaction flow', () {
    test(
      'persists typed goal_unlock transaction with goal_id and account_id',
      () async {
        final db = DatabaseHelper.instance;
        final accountId = await db.createAccount(
          Account(name: 'Checking', balance: 500.0, type: 'Bank'),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Emergency Fund',
            totalTarget: 1000.0,
            targetDate: '2027-01-01',
            currentSaved: 0.0,
          ),
        );

        await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: accountId,
          amount: 200.0,
          date: '2026-09-13',
        );

        final unlockTxId = await db.createGoalUnlockTransaction(
          goalId: goalId,
          accountId: accountId,
          amount: 100.0,
          date: '2026-09-14',
          note: 'Partial emergency release',
        );

        expect(unlockTxId, isPositive);

        final transactions = await (await db.database).query(
          'transactions',
          where: 'type = ?',
          whereArgs: ['goal_unlock'],
        );
        expect(transactions, hasLength(1));
        final tx = transactions.first;
        expect(tx['type'], 'goal_unlock');
        expect(tx['account_id'], accountId);
        expect(tx['destination_account_id'], isNull);
        expect(tx['category_id'], isNull);
        expect(tx['goal_id'], goalId);
        expect(tx['amount'], 100.0);
        expect(tx['date'], '2026-09-14');
        expect(tx['note'], 'Partial emergency release');
      },
    );

    test('restores usable balance and decrements goal currentSaved', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Savings', balance: 1000.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Car Repair',
          totalTarget: 500.0,
          targetDate: '2026-12-31',
          currentSaved: 0.0,
        ),
      );

      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 300.0,
        date: '2026-09-13',
      );

      expect(await db.calculateUsableBalance(), 700.0);
      expect(await db.getTotalLockedAmount(), 300.0);

      // Unlock 100
      await db.createGoalUnlockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 100.0,
        date: '2026-09-14',
      );

      expect(await db.calculateUsableBalance(), 800.0);
      expect(await db.getTotalLockedAmount(), 200.0);

      final goals = await db.readAllGoals();
      expect(goals.single.currentSaved, 200.0);

      final locks = await (await db.database).query('locked_allocations');
      expect(locks, hasLength(1));
      expect(locks.first['amount'], 200.0);

      // Physical account balance must remain unchanged
      final accounts = await db.readAllAccounts();
      expect(accounts.single.balance, 1000.0);
    });

    test(
      'removes locked_allocations row completely when fully unlocked',
      () async {
        final db = DatabaseHelper.instance;
        final accountId = await db.createAccount(
          Account(name: 'Vault', balance: 500.0, type: 'Bank'),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Laptop',
            totalTarget: 250.0,
            targetDate: '2027-01-01',
            currentSaved: 0.0,
          ),
        );

        await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: accountId,
          amount: 250.0,
          date: '2026-09-13',
        );

        expect(await db.getTotalLockedAmount(), 250.0);

        await db.createGoalUnlockTransaction(
          goalId: goalId,
          accountId: accountId,
          amount: 250.0,
          date: '2026-09-14',
        );

        expect(await db.calculateUsableBalance(), 500.0);
        expect(await db.getTotalLockedAmount(), 0.0);

        final goals = await db.readAllGoals();
        expect(goals.single.currentSaved, 0.0);

        final locks = await (await db.database).query('locked_allocations');
        expect(locks, isEmpty);
      },
    );

    test(
      'rejects unlock amount greater than locked amount in account',
      () async {
        final db = DatabaseHelper.instance;
        final accountId = await db.createAccount(
          Account(name: 'Checking', balance: 500.0, type: 'Bank'),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Holiday',
            totalTarget: 500.0,
            targetDate: '2027-01-01',
            currentSaved: 0.0,
          ),
        );

        await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: accountId,
          amount: 100.0,
          date: '2026-09-13',
        );

        await expectLater(
          () => db.createGoalUnlockTransaction(
            goalId: goalId,
            accountId: accountId,
            amount: 150.0,
            date: '2026-09-14',
          ),
          throwsStateError,
        );

        // State remains intact
        expect(await db.getTotalLockedAmount(), 100.0);
        final goal = (await db.readAllGoals()).single;
        expect(goal.currentSaved, 100.0);
      },
    );

    test('rejects zero or negative unlock amount', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Checking', balance: 500.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Trip',
          totalTarget: 500.0,
          targetDate: '2027-01-01',
          currentSaved: 0.0,
        ),
      );

      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 100.0,
        date: '2026-09-13',
      );

      await expectLater(
        () => db.createGoalUnlockTransaction(
          goalId: goalId,
          accountId: accountId,
          amount: 0.0,
          date: '2026-09-14',
        ),
        throwsArgumentError,
      );

      await expectLater(
        () => db.createGoalUnlockTransaction(
          goalId: goalId,
          accountId: accountId,
          amount: -50.0,
          date: '2026-09-14',
        ),
        throwsArgumentError,
      );
    });

    test('unlocks goal across multiple accounts creating distinct goal_unlock transactions', () async {
      final db = DatabaseHelper.instance;
      final acc1 = await db.createAccount(
        Account(name: 'Checking', balance: 5000.0, type: 'Bank'),
      );
      final acc2 = await db.createAccount(
        Account(name: 'Savings', balance: 10000.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Renovation',
          totalTarget: 15000.0,
          targetDate: '2027-01-01',
          currentSaved: 0.0,
        ),
      );

      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: acc1,
        amount: 3000.0,
        date: '2026-09-10',
      );
      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: acc2,
        amount: 7000.0,
        date: '2026-09-10',
      );

      expect(await db.calculateUsableBalance(), 5000.0); // 15k - 10k locked
      expect(await db.getTotalLockedAmount(), 10000.0);

      // Unlock 2,000 from acc1 and 4,000 from acc2
      final txIds = await db.createMultiAccountGoalUnlockTransactions(
        goalId: goalId,
        amountsPerAccount: {acc1: 2000.0, acc2: 4000.0},
        date: '2026-09-14',
        note: 'Partial release',
      );

      expect(txIds, hasLength(2));

      final txs = await (await db.database).query(
        'transactions',
        where: 'type = ?',
        whereArgs: ['goal_unlock'],
        orderBy: 'account_id ASC',
      );
      expect(txs, hasLength(2));
      final tx1 = txs.firstWhere((t) => t['account_id'] == acc1);
      expect(tx1['amount'], 2000.0);
      expect(tx1['goal_id'], goalId);

      final tx2 = txs.firstWhere((t) => t['account_id'] == acc2);
      expect(tx2['amount'], 4000.0);
      expect(tx2['goal_id'], goalId);

      // Physical balances remain unchanged (5k, 10k)
      final accounts = await db.readAllAccounts();
      expect(accounts.firstWhere((a) => a.id == acc1).balance, 5000.0);
      expect(accounts.firstWhere((a) => a.id == acc2).balance, 10000.0);

      // Remaining locked allocations: acc1 has 1000, acc2 has 3000 -> total 4000
      expect(await db.getTotalLockedAmount(), 4000.0);
      expect(await db.calculateUsableBalance(), 11000.0); // 15k - 4k locked

      // Goal currentSaved updated to 4000
      final goal = (await db.readAllGoals()).single;
      expect(goal.currentSaved, 4000.0);
    });

    test('fails atomically if any account exceeds locked funds during multi-account unlock', () async {
      final db = DatabaseHelper.instance;
      final acc1 = await db.createAccount(
        Account(name: 'Checking', balance: 5000.0, type: 'Bank'),
      );
      final acc2 = await db.createAccount(
        Account(name: 'Savings', balance: 5000.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Emergency',
          totalTarget: 5000.0,
          targetDate: '2027-01-01',
          currentSaved: 0.0,
        ),
      );

      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: acc1,
        amount: 2000.0,
        date: '2026-09-10',
      );
      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: acc2,
        amount: 2000.0,
        date: '2026-09-10',
      );

      await expectLater(
        () => db.createMultiAccountGoalUnlockTransactions(
          goalId: goalId,
          amountsPerAccount: {
            acc1: 1000.0,
            acc2: 5000.0, // Exceeds 2000 locked
          },
          date: '2026-09-14',
        ),
        throwsStateError,
      );

      // Verification: acc1 remains untouched
      expect(await db.getTotalLockedAmount(), 4000.0);
      final goal = (await db.readAllGoals()).single;
      expect(goal.currentSaved, 4000.0);
    });
  });
}
