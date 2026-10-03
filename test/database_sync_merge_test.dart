import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/services/backup_codec.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.setTestDatabaseName(inMemoryDatabasePath);

  setUp(() async {
    await DatabaseHelper.instance.resetDatabase();
  });

  tearDown(() async {
    await DatabaseHelper.instance.resetDatabase();
  });

  group('Database Sync Merge & Rollback Tests', () {
    test('mergeDatabaseFromJSON performs additive union without deleting local records', () async {
      final db = DatabaseHelper.instance;

      // 1. Create a local account, category, and transaction
      final accId = await db.createAccount(
        Account(name: 'Local Checking', balance: 500.0, type: 'Bank'),
      );
      final catId = await db.createCategory(
        Category(name: 'General', monthlyBudget: 200.0),
      );
      await db.createExpenseTransaction(
        accountId: accId,
        amount: 25.0,
        date: '2026-10-01',
        categoryId: catId,
        note: 'Coffee on Desktop',
      );

      final initialAccounts = await db.readAllAccounts();
      final initialTx = await db.getTransactionHistory();
      expect(initialAccounts.length, equals(1));
      expect(initialTx.length, equals(1));

      // 2. Prepare remote payload from "Mobile" device with another account & transaction
      final remoteJson = BackupCodec.encode(
        accounts: [
          {
            'id': 1,
            'name': 'Mobile Savings',
            'type': 'Bank',
            'balance': 1000.0,
          },
        ],
        categories: [
          {
            'id': 1,
            'name': 'Groceries',
            'type': 'expense',
            'monthly_budget': 300.0,
          },
        ],
        goals: [],
        transactions: [
          {
            'account_id': 1,
            'amount': 80.0,
            'date': '2026-10-02',
            'type': 'expense',
            'note': 'Groceries on Phone',
            'category_id': 1,
          },
        ],
        lockedAllocations: [],
      );

      // 3. Execute safe additive merge
      final results = await db.mergeDatabaseFromJSON(remoteJson);

      expect(results['accounts'], equals(1));
      expect(results['transactions'], equals(1));

      // 4. Verify both local and remote exist together (1 + 1 = 2)
      final mergedAccounts = await db.readAllAccounts();
      final mergedTx = await db.getTransactionHistory();
      expect(mergedAccounts.length, equals(2));
      expect(mergedTx.length, equals(2));

      // 4b. Verify remote account balance adjusted for the remote transaction (1000 - 80 = 920)
      final mobileSavings = mergedAccounts.firstWhere(
        (a) => a.name == 'Mobile Savings',
      );
      expect(mobileSavings.balance, equals(920.0));

      // 5. Test rollback undo
      expect(db.hasPreSyncBackup, isTrue);
      final restored = await db.restorePreSyncBackup();
      expect(restored, isTrue);

      // Verify restored back to 1 account and 1 transaction
      final restoredAccounts = await db.readAllAccounts();
      final restoredTx = await db.getTransactionHistory();
      expect(restoredAccounts.length, equals(1));
      expect(restoredTx.length, equals(1));
      expect(restoredTx.first['note'], equals('Coffee on Desktop'));
    });
  });
}
