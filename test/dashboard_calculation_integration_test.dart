import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/models/salary_cycle.dart';
import 'package:cashflow/models/transaction_model.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/theme/theme_constants.dart';

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

  group('AC1: Seeded Accounts and Transactions Dashboard Calculations', () {
    test('produces exact totalPhysical, lockedAmount, usableBalance, budgetLimit, and spent', () async {
      final db = DatabaseHelper.instance;

      // 1. Seed two physical accounts
      final bankId = await db.createAccount(
        Account(name: 'HDFC Salary Account', balance: 75000.0, type: 'Bank'),
      );
      final cashId = await db.createAccount(
        Account(name: 'Wallet Cash', balance: 5000.0, type: 'Cash'),
      );

      // 2. Seed categories with monthly budgets
      final groceriesCatId = await db.createCategory(
        Category(name: 'Groceries', monthlyBudget: 12000.0),
      );
      final diningCatId = await db.createCategory(
        Category(name: 'Dining & Food', monthlyBudget: 8000.0),
      );
      await db.createCategory(
        Category(name: 'Utilities', monthlyBudget: 5000.0),
      );
      // Category without a budget limit (unbudgeted tracking)
      final miscCatId = await db.createCategory(Category(name: 'Misc'));

      // 3. Seed goals and lock allocations
      final laptopGoalId = await db.createGoal(
        Goal(
          name: 'Work Laptop',
          totalTarget: 90000.0,
          currentSaved: 15000.0,
          targetDate: '2026-12-31',
        ),
      );
      await db.createGoalLockTransaction(
        goalId: laptopGoalId,
        accountId: bankId,
        amount: 15000.0,
        date: '2026-09-02',
        note: 'Saved for laptop',
      );

      // 4. Seed categorized expense transactions in current salary cycle
      final cycle = SalaryCycle.resolve(salaryDay: 1);
      final currentDateStr =
          cycle.startDateString; // Guaranteed inside active cycle

      await db.insertTransaction(
        TransactionModel(
          accountId: bankId,
          categoryId: groceriesCatId,
          amount: 4500.0,
          date: currentDateStr,
          note: 'Supermarket grocery haul',
          type: 'expense',
        ),
      );
      await db.insertTransaction(
        TransactionModel(
          accountId: cashId,
          categoryId: diningCatId,
          amount: 1500.0,
          date: currentDateStr,
          note: 'Dinner out',
          type: 'expense',
        ),
      );
      await db.insertTransaction(
        TransactionModel(
          accountId: bankId,
          categoryId: miscCatId,
          amount: 1000.0,
          date: currentDateStr,
          note: 'Stationery',
          type: 'expense',
        ),
      );

      // --- Verify Metrics ---
      final accounts = await db.readAllAccounts();
      final totalPhysical = accounts.fold<double>(
        0.0,
        (sum, a) => sum + a.balance,
      );
      final locked = await db.getTotalLockedAmount();
      final usable = await db.calculateUsableBalance();

      final categories = await db.readAllCategories();
      final totalBudgetLimit = categories.fold<double>(
        0.0,
        (sum, c) => sum + (c.monthlyBudget ?? 0.0),
      );

      final spendingMap = await db.getMonthlySpendingByCategoryId(cycle: cycle);
      final totalSpent = spendingMap.values.fold<double>(
        0.0,
        (sum, val) => sum + val,
      );

      // Physical sum: 75,000 + 5,000 = 80,000
      expect(totalPhysical, 80000.0);
      // Locked amount for goals: 15,000
      expect(locked, 15000.0);
      // Usable cash = 80,000 - 15,000 = 65,000
      expect(usable, 65000.0);
      // Budget limit: 12,000 + 8,000 + 5,000 = 25,000
      expect(totalBudgetLimit, 25000.0);
      // Total spent: 4,500 (groceries) + 1,500 (dining) + 1,000 (misc) = 7,000
      expect(totalSpent, 7000.0);

      // Remaining budget calculation
      final remainingBudget = (totalBudgetLimit - totalSpent).clamp(
        0.0,
        double.infinity,
      );
      expect(remainingBudget, 18000.0);

      // Verify UI string representations
      expect(AppFormatters.currency(usable, isPrivate: false), '₹65,000');
      expect(
        AppFormatters.compactCurrency(totalPhysical, isPrivate: false),
        '₹80.0k',
      );
      expect(AppFormatters.compactCurrency(locked, isPrivate: false), '₹15.0k');
      expect(
        AppFormatters.compactCurrency(totalBudgetLimit, isPrivate: false),
        '₹25.0k',
      );
      expect(AppFormatters.currency(totalSpent, isPrivate: false), '₹7,000');
    });
  });

  group('AC2: Usable Balance Dynamics Across Financial Transactions', () {
    test('goal locks decrement usable balance, goal unlocks restore usable balance', () async {
      final db = DatabaseHelper.instance;

      final accountId = await db.createAccount(
        Account(name: 'Checking', balance: 50000.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Emergency Fund',
          totalTarget: 100000.0,
          currentSaved: 0.0,
          targetDate: '2027-01-01',
        ),
      );

      // Baseline: physical = 50,000, locked = 0, usable = 50,000
      expect(await db.calculateUsableBalance(), 50000.0);
      expect(await db.getTotalLockedAmount(), 0.0);

      // Step 1: Lock 20,000
      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 20000.0,
        date: '2026-09-05',
        note: 'First lock',
      );

      // Physical remains 50,000; locked becomes 20,000; usable becomes 30,000
      final acc1 = (await db.readAllAccounts()).first;
      expect(acc1.balance, 50000.0);
      expect(await db.getTotalLockedAmount(), 20000.0);
      expect(await db.calculateUsableBalance(), 30000.0);

      // Step 2: Unlock 8,000
      await db.createGoalUnlockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 8000.0,
        date: '2026-09-08',
        note: 'Partial unlock for emergency',
      );

      // Physical remains 50,000; locked becomes 12,000; usable restored to 38,000
      final acc2 = (await db.readAllAccounts()).first;
      expect(acc2.balance, 50000.0);
      expect(await db.getTotalLockedAmount(), 12000.0);
      expect(await db.calculateUsableBalance(), 38000.0);
    });

    test('goal payment atomically decrements physical and locked amounts; usable balance stays invariant', () async {
      final db = DatabaseHelper.instance;

      final accountId = await db.createAccount(
        Account(name: 'Bank', balance: 50000.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Flight Tickets',
          totalTarget: 25000.0,
          currentSaved: 0.0,
          targetDate: '2026-11-01',
        ),
      );

      // Lock 25,000: usable balance = 25,000
      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 25000.0,
        date: '2026-09-01',
      );
      expect(await db.calculateUsableBalance(), 25000.0);

      // Now pay 25,000 directly from the goal
      await db.createGoalPaymentTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 25000.0,
        date: '2026-09-10',
        note: 'Booked flights',
      );

      // Physical decrements from 50,000 to 25,000
      final acc = (await db.readAllAccounts()).first;
      expect(acc.balance, 25000.0);

      // Locked decrements from 25,000 to 0
      expect(await db.getTotalLockedAmount(), 0.0);

      // Crucial: Usable balance was already excluding the 25,000; paying it keeps usable balance at 25,000!
      expect(await db.calculateUsableBalance(), 25000.0);
    });

    test(
      'monthly tracking budgets do NOT deduct physical cash or usable balance',
      () async {
        final db = DatabaseHelper.instance;

        await db.createAccount(
          Account(name: 'Checking', balance: 40000.0, type: 'Bank'),
        );

        expect(await db.calculateUsableBalance(), 40000.0);

        // Create categories with huge budgets (e.g. 500,000 total)
        await db.createCategory(
          Category(name: 'Luxury Travel', monthlyBudget: 300000.0),
        );
        await db.createCategory(
          Category(name: 'Investments', monthlyBudget: 200000.0),
        );

        // Monthly budgets are tracking limits, NOT cash deductions
        // Usable cash must still be 40,000
        expect(await db.calculateUsableBalance(), 40000.0);
      },
    );

    test(
      'income, expenses, and inter-account transfers reflect correctly',
      () async {
        final db = DatabaseHelper.instance;

        final accA = await db.createAccount(
          Account(name: 'Account A', balance: 20000.0, type: 'Bank'),
        );
        final accB = await db.createAccount(
          Account(name: 'Account B', balance: 10000.0, type: 'Bank'),
        );

        // Initial usable = 30,000
        expect(await db.calculateUsableBalance(), 30000.0);

        // Transfer 5,000 from A to B
        await db.createTransferTransaction(
          sourceAccountId: accA,
          destinationAccountId: accB,
          amount: 5000.0,
          date: '2026-09-11',
          note: 'Internal transfer',
        );

        // Net physical and usable balances remain 30,000
        final accountsAfterTransfer = await db.readAllAccounts();
        final balanceA = accountsAfterTransfer
            .firstWhere((a) => a.id == accA)
            .balance;
        final balanceB = accountsAfterTransfer
            .firstWhere((a) => a.id == accB)
            .balance;
        expect(balanceA, 15000.0);
        expect(balanceB, 15000.0);
        expect(await db.calculateUsableBalance(), 30000.0);

        // Income of 10,000 into Account A
        await db.createIncomeTransaction(
          accountId: accA,
          amount: 10000.0,
          date: '2026-09-12',
          note: 'Freelance gig',
        );
        expect(await db.calculateUsableBalance(), 40000.0);

        // Expense of 4,000 from Account B
        final catId = await db.createCategory(
          Category(name: 'Shopping', monthlyBudget: 5000.0),
        );
        await db.createExpenseTransaction(
          accountId: accB,
          categoryId: catId,
          amount: 4000.0,
          date: '2026-09-13',
          note: 'Clothes',
        );
        expect(await db.calculateUsableBalance(), 36000.0);
      },
    );
  });

  group('AC3: Refresh After Write Updates Displayed Values & Revision Listener', () {
    test(
      'DatabaseHelper.dataRevision fires across inserts, updates, and deletes',
      () async {
        final db = DatabaseHelper.instance;
        int revisions = 0;
        void listener() => revisions++;
        DatabaseHelper.dataRevision.addListener(listener);

        // 1. Insert account
        final accId = await db.createAccount(
          Account(name: 'Test Bank', balance: 1000.0, type: 'Bank'),
        );
        expect(revisions, 1);

        // 2. Insert category
        final catId = await db.createCategory(
          Category(name: 'Fuel', monthlyBudget: 3000.0),
        );
        expect(revisions, 2);

        // 3. Insert transaction
        final txId = await db.insertTransaction(
          TransactionModel(
            accountId: accId,
            categoryId: catId,
            amount: 500.0,
            date: '2026-09-14',
            note: 'Initial fuel',
            type: 'expense',
          ),
        );
        expect(revisions, 3);

        // 4. Update transaction
        await db.updateTransaction(
          id: txId,
          accountId: accId,
          categoryId: catId,
          amount: 600.0,
          date: '2026-09-14',
          note: 'Adjusted fuel',
        );
        expect(revisions, 4);

        // 5. Delete transaction
        await db.deleteTransaction(txId);
        expect(revisions, 5);

        DatabaseHelper.dataRevision.removeListener(listener);
      },
    );
  });

  group('AC4: Empty and Error / Boundary States Covered', () {
    test('zero accounts, categories, goals, and transactions return clean zero values', () async {
      final db = DatabaseHelper.instance;

      expect(await db.readAllAccounts(), isEmpty);
      expect(await db.readAllCategories(), isEmpty);
      expect(await db.readAllGoals(), isEmpty);
      expect(await db.getTransactionHistory(), isEmpty);

      expect(await db.getTotalLockedAmount(), 0.0);
      expect(await db.calculateUsableBalance(), 0.0);

      final cycle = SalaryCycle.resolve(salaryDay: 1);
      final spendingMap = await db.getMonthlySpendingByCategoryId(cycle: cycle);
      expect(spendingMap, isEmpty);
    });

    test('usable balance is safely clamped to zero when locked funds exceed physical balance', () async {
      final db = DatabaseHelper.instance;

      // Seed account with 10,000
      final accId = await db.createAccount(
        Account(name: 'Checking', balance: 10000.0, type: 'Bank'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Big Goal',
          totalTarget: 50000.0,
          currentSaved: 10000.0,
          targetDate: '2027-01-01',
        ),
      );

      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accId,
        amount: 10000.0,
        date: '2026-09-01',
      );
      expect(await db.calculateUsableBalance(), 0.0);

      // Now directly reduce physical balance below locked amount (e.g. fee or manual balance edit to 3,000)
      await db.updateAccount(
        Account(id: accId, name: 'Checking', balance: 3000.0, type: 'Bank'),
      );

      // Physical = 3,000, Locked = 10,000.
      // Usable must clamp to 0.0 and never return negative numbers
      expect(await db.calculateUsableBalance(), 0.0);
    });

    test('custom salary payday dynamically scopes monthly spending to cycle boundaries', () async {
      final db = DatabaseHelper.instance;

      // Set payday to 15th of the month
      await db.setSalaryDay(15);
      expect(await db.getSalaryDay(), 15);

      final accId = await db.createAccount(
        Account(name: 'Salary Bank', balance: 100000.0, type: 'Bank'),
      );
      final catId = await db.createCategory(
        Category(name: 'Rent', monthlyBudget: 25000.0),
      );

      final cycle = SalaryCycle.resolve(
        today: DateTime(2026, 9, 20),
        salaryDay: 15,
      );
      // For Sept 20 with payday 15: cycle is 2026-09-15 through 2026-10-14
      expect(cycle.startDateString, '2026-09-15');
      expect(cycle.endDateString, '2026-10-14');

      // Expense on 2026-09-10 (BEFORE cycle start)
      await db.insertTransaction(
        TransactionModel(
          accountId: accId,
          categoryId: catId,
          amount: 5000.0,
          date: '2026-09-10',
          note: 'Previous cycle expense',
          type: 'expense',
        ),
      );

      // Expense on 2026-09-18 (INSIDE active cycle)
      await db.insertTransaction(
        TransactionModel(
          accountId: accId,
          categoryId: catId,
          amount: 25000.0,
          date: '2026-09-18',
          note: 'Current rent',
          type: 'expense',
        ),
      );

      // Expense on 2026-10-20 (AFTER active cycle)
      await db.insertTransaction(
        TransactionModel(
          accountId: accId,
          categoryId: catId,
          amount: 8000.0,
          date: '2026-10-20',
          note: 'Future cycle expense',
          type: 'expense',
        ),
      );

      // Query spending for the active salary cycle
      final spendingMap = await db.getMonthlySpendingByCategoryId(cycle: cycle);
      expect(spendingMap[catId], 25000.0);

      final spentInMonth = await db.getCategorySpendingForMonth(
        catId,
        cycle: cycle,
      );
      expect(spentInMonth, 25000.0);
    });

    test('Dashboard calculation excludes unbudgeted categories from budget envelope', () async {
      final db = DatabaseHelper.instance;

      final accId = await db.createAccount(
        Account(name: 'Checking', balance: 50000.0, type: 'Bank'),
      );

      final budgetedCat = await db.createCategory(
        Category(name: 'Groceries', monthlyBudget: 15000.0),
      );
      final unbudgetedCat = await db.createCategory(
        Category(name: 'Emergency', monthlyBudget: null),
      );

      final today = DateTime.now().toIso8601String();
      await db.createExpenseTransaction(
        accountId: accId,
        categoryId: budgetedCat,
        amount: 4000.0,
        date: today,
        note: 'Supermarket',
      );
      await db.createExpenseTransaction(
        accountId: accId,
        categoryId: unbudgetedCat,
        amount: 8000.0,
        date: today,
        note: 'Doctor visit',
      );

      final categories = await db.readAllCategories();
      final cycle = SalaryCycle.resolve(salaryDay: 1);
      final spendingMap = await db.getMonthlySpendingByCategoryId(cycle: cycle);

      double totalBudget = 0;
      double totalBudgetedSpent = 0;
      for (var cat in categories) {
        final budget = cat.monthlyBudget;
        final hasBudget = budget != null && budget > 0;
        if (hasBudget) {
          totalBudget += budget;
        }
        if (cat.id != null) {
          final spent = spendingMap[cat.id!] ?? 0.0;
          if (hasBudget) {
            totalBudgetedSpent += spent;
          }
        }
      }

      expect(totalBudget, 15000.0);
      expect(totalBudgetedSpent, 4000.0);
      expect(totalBudgetedSpent / totalBudget, closeTo(0.2667, 0.001));
    });
  });
}
