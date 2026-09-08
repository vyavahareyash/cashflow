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

  test('fresh install creates v2 schema', () async {
    final db = await DatabaseHelper.instance.database;

    final transactionColumns = await db.rawQuery("PRAGMA table_info('transactions')");
    final categoryColumns = await db.rawQuery("PRAGMA table_info('categories')");

    expect(
      transactionColumns.map((column) => column['name']).toList(),
      containsAll(['type', 'destination_account_id', 'goal_id']),
    );
    expect(
      categoryColumns.map((column) => column['name']).toList(),
      contains('monthly_budget'),
    );
  });

  test('v1 database upgrades to the v2 schema without losing data', () async {
    final dbPath = await getDatabasesPath();
    final filePath = join(dbPath, databaseFileName);

    final legacyDb = await openDatabase(
      filePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            balance REAL NOT NULL,
            type TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            monthly_budget REAL NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_id INTEGER NOT NULL,
            category_id INTEGER NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            note TEXT,
            FOREIGN KEY (account_id) REFERENCES accounts (id),
            FOREIGN KEY (category_id) REFERENCES categories (id)
          )
        ''');
      },
    );

    final accountId = await legacyDb.insert('accounts', {
      'name': 'Checking',
      'balance': 2500.0,
      'type': 'Bank',
    });

    final categoryId = await legacyDb.insert('categories', {
      'name': 'Groceries',
      'monthly_budget': 1800.0,
    });

    await legacyDb.insert('transactions', {
      'account_id': accountId,
      'category_id': categoryId,
      'amount': 120.0,
      'date': '2026-01-10',
      'note': 'Milk and bread',
    });

    await legacyDb.close();

    final upgradedDb = await DatabaseHelper.instance.database;
    final transactions = await upgradedDb.query('transactions');
    final categories = await upgradedDb.query('categories');

    expect(transactions, hasLength(1));
    expect(transactions.first['type'], 'expense');
    expect(transactions.first['destination_account_id'], isNull);
    expect(transactions.first['goal_id'], isNull);
    expect(transactions.first['category_id'], categoryId);
    expect(categories, hasLength(1));
    expect(categories.first['monthly_budget'], 1800.0);

    final transactionColumns = await upgradedDb.rawQuery("PRAGMA table_info('transactions')");
    expect(
      transactionColumns.map((column) => column['name']).toList(),
      containsAll(['type', 'destination_account_id', 'goal_id']),
    );
  });
}
