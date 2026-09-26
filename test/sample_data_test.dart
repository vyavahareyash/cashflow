import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/models/salary_cycle.dart';
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

  test(
    'seeded demo data exercises complete multi-month timeline and scenarios',
    () async {
      final db = DatabaseHelper.instance;

      await db.seedSampleData();
      final history = await db.getTransactionHistory();
      final types = history.map((row) => row['type']).toSet();

      // 1. Transaction Types Coverage
      expect(
        types,
        containsAll([
          'expense',
          'income',
          'transfer',
          'goal_lock',
          'goal_unlock',
          'goal_payment',
        ]),
      );

      // 2. Multi-Month Timeline (at least 6 distinct calendar months)
      final periods = history
          .map((row) => DateTime.parse(row['date'] as String))
          .map(
            (date) => '${date.year}-${date.month.toString().padLeft(2, '0')}',
          )
          .toSet();
      expect(periods.length, greaterThanOrEqualTo(6));

      // 3. Trends Data Verification
      final trends = await db.getMonthlySpendings(months: 6);
      expect(trends.length, greaterThanOrEqualTo(6));
      expect(trends.values, everyElement(greaterThan(0.0)));

      // 4. Categories & Budget Scenarios
      final salaryDay = await db.getSalaryDay();
      final cycle = SalaryCycle.resolve(salaryDay: salaryDay);
      final categories = await db.readAllCategories();
      final monthlySpending = await db.getMonthlySpendingByCategoryId(
        cycle: cycle,
      );

      // Over-budget scenario (Dining Out)
      expect(
        categories.any(
          (c) =>
              c.monthlyBudget != null &&
              (monthlySpending[c.id] ?? 0.0) > c.monthlyBudget!,
        ),
        isTrue,
      );

      // 100% Full budget scenario (Shopping)
      expect(
        categories.any(
          (c) =>
              c.monthlyBudget != null &&
              (monthlySpending[c.id] ?? 0.0) == c.monthlyBudget!,
        ),
        isTrue,
      );

      // On-track budget scenario (Groceries)
      expect(
        categories.any(
          (c) =>
              c.name == 'Groceries' &&
              c.monthlyBudget != null &&
              (monthlySpending[c.id] ?? 0.0) > 0.0 &&
              (monthlySpending[c.id] ?? 0.0) < c.monthlyBudget!,
        ),
        isTrue,
      );

      // Untouched category scenario (Health & Medical)
      expect(
        categories.any(
          (c) =>
              c.name == 'Health & Medical' &&
              c.monthlyBudget != null &&
              (monthlySpending[c.id] ?? 0.0) == 0.0,
        ),
        isTrue,
      );

      // Unbudgeted category scenario (Entertainment & Leisure)
      expect(categories.any((c) => c.monthlyBudget == null), isTrue);

      // 5. Goals & Sinking Funds Scenarios
      final database = await db.database;
      final lockedAllocations = await database.query('locked_allocations');
      final goals = await db.readAllGoals();

      expect(lockedAllocations, isNotEmpty);
      expect(
        goals,
        everyElement(
          predicate((Object? goal) => (goal as Goal).currentSaved > 0),
        ),
      );

      // Completed goal flair scenario (Annual Car Insurance)
      expect(goals.any((goal) => goal.isCompleted), isTrue);

      // Allocation integrity check for every goal
      for (final goal in goals) {
        final lockedTotal = lockedAllocations
            .where((row) => row['goal_id'] == goal.id)
            .fold<double>(
              0.0,
              (total, row) => total + (row['amount'] as num).toDouble(),
            );
        expect(lockedTotal, goal.currentSaved);
      }

      // 6. Accounts & Usable Balance Integrity
      final accounts = await db.readAllAccounts();
      final physicalAccounts = accounts.where((a) => !a.isCreditCard).toList();
      final creditAccounts = accounts.where((a) => a.isCreditCard).toList();
      expect(physicalAccounts.length, 3);
      expect(creditAccounts.length, 2);
      expect(accounts.length, 5);

      final totalPhysical = physicalAccounts.fold<double>(
        0.0,
        (sum, a) => sum + a.balance,
      );
      final totalLocked = await db.getTotalLockedAmount();
      expect(totalPhysical, greaterThan(totalLocked));

      // 7. Credit Card Liabilities & Reserves Integrity
      final creditCards = await db.readAllCreditCards();
      expect(creditCards.length, 2);

      final totalCcOutstanding = await db.getTotalCreditCardOutstanding();
      expect(totalCcOutstanding, 27000.0); // 18,500 (Regalia) + 8,500 (ICICI)

      final totalCcLocked = await db.getTotalCreditCardLockedAmount();
      expect(
        totalCcLocked,
        12000.0,
      ); // 12,000 locked for Regalia in HDFC Salary

      final totalCcUnbacked = totalCcOutstanding - totalCcLocked;
      expect(
        totalCcUnbacked,
        15000.0,
      ); // 6,500 unbacked on Regalia + 8,500 on ICICI
    },
  );
}
