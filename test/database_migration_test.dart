import 'package:cashflow/services/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;

  const databaseFileName = 'database_migration.db';
  DatabaseHelper.setTestDatabaseName(databaseFileName);

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

  test('fresh install creates v4 schema', () async {
    final db = await DatabaseHelper.instance.database;

    final transactionColumns = await db.rawQuery(
      "PRAGMA table_info('transactions')",
    );
    final categoryColumns = await db.rawQuery(
      "PRAGMA table_info('categories')",
    );
    final lockColumns = await db.rawQuery(
      "PRAGMA table_info('locked_allocations')",
    );
    final ccColumns = await db.rawQuery("PRAGMA table_info('credit_cards')");

    expect(
      transactionColumns.map((column) => column['name']).toList(),
      containsAll(['type', 'destination_account_id', 'goal_id']),
    );
    expect(
      categoryColumns.map((column) => column['name']).toList(),
      containsAll(['monthly_budget', 'type']),
    );
    expect(
      lockColumns.map((column) => column['name']).toList(),
      containsAll(['goal_id', 'credit_card_id', 'account_id', 'amount']),
    );
    expect(
      ccColumns.map((column) => column['name']).toList(),
      containsAll([
        'account_id',
        'credit_limit',
        'statement_day',
        'due_day',
        'auto_lock',
      ]),
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
    expect(categories.length, 7);
    final groceriesCat = categories.firstWhere((c) => c['id'] == categoryId);
    expect(groceriesCat['name'], 'Groceries');
    expect(groceriesCat['monthly_budget'], 1800.0);
    expect(groceriesCat['type'], 'expense');

    final transactionColumns = await upgradedDb.rawQuery(
      "PRAGMA table_info('transactions')",
    );
    expect(
      transactionColumns.map((column) => column['name']).toList(),
      containsAll(['type', 'destination_account_id', 'goal_id']),
    );
  });

  test('v2 database upgrades to v3 schema without losing data and creates credit_cards', () async {
    final dbPath = await getDatabasesPath();
    final filePath = join(dbPath, databaseFileName);

    final v2Db = await openDatabase(
      filePath,
      version: 2,
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
            monthly_budget REAL DEFAULT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_id INTEGER NOT NULL,
            destination_account_id INTEGER DEFAULT NULL,
            category_id INTEGER DEFAULT NULL,
            goal_id INTEGER DEFAULT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            note TEXT,
            type TEXT NOT NULL DEFAULT 'expense'
              CHECK (type IN ('expense', 'income', 'transfer', 'goal_lock', 'goal_unlock', 'goal_payment'))
          )
        ''');
        await db.execute('''
          CREATE TABLE goals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            total_target REAL NOT NULL,
            target_date TEXT NOT NULL,
            current_saved REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE locked_allocations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            goal_id INTEGER NOT NULL,
            account_id INTEGER NOT NULL,
            amount REAL NOT NULL
          )
        ''');
      },
    );

    final accId = await v2Db.insert('accounts', {
      'name': 'HDFC Salary',
      'balance': 50000.0,
      'type': 'Bank',
    });
    final goalId = await v2Db.insert('goals', {
      'name': 'Vacation',
      'total_target': 20000.0,
      'target_date': '2026-12-31',
      'current_saved': 5000.0,
    });
    await v2Db.insert('locked_allocations', {
      'goal_id': goalId,
      'account_id': accId,
      'amount': 5000.0,
    });

    await v2Db.close();

    // Now open via DatabaseHelper, which triggers onUpgrade to v3
    final upgradedDb = await DatabaseHelper.instance.database;

    final ccTable = await upgradedDb.rawQuery(
      "PRAGMA table_info('credit_cards')",
    );
    final lockTable = await upgradedDb.rawQuery(
      "PRAGMA table_info('locked_allocations')",
    );
    final locks = await upgradedDb.query('locked_allocations');

    expect(ccTable, isNotEmpty);
    expect(lockTable.any((col) => col['name'] == 'credit_card_id'), isTrue);
    expect(locks, hasLength(1));
    expect(locks.first['amount'], 5000.0);
    expect(locks.first['goal_id'], goalId);
  });

  test('v3 database upgrades to the v4 schema without losing data', () async {
    final dbPath = await getDatabasesPath();
    final filePath = join(dbPath, databaseFileName);

    // Seed a v3 database
    final v3Db = await openDatabase(
      filePath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            monthly_budget REAL DEFAULT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            balance REAL NOT NULL,
            type TEXT NOT NULL
          )
        ''');
      },
    );

    final catId = await v3Db.insert('categories', {
      'name': 'Groceries',
      'monthly_budget': 12000.0,
    });
    await v3Db.close();

    // Open via DatabaseHelper to trigger onUpgrade to v4
    final upgradedDb = await DatabaseHelper.instance.database;

    final catCols = await upgradedDb.rawQuery(
      "PRAGMA table_info('categories')",
    );
    expect(catCols.any((col) => col['name'] == 'type'), isTrue);

    final categories = await upgradedDb.query('categories');
    final existingCat = categories.firstWhere((c) => c['id'] == catId);
    expect(existingCat['name'], 'Groceries');
    expect(existingCat['type'], 'expense');
    expect(existingCat['monthly_budget'], 12000.0);

    // Default income categories automatically seeded
    final incomeCategories = categories
        .where((c) => c['type'] == 'income')
        .toList();
    expect(incomeCategories.isNotEmpty, isTrue);
    expect(incomeCategories.any((c) => c['name'] == 'Salary'), isTrue);
  });
}
