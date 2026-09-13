import 'package:cashflow/models/account_model.dart';
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

    test(
      'restores usable balance and decrements goal currentSaved',
      () async {
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
      },
    );

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

    test(
      'rejects zero or negative unlock amount',
      () async {
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
      },
    );
  });
}
