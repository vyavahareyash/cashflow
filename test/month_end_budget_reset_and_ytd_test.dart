import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/salary_cycle.dart';
import 'package:cashflow/services/database_helper.dart';

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

  group('Payday Cycle Budget Reset and Zero Rollover (LEGACY-011)', () {
    test('strictly scopes spending to active SalaryCycle with zero rollover across cycles', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Checking Account', balance: 50000.0, type: 'Bank'),
      );
      final groceriesId = await db.createCategory(
        Category(name: 'Groceries', monthlyBudget: 10000.0),
      );

      // Cycle 1: July 25, 2026 to August 24, 2026 (salaryDay = 25)
      final cycle1 = SalaryCycle.resolve(
        today: DateTime(2026, 8, 10),
        salaryDay: 25,
      );
      expect(cycle1.startDateString, '2026-07-25');
      expect(cycle1.endDateString, '2026-08-24');

      // Spend in Cycle 1: ₹4,000 (under budget by ₹6,000)
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: groceriesId,
        amount: 4000.0,
        date: '2026-08-05T12:00:00.000',
      );

      final cycle1Spent = await db.getMonthlySpendingByCategoryId(cycle: cycle1);
      expect(cycle1Spent[groceriesId], 4000.0);

      // Cycle 2: August 25, 2026 to September 24, 2026
      final cycle2 = SalaryCycle.resolve(
        today: DateTime(2026, 8, 26),
        salaryDay: 25,
      );
      expect(cycle2.startDateString, '2026-08-25');
      expect(cycle2.endDateString, '2026-09-24');

      // Prior to any spending in Cycle 2, spend MUST be 0.0 (zero rollover, no budget carryover)
      final cycle2InitialSpent = await db.getMonthlySpendingByCategoryId(cycle: cycle2);
      expect(cycle2InitialSpent[groceriesId] ?? 0.0, 0.0);

      // Add spending in Cycle 2: ₹12,000 (over budget by ₹2,000 against fresh ₹10,000 limit)
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: groceriesId,
        amount: 12000.0,
        date: '2026-08-28T14:30:00.000',
      );

      final cycle2FinalSpent = await db.getMonthlySpendingByCategoryId(cycle: cycle2);
      expect(cycle2FinalSpent[groceriesId], 12000.0);

      // Verify Cycle 1 spending remains intact and unaffected
      final cycle1Rechecked = await db.getMonthlySpendingByCategoryId(cycle: cycle1);
      expect(cycle1Rechecked[groceriesId], 4000.0);

      // Cycle 3: September 25, 2026 to October 24, 2026
      final cycle3 = SalaryCycle.resolve(
        today: DateTime(2026, 9, 26),
        salaryDay: 25,
      );
      expect(cycle3.startDateString, '2026-09-25');
      expect(cycle3.endDateString, '2026-10-24');

      // Cycle 3 starts fresh at 0.0 (overspend in Cycle 2 does NOT penalize Cycle 3)
      final cycle3Spent = await db.getMonthlySpendingByCategoryId(cycle: cycle3);
      expect(cycle3Spent[groceriesId] ?? 0.0, 0.0);
    });

    test('getTotalSpendingForSalaryCycle computes cumulative spending for the cycle', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Checking', balance: 40000.0, type: 'Bank'),
      );
      final diningId = await db.createCategory(
        Category(name: 'Dining', monthlyBudget: 5000.0),
      );
      final utilId = await db.createCategory(
        Category(name: 'Utilities', monthlyBudget: 3000.0),
      );

      final cycle = SalaryCycle.resolve(
        today: DateTime(2026, 9, 15),
        salaryDay: 10,
      );
      // Sep 10 - Oct 9
      expect(cycle.startDateString, '2026-09-10');
      expect(cycle.endDateString, '2026-10-09');

      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: diningId,
        amount: 1500.0,
        date: '2026-09-12T10:00:00.000',
      );
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: utilId,
        amount: 2200.0,
        date: '2026-09-20T11:00:00.000',
      );
      // Out of cycle (Sep 5)
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: diningId,
        amount: 800.0,
        date: '2026-09-05T12:00:00.000',
      );

      final totalCycleSpend = await db.getTotalSpendingForSalaryCycle(cycle);
      expect(totalCycleSpend, 3700.0); // 1500 + 2200
    });
  });

  group('Year-to-Date (YTD) Cumulative Analytics (LEGACY-011)', () {
    test('getYtdSpending, getYtdSpendingByCategory, and getYtdCashflowSummary isolate year correctly', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Main Account', balance: 100000.0, type: 'Bank'),
      );
      final foodId = await db.createCategory(
        Category(name: 'Food & Dining', monthlyBudget: 8000.0),
      );
      final travelId = await db.createCategory(
        Category(name: 'Travel', monthlyBudget: 5000.0),
      );

      // Prior year 2025 transactions (must be excluded from 2026 YTD)
      await db.createIncomeTransaction(
        accountId: accountId,
        amount: 30000.0,
        date: '2025-12-15T10:00:00.000',
      );
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: foodId,
        amount: 5000.0,
        date: '2025-12-20T18:00:00.000',
      );

      // 2026 Transactions
      // Jan 2026
      await db.createIncomeTransaction(
        accountId: accountId,
        amount: 50000.0,
        date: '2026-01-02T09:00:00.000',
      );
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: foodId,
        amount: 8000.0,
        date: '2026-01-10T12:00:00.000',
      );

      // Feb 2026
      await db.createIncomeTransaction(
        accountId: accountId,
        amount: 50000.0,
        date: '2026-02-01T09:00:00.000',
      );
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: travelId,
        amount: 12000.0,
        date: '2026-02-15T14:00:00.000',
      );

      // Mar 2026
      await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: foodId,
        amount: 6000.0,
        date: '2026-03-05T19:00:00.000',
      );

      // 1. Total YTD Spending (2026)
      final ytdSpend2026 = await db.getYtdSpending(year: 2026);
      expect(ytdSpend2026, 26000.0); // 8000 + 12000 + 6000

      // 2. YTD Spending By Category (2026)
      final catSpend2026 = await db.getYtdSpendingByCategory(year: 2026);
      expect(catSpend2026['Food & Dining'], 14000.0); // 8000 + 6000
      expect(catSpend2026['Travel'], 12000.0);
      expect(catSpend2026.containsKey('NonExistent'), isFalse);

      // 3. YTD Monthly Spendings (2026)
      final monthlySpend2026 = await db.getYtdMonthlySpendings(year: 2026);
      expect(monthlySpend2026['2026-01'], 8000.0);
      expect(monthlySpend2026['2026-02'], 12000.0);
      expect(monthlySpend2026['2026-03'], 6000.0);
      expect(monthlySpend2026.containsKey('2025-12'), isFalse);

      // 4. YTD Cashflow Summary (2026)
      final cashflow2026 = await db.getYtdCashflowSummary(year: 2026);
      expect(cashflow2026['inflow'], 100000.0); // 50000 + 50000
      expect(cashflow2026['outflow'], 26000.0);
      expect(cashflow2026['netSavings'], 74000.0); // 100000 - 26000
      expect(cashflow2026['savingsRate'], closeTo(74.0, 0.01)); // 74000 / 100000 * 100

      // Prior year 2025 isolation check
      final ytdSpend2025 = await db.getYtdSpending(year: 2025);
      expect(ytdSpend2025, 5000.0);
    });
  });

  group('SalaryCycle boundary handling', () {
    test('handles end-of-month and leap year transitions safely', () {
      // Leap year Feb 2024: mid-month reference date before payday (Feb 29)
      final leapCycle = SalaryCycle.resolve(
        today: DateTime(2024, 2, 15),
        salaryDay: 31,
      );
      expect(leapCycle.startDateString, '2024-01-31');
      expect(leapCycle.endDateString, '2024-02-28');

      // Leap year Feb 2024 on the payday itself (Feb 29): starts the next cycle
      final leapPaydayCycle = SalaryCycle.resolve(
        today: DateTime(2024, 2, 29),
        salaryDay: 31,
      );
      expect(leapPaydayCycle.startDateString, '2024-02-29');
      expect(leapPaydayCycle.endDateString, '2024-03-30');

      // Non-leap year Feb 2025: mid-month reference date before payday (Feb 28)
      final nonLeapCycle = SalaryCycle.resolve(
        today: DateTime(2025, 2, 15),
        salaryDay: 31,
      );
      expect(nonLeapCycle.startDateString, '2025-01-31');
      expect(nonLeapCycle.endDateString, '2025-02-27');
    });
  });
}
