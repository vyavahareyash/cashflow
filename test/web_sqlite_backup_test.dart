import 'dart:convert' show utf8;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cashflow/components/export_backup_dialog.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/models/transaction_model.dart';
import 'package:cashflow/screens/backup_restore_screen.dart';
import 'package:cashflow/services/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;

  const databaseFileName = 'web_sqlite_backup_test.db';
  DatabaseHelper.setTestDatabaseName(databaseFileName);

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('web_sqlite_test_');
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
  });

  tearDown(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('SQLite Binary (.db) Export & Import Parity', () {
    test(
      'Exporting SQLite Database produces valid SQLite binary file',
      () async {
        final db = DatabaseHelper.instance;

        // Seed data
        final accountId = await db.createAccount(
          Account(name: 'Checking Account', balance: 12000.0, type: 'Bank'),
        );
        final categoryId = await db.createCategory(
          Category(name: 'Utilities', monthlyBudget: 4000.0),
        );
        await db.insertTransaction(
          TransactionModel(
            accountId: accountId,
            categoryId: categoryId,
            amount: 1500.0,
            date: '2026-10-02',
            note: 'Electricity Bill',
            type: 'expense',
          ),
        );

        final exportPath = await db.exportDatabase(
          destinationDirectory: tempDir.path,
          fileName: 'cashflow_backup.db',
        );

        expect(exportPath, isNotNull);
        final exportedFile = File(exportPath!);
        expect(await exportedFile.exists(), isTrue);

        final bytes = await exportedFile.readAsBytes();
        expect(bytes.length, greaterThanOrEqualTo(16));

        // Check SQLite header magic bytes "SQLite format 3\0"
        const sqliteHeader = [
          0x53,
          0x51,
          0x4c,
          0x69,
          0x74,
          0x65,
          0x20,
          0x66,
          0x6f,
          0x72,
          0x6d,
          0x61,
          0x74,
          0x20,
          0x33,
          0x00,
        ];
        expect(bytes.sublist(0, 16), equals(sqliteHeader));

        // Verify last backup timestamp is set
        final lastBackup = await db.getLastBackupTimestamp();
        expect(lastBackup, isNotNull);
      },
    );

    test('Importing valid SQLite .db file restores accounts, categories, goals, and transactions, and increments dataRevision', () async {
      final db = DatabaseHelper.instance;

      // Seed initial data to export
      final accountId = await db.createAccount(
        Account(name: 'Salary Account', balance: 75000.0, type: 'Bank'),
      );
      final categoryId = await db.createCategory(
        Category(name: 'Shopping', monthlyBudget: 8000.0),
      );
      final goalId = await db.createGoal(
        Goal(
          name: 'Holiday Trip',
          totalTarget: 50000.0,
          currentSaved: 10000.0,
          targetDate: '2026-11-30',
        ),
      );
      await db.createGoalLockTransaction(
        goalId: goalId,
        accountId: accountId,
        amount: 10000.0,
        date: '2026-10-01',
        note: 'Deposit for flights',
      );
      await db.insertTransaction(
        TransactionModel(
          accountId: accountId,
          categoryId: categoryId,
          amount: 2500.0,
          date: '2026-10-02',
          note: 'Winter Jacket',
          type: 'expense',
        ),
      );

      // Export database
      final exportPath = await db.exportDatabase(
        destinationDirectory: tempDir.path,
        fileName: 'valid_backup.db',
      );
      expect(exportPath, isNotNull);
      final backupBytes = await File(exportPath!).readAsBytes();

      // Clear all database tables
      await db.clearAllTables();
      expect(await db.readAllAccounts(), isEmpty);
      expect(await db.readAllCategories(), isEmpty);
      expect(await db.readAllGoals(), isEmpty);
      expect(await db.getTransactionHistory(), isEmpty);

      // Listen for reactive notification
      int revisionNotified = 0;
      void listener() => revisionNotified++;
      DatabaseHelper.dataRevision.addListener(listener);

      // Import the exported bytes
      final success = await db.importDatabase(bytesForTesting: backupBytes);
      DatabaseHelper.dataRevision.removeListener(listener);

      expect(success, isTrue);
      expect(revisionNotified, greaterThan(0));
      expect(db.lastImportError, isNull);

      // Verify restored records
      final accounts = await db.readAllAccounts();
      expect(accounts.length, 1);
      expect(accounts.first.name, 'Salary Account');

      final categories = await db.readAllCategories();
      expect(categories.any((c) => c.name == 'Shopping'), isTrue);

      final goals = await db.readAllGoals();
      expect(goals.length, 1);
      expect(goals.first.name, 'Holiday Trip');

      final transactions = await db.getTransactionHistory();
      expect(transactions.length, 2);

      final locked = await db.getTotalLockedAmount();
      expect(locked, 10000.0);
    });

    test('Corrupted or invalid non-SQLite files are rejected with user-visible validation feedback and preserve existing data', () async {
      final db = DatabaseHelper.instance;

      // Seed data that should be preserved
      await db.createAccount(
        Account(name: 'Preserved Account', balance: 500.0, type: 'Cash'),
      );
      expect((await db.readAllAccounts()).length, 1);

      // 1. Too short bytes
      final shortResult = await db.importDatabase(bytesForTesting: [1, 2, 3]);
      expect(shortResult, isFalse);
      expect(db.lastImportError, contains('too small'));

      // 2. Non-SQLite header
      final nonSqlite = utf8.encode('Hello World this is plain text!');
      final textResult = await db.importDatabase(bytesForTesting: nonSqlite);
      expect(textResult, isFalse);
      expect(db.lastImportError, contains('not a SQLite database'));

      // 3. Corrupted SQLite file (valid header but corrupted body)
      const sqliteHeader = [
        0x53,
        0x4c,
        0x4c,
        0x69,
        0x74,
        0x65,
        0x20,
        0x66,
        0x6f,
        0x72,
        0x6d,
        0x61,
        0x74,
        0x20,
        0x33,
        0x00,
      ];
      final corruptedBytes = [...sqliteHeader, ...List<int>.filled(500, 0xFF)];
      final corruptResult = await db.importDatabase(
        bytesForTesting: corruptedBytes,
      );
      expect(corruptResult, isFalse);
      expect(db.lastImportError, isNotNull);

      // Existing data must remain intact after all failed import attempts
      final accounts = await db.readAllAccounts();
      expect(accounts.length, 1);
      expect(accounts.first.name, 'Preserved Account');
    });

    test('Modifying, adding, and deleting data after import works seamlessly without database locking errors', () async {
      final db = DatabaseHelper.instance;

      // Seed and export
      final accountId = await db.createAccount(
        Account(name: 'Primary Bank', balance: 20000.0, type: 'Bank'),
      );
      final categoryId = await db.createCategory(
        Category(name: 'Groceries', monthlyBudget: 5000.0),
      );
      final exportPath = await db.exportDatabase(
        destinationDirectory: tempDir.path,
        fileName: 'working_backup.db',
      );
      final bytes = await File(exportPath!).readAsBytes();

      // Import
      final imported = await db.importDatabase(bytesForTesting: bytes);
      expect(imported, isTrue);

      // 1. Add new account
      final newAccId = await db.createAccount(
        Account(name: 'Savings 2', balance: 15000.0, type: 'Bank'),
      );
      expect(newAccId, greaterThan(0));

      // 2. Add new transaction
      final txId = await db.insertTransaction(
        TransactionModel(
          accountId: accountId,
          categoryId: categoryId,
          amount: 500.0,
          date: '2026-10-02',
          note: 'Milk & Bread',
          type: 'expense',
        ),
      );
      expect(txId, greaterThan(0));

      // 3. Update account
      await db.updateAccount(
        Account(
          id: accountId,
          name: 'Primary Bank Renamed',
          balance: 19500.0,
          type: 'Bank',
        ),
      );
      final updatedAccount = await db.readAccount(accountId);
      expect(updatedAccount?.name, 'Primary Bank Renamed');

      // 4. Delete transaction
      await db.deleteTransaction(txId);
      final txList = await db.getTransactionHistory();
      expect(txList.any((t) => t['id'] == txId), isFalse);

      // 5. Query and verify consistency
      final accounts = await db.readAllAccounts();
      expect(accounts.length, 2);
    });

    testWidgets('ExportBackupDialog renders SQLite Database (.db) option', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExportBackupDialog(
              isDark: false,
              defaultDirectory: '/test/dir',
              initialDirectory: '/test/dir',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SQLite Database (.db)'), findsOneWidget);
      expect(find.text('JSON Backup (.json)'), findsOneWidget);
      expect(find.text('Transactions CSV (.csv)'), findsOneWidget);
    });

    testWidgets(
      'BackupRestoreScreen settings tiles display SQLite (.db) option and subtitle',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: BackupRestoreScreen()));
        await tester.pumpAndSettle();

        expect(
          find.text('Export as SQLite (.db), JSON, or CSV spreadsheet'),
          findsOneWidget,
        );
        expect(
          find.text('Restore from SQLite (.db) or JSON backup'),
          findsOneWidget,
        );
      },
    );
  });
}
