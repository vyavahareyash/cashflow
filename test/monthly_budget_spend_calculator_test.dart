import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/services/database_helper.dart';

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

  group('Monthly budget spend calculator tests (NEW-008)', () {
    test('sums expenses by category and calendar month while excluding non-expense types', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Primary Checking', balance: 50000.0, type: 'Bank'),
      );
      final savingsId = await db.createAccount(
        Account(name: 'Emergency Savings', balance: 10000.0, type: 'Bank'),
      );
      final groceriesId = await db.createCategory(
        Category(name: 'Groceries', monthlyBudget: 8000.0),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Home Renovation',
          totalTarget: 50000.0,
          targetDate: '2027-12-31',
          currentSaved: 0.0,
        ),
      );

      // Expenses in Sept 2026
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: groceriesId,
        amount: 1500.0,
        date: '2026-09-05T10:30:00.000',
      );
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: groceriesId,
        amount: 500.0,
        date: '2026-09-18T16:45:00.000',
      );

      // Income (associated with groceries category)
      await db.createIncomeTransaction(
        accountId: accountId,
        amount: 12000.0,
        date: '2026-09-01T09:00:00.000',
      );

      // Transfer between accounts
      await db.createTransferTransaction(
        sourceAccountId: accountId,
        destinationAccountId: savingsId,
        amount: 3000.0,
        date: '2026-09-08T11:00:00.000',
      );

      // Goal operations
      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 2000.0,
        date: '2026-09-12T14:00:00.000',
      );
      await db.createGoalUnlockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 500.0,
        date: '2026-09-15T15:00:00.000',
      );
      await db.createGoalPaymentTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 500.0,
        date: '2026-09-20T17:00:00.000',
      );

      // Verify category spending for September 2026: only expenses are summed
      final septSpent = await db.getCategorySpendingForMonth(
        groceriesId,
        month: 9,
        year: 2026,
      );
      expect(septSpent, equals(2000.0));
    });

    test('correctly handles month boundaries without dropping late-month transactions', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Checking', balance: 20000.0, type: 'Bank'),
      );
      final diningId = await db.createCategory(
        Category(name: 'Dining', monthlyBudget: 5000.0),
      );

      // 1. First moment of September
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: diningId,
        amount: 100.0,
        date: '2026-09-01T00:00:00.000',
      );

      // 2. Middle of September
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: diningId,
        amount: 250.0,
        date: '2026-09-15T12:00:00.000',
      );

      // 3. Final moment of September (23:59:59 - previously broken by midnight truncation)
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: diningId,
        amount: 150.0,
        date: '2026-09-30T23:59:59.999',
      );

      // 4. Last moment of previous month (August 31 23:59:59)
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: diningId,
        amount: 400.0,
        date: '2026-08-31T23:59:59.999',
      );

      // 5. First moment of next month (October 1 00:00:00)
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: diningId,
        amount: 600.0,
        date: '2026-10-01T00:00:00.000',
      );

      // September total: 100 + 250 + 150 = 500
      final septTotal = await db.getCategorySpendingForMonth(
        diningId,
        month: 9,
        year: 2026,
      );
      expect(septTotal, equals(500.0));

      // August total: 400
      final augTotal = await db.getCategorySpendingForMonth(
        diningId,
        month: 8,
        year: 2026,
      );
      expect(augTotal, equals(400.0));

      // October total: 600
      final octTotal = await db.getCategorySpendingForMonth(
        diningId,
        month: 10,
        year: 2026,
      );
      expect(octTotal, equals(600.0));
    });

    test(
      'supports unbudgeted categories (monthlyBudget == null) without errors',
      () async {
        final db = DatabaseHelper.instance;
        final accountId = await db.createAccount(
          Account(name: 'Checking', balance: 10000.0, type: 'Bank'),
        );
        final unbudgetedCatId = await db.createCategory(
          Category(name: 'Miscellaneous', monthlyBudget: null),
        );

        await db.createExpenseTransaction(
          accountId: accountId,
          categoryId: unbudgetedCatId,
          amount: 450.0,
          date: '2026-09-10T11:00:00.000',
        );

        final spent = await db.getCategorySpendingForMonth(
          unbudgetedCatId,
          month: 9,
          year: 2026,
        );
        expect(spent, equals(450.0));
      },
    );

    test('returns 0.0 safely for missing or non-existent categories', () async {
      final db = DatabaseHelper.instance;

      // Existing category with no transactions
      final emptyCatId = await db.createCategory(
        Category(name: 'Subscriptions', monthlyBudget: 1000.0),
      );
      final zeroSpent = await db.getCategorySpendingForMonth(
        emptyCatId,
        month: 9,
        year: 2026,
      );
      expect(zeroSpent, equals(0.0));

      // Completely non-existent category ID
      final missingSpent = await db.getCategorySpendingForMonth(
        999999,
        month: 9,
        year: 2026,
      );
      expect(missingSpent, equals(0.0));
    });

    test('batch method getMonthlySpendingByCategoryId returns aggregated category map', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Checking', balance: 30000.0, type: 'Bank'),
      );
      final cat1Id = await db.createCategory(
        Category(name: 'Food', monthlyBudget: 6000.0),
      );
      final cat2Id = await db.createCategory(
        Category(name: 'Transport', monthlyBudget: 3000.0),
      );
      final cat3Id = await db.createCategory(
        Category(name: 'Shopping', monthlyBudget: null),
      );

      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: cat1Id,
        amount: 1200.0,
        date: '2026-09-02T10:00:00.000',
      );
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: cat1Id,
        amount: 800.0,
        date: '2026-09-14T12:00:00.000',
      );
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: cat2Id,
        amount: 450.0,
        date: '2026-09-10T08:00:00.000',
      );
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: cat3Id,
        amount: 900.0,
        date: '2026-09-22T15:00:00.000',
      );

      // Non-expense and out-of-month transactions
      await db.createIncomeTransaction(
        accountId: accountId,
        amount: 50000.0,
        date: '2026-09-01T09:00:00.000',
      );
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: cat1Id,
        amount: 700.0,
        date: '2026-08-25T10:00:00.000',
      );

      final batchMap = await db.getMonthlySpendingByCategoryId(
        month: 9,
        year: 2026,
      );

      expect(batchMap[cat1Id], equals(2000.0));
      expect(batchMap[cat2Id], equals(450.0));
      expect(batchMap[cat3Id], equals(900.0));
      expect(batchMap.containsKey(999999), isFalse);
    });

    test('backward-compatible getCategorySpendingForCurrentMonth returns current month spend', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Checking', balance: 10000.0, type: 'Bank'),
      );
      final catId = await db.createCategory(
        Category(name: 'Utilities', monthlyBudget: 2500.0),
      );

      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: catId,
        amount: 750.0,
        date: DateTime.now().toIso8601String(),
      );

      final currentSpent = await db.getCategorySpendingForCurrentMonth(catId);
      expect(currentSpent, equals(750.0));
    });
  });
}
