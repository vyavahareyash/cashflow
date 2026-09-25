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

  group('goal lock transaction flow', () {
    test(
      'persists typed goal_lock transaction with goal_id and account_id',
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

        final txId = await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: accountId,
          amount: 150.0,
          date: '2026-09-13',
          note: 'Emergency savings allocation',
        );

        expect(txId, isPositive);

        final transactions = await (await db.database).query('transactions');
        expect(transactions, hasLength(1));
        final tx = transactions.first;
        expect(tx['type'], 'goal_lock');
        expect(tx['account_id'], accountId);
        expect(tx['destination_account_id'], isNull);
        expect(tx['category_id'], isNull);
        expect(tx['goal_id'], goalId);
        expect(tx['amount'], 150.0);
        expect(tx['date'], '2026-09-13');
        expect(tx['note'], 'Emergency savings allocation');
      },
    );

    test(
      'locks funds without changing total physical account balance',
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

        final beforeAccounts = await db.readAllAccounts();
        final beforeBalance = beforeAccounts.fold<double>(
          0.0,
          (sum, a) => sum + a.balance,
        );

        await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: accountId,
          amount: 300.0,
          date: '2026-09-13',
        );

        final afterAccounts = await db.readAllAccounts();
        final afterBalance = afterAccounts.fold<double>(
          0.0,
          (sum, a) => sum + a.balance,
        );
        expect(afterBalance, beforeBalance);
        expect(afterAccounts.single.balance, 1000.0);

        final goals = await db.readAllGoals();
        expect(goals.single.currentSaved, 300.0);

        final locks = await (await db.database).query('locked_allocations');
        expect(locks, hasLength(1));
        expect(locks.first['goal_id'], goalId);
        expect(locks.first['account_id'], accountId);
        expect(locks.first['amount'], 300.0);
      },
    );

    test('reduces usable balance by the locked amount', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Checking', balance: 400.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Vacation',
          totalTarget: 500.0,
          targetDate: '2027-06-01',
          currentSaved: 0.0,
        ),
      );

      expect(await db.calculateUsableBalance(), 400.0);

      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 150.0,
        date: '2026-09-13',
      );

      expect(await db.calculateUsableBalance(), 250.0);
      expect(await db.getTotalLockedAmount(), 150.0);
    });

    test(
      'rejects zero or negative lock amounts and leaves data unchanged',
      () async {
        final db = DatabaseHelper.instance;
        final accountId = await db.createAccount(
          Account(name: 'Checking', balance: 200.0, type: 'Bank'),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Gadget',
            totalTarget: 300.0,
            targetDate: '2027-01-01',
            currentSaved: 0.0,
          ),
        );

        await expectLater(
          () => db.createGoalLockTransaction(
            goalId: goalId,
            accountId: accountId,
            amount: 0.0,
            date: '2026-09-13',
          ),
          throwsArgumentError,
        );

        await expectLater(
          () => db.createGoalLockTransaction(
            goalId: goalId,
            accountId: accountId,
            amount: -50.0,
            date: '2026-09-13',
          ),
          throwsArgumentError,
        );

        final txs = await (await db.database).query('transactions');
        expect(txs, isEmpty);
        final locks = await (await db.database).query('locked_allocations');
        expect(locks, isEmpty);
        final goal = (await db.readAllGoals()).single;
        expect(goal.currentSaved, 0.0);
      },
    );

    test(
      'rejects lock amount exceeding available account balance and rolls back',
      () async {
        final db = DatabaseHelper.instance;
        final accountId = await db.createAccount(
          Account(name: 'Checking', balance: 100.0, type: 'Bank'),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Laptop',
            totalTarget: 500.0,
            targetDate: '2027-01-01',
            currentSaved: 0.0,
          ),
        );

        await expectLater(
          () => db.createGoalLockTransaction(
            goalId: goalId,
            accountId: accountId,
            amount: 150.0,
            date: '2026-09-13',
          ),
          throwsStateError,
        );

        final txs = await (await db.database).query('transactions');
        expect(txs, isEmpty);
        final locks = await (await db.database).query('locked_allocations');
        expect(locks, isEmpty);
        final goal = (await db.readAllGoals()).single;
        expect(goal.currentSaved, 0.0);
      },
    );

    test(
      'rejects lock when account or goal is missing and rolls back completely',
      () async {
        final db = DatabaseHelper.instance;
        final accountId = await db.createAccount(
          Account(name: 'Checking', balance: 100.0, type: 'Bank'),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Laptop',
            totalTarget: 500.0,
            targetDate: '2027-01-01',
            currentSaved: 0.0,
          ),
        );

        // Missing account
        await expectLater(
          () => db.createGoalLockTransaction(
            goalId: goalId,
            accountId: 9999,
            amount: 50.0,
            date: '2026-09-13',
          ),
          throwsStateError,
        );

        // Missing goal
        await expectLater(
          () => db.createGoalLockTransaction(
            goalId: 9999,
            accountId: accountId,
            amount: 50.0,
            date: '2026-09-13',
          ),
          throwsStateError,
        );

        final txs = await (await db.database).query('transactions');
        expect(txs, isEmpty);
        final locks = await (await db.database).query('locked_allocations');
        expect(locks, isEmpty);
        final goal = (await db.readAllGoals()).single;
        expect(goal.currentSaved, 0.0);
      },
    );

    test('cumulatively tracks multiple goal locks from the same account up to the balance', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Checking', balance: 100.0, type: 'Bank'),
      );
      final goal1 = await db.createGoal(
        Goal(
          name: 'Goal 1',
          totalTarget: 100.0,
          targetDate: '2027-01-01',
          currentSaved: 0.0,
        ),
      );
      final goal2 = await db.createGoal(
        Goal(
          name: 'Goal 2',
          totalTarget: 100.0,
          targetDate: '2027-01-01',
          currentSaved: 0.0,
        ),
      );

      await db.createGoalLockTransaction(
        goalId: goal1,
        accountId: accountId,
        amount: 40.0,
        date: '2026-09-13',
      );

      await db.createGoalLockTransaction(
        goalId: goal2,
        accountId: accountId,
        amount: 40.0,
        date: '2026-09-13',
      );

      expect(await db.calculateUsableBalance(), 20.0);
      expect((await db.readAllAccounts()).single.balance, 100.0);

      // Remaining available in account is 20. Trying to lock 30 should fail.
      await expectLater(
        () => db.createGoalLockTransaction(
          goalId: goal1,
          accountId: accountId,
          amount: 30.0,
          date: '2026-09-13',
        ),
        throwsStateError,
      );

      expect(await db.calculateUsableBalance(), 20.0);
      expect((await db.readAllAccounts()).single.balance, 100.0);
    });
  });
}
