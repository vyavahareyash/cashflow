import 'package:cashflow/components/custom_input.dart';
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

  group('Goal payment transaction flow (NEW-021)', () {
    test('persists typed goal_payment transaction with goal_id, account_id, and category_id', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Checking', balance: 5000.0, type: 'Bank'),
      );
      final categoryId = await db.createCategory(
        Category(name: 'Insurance', monthlyBudget: 10000.0),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Car Insurance',
          totalTarget: 10000.0,
          targetDate: '2026-11-30',
          currentSaved: 0.0,
        ),
      );

      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 3000.0,
        date: '2026-09-10',
        note: 'Lock for insurance',
      );

      final paymentTxId = await db.createGoalPaymentTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 2500.0,
        date: '2026-09-14',
        categoryId: categoryId,
        note: 'Annual policy renewal',
      );

      expect(paymentTxId, isPositive);

      final transactions = await (await db.database).query(
        'transactions',
        where: 'id = ?',
        whereArgs: [paymentTxId],
      );
      expect(transactions, hasLength(1));
      final tx = transactions.first;
      expect(tx['type'], 'goal_payment');
      expect(tx['account_id'], accountId);
      expect(tx['destination_account_id'], isNull);
      expect(tx['category_id'], categoryId);
      expect(tx['goal_id'], goalId);
      expect(tx['amount'], 2500.0);
      expect(tx['date'], '2026-09-14');
      expect(tx['note'], 'Annual policy renewal');
    });

    test('atomically reduces physical account balance, locked allocation, and goal currentSaved', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Salary Acc', balance: 20000.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Flight Tickets',
          totalTarget: 15000.0,
          targetDate: '2026-12-25',
          currentSaved: 0.0,
        ),
      );

      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 10000.0,
        date: '2026-09-01',
      );

      // Pre-payment assertions
      expect(await db.calculateUsableBalance(), 10000.0); // 20k - 10k
      expect(await db.getTotalLockedAmount(), 10000.0);

      // Pay 6,000 for flights
      await db.createGoalPaymentTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 6000.0,
        date: '2026-09-14',
        note: 'Airline payment',
      );

      // Physical account balance must be reduced by 6,000 (20k -> 14k)
      final accounts = await db.readAllAccounts();
      expect(accounts.single.balance, 14000.0);

      // Locked allocation must be reduced by 6,000 (10k -> 4k)
      final locks = await (await db.database).query('locked_allocations');
      expect(locks, hasLength(1));
      expect((locks.first['amount'] as num).toDouble(), 4000.0);

      // Goal currentSaved must be reduced by 6,000 (10k -> 4k)
      final goals = await db.readAllGoals();
      expect(goals, hasLength(1));
      expect(goals.single.currentSaved, 4000.0);

      // Usable balance: 14k physical - 4k locked = 10,000
      expect(await db.calculateUsableBalance(), 10000.0);
      expect(await db.getTotalLockedAmount(), 4000.0);
    });

    test(
      'deletes locked allocation row when fully paid but preserves goal entity',
      () async {
        final db = DatabaseHelper.instance;
        final accountId = await db.createAccount(
          Account(name: 'Savings', balance: 5000.0, type: 'Bank'),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Gym Membership',
            totalTarget: 2000.0,
            targetDate: '2026-10-01',
            currentSaved: 0.0,
          ),
        );

        await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: accountId,
          amount: 2000.0,
          date: '2026-09-01',
        );

        await db.createGoalPaymentTransaction(
          goalId: goalId,
          accountId: accountId,
          amount: 2000.0,
          date: '2026-09-14',
          note: 'Pay gym',
        );

        // Locked allocation row is cleaned up
        final locks = await (await db.database).query('locked_allocations');
        expect(locks, isEmpty);

        // Goal is preserved with currentSaved = 0.0
        final goals = await db.readAllGoals();
        expect(goals, hasLength(1));
        expect(goals.single.id, goalId);
        expect(goals.single.currentSaved, 0.0);

        // Physical account balance reduced by 2000 (5000 -> 3000)
        final accounts = await db.readAllAccounts();
        expect(accounts.single.balance, 3000.0);
      },
    );

    test(
      'rejects payment amount exceeding locked allocation in account',
      () async {
        final db = DatabaseHelper.instance;
        final accountId = await db.createAccount(
          Account(name: 'Checking', balance: 10000.0, type: 'Bank'),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Gadget',
            totalTarget: 5000.0,
            targetDate: '2026-12-01',
            currentSaved: 0.0,
          ),
        );

        await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: accountId,
          amount: 1000.0,
          date: '2026-09-01',
        );

        await expectLater(
          () => db.createGoalPaymentTransaction(
            goalId: goalId,
            accountId: accountId,
            amount: 1500.0,
            date: '2026-09-14',
          ),
          throwsStateError,
        );

        // Data untouched
        final accounts = await db.readAllAccounts();
        expect(accounts.single.balance, 10000.0);
        final goals = await db.readAllGoals();
        expect(goals.single.currentSaved, 1000.0);
        expect(await db.getTotalLockedAmount(), 1000.0);
      },
    );

    test('rejects payment amount exceeding account physical balance', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Empty Wallet', balance: 500.0, type: 'Cash'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Emergency',
          totalTarget: 500.0,
          targetDate: '2026-12-01',
          currentSaved: 0.0,
        ),
      );

      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 500.0,
        date: '2026-09-01',
      );

      // Manually simulate corrupted/dropped account balance
      final rawDb = await db.database;
      await rawDb.update(
        'accounts',
        {'balance': 200.0},
        where: 'id = ?',
        whereArgs: [accountId],
      );

      await expectLater(
        () => db.createGoalPaymentTransaction(
          goalId: goalId,
          accountId: accountId,
          amount: 500.0,
          date: '2026-09-14',
        ),
        throwsStateError,
      );

      // Ensure rollback
      final accounts = await db.readAllAccounts();
      expect(accounts.single.balance, 200.0);
      final locks = await rawDb.query('locked_allocations');
      expect((locks.first['amount'] as num).toDouble(), 500.0);
    });

    test('rejects zero, negative, or invalid amounts', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Checking', balance: 1000.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Books',
          totalTarget: 500.0,
          targetDate: '2026-12-01',
          currentSaved: 0.0,
        ),
      );

      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 500.0,
        date: '2026-09-01',
      );

      await expectLater(
        () => db.createGoalPaymentTransaction(
          goalId: goalId,
          accountId: accountId,
          amount: 0.0,
          date: '2026-09-14',
        ),
        throwsArgumentError,
      );

      await expectLater(
        () => db.createGoalPaymentTransaction(
          goalId: goalId,
          accountId: accountId,
          amount: -100.0,
          date: '2026-09-14',
        ),
        throwsArgumentError,
      );
    });

    test(
      'payBill convenience helper delegates to createGoalPaymentTransaction',
      () async {
        final db = DatabaseHelper.instance;
        final accountId = await db.createAccount(
          Account(name: 'Checking', balance: 5000.0, type: 'Bank'),
        );
        final categoryId = await db.createCategory(
          Category(name: 'Utilities', monthlyBudget: 4000.0),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Electricity Deposit',
            totalTarget: 3000.0,
            targetDate: '2026-10-15',
            currentSaved: 0.0,
          ),
        );

        await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: accountId,
          amount: 2000.0,
          date: '2026-09-01',
        );

        final txId = await db.payBill(
          goalId,
          accountId,
          1500.0,
          categoryId: categoryId,
          note: 'Power bill settled',
        );

        expect(txId, isPositive);

        final history = await db.getGoalTransactions(goalId);
        expect(history, hasLength(2));
        final payTx = history.firstWhere((t) => t['type'] == 'goal_payment');
        expect(payTx['amount'], 1500.0);
        expect(payTx['category_id'], categoryId);
        expect(payTx['note'], 'Power bill settled');
        expect(payTx['goal_name'], 'Electricity Deposit');
      },
    );
  });

  group('Goal payment UI component tests', () {
    test(
      'retrieves goal contributions and categories for payment modal flow',
      () async {
        final db = DatabaseHelper.instance;
        final accChecking = await db.createAccount(
          Account(name: 'HDFC Checking', balance: 10000.0, type: 'Bank'),
        );
        final catInsurance = await db.createCategory(
          Category(name: 'Insurance', monthlyBudget: 12000.0),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Annual Health Cover',
            totalTarget: 20000.0,
            targetDate: '2026-11-30',
            currentSaved: 0.0,
          ),
        );

        await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: accChecking,
          amount: 8000.0,
          date: '2026-09-01',
        );

        final contributions = await db.getGoalContributions(goalId);
        final categories = await db.readAllCategories();

        expect(contributions, hasLength(1));
        expect(contributions.first['account_name'], 'HDFC Checking');
        expect(contributions.first['amount'], 8000.0);
        expect(categories.any((c) => c.id == catInsurance), isTrue);
      },
    );

    testWidgets(
      'renders payment modal layout with accounts holding locked funds and category picker',
      (tester) async {
        final contributions = [
          {'account_id': 1, 'account_name': 'HDFC Checking', 'amount': 8000.0},
        ];
        final categories = [
          Category(id: 1, name: 'Insurance', monthlyBudget: 12000.0),
        ];

        int selectedAccountId = (contributions.first['account_id'] as num)
            .toInt();
        final double maxPayable = (contributions.first['amount'] as num)
            .toDouble();
        final amountController = TextEditingController(
          text: maxPayable.toStringAsFixed(0),
        );
        int? selectedCategoryId = categories.first.id;
        final noteController = TextEditingController(
          text: 'Health insurance renewal',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (ctx, setState) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pay / Settle from "Annual Health Cover"',
                          style: AppTypography.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CustomInputField(
                          controller: amountController,
                          label: 'Payment Amount',
                          prefixText: '₹ ',
                          prefixIcon: Icons.payment_rounded,
                        ),
                        Text(
                          'Max available: ₹${maxPayable.toStringAsFixed(0)}',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<int>(
                          initialValue: selectedAccountId,
                          items: contributions.map((c) {
                            return DropdownMenuItem<int>(
                              value: (c['account_id'] as num).toInt(),
                              child: Text(
                                '${c['account_name']} (₹${c['amount']} locked)',
                              ),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => selectedAccountId = val!),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<int?>(
                          initialValue: selectedCategoryId,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('No Category / Sinking Fund'),
                            ),
                            ...categories.map(
                              (c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => selectedCategoryId = val),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CustomInputField(
                          controller: noteController,
                          label: 'Note / Payee (Optional)',
                          prefixIcon: Icons.notes_rounded,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('Confirm Payment'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await tester.pump();

        expect(
          find.text('Pay / Settle from "Annual Health Cover"'),
          findsOneWidget,
        );
        expect(find.text('Max available: ₹8000'), findsOneWidget);
        expect(find.text('HDFC Checking (₹8000.0 locked)'), findsOneWidget);
        expect(find.text('Insurance'), findsOneWidget);
        expect(find.text('Health insurance renewal'), findsOneWidget);
        expect(find.text('Confirm Payment'), findsOneWidget);
      },
    );

    test('settles goal across multiple accounts creating distinct transactions per account', () async {
      final db = DatabaseHelper.instance;
      final acc1 = await db.createAccount(
        Account(name: 'SBI Savings', balance: 25000.0, type: 'Bank'),
      );
      final acc2 = await db.createAccount(
        Account(name: 'HDFC Checking', balance: 18000.0, type: 'Bank'),
      );
      final categoryId = await db.createCategory(
        Category(name: 'Travel', monthlyBudget: 50000.0),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Europe Trip',
          totalTarget: 50000.0,
          targetDate: '2026-12-31',
          currentSaved: 0.0,
        ),
      );

      // Lock funds from both accounts
      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: acc1,
        amount: 15000.0,
        date: '2026-09-01',
      );
      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: acc2,
        amount: 10000.0,
        date: '2026-09-02',
      );

      // Verify pre-settlement state
      var goal = (await db.readAllGoals()).single;
      expect(goal.currentSaved, 25000.0);
      expect(await db.getTotalLockedAmount(), 25000.0);

      // Settle across both accounts (10k from SBI, 6k from HDFC)
      final txIds = await db.createMultiAccountGoalPaymentTransactions(
        goalId: goalId,
        amountsPerAccount: {acc1: 10000.0, acc2: 6000.0},
        date: '2026-09-14',
        categoryId: categoryId,
        note: 'Flight and Hotel Booking',
      );

      expect(txIds, hasLength(2));

      // Query transactions
      final txs = await (await db.database).query(
        'transactions',
        where: 'type = ?',
        whereArgs: ['goal_payment'],
        orderBy: 'account_id ASC',
      );
      expect(txs, hasLength(2));

      final tx1 = txs.firstWhere((t) => t['account_id'] == acc1);
      expect(tx1['amount'], 10000.0);
      expect(tx1['goal_id'], goalId);
      expect(tx1['category_id'], categoryId);
      expect(tx1['note'], 'Flight and Hotel Booking');

      final tx2 = txs.firstWhere((t) => t['account_id'] == acc2);
      expect(tx2['amount'], 6000.0);
      expect(tx2['goal_id'], goalId);
      expect(tx2['category_id'], categoryId);
      expect(tx2['note'], 'Flight and Hotel Booking');

      // Verify account physical balances deducted properly
      final accounts = await db.readAllAccounts();
      final sbi = accounts.firstWhere((a) => a.id == acc1);
      final hdfc = accounts.firstWhere((a) => a.id == acc2);
      expect(sbi.balance, 15000.0); // 25k - 10k
      expect(hdfc.balance, 12000.0); // 18k - 6k

      // Verify remaining locked allocations
      final contributions = await db.getGoalContributions(goalId);
      expect(contributions, hasLength(2));
      final sbiLock = contributions.firstWhere((c) => c['account_id'] == acc1);
      final hdfcLock = contributions.firstWhere((c) => c['account_id'] == acc2);
      expect((sbiLock['amount'] as num).toDouble(), 5000.0); // 15k - 10k
      expect((hdfcLock['amount'] as num).toDouble(), 4000.0); // 10k - 6k

      // Verify goal currentSaved decremented by total 16,000
      goal = (await db.readAllGoals()).single;
      expect(goal.currentSaved, 9000.0); // 25k - 16k
      expect(await db.getTotalLockedAmount(), 9000.0);
    });

    test('fails atomically if any account has insufficient locked funds during multi-account payment', () async {
      final db = DatabaseHelper.instance;
      final acc1 = await db.createAccount(
        Account(name: 'SBI', balance: 20000.0, type: 'Bank'),
      );
      final acc2 = await db.createAccount(
        Account(name: 'HDFC', balance: 10000.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Bike',
          totalTarget: 20000.0,
          targetDate: '2026-12-31',
          currentSaved: 0.0,
        ),
      );

      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: acc1,
        amount: 5000.0,
        date: '2026-09-01',
      );
      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: acc2,
        amount: 5000.0,
        date: '2026-09-01',
      );

      // acc2 only has 5000 locked, trying to pay 8000
      await expectLater(
        () => db.createMultiAccountGoalPaymentTransactions(
          goalId: goalId,
          amountsPerAccount: {acc1: 3000.0, acc2: 8000.0},
          date: '2026-09-14',
        ),
        throwsStateError,
      );

      // Atomicity verification: acc1 should NOT be touched
      final accounts = await db.readAllAccounts();
      expect(accounts.firstWhere((a) => a.id == acc1).balance, 20000.0);
      final goal = (await db.readAllGoals()).single;
      expect(goal.currentSaved, 10000.0);
    });
  });
}
