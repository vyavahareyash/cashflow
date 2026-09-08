import 'package:cashflow/models/account_model.dart';
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
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
  });

  tearDown(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
  });

  group('income transaction flow', () {
    test('persists typed income with correct amount and type', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'HDFC', type: 'Bank', balance: 1000.0),
      );

      await db.createIncomeTransaction(
        accountId: accountId,
        amount: 250.0,
        date: '2026-09-08',
      );

      final transactions = await (await db.database).query('transactions');
      expect(transactions, hasLength(1));
      expect(transactions.first['type'], 'income');
      expect(transactions.first['amount'], 250.0);
      expect(transactions.first['account_id'], accountId);
    });

    test('increases account physical balance exactly once', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'HDFC', type: 'Bank', balance: 1000.0),
      );

      await db.createIncomeTransaction(
        accountId: accountId,
        amount: 250.0,
        date: '2026-09-08',
      );

      final accounts = await db.readAllAccounts();
      expect(accounts, hasLength(1));
      expect(accounts.first.balance, 1250.0);
    });

    test('rejects zero amount and leaves data unchanged', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'HDFC', type: 'Bank', balance: 1000.0),
      );

      expect(
        () => db.createIncomeTransaction(
          accountId: accountId,
          amount: 0.0,
          date: '2026-09-08',
        ),
        throwsA(isA<ArgumentError>()),
      );

      final accounts = await db.readAllAccounts();
      expect(accounts.first.balance, 1000.0);
      final transactions = await (await db.database).query('transactions');
      expect(transactions, isEmpty);
    });

    test('rejects negative amount and leaves data unchanged', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'HDFC', type: 'Bank', balance: 1000.0),
      );

      expect(
        () => db.createIncomeTransaction(
          accountId: accountId,
          amount: -50.0,
          date: '2026-09-08',
        ),
        throwsA(isA<ArgumentError>()),
      );

      final accounts = await db.readAllAccounts();
      expect(accounts.first.balance, 1000.0);
    });

    test('rejects non-existent account id', () async {
      final db = DatabaseHelper.instance;
      await db.createAccount(
        Account(name: 'HDFC', type: 'Bank', balance: 1000.0),
      );

      await expectLater(
        db.createIncomeTransaction(
          accountId: 999,
          amount: 100.0,
          date: '2026-09-08',
        ),
        throwsStateError,
      );
    });
  });
}
