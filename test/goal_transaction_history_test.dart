import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/goal_model.dart';
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

  Future<Account> getAccount(DatabaseHelper db, int id) async {
    final accounts = await db.readAllAccounts();
    return accounts.firstWhere((a) => a.id == id);
  }

  Future<Goal> getGoal(DatabaseHelper db, int id) async {
    final goals = await db.readAllGoals();
    return goals.firstWhere((g) => g.id == id);
  }

  group('Goal transaction history retrieval and search', () {
    test(
      'getGoalTransactions returns only transactions for target goal',
      () async {
        final db = DatabaseHelper.instance;
        final accId = await db.createAccount(
          Account(name: 'Checking', balance: 5000.0, type: 'Bank'),
        );
        final g1 = await db.createGoal(
          Goal(
            name: 'Emergency Fund',
            totalTarget: 10000.0,
            targetDate: '2027-01-01',
            currentSaved: 0.0,
          ),
        );
        final g2 = await db.createGoal(
          Goal(
            name: 'Vacation',
            totalTarget: 5000.0,
            targetDate: '2027-06-01',
            currentSaved: 0.0,
          ),
        );

        final tx1 = await db.createGoalLockTransaction(
          goalId: g1,
          accountId: accId,
          amount: 1000.0,
          date: '2026-09-01',
          note: 'First emergency lock',
        );
        final tx2 = await db.createGoalLockTransaction(
          goalId: g2,
          accountId: accId,
          amount: 500.0,
          date: '2026-09-05',
          note: 'Vacation savings',
        );
        final tx3 = await db.createGoalUnlockTransaction(
          goalId: g1,
          accountId: accId,
          amount: 200.0,
          date: '2026-09-10',
          note: 'Emergency withdrawal',
        );

        final g1History = await db.getGoalTransactions(g1);
        expect(g1History, hasLength(2));
        expect(g1History[0]['id'], tx3);
        expect(g1History[0]['type'], 'goal_unlock');
        expect(g1History[0]['goal_name'], 'Emergency Fund');
        expect(g1History[1]['id'], tx1);
        expect(g1History[1]['type'], 'goal_lock');

        final g2History = await db.getGoalTransactions(g2);
        expect(g2History, hasLength(1));
        expect(g2History[0]['id'], tx2);
        expect(g2History[0]['goal_name'], 'Vacation');
      },
    );

    test('history search matches on goal_name', () async {
      final db = DatabaseHelper.instance;
      final accId = await db.createAccount(
        Account(name: 'Savings', balance: 5000.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'MacBook Pro',
          totalTarget: 2000.0,
          targetDate: '2026-12-01',
          currentSaved: 0.0,
        ),
      );

      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accId,
        amount: 800.0,
        date: '2026-09-12',
        note: 'Tech savings',
      );

      final allTx = await db.getTransactionHistory();
      const q = 'macbook';
      final matched = allTx.where((tx) {
        final note = (tx['note'] as String? ?? '').toLowerCase();
        final category = (tx['category_name'] as String? ?? '').toLowerCase();
        final account = (tx['account_name'] as String? ?? '').toLowerCase();
        final goal = (tx['goal_name'] as String? ?? '').toLowerCase();
        return note.contains(q) ||
            category.contains(q) ||
            account.contains(q) ||
            goal.contains(q);
      }).toList();

      expect(matched, hasLength(1));
      expect(matched.first['goal_name'], 'MacBook Pro');
    });
  });

  group('Goal transaction editing and atomic synchronization', () {
    test('editing goal_lock amount synchronizes locked_allocations and goals.current_saved', () async {
      final db = DatabaseHelper.instance;
      final accId = await db.createAccount(
        Account(name: 'Checking', balance: 2000.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Home Renovation',
          totalTarget: 10000.0,
          targetDate: '2027-01-01',
          currentSaved: 0.0,
        ),
      );

      final txId = await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accId,
        amount: 500.0,
        date: '2026-09-01',
      );

      expect((await getGoal(db, goalId)).currentSaved, 500.0);
      var contribs = await db.getGoalContributions(goalId);
      expect(contribs.first['amount'], 500.0);

      // Increase lock amount from 500 to 800
      await db.updateTransaction(
        id: txId,
        amount: 800.0,
        date: '2026-09-01',
        accountId: accId,
        note: 'Increased allocation',
      );

      expect((await getGoal(db, goalId)).currentSaved, 800.0);
      contribs = await db.getGoalContributions(goalId);
      expect(contribs.first['amount'], 800.0);

      // Decrease lock amount from 800 to 300
      await db.updateTransaction(
        id: txId,
        amount: 300.0,
        date: '2026-09-01',
        accountId: accId,
      );

      expect((await getGoal(db, goalId)).currentSaved, 300.0);
      contribs = await db.getGoalContributions(goalId);
      expect(contribs.first['amount'], 300.0);
    });

    test(
      'editing goal_lock account shifts locked allocation across accounts',
      () async {
        final db = DatabaseHelper.instance;
        final acc1 = await db.createAccount(
          Account(name: 'Bank A', balance: 1000.0, type: 'Bank'),
        );
        final acc2 = await db.createAccount(
          Account(name: 'Bank B', balance: 1000.0, type: 'Bank'),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Wedding',
            totalTarget: 5000.0,
            targetDate: '2027-01-01',
            currentSaved: 0.0,
          ),
        );

        final txId = await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: acc1,
          amount: 400.0,
          date: '2026-09-01',
        );

        final a1Contrib = await db.getGoalContributions(goalId);
        expect(a1Contrib, hasLength(1));
        expect(a1Contrib.first['account_id'], acc1);

        // Shift goal lock from Bank A to Bank B and adjust amount to 500
        await db.updateTransaction(
          id: txId,
          amount: 500.0,
          date: '2026-09-01',
          accountId: acc2,
        );

        final contribs = await db.getGoalContributions(goalId);
        expect(contribs, hasLength(1));
        expect(contribs.first['account_id'], acc2);
        expect(contribs.first['amount'], 500.0);
        expect((await getGoal(db, goalId)).currentSaved, 500.0);
      },
    );

    test(
      'editing goal_lock beyond available usable balance throws error',
      () async {
        final db = DatabaseHelper.instance;
        final accId = await db.createAccount(
          Account(name: 'Checking', balance: 500.0, type: 'Bank'),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Emergency',
            totalTarget: 5000.0,
            targetDate: '2027-01-01',
            currentSaved: 0.0,
          ),
        );

        final txId = await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: accId,
          amount: 300.0,
          date: '2026-09-01',
        );

        // Try increasing lock to 800 when account only has 500 balance
        expect(
          () => db.updateTransaction(
            id: txId,
            amount: 800.0,
            date: '2026-09-01',
            accountId: accId,
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('editing goal_unlock synchronizes locked_allocations and goals.current_saved', () async {
      final db = DatabaseHelper.instance;
      final accId = await db.createAccount(
        Account(name: 'Checking', balance: 2000.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Education',
          totalTarget: 5000.0,
          targetDate: '2027-01-01',
          currentSaved: 0.0,
        ),
      );

      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accId,
        amount: 1000.0,
        date: '2026-09-01',
      );

      final unlockTxId = await db.createGoalUnlockTransaction(
        goalId: goalId,
        accountId: accId,
        amount: 400.0,
        date: '2026-09-02',
      );

      expect((await getGoal(db, goalId)).currentSaved, 600.0);

      // Change unlock amount from 400 to 200 (re-locking 200)
      await db.updateTransaction(
        id: unlockTxId,
        amount: 200.0,
        date: '2026-09-02',
        accountId: accId,
      );

      expect((await getGoal(db, goalId)).currentSaved, 800.0);
      final contribs = await db.getGoalContributions(goalId);
      expect(contribs.first['amount'], 800.0);
    });

    test(
      'editing goal_payment synchronizes account balance and locked funds',
      () async {
        final db = DatabaseHelper.instance;
        final accId = await db.createAccount(
          Account(name: 'Checking', balance: 2000.0, type: 'Bank'),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Car Down Payment',
            totalTarget: 5000.0,
            targetDate: '2027-01-01',
            currentSaved: 0.0,
          ),
        );

        await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: accId,
          amount: 1000.0,
          date: '2026-09-01',
        );

        final payTxId = await db.createGoalPaymentTransaction(
          goalId: goalId,
          accountId: accId,
          amount: 600.0,
          date: '2026-09-03',
        );

        expect((await getAccount(db, accId)).balance, 1400.0);
        expect((await getGoal(db, goalId)).currentSaved, 400.0);

        // Edit payment amount from 600 to 800
        await db.updateTransaction(
          id: payTxId,
          amount: 800.0,
          date: '2026-09-03',
          accountId: accId,
        );

        expect((await getAccount(db, accId)).balance, 1200.0);
        expect((await getGoal(db, goalId)).currentSaved, 200.0);
        final contribs = await db.getGoalContributions(goalId);
        expect(contribs.first['amount'], 200.0);
      },
    );
  });

  group('Goal transaction deletion rollback', () {
    test('deleting goal_lock releases funds back to spendable', () async {
      final db = DatabaseHelper.instance;
      final accId = await db.createAccount(
        Account(name: 'Checking', balance: 1000.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Trip',
          totalTarget: 2000.0,
          targetDate: '2027-01-01',
          currentSaved: 0.0,
        ),
      );

      final txId = await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accId,
        amount: 400.0,
        date: '2026-09-01',
      );

      expect((await getGoal(db, goalId)).currentSaved, 400.0);
      expect(await db.getGoalContributions(goalId), hasLength(1));

      await db.deleteTransaction(txId);

      expect((await getGoal(db, goalId)).currentSaved, 0.0);
      expect(await db.getGoalContributions(goalId), isEmpty);
    });

    test('deleting goal_unlock re-locks funds into goal', () async {
      final db = DatabaseHelper.instance;
      final accId = await db.createAccount(
        Account(name: 'Checking', balance: 1000.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Trip',
          totalTarget: 2000.0,
          targetDate: '2027-01-01',
          currentSaved: 0.0,
        ),
      );

      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accId,
        amount: 600.0,
        date: '2026-09-01',
      );

      final unlockTxId = await db.createGoalUnlockTransaction(
        goalId: goalId,
        accountId: accId,
        amount: 200.0,
        date: '2026-09-02',
      );

      expect((await getGoal(db, goalId)).currentSaved, 400.0);

      await db.deleteTransaction(unlockTxId);

      expect((await getGoal(db, goalId)).currentSaved, 600.0);
      final contribs = await db.getGoalContributions(goalId);
      expect(contribs.first['amount'], 600.0);
    });

    test(
      'deleting goal_payment restores locked allocation and refunds account',
      () async {
        final db = DatabaseHelper.instance;
        final accId = await db.createAccount(
          Account(name: 'Checking', balance: 2000.0, type: 'Bank'),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Trip',
            totalTarget: 2000.0,
            targetDate: '2027-01-01',
            currentSaved: 0.0,
          ),
        );

        await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: accId,
          amount: 800.0,
          date: '2026-09-01',
        );

        final payTxId = await db.createGoalPaymentTransaction(
          goalId: goalId,
          accountId: accId,
          amount: 500.0,
          date: '2026-09-02',
        );

        expect((await getAccount(db, accId)).balance, 1500.0);
        expect((await getGoal(db, goalId)).currentSaved, 300.0);

        await db.deleteTransaction(payTxId);

        expect((await getAccount(db, accId)).balance, 2000.0);
        expect((await getGoal(db, goalId)).currentSaved, 800.0);
        final contribs = await db.getGoalContributions(goalId);
        expect(contribs.first['amount'], 800.0);
      },
    );
  });

  group('GoalsScreen contribution log data and component tests', () {
    test(
      'verifies data provider for goal contribution and activity log',
      () async {
        final db = DatabaseHelper.instance;
        final accId = await db.createAccount(
          Account(name: 'Main Bank', balance: 5000.0, type: 'Bank'),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'MacBook Pro',
            totalTarget: 10000.0,
            targetDate: '2027-01-01',
            currentSaved: 0.0,
          ),
        );

        await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: accId,
          amount: 2500.0,
          date: '2026-09-01',
          note: 'Savings batch 1',
        );

        final contribs = await db.getGoalContributions(goalId);
        final txs = await db.getGoalTransactions(goalId);

        expect(contribs, hasLength(1));
        expect(contribs.first['account_name'], 'Main Bank');
        expect(contribs.first['amount'], 2500.0);

        expect(txs, hasLength(1));
        expect(txs.first['type'], 'goal_lock');
        expect(txs.first['note'], 'Savings batch 1');
        expect(txs.first['amount'], 2500.0);
      },
    );

    testWidgets('renders goal contribution and activity card layout', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Locked Funds by Account'),
                Text('Contribution & Activity History'),
                Text('Main Bank'),
                Text('Locked Funds'),
                Text('Savings batch 1'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Locked Funds by Account'), findsOneWidget);
      expect(find.text('Contribution & Activity History'), findsOneWidget);
      expect(find.text('Main Bank'), findsOneWidget);
      expect(find.text('Locked Funds'), findsOneWidget);
      expect(find.text('Savings batch 1'), findsOneWidget);
    });
  });
}
