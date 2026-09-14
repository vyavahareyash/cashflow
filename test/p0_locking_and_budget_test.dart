import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/credit_card_model.dart';
import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/models/salary_cycle.dart';
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

  group('P0 Issue #68: Segregate fund locking logic for goals and credit cards', () {
    test('getTotalGoalLockedAmount and getTotalCreditCardLockedAmount segregate allocations', () async {
      final db = DatabaseHelper.instance;

      // 1. Create a bank account
      final bankId = await db.createAccount(
        Account(name: 'Main Checking', balance: 100000.0, type: 'Bank'),
      );

      // 2. Create a credit card account
      final ccAccountId = await db.createAccount(
        Account(name: 'Platinum CC', balance: 0.0, type: 'Credit Card'),
      );
      await db.createCreditCard(
        CreditCard(
          accountId: ccAccountId,
          creditLimit: 200000.0,
          statementDay: 1,
          dueDay: 20,
          defaultLockAccountId: bankId,
          autoLock: true,
        ),
      );

      // 3. Create a category
      final catId = await db.createCategory(
        Category(name: 'Shopping', monthlyBudget: 20000.0),
      );

      // 4. Create a Goal
      final goalId = await db.createGoal(
        Goal(
          name: 'Vacation',
          totalTarget: 50000.0,
          targetDate: '2026-12-31',
          currentSaved: 0.0,
        ),
      );

      // 5. Lock funds for Goal (20,000)
      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: bankId,
        amount: 20000.0,
        date: DateTime.now().toIso8601String(),
        note: 'Saved for Vacation',
      );

      // 6. Spend on CC with auto-lock (15,000)
      await db.createCreditCardExpenseTransaction(
        ccAccountId: ccAccountId,
        categoryId: catId,
        amount: 15000.0,
        date: DateTime.now().toIso8601String(),
        note: 'Flight tickets',
        lockBankAccountId: bankId,
      );

      // Verify segregated lock metrics
      final totalLockedAll = await db.getTotalLockedAmount();
      final goalLocked = await db.getTotalGoalLockedAmount();
      final ccLocked = await db.getTotalCreditCardLockedAmount();
      final availToLock = await db.getAccountAvailableToLock(bankId);
      final usableBalance = await db.calculateUsableBalance();

      // Total locked across all accounts: 20k (goal) + 15k (cc) = 35k
      expect(totalLockedAll, 35000.0);
      // Segregated goal locked: strictly 20k
      expect(goalLocked, 20000.0);
      // Segregated cc locked: strictly 15k
      expect(ccLocked, 15000.0);
      // Available to lock in bank: 100k - 35k = 65k
      expect(availToLock, 65000.0);
      // Usable cash balance: 100k - 35k = 65k
      expect(usableBalance, 65000.0);

      // Goal object saved amount remains 20k
      final goals = await db.readAllGoals();
      expect(goals.first.currentSaved, 20000.0);
    });

    test('getAccountAvailableToLock returns 0 for credit card accounts', () async {
      final db = DatabaseHelper.instance;
      final ccAccountId = await db.createAccount(
        Account(name: 'Travel Card', balance: 5000.0, type: 'Credit Card'),
      );

      final avail = await db.getAccountAvailableToLock(ccAccountId);
      expect(avail, 0.0);
    });
  });

  group('P0 Issue #69: Categories without budgets should not be calculated in monthly budget progress', () {
    test('unbudgeted category spends are excluded from budgeted progress calculations', () async {
      final db = DatabaseHelper.instance;

      final bankId = await db.createAccount(
        Account(name: 'Savings', balance: 50000.0, type: 'Bank'),
      );

      // Category with monthly budget
      final budgetedCatId = await db.createCategory(
        Category(name: 'Groceries', monthlyBudget: 10000.0),
      );

      // Category WITHOUT monthly budget (unbudgeted)
      final unbudgetedCatId = await db.createCategory(
        Category(name: 'Ad-hoc Gifts', monthlyBudget: null),
      );

      final now = DateTime.now();
      final dateStr = now.toIso8601String();

      // Spend 3,000 in budgeted category
      await db.createExpenseTransaction(
        accountId: bankId,
        categoryId: budgetedCatId,
        amount: 3000.0,
        date: dateStr,
        note: 'Supermarket',
      );

      // Spend 7,000 in unbudgeted category
      await db.createExpenseTransaction(
        accountId: bankId,
        categoryId: unbudgetedCatId,
        amount: 7000.0,
        date: dateStr,
        note: 'Birthday gift',
      );

      // Fetch categories & spending map
      final categories = await db.readAllCategories();
      final cycle = SalaryCycle.resolve(salaryDay: 1);
      final spendingMap = await db.getMonthlySpendingByCategoryId(cycle: cycle);

      // Verify individual category spending tracking is preserved
      expect(spendingMap[budgetedCatId], 3000.0);
      expect(spendingMap[unbudgetedCatId], 7000.0);

      // Calculate monthly budget progress bar values using the updated logic
      double totalBudgetLimit = 0.0;
      double totalBudgetedSpent = 0.0;
      for (var cat in categories) {
        final budget = cat.monthlyBudget;
        final hasBudget = budget != null && budget > 0;
        if (hasBudget) {
          totalBudgetLimit += budget;
        }
        if (cat.id != null) {
          final spent = spendingMap[cat.id!] ?? 0.0;
          if (hasBudget) {
            totalBudgetedSpent += spent;
          }
        }
      }

      // Budget limit is strictly 10,000
      expect(totalBudgetLimit, 10000.0);
      // Spent so far for monthly budget progress is 3,000 (NOT 10,000!)
      expect(totalBudgetedSpent, 3000.0);

      final progress = totalBudgetedSpent / totalBudgetLimit;
      expect(progress, 0.3); // 30% progress, NOT 100%

      final remainingBudget = (totalBudgetLimit - totalBudgetedSpent).clamp(0.0, double.infinity);
      expect(remainingBudget, 7000.0); // 7,000 remaining, NOT 0.0
    });
  });
}
