import 'dart:convert';
import 'package:cashflow/main.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/draft_transaction.dart';
import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
  const databaseFileName = 'money_tracker.db';

  setUp(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(p.join(dbPath, databaseFileName));
  });

  tearDown(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(p.join(dbPath, databaseFileName));
  });

  group('Security Hardening Tests', () {
    test('deleteGoal does not create phantom money and nullifies transaction goal_id', () async {
      final db = DatabaseHelper.instance;

      // 1. Create account with $1000 balance
      final accountId = await db.createAccount(
        Account(name: 'Checking', balance: 1000.0, type: 'Bank'),
      );

      // 2. Create goal with $500 target
      final goalId = await db.createGoal(
        Goal(
          name: 'Vacation',
          totalTarget: 500.0,
          targetDate: '2027-01-01',
          currentSaved: 0.0,
        ),
      );

      // 3. Lock $300 for the goal
      final txId = await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 300.0,
        date: '2026-09-23',
        note: 'Locking for vacation',
      );

      // Verify state before deletion
      final accBefore = (await db.readAllAccounts()).firstWhere((a) => a.id == accountId);
      expect(accBefore.balance, equals(1000.0)); // Physical balance unchanged
      final usableBefore = await db.getUsableBalanceForAccount(accountId);
      expect(usableBefore, equals(700.0)); // $1000 - $300 locked

      // 4. Delete the goal
      await db.deleteGoal(goalId);

      // 5. Verify physical balance was NOT credited (no phantom money!)
      final accAfter = (await db.readAllAccounts()).firstWhere((a) => a.id == accountId);
      expect(accAfter.balance, equals(1000.0)); // Still 1000.0, NOT 1300.0!

      // 6. Usable balance is restored to 1000.0 because lock is removed
      final usableAfter = await db.getUsableBalanceForAccount(accountId);
      expect(usableAfter, equals(1000.0));

      // 7. Verify transaction still exists and goal_id is nullified
      final rawDb = await db.database;
      final txRows = await rawDb.query('transactions', where: 'id = ?', whereArgs: [txId]);
      expect(txRows.length, equals(1));
      expect(txRows.first['goal_id'], isNull);

      // 8. Verify goal is deleted
      final goals = await db.readAllGoals();
      expect(goals.any((g) => g.id == goalId), isFalse);
    });

    test('deleteCategory nullifies transaction category_id and deletes category safely', () async {
      final db = DatabaseHelper.instance;

      final accountId = await db.createAccount(
        Account(name: 'Wallet', balance: 500.0, type: 'Cash'),
      );
      final catId = await db.createCategory(
        Category(name: 'Entertainment', monthlyBudget: 100.0, type: 'expense'),
      );

      final rawDb = await db.database;
      final txId = await rawDb.insert('transactions', {
        'account_id': accountId,
        'category_id': catId,
        'amount': 25.0,
        'date': '2026-09-23',
        'note': 'Movie night',
        'type': 'expense',
      });

      // Delete the category
      await db.deleteCategory(catId);

      // Verify category is gone
      final categories = await db.readAllCategories();
      expect(categories.any((c) => c.id == catId), isFalse);

      // Verify transaction still exists with category_id set to null
      final txRows = await rawDb.query('transactions', where: 'id = ?', whereArgs: [txId]);
      expect(txRows.length, equals(1));
      expect(txRows.first['category_id'], isNull);
    });

    test('importDatabase rejects non-SQLite files and preserves existing database', () async {
      final db = DatabaseHelper.instance;

      // Seed something in the database
      await db.createAccount(
        Account(name: 'SeedAccount', balance: 250.0, type: 'Bank'),
      );
      expect((await db.readAllAccounts()).length, equals(1));

      // 1. Reject too short bytes (<16 bytes)
      final shortBytes = [1, 2, 3];
      final resShort = await db.importDatabase(bytesForTesting: shortBytes);
      expect(resShort, isFalse);

      // 2. Reject non-SQLite header
      final textBytes = utf8.encode('This is just a random text file, not a SQLite db!');
      final resText = await db.importDatabase(bytesForTesting: textBytes);
      expect(resText, isFalse);

      // Verify original database remains intact
      final accounts = await db.readAllAccounts();
      expect(accounts.length, equals(1));
      expect(accounts.first.name, equals('SeedAccount'));
    });

    test('createCreditCardExpenseTransaction rejects locking when usable funds are insufficient', () async {
      final db = DatabaseHelper.instance;

      // Create Bank account with $100
      final bankId = await db.createAccount(
        Account(name: 'Bank', balance: 100.0, type: 'Bank'),
      );

      // Create Credit Card account
      final ccAccountId = await db.createAccount(
        Account(name: 'Visa', balance: 0.0, type: 'Credit Card'),
      );
      await (await db.database).insert('credit_cards', {
        'account_id': ccAccountId,
        'credit_limit': 1000.0,
        'statement_day': 1,
        'due_day': 20,
        'auto_lock': 1,
        'default_lock_account_id': bankId,
      });

      // Attempting to spend $150 with lock in bankId ($100 balance) should fail with StateError
      expect(
        () => db.createCreditCardExpenseTransaction(
          ccAccountId: ccAccountId,
          categoryId: null,
          amount: 150.0,
          date: '2026-09-23',
          note: 'Big purchase',
          lockBankAccountId: bankId,
        ),
        throwsA(isA<StateError>()),
      );

      // Spending $50 should succeed
      final txId = await db.createCreditCardExpenseTransaction(
        ccAccountId: ccAccountId,
        categoryId: null,
        amount: 50.0,
        date: '2026-09-23',
        note: 'Normal purchase',
        lockBankAccountId: bankId,
      );
      expect(txId, isPositive);

      // Usable balance in bank is now $50 ($100 - $50 locked)
      final usable = await db.getUsableBalanceForAccount(bankId);
      expect(usable, equals(50.0));
    });

    test('createExpenseTransaction rejects expense greater than account balance', () async {
      final db = DatabaseHelper.instance;

      final accountId = await db.createAccount(
        Account(name: 'Checking', balance: 100.0, type: 'Bank'),
      );
      final catId = await db.createCategory(
        Category(name: 'Food', monthlyBudget: 200.0, type: 'expense'),
      );

      // Attempting to spend $150 from $100 balance should fail
      expect(
        () => db.createExpenseTransaction(
          accountId: accountId,
          categoryId: catId,
          amount: 150.0,
          date: '2026-09-23',
          note: 'Overdraft attempt',
        ),
        throwsA(isA<StateError>()),
      );

      // Account balance remains unchanged
      final accBefore = (await db.readAllAccounts()).firstWhere((a) => a.id == accountId);
      expect(accBefore.balance, equals(100.0));

      // Spending $60 should succeed
      final txId = await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: catId,
        amount: 60.0,
        date: '2026-09-23',
        note: 'Valid expense',
      );
      expect(txId, isPositive);

      final accAfter = (await db.readAllAccounts()).firstWhere((a) => a.id == accountId);
      expect(accAfter.balance, equals(40.0));
    });

    test('createTransferTransaction rejects transfer greater than source account balance', () async {
      final db = DatabaseHelper.instance;

      final sourceId = await db.createAccount(
        Account(name: 'Source Bank', balance: 75.0, type: 'Bank'),
      );
      final destId = await db.createAccount(
        Account(name: 'Destination Cash', balance: 50.0, type: 'Cash'),
      );

      // Transferring $100 from $75 balance should fail
      expect(
        () => db.createTransferTransaction(
          sourceAccountId: sourceId,
          destinationAccountId: destId,
          amount: 100.0,
          date: '2026-09-23',
          note: 'Overdraft transfer',
        ),
        throwsA(isA<StateError>()),
      );

      // Balances remain intact
      expect((await db.readAllAccounts()).firstWhere((a) => a.id == sourceId).balance, equals(75.0));
      expect((await db.readAllAccounts()).firstWhere((a) => a.id == destId).balance, equals(50.0));

      // Transferring $30 should succeed
      final txId = await db.createTransferTransaction(
        sourceAccountId: sourceId,
        destinationAccountId: destId,
        amount: 30.0,
        date: '2026-09-23',
        note: 'Valid transfer',
      );
      expect(txId, isPositive);

      expect((await db.readAllAccounts()).firstWhere((a) => a.id == sourceId).balance, equals(45.0));
      expect((await db.readAllAccounts()).firstWhere((a) => a.id == destId).balance, equals(80.0));
    });

    test('commitDraftTransactions atomically rolls back if any draft exceeds account balance', () async {
      final db = DatabaseHelper.instance;

      final accountId = await db.createAccount(
        Account(name: 'Wallet', balance: 50.0, type: 'Cash'),
      );
      final catId = await db.createCategory(
        Category(name: 'Snacks', monthlyBudget: 100.0, type: 'expense'),
      );

      final drafts = [
        DraftTransaction(
          id: 'draft-1',
          amount: 30.0,
          type: 'expense',
          accountId: accountId,
          categoryId: catId,
          date: '2026-09-23',
          note: 'Snack 1',
        ),
        DraftTransaction(
          id: 'draft-2',
          amount: 40.0, // Total = $70 > $50 balance!
          type: 'expense',
          accountId: accountId,
          categoryId: catId,
          date: '2026-09-23',
          note: 'Snack 2',
        ),
      ];

      expect(
        () => db.commitDraftTransactions(drafts),
        throwsA(isA<StateError>()),
      );

      // Verify atomic rollback: balance is still 50.0 and no transactions were created
      final acc = (await db.readAllAccounts()).firstWhere((a) => a.id == accountId);
      expect(acc.balance, equals(50.0));
      final txs = await db.getTransactionHistory();
      expect(txs, isEmpty);
    });

    test('updateTransaction rejects increasing expense beyond account balance', () async {
      final db = DatabaseHelper.instance;

      final accountId = await db.createAccount(
        Account(name: 'Savings', balance: 100.0, type: 'Bank'),
      );
      final catId = await db.createCategory(
        Category(name: 'Repairs', monthlyBudget: 200.0, type: 'expense'),
      );

      final txId = await db.createExpenseTransaction(
        accountId: accountId,
        categoryId: catId,
        amount: 40.0,
        date: '2026-09-23',
        note: 'Small repair',
      );
      // Balance is now 60.0

      // Updating from 40 to 120 (delta = 80 > 60 available) should fail
      expect(
        () => db.updateTransaction(
          id: txId,
          accountId: accountId,
          categoryId: catId,
          amount: 120.0,
          date: '2026-09-23',
          note: 'Expensive repair attempt',
        ),
        throwsA(isA<StateError>()),
      );

      // Balance remains 60.0 and transaction amount remains 40.0
      expect((await db.readAllAccounts()).firstWhere((a) => a.id == accountId).balance, equals(60.0));
      final tx = (await db.getTransactionHistory()).firstWhere((t) => t['id'] == txId);
      expect(tx['amount'], equals(40.0));
    });

    testWidgets('App lock staging screen places logo above biometric overlay and lock in center', (tester) async {
      await tester.pumpWidget(
        const MoneyTrackerApp(initialAppLockEnabled: true),
      );
      await tester.pump();

      // Lock icon is displayed in center
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      // App logo is rendered
      expect(find.byType(Image), findsOneWidget);

      // Verify Align with negative y-alignment (elevated above center)
      final alignFinder = find.ancestor(
        of: find.byType(ClipRRect),
        matching: find.byType(Align),
      );
      expect(alignFinder, findsOneWidget);
      final alignWidget = tester.widget<Align>(alignFinder);
      expect(alignWidget.alignment, equals(const Alignment(0, -0.6)));

      // Verify Center contains lock icon container
      final centerFinder = find.ancestor(
        of: find.byIcon(Icons.lock_rounded),
        matching: find.byType(Center),
      );
      expect(centerFinder, findsOneWidget);
    });
  });
}
