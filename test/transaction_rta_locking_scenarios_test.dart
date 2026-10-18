import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/credit_card_model.dart';
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

  Future<Account> getAccount(DatabaseHelper db, int id) async {
    final accounts = await db.readAllAccounts();
    return accounts.firstWhere((a) => a.id == id);
  }

  Future<Goal> getGoal(DatabaseHelper db, int id) async {
    final goals = await db.readAllGoals();
    return goals.firstWhere((g) => g.id == id);
  }

  group('User Bug 1: Expense Account Change CC -> Bank', () {
    test('editing expense from CC to Bank removes CC lock and avoids duplicate deduction', () async {
      final db = DatabaseHelper.instance;

      // Bank: 50,000 balance
      final bankId = await db.createAccount(
        Account(name: 'Salary Checking', balance: 50000.0, type: 'Bank'),
      );

      // CC: 0 balance (liability), auto-lock to Bank
      final ccAccountId = await db.createAccount(
        Account(name: 'Infinia CC', balance: 0.0, type: 'Credit Card'),
      );
      final ccId = await db.createCreditCard(
        CreditCard(
          accountId: ccAccountId,
          creditLimit: 150000.0,
          statementDay: 1,
          dueDay: 20,
          defaultLockAccountId: bankId,
          autoLock: true,
        ),
      );

      final catId = await db.createCategory(Category(name: 'Dining Out'));

      // Step 1: Add expense of 5,000 on CC with lock in bank
      final txId = await db.createCreditCardExpenseTransaction(
        ccAccountId: ccAccountId,
        categoryId: catId,
        amount: 5000.0,
        date: '2026-10-18T12:00:00',
        note: 'Team dinner',
        lockBankAccountId: bankId,
      );

      // Verify initial state after CC spend:
      // Physical bank = 50,000
      // CC liability = 5,000
      // Locked in bank = 5,000
      // Usable = 45,000
      expect((await getAccount(db, ccAccountId)).balance, 5000.0);
      expect((await getAccount(db, bankId)).balance, 50000.0);
      expect(await db.getTotalLockedAmount(), 5000.0);
      expect(await db.getLockedAmountForCreditCard(ccId), 5000.0);
      expect(await db.calculateUsableBalance(), 45000.0);

      // Step 2: Edit the expense from CC to Bank account!
      await db.updateTransaction(
        id: txId,
        amount: 5000.0,
        date: '2026-10-18T12:00:00',
        accountId: bankId, // Changed to Bank!
        categoryId: catId,
        note: 'Team dinner (switched to debit card)',
      );

      // Verify:
      // CC liability must be reset to 0
      final updatedCc = await getAccount(db, ccAccountId);
      expect(updatedCc.balance, 0.0);

      // Bank physical balance must be 45,000 (deducted once)
      final updatedBank = await getAccount(db, bankId);
      expect(updatedBank.balance, 45000.0);

      // Locked allocation for CC must be 0 (removed completely!)
      expect(await db.getTotalLockedAmount(), 0.0);
      expect(await db.getLockedAmountForCreditCard(ccId), 0.0);

      // Usable balance must be 45,000 - STABLE, NO DUPLICATE REDUCTION!
      expect(await db.calculateUsableBalance(), 45000.0);
    });
  });

  group('Bug 2: Expense Account Change Bank -> CC', () {
    test(
      'editing expense from Bank to CC restores bank and creates CC auto-lock',
      () async {
        final db = DatabaseHelper.instance;

        final bankId = await db.createAccount(
          Account(name: 'Salary Checking', balance: 50000.0, type: 'Bank'),
        );
        final ccAccountId = await db.createAccount(
          Account(name: 'Infinia CC', balance: 0.0, type: 'Credit Card'),
        );
        final ccId = await db.createCreditCard(
          CreditCard(
            accountId: ccAccountId,
            creditLimit: 150000.0,
            statementDay: 1,
            dueDay: 20,
            defaultLockAccountId: bankId,
            autoLock: true,
          ),
        );
        final catId = await db.createCategory(Category(name: 'Shopping'));

        // Step 1: Expense of 4,000 on Bank
        final txId = await db.createExpenseTransaction(
          accountId: bankId,
          categoryId: catId,
          amount: 4000.0,
          date: '2026-10-18T14:00:00',
          note: 'Shoes',
        );

        expect((await getAccount(db, bankId)).balance, 46000.0);
        expect((await getAccount(db, ccAccountId)).balance, 0.0);
        expect(await db.getTotalLockedAmount(), 0.0);
        expect(await db.calculateUsableBalance(), 46000.0);

        // Step 2: Edit to CC
        await db.updateTransaction(
          id: txId,
          amount: 4000.0,
          date: '2026-10-18T14:00:00',
          accountId: ccAccountId,
          categoryId: catId,
          note: 'Shoes on CC',
        );

        // Verify:
        // Bank physical restored to 50,000
        expect((await getAccount(db, bankId)).balance, 50000.0);
        // CC liability is 4,000
        expect((await getAccount(db, ccAccountId)).balance, 4000.0);
        // Bank locked is 4,000 (auto-lock created!)
        expect(await db.getTotalLockedAmount(), 4000.0);
        expect(await db.getLockedAmountForCreditCard(ccId), 4000.0);
        // Usable balance is 46,000
        expect(await db.calculateUsableBalance(), 46000.0);
      },
    );
  });

  group('Bug 3: Multiple CC expenses with same amount (traceable by transaction_id)', () {
    test('editing one CC expense does not affect other CC expense with identical amount', () async {
      final db = DatabaseHelper.instance;

      final bankId = await db.createAccount(
        Account(name: 'Salary Checking', balance: 50000.0, type: 'Bank'),
      );
      final ccAccountId = await db.createAccount(
        Account(name: 'Infinia CC', balance: 0.0, type: 'Credit Card'),
      );
      final ccId = await db.createCreditCard(
        CreditCard(
          accountId: ccAccountId,
          creditLimit: 150000.0,
          statementDay: 1,
          dueDay: 20,
          defaultLockAccountId: bankId,
          autoLock: true,
        ),
      );
      final catId = await db.createCategory(Category(name: 'Groceries'));

      // Two identical 1,000 expenses on CC
      final tx1 = await db.createCreditCardExpenseTransaction(
        ccAccountId: ccAccountId,
        categoryId: catId,
        amount: 1000.0,
        date: '2026-10-18T10:00:00',
        note: 'Store A',
        lockBankAccountId: bankId,
      );
      final tx2 = await db.createCreditCardExpenseTransaction(
        ccAccountId: ccAccountId,
        categoryId: catId,
        amount: 1000.0,
        date: '2026-10-18T11:00:00',
        note: 'Store B',
        lockBankAccountId: bankId,
      );

      expect((await getAccount(db, ccAccountId)).balance, 2000.0);
      expect(await db.getTotalLockedAmount(), 2000.0);

      // Edit tx1 to 1,500
      await db.updateTransaction(
        id: tx1,
        amount: 1500.0,
        date: '2026-10-18T10:00:00',
        accountId: ccAccountId,
        categoryId: catId,
      );

      expect((await getAccount(db, ccAccountId)).balance, 2500.0);
      expect(await db.getTotalLockedAmount(), 2500.0);

      // Delete tx2
      await db.deleteTransaction(tx2);

      expect((await getAccount(db, ccAccountId)).balance, 1500.0);
      expect(await db.getTotalLockedAmount(), 1500.0);
      expect(await db.getLockedAmountForCreditCard(ccId), 1500.0);

      // Verify the remaining lock is indeed tx1's lock
      final rawDb = await db.database;
      final remainingLocks = await rawDb.query('locked_allocations');
      expect(remainingLocks, hasLength(1));
      expect(remainingLocks.first['amount'], 1500.0);
      expect(remainingLocks.first['transaction_id'], tx1);
    });
  });

  group('Goal Lock and Payment Scenarios with RTA', () {
    test('editing goal lock to different account moves lock cleanly', () async {
      final db = DatabaseHelper.instance;

      final bank1 = await db.createAccount(
        Account(name: 'Bank 1', balance: 10000.0, type: 'Bank'),
      );
      final bank2 = await db.createAccount(
        Account(name: 'Bank 2', balance: 10000.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Emergency Fund',
          totalTarget: 10000.0,
          targetDate: '2027-01-01',
          currentSaved: 0.0,
        ),
      );

      final lockTxId = await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: bank1,
        amount: 3000.0,
        date: '2026-10-18',
      );

      var goal = await getGoal(db, goalId);
      expect(goal.currentSaved, 3000.0);
      var b1Locks = await db.getLocksForAccount(bank1);
      expect(b1Locks.first.amount, 3000.0);

      // Edit lock to move to bank2
      await db.updateTransaction(
        id: lockTxId,
        amount: 3000.0,
        date: '2026-10-18',
        accountId: bank2,
      );

      goal = await getGoal(db, goalId);
      expect(goal.currentSaved, 3000.0);

      b1Locks = await db.getLocksForAccount(bank1);
      expect(b1Locks, isEmpty);

      final b2Locks = await db.getLocksForAccount(bank2);
      expect(b2Locks, hasLength(1));
      expect(b2Locks.first.amount, 3000.0);
    });

    test(
      'editing goal payment amount adjusts account, lock, and goal in sync',
      () async {
        final db = DatabaseHelper.instance;

        final bankId = await db.createAccount(
          Account(name: 'Checking', balance: 10000.0, type: 'Bank'),
        );
        final goalId = await db.createGoal(
          Goal(
            name: 'Laptop',
            totalTarget: 5000.0,
            targetDate: '2027-01-01',
            currentSaved: 0.0,
          ),
        );

        await db.createGoalLockTransaction(
          goalId: goalId,
          accountId: bankId,
          amount: 3000.0,
          date: '2026-10-18',
        );

        final payTxId = await db.createGoalPaymentTransaction(
          goalId: goalId,
          accountId: bankId,
          amount: 1000.0,
          date: '2026-10-19',
        );

        expect((await getAccount(db, bankId)).balance, 9000.0);
        expect((await getGoal(db, goalId)).currentSaved, 2000.0);
        expect((await db.getLocksForAccount(bankId)).first.amount, 2000.0);

        // Edit payment from 1000 to 1500
        await db.updateTransaction(
          id: payTxId,
          amount: 1500.0,
          date: '2026-10-19',
          accountId: bankId,
        );

        expect((await getAccount(db, bankId)).balance, 8500.0);
        expect((await getGoal(db, goalId)).currentSaved, 1500.0);
        expect((await db.getLocksForAccount(bankId)).first.amount, 1500.0);
      },
    );
  });
}
