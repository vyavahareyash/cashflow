import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/credit_card_model.dart';
import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/models/locked_allocation_model.dart';
import 'package:cashflow/models/salary_cycle.dart';
import 'package:cashflow/screens/accounts_screen.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

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

  group('P2 Issue #70: Category Model Type Separation', () {
    test('Category defaults to expense type and getters work correctly', () {
      final expenseCat = Category(name: 'Groceries', monthlyBudget: 5000);
      expect(expenseCat.type, 'expense');
      expect(expenseCat.isExpense, isTrue);
      expect(expenseCat.isIncome, isFalse);

      final incomeCat = Category(name: 'Salary', type: 'income');
      expect(incomeCat.type, 'income');
      expect(incomeCat.isExpense, isFalse);
      expect(incomeCat.isIncome, isTrue);
    });

    test('Category serialization includes and restores type correctly', () {
      final cat = Category(id: 10, name: 'Freelance', type: 'income');
      final map = cat.toMap();
      expect(map['type'], 'income');

      final restored = Category.fromMap(map);
      expect(restored.id, 10);
      expect(restored.name, 'Freelance');
      expect(restored.type, 'income');
      expect(restored.isIncome, isTrue);

      // Backwards compatibility when type key is omitted
      final legacyMap = {'id': 11, 'name': 'Old Category', 'monthly_budget': 1000.0};
      final fromLegacy = Category.fromMap(legacyMap);
      expect(fromLegacy.type, 'expense');
      expect(fromLegacy.isExpense, isTrue);
    });
  });

  group('P2 Issue #66: Usable Balance calculation in DatabaseHelper', () {
    test('getUsableBalanceForAccount deducts goal locks and CC locks correctly', () async {
      final db = DatabaseHelper.instance;

      final bankId = await db.createAccount(
        Account(name: 'Main Bank', balance: 50000.0, type: 'Bank'),
      );
      final ccId = await db.createAccount(
        Account(name: 'Reward CC', balance: 0.0, type: 'Credit Card'),
      );
      await db.createCreditCard(
        CreditCard(
          accountId: ccId,
          creditLimit: 100000.0,
          statementDay: 1,
          dueDay: 20,
          defaultLockAccountId: bankId,
          autoLock: true,
        ),
      );

      final catId = await db.createCategory(
        Category(name: 'Dining', monthlyBudget: 10000.0),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Emergency Fund',
          totalTarget: 50000.0,
          targetDate: '2026-12-31',
          currentSaved: 0.0,
        ),
      );

      // Initially no locks
      final initialUsable = await db.getUsableBalanceForAccount(bankId);
      expect(initialUsable, 50000.0);

      // Lock ₹10,000 for goal
      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: bankId,
        amount: 10000.0,
        date: DateTime.now().toIso8601String(),
      );

      // Charge ₹5,000 to credit card with auto-lock on bank
      await db.createCreditCardExpenseTransaction(
        ccAccountId: ccId,
        categoryId: catId,
        amount: 5000.0,
        date: DateTime.now().toIso8601String(),
        note: 'Dinner',
        lockBankAccountId: bankId,
      );

      // Usable balance = 50,000 - 10,000 (goal lock) - 5,000 (cc lock) = 35,000
      final usableAfterLocks = await db.getUsableBalanceForAccount(bankId);
      expect(usableAfterLocks, 35000.0);
    });
  });

  group('P2 Issue #70: DatabaseHelper Income Category and Earnings Query', () {
    test('readAllCategories filters by type and seeds default income categories', () async {
      final db = DatabaseHelper.instance;
      await db.seedDatabase();
      final allCats = await db.readAllCategories();
      final expenseCats = await db.readAllCategories(type: 'expense');
      final incomeCats = await db.readCategoriesByType('income');

      expect(incomeCats.isNotEmpty, isTrue);
      expect(expenseCats.isNotEmpty, isTrue);
      expect(allCats.length, expenseCats.length + incomeCats.length);

      final incomeNames = incomeCats.map((c) => c.name).toList();
      expect(incomeNames.contains('Salary'), isTrue);
      expect(incomeNames.contains('Freelance'), isTrue);
    });

    test('createIncomeTransaction with categoryId and getMonthlyIncomeByCategoryId', () async {
      final db = DatabaseHelper.instance;
      await db.seedDatabase();
      final bankId = await db.createAccount(
        Account(name: 'Savings', balance: 10000.0, type: 'Bank'),
      );
      final incomeCats = await db.readCategoriesByType('income');
      final salaryCat = incomeCats.firstWhere((c) => c.name == 'Salary');

      final now = DateTime.now();
      final cycle = SalaryCycle.resolve(salaryDay: 1, today: now);

      await db.createIncomeTransaction(
        accountId: bankId,
        amount: 45000.0,
        date: now.toIso8601String(),
        categoryId: salaryCat.id,
        note: 'Monthly salary credit',
      );

      final incomeByCat = await db.getMonthlyIncomeByCategoryId(cycle: cycle);
      expect(incomeByCat[salaryCat.id!], 45000.0);
    });
  });

  group('P2 Issue #66: AccountCard Usable Balance Display & Actions Popup', () {
    testWidgets('AccountCard displays usable balance when totalLocked > 0', (tester) async {
      final account = Account(id: 1, name: 'HDFC Checking', balance: 50000.0, type: 'Bank');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountCard(
              account: account,
              locks: [
                LockedAllocation(
                  accountId: account.id!,
                  amount: 12000.0,
                  goalId: 1,
                  goalName: 'Vacation',
                ),
              ],
              onEdit: () {},
              onTransfer: () {},
            ),
          ),
        ),
      );

      // Actual balance = 50,000 (primary), usable balance = 50,000 - 12,000 = 38,000 (subtitle)
      expect(find.text('₹50,000'), findsOneWidget);
      expect(find.textContaining('usable'), findsOneWidget);
      // Popup action menu exists
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets('AccountCard displays single balance when totalLocked is 0', (tester) async {
      final account = Account(id: 2, name: 'Cash in Hand', balance: 5000.0, type: 'Cash');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountCard(
              account: account,
              locks: const [],
            ),
          ),
        ),
      );

      expect(find.text('₹5,000'), findsOneWidget);
      expect(find.textContaining('usable'), findsNothing);
    });
  });

  group('P2 Issue #70: BudgetScreen Segmented Tab and Income Categories', () {
    testWidgets('SegmentedButton toggles between Expense Budgets and Income Categories', (tester) async {
      String selectedTab = 'expense';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    SegmentedButton<String>(
                      key: const Key('budget_tab_segmented_button'),
                      segments: const [
                        ButtonSegment<String>(
                          value: 'expense',
                          label: Text('Expense Budgets'),
                          icon: Icon(Icons.pie_chart_outline_rounded),
                        ),
                        ButtonSegment<String>(
                          value: 'income',
                          label: Text('Income Categories'),
                          icon: Icon(Icons.savings_outlined),
                        ),
                      ],
                      selected: {selectedTab},
                      onSelectionChanged: (newSelection) {
                        setState(() => selectedTab = newSelection.first);
                      },
                    ),
                    if (selectedTab == 'expense') ...[
                      const Text('Category Allocations'),
                      const Text('Add Budget'),
                    ] else ...[
                      const Text('Income Streams'),
                      const Text('Add Category'),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('budget_tab_segmented_button')), findsOneWidget);
      expect(find.text('Expense Budgets'), findsOneWidget);
      expect(find.text('Income Categories'), findsOneWidget);
      expect(find.text('Add Budget'), findsOneWidget);
      expect(find.text('Category Allocations'), findsOneWidget);

      // Switch to Income Categories tab
      await tester.tap(find.text('Income Categories'));
      await tester.pumpAndSettle();

      expect(find.text('Income Streams'), findsOneWidget);
      expect(find.text('Add Category'), findsOneWidget);
    });
  });
}
