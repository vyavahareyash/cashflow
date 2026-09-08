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

  group('transfer transaction flow', () {
    test(
      'persists typed transfer with source and destination accounts',
      () async {
        final db = DatabaseHelper.instance;
        final sourceId = await db.createAccount(
          Account(name: 'Checking', balance: 100.0, type: 'Bank'),
        );
        final destinationId = await db.createAccount(
          Account(name: 'Savings', balance: 25.0, type: 'Bank'),
        );

        await db.createTransferTransaction(
          sourceAccountId: sourceId,
          destinationAccountId: destinationId,
          amount: 40.0,
          date: '2026-09-08',
        );

        final transactions = await (await db.database).query('transactions');
        expect(transactions, hasLength(1));
        expect(transactions.first['type'], 'transfer');
        expect(transactions.first['account_id'], sourceId);
        expect(transactions.first['destination_account_id'], destinationId);
        expect(transactions.first['amount'], 40.0);
      },
    );

    test('moves money without changing total physical balance', () async {
      final db = DatabaseHelper.instance;
      final sourceId = await db.createAccount(
        Account(name: 'Checking', balance: 100.0, type: 'Bank'),
      );
      final destinationId = await db.createAccount(
        Account(name: 'Savings', balance: 25.0, type: 'Bank'),
      );
      final before = (await db.readAllAccounts()).fold<double>(
        0.0,
        (total, account) => total + account.balance,
      );

      await db.createTransferTransaction(
        sourceAccountId: sourceId,
        destinationAccountId: destinationId,
        amount: 40.0,
        date: '2026-09-08',
      );

      final accounts = await db.readAllAccounts();
      expect(
        accounts.firstWhere((account) => account.id == sourceId).balance,
        60.0,
      );
      expect(
        accounts.firstWhere((account) => account.id == destinationId).balance,
        65.0,
      );
      final after = accounts.fold<double>(
        0.0,
        (total, account) => total + account.balance,
      );
      expect(after, before);
    });

    test('rejects identical accounts and leaves data unchanged', () async {
      final db = DatabaseHelper.instance;
      final accountId = await db.createAccount(
        Account(name: 'Checking', balance: 100.0, type: 'Bank'),
      );

      expect(
        () => db.createTransferTransaction(
          sourceAccountId: accountId,
          destinationAccountId: accountId,
          amount: 40.0,
          date: '2026-09-08',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect((await db.readAllAccounts()).single.balance, 100.0);
      expect((await (await db.database).query('transactions')), isEmpty);
    });

    test('rejects invalid amounts and leaves data unchanged', () async {
      final db = DatabaseHelper.instance;
      final sourceId = await db.createAccount(
        Account(name: 'Checking', balance: 100.0, type: 'Bank'),
      );
      final destinationId = await db.createAccount(
        Account(name: 'Savings', balance: 25.0, type: 'Bank'),
      );

      for (final amount in [0.0, -10.0]) {
        expect(
          () => db.createTransferTransaction(
            sourceAccountId: sourceId,
            destinationAccountId: destinationId,
            amount: amount,
            date: '2026-09-08',
          ),
          throwsA(isA<ArgumentError>()),
        );
      }

      final accounts = await db.readAllAccounts();
      expect(
        accounts.firstWhere((account) => account.id == sourceId).balance,
        100.0,
      );
      expect(
        accounts.firstWhere((account) => account.id == destinationId).balance,
        25.0,
      );
      expect((await (await db.database).query('transactions')), isEmpty);
    });

    test('rejects a missing account and rolls back the transfer', () async {
      final db = DatabaseHelper.instance;
      final sourceId = await db.createAccount(
        Account(name: 'Checking', balance: 100.0, type: 'Bank'),
      );

      expect(
        () => db.createTransferTransaction(
          sourceAccountId: sourceId,
          destinationAccountId: 999,
          amount: 40.0,
          date: '2026-09-08',
        ),
        throwsStateError,
      );

      expect((await db.readAllAccounts()).single.balance, 100.0);
      expect((await (await db.database).query('transactions')), isEmpty);
    });
  });
}
