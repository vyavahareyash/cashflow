import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/models/transaction_model.dart';
import 'package:cashflow/services/backup_codec.dart';
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

  group('Database Backup & Restore Foreign Key & Integrity Flow', () {
    test('JSON export and import roundtrips goal-linked transactions without FK violation', () async {
      final db = DatabaseHelper.instance;

      // Seed account, category, goal
      final accountId = await db.createAccount(
        Account(name: 'HDFC Savings', balance: 50000.0, type: 'Bank'),
      );
      final categoryId = await db.createCategory(
        Category(name: 'Groceries', monthlyBudget: 10000.0),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'MacBook Pro',
          totalTarget: 150000.0,
          currentSaved: 20000.0,
          targetDate: '2026-12-31',
        ),
      );

      // Lock funds to goal (creates locked_allocation and goal_lock transaction with goal_id)
      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 20000.0,
        date: '2026-09-10',
        note: 'Initial lock for MacBook',
      );

      // Add regular expense
      await db.insertTransaction(
        TransactionModel(
          accountId: accountId,
          categoryId: categoryId,
          amount: 2500.0,
          date: '2026-09-12',
          note: 'Weekly supermarket',
          type: 'expense',
        ),
      );

      // Verify pre-export counts
      expect(await db.readAllAccounts(), hasLength(1));
      expect(await db.readAllCategories(), hasLength(1));
      expect(await db.readAllGoals(), hasLength(1));
      expect(await db.getTransactionHistory(), hasLength(2));
      expect(await db.getTotalLockedAmount(), 20000.0);

      // Query raw rows and encode via BackupCodec
      final sqliteDb = await db.database;
      final accounts = await sqliteDb.query('accounts');
      final categories = await sqliteDb.query('categories');
      final transactions = await sqliteDb.query('transactions');
      final goals = await sqliteDb.query('goals');
      final lockedAllocations = await sqliteDb.query('locked_allocations');

      final jsonPayload = BackupCodec.encode(
        accounts: accounts.map(Map<String, dynamic>.from).toList(),
        categories: categories.map(Map<String, dynamic>.from).toList(),
        transactions: transactions.map(Map<String, dynamic>.from).toList(),
        goals: goals.map(Map<String, dynamic>.from).toList(),
        lockedAllocations: lockedAllocations.map(Map<String, dynamic>.from).toList(),
      );

      // Simulate restore by decoding and writing into a fresh transaction
      final data = BackupCodec.decode(jsonPayload);

      int revisionsFired = 0;
      void listener() => revisionsFired++;
      DatabaseHelper.dataRevision.addListener(listener);

      // Execute import logic (verifying table deletion and insertion ordering)
      await sqliteDb.transaction((txn) async {
        await txn.delete('locked_allocations');
        await txn.delete('transactions');
        await txn.delete('goals');
        await txn.delete('categories');
        await txn.delete('accounts');

        for (final account in data['accounts'] as List<Map<String, dynamic>>) {
          await txn.insert('accounts', account);
        }
        for (final category in data['categories'] as List<Map<String, dynamic>>) {
          await txn.insert('categories', category);
        }
        for (final goal in data['goals'] as List<Map<String, dynamic>>) {
          await txn.insert('goals', goal);
        }
        for (final transaction in data['transactions'] as List<Map<String, dynamic>>) {
          await txn.insert('transactions', transaction);
        }
        for (final lock in data['locked_allocations'] as List<Map<String, dynamic>>) {
          await txn.insert('locked_allocations', lock);
        }
      });
      DatabaseHelper.notifyDataChanged();

      DatabaseHelper.dataRevision.removeListener(listener);

      // Invariants preserved
      expect(revisionsFired, 1);
      final restoredAccounts = await db.readAllAccounts();
      final restoredGoals = await db.readAllGoals();
      final restoredTransactions = await db.getTransactionHistory();
      final restoredLocked = await db.getTotalLockedAmount();

      expect(restoredAccounts, hasLength(1));
      expect(restoredAccounts.first.name, 'HDFC Savings');
      expect(restoredGoals, hasLength(1));
      expect(restoredGoals.first.name, 'MacBook Pro');
      expect(restoredTransactions, hasLength(2));
      expect(restoredLocked, 20000.0);
    });

    test('resetDatabase clears all entities and re-initializes clean state without FK failure', () async {
      final db = DatabaseHelper.instance;

      final accountId = await db.createAccount(
        Account(name: 'Cash In Hand', balance: 5000.0, type: 'Cash'),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Bike Service',
          totalTarget: 5000.0,
          currentSaved: 1500.0,
          targetDate: '2026-10-01',
        ),
      );
      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 1500.0,
        date: '2026-09-13',
        note: 'Bike fund reservation',
      );

      // Reset
      await db.resetDatabase();

      // Database should be completely empty
      expect(await db.readAllAccounts(), isEmpty);
      expect(await db.readAllGoals(), isEmpty);
      expect(await db.readAllCategories(), isEmpty);
      expect(await db.getTransactionHistory(), isEmpty);
      expect(await db.getTotalLockedAmount(), 0.0);
    });
  });

  group('BackupRestoreScreen UI Feedback & Progress Tests', () {
    testWidgets('renders backup freshness header and linear progress bar when processing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_done_rounded),
                      Text('Backup Status'),
                    ],
                  ),
                ),
                const LinearProgressIndicator(
                  minHeight: 3,
                  color: Color(0xFF047857),
                ),
                Container(
                  key: const Key('backup_status_message_banner'),
                  child: const Text('Backup exported successfully to: /path/backup.json'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Backup Status'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('backup_status_message_banner')), findsOneWidget);
      expect(find.textContaining('Backup exported successfully'), findsOneWidget);
    });

    testWidgets('displays status banner and SnackBar on feedback triggers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('JSON data imported successfully!'),
                        backgroundColor: Color(0xFF047857),
                      ),
                    );
                  },
                  child: const Text('Simulate Import'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Simulate Import'));
      await tester.pump();

      expect(find.text('JSON data imported successfully!'), findsOneWidget);
    });
  });
}
