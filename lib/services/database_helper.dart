import 'dart:convert' show utf8;
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:cashflow/services/backup_platform.dart';
import 'package:cashflow/services/backup_codec.dart';

import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/transaction_model.dart';
import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/models/credit_card_model.dart';
import 'package:cashflow/models/locked_allocation_model.dart';
import 'package:cashflow/models/salary_cycle.dart';

class DatabaseHelper {
  // Singleton pattern: ensures only one database connection exists
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static Future<Database>? _databaseFuture;

  /// Global notifier that broadcasts whenever any financial data or database state changes
  static final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);

  static void notifyDataChanged() {
    dataRevision.value++;
  }

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _databaseFuture ??= _initDB('money_tracker.db');
    _database = await _databaseFuture;
    return _database!;
  }

  Future<void> resetDatabase() async {
    if (kIsWeb) {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('locked_allocations');
        await txn.delete('transactions');
        await txn.delete('goals');
        await txn.delete('credit_cards');
        await txn.delete('categories');
        await txn.delete('accounts');
        await txn.execute(
          'CREATE TABLE IF NOT EXISTS app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await txn.delete('app_settings');
      });
      notifyDataChanged();
      return;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'money_tracker.db');
    await deleteDatabase(path);
    _database = null; // Reset the singleton instance
    _databaseFuture = null;
    notifyDataChanged();
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateV1toV2(db);
        }
        if (oldVersion < 3) {
          await _migrateV2toV3(db);
        }
        if (oldVersion < 4) {
          await _migrateV3toV4(db);
        }
      },
    );
  }

  Future<void> _migrateV1toV2(Database db) async {
    final goalsExists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'goals'",
    );
    if (goalsExists.isEmpty) {
      await db.execute('''
        CREATE TABLE goals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          total_target REAL NOT NULL,
          target_date TEXT NOT NULL,
          current_saved REAL NOT NULL
        )
      ''');
    }

    final legacyTransactions = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'transactions'",
    );

    if (legacyTransactions.isNotEmpty) {
      await db.execute('''
        CREATE TABLE transactions_migration (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id INTEGER NOT NULL,
          destination_account_id INTEGER DEFAULT NULL,
          category_id INTEGER DEFAULT NULL,
          goal_id INTEGER DEFAULT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          note TEXT,
          type TEXT DEFAULT 'expense'
        )
      ''');
      await db.execute('''
        INSERT INTO transactions_migration (
          id,
          account_id,
          destination_account_id,
          category_id,
          goal_id,
          amount,
          date,
          note,
          type
        )
        SELECT
          id,
          account_id,
          NULL,
          category_id,
          NULL,
          amount,
          date,
          note,
          'expense'
        FROM transactions
      ''');
      await db.execute('DROP TABLE transactions');
    }

    final legacyCategories = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'categories'",
    );

    if (legacyCategories.isNotEmpty) {
      await db.execute('''
        CREATE TABLE categories_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          monthly_budget REAL DEFAULT NULL
        )
      ''');
      await db.execute('''
        INSERT INTO categories_new (id, name, monthly_budget)
        SELECT id, name, monthly_budget
        FROM categories
      ''');
      await db.execute('DROP TABLE categories');
      await db.execute('ALTER TABLE categories_new RENAME TO categories');
    }

    if (legacyTransactions.isNotEmpty) {
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
            CHECK (type IN ('expense', 'income', 'transfer', 'goal_lock', 'goal_unlock', 'goal_payment')),
          FOREIGN KEY (account_id) REFERENCES accounts (id),
          FOREIGN KEY (destination_account_id) REFERENCES accounts (id),
          FOREIGN KEY (category_id) REFERENCES categories (id),
          FOREIGN KEY (goal_id) REFERENCES goals (id)
        )
      ''');
      await db.execute('''
        INSERT INTO transactions (
          id,
          account_id,
          destination_account_id,
          category_id,
          goal_id,
          amount,
          date,
          note,
          type
        )
        SELECT
          id,
          account_id,
          destination_account_id,
          category_id,
          goal_id,
          amount,
          date,
          note,
          type
        FROM transactions_migration
      ''');
      await db.execute('DROP TABLE transactions_migration');
    }
  }

  Future<void> _migrateV2toV3(Database db) async {
    final ccExists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'credit_cards'",
    );
    if (ccExists.isEmpty) {
      await db.execute('''
        CREATE TABLE credit_cards (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id INTEGER NOT NULL UNIQUE,
          credit_limit REAL NOT NULL,
          statement_day INTEGER NOT NULL DEFAULT 1,
          due_day INTEGER NOT NULL DEFAULT 20,
          default_lock_account_id INTEGER,
          auto_lock INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
          FOREIGN KEY (default_lock_account_id) REFERENCES accounts (id)
        )
      ''');
    }

    final lockTableExists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'locked_allocations'",
    );
    if (lockTableExists.isEmpty) {
      await db.execute('''
        CREATE TABLE locked_allocations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          goal_id INTEGER DEFAULT NULL,
          credit_card_id INTEGER DEFAULT NULL,
          account_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          FOREIGN KEY (goal_id) REFERENCES goals (id),
          FOREIGN KEY (credit_card_id) REFERENCES credit_cards (id) ON DELETE CASCADE,
          FOREIGN KEY (account_id) REFERENCES accounts (id)
        )
      ''');
    } else {
      final lockCols = await db.rawQuery("PRAGMA table_info('locked_allocations')");
      final hasCreditCardId = lockCols.any((c) => c['name'] == 'credit_card_id');
      if (!hasCreditCardId) {
        await db.execute('''
          CREATE TABLE locked_allocations_v3 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            goal_id INTEGER DEFAULT NULL,
            credit_card_id INTEGER DEFAULT NULL,
            account_id INTEGER NOT NULL,
            amount REAL NOT NULL,
            FOREIGN KEY (goal_id) REFERENCES goals (id),
            FOREIGN KEY (credit_card_id) REFERENCES credit_cards (id) ON DELETE CASCADE,
            FOREIGN KEY (account_id) REFERENCES accounts (id)
          )
        ''');
        await db.execute('''
          INSERT INTO locked_allocations_v3 (id, goal_id, credit_card_id, account_id, amount)
          SELECT id, goal_id, NULL, account_id, amount FROM locked_allocations
        ''');
        await db.execute('DROP TABLE locked_allocations');
        await db.execute('ALTER TABLE locked_allocations_v3 RENAME TO locked_allocations');
      }
    }

    final txSql = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'transactions'",
    );
    if (txSql.isNotEmpty) {
      final sql = (txSql.first['sql'] as String? ?? '').toLowerCase();
      if (!sql.contains('cc_payment')) {
        await db.execute('''
          CREATE TABLE transactions_v3 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_id INTEGER NOT NULL,
            destination_account_id INTEGER DEFAULT NULL,
            category_id INTEGER DEFAULT NULL,
            goal_id INTEGER DEFAULT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            note TEXT,
            type TEXT NOT NULL DEFAULT 'expense'
              CHECK (type IN ('expense', 'income', 'transfer', 'goal_lock', 'goal_unlock', 'goal_payment', 'cc_payment', 'cc_lock', 'cc_unlock')),
            FOREIGN KEY (account_id) REFERENCES accounts (id),
            FOREIGN KEY (destination_account_id) REFERENCES accounts (id),
            FOREIGN KEY (category_id) REFERENCES categories (id),
            FOREIGN KEY (goal_id) REFERENCES goals (id)
          )
        ''');
        await db.execute('''
          INSERT INTO transactions_v3 (id, account_id, destination_account_id, category_id, goal_id, amount, date, note, type)
          SELECT id, account_id, destination_account_id, category_id, goal_id, amount, date, note, type FROM transactions
        ''');
        await db.execute('DROP TABLE transactions');
        await db.execute('ALTER TABLE transactions_v3 RENAME TO transactions');
      }
    }
  }

  Future<void> _migrateV3toV4(Database db) async {
    final catCols = await db.rawQuery("PRAGMA table_info('categories')");
    final hasType = catCols.any((c) => c['name'] == 'type');
    if (!hasType) {
      await db.execute(
        "ALTER TABLE categories ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'",
      );
    }

    final incomeCats = await db.rawQuery(
      "SELECT id FROM categories WHERE type = 'income'",
    );
    if (incomeCats.isEmpty) {
      final defaultIncome = [
        'Salary',
        'Freelance',
        'Investments',
        'Rental',
        'Gifts',
        'Other Income',
      ];
      for (final name in defaultIncome) {
        await db.insert('categories', {
          'name': name,
          'monthly_budget': null,
          'type': 'income',
        });
      }
    }
  }

  // --- CREATE TABLES ---
  Future _createDB(Database db, int version) async {
    // 1. Accounts Table
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        balance REAL NOT NULL,
        type TEXT NOT NULL
      )
    ''');

    // 2. Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        monthly_budget REAL DEFAULT NULL,
        type TEXT NOT NULL DEFAULT 'expense'
      )
    ''');

    // 3. Transactions Table
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
          CHECK (type IN ('expense', 'income', 'transfer', 'goal_lock', 'goal_unlock', 'goal_payment', 'cc_payment', 'cc_lock', 'cc_unlock')),
        FOREIGN KEY (account_id) REFERENCES accounts (id),
        FOREIGN KEY (destination_account_id) REFERENCES accounts (id),
        FOREIGN KEY (category_id) REFERENCES categories (id),
        FOREIGN KEY (goal_id) REFERENCES goals (id)
      )
    ''');

    // 4. Goals Table
    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        total_target REAL NOT NULL,
        target_date TEXT NOT NULL,
        current_saved REAL NOT NULL
      )
    ''');

    // 5. Credit Cards Table
    await db.execute('''
      CREATE TABLE credit_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL UNIQUE,
        credit_limit REAL NOT NULL,
        statement_day INTEGER NOT NULL DEFAULT 1,
        due_day INTEGER NOT NULL DEFAULT 20,
        default_lock_account_id INTEGER,
        auto_lock INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
        FOREIGN KEY (default_lock_account_id) REFERENCES accounts (id)
      )
    ''');

    // 6. Locked Allocations Table (The Bridge)
    await db.execute('''
      CREATE TABLE locked_allocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER DEFAULT NULL,
        credit_card_id INTEGER DEFAULT NULL,
        account_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY (goal_id) REFERENCES goals (id),
        FOREIGN KEY (credit_card_id) REFERENCES credit_cards (id) ON DELETE CASCADE,
        FOREIGN KEY (account_id) REFERENCES accounts (id)
      )
    ''');

    // 7. App Settings Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // --- ACCOUNT OPERATIONS ---
  Future<int> createAccount(Account account) async {
    final db = await instance.database;
    final id = await db.insert('accounts', account.toMap());
    notifyDataChanged();
    return id;
  }

  Future<List<Account>> readAllAccounts() async {
    final db = await instance.database;
    final result = await db.query('accounts');
    return result.map((json) => Account.fromMap(json)).toList();
  }

  Future<Account?> readAccount(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return Account.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateAccountBalance(int id, double newBalance) async {
    final db = await instance.database;
    final res = await db.update(
      'accounts',
      {'balance': newBalance},
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyDataChanged();
    return res;
  }

  Future<int> updateAccount(Account account) async {
    final db = await instance.database;
    final res = await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
    notifyDataChanged();
    return res;
  }

  Future<int> deleteAccount(int id) async {
    final db = await instance.database;
    final res = await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    notifyDataChanged();
    return res;
  }

  // Close database
  Future close() async {
    final db = _database;
    _database = null;
    _databaseFuture = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  // --- DATABASE MANAGEMENT ---

  /// Exports the database file to a user-selected location or effective backup directory.
  Future<String?> exportDatabase({
    String? destinationDirectory,
    String? fileName,
  }) async {
    if (kIsWeb) return null;

    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'money_tracker.db');
      final file = File(path);

      if (!await file.exists()) {
        throw Exception('Database file not found');
      }

      final targetDir = destinationDirectory ?? await getEffectiveBackupDirectory();
      final name = fileName ?? 'cashflow_backup.db';
      final backupDir = Directory(targetDir);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      final backupPath = join(targetDir, name);
      final backupFile = await file.copy(backupPath);
      await setLastBackupTimestamp(DateTime.now());

      return backupFile.path;
    } catch (e, stackTrace) {
      developer.log(
        'Export error',
        name: 'DatabaseHelper',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Imports a database file from a user-selected location.
  Future<bool> importDatabase() async {
    if (kIsWeb) return false;

    try {
      final bytes = await pickBackupBytes();
      if (bytes == null) return false;

      await close();
      _database = null;

      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'money_tracker.db');

      await File(path).writeAsBytes(bytes, flush: true);
      await instance.database;
      notifyDataChanged();

      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Import error',
        name: 'DatabaseHelper',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // --- CATEGORY OPERATIONS ---
  Future<int> createCategory(Category category) async {
    final db = await instance.database;
    final id = await db.insert('categories', category.toMap());
    notifyDataChanged();
    return id;
  }

  Future<int> updateCategory(Category category) async {
    final db = await instance.database;
    final res = await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
    notifyDataChanged();
    return res;
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    final res = await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    notifyDataChanged();
    return res;
  }

  Future<List<Category>> readAllCategories({String? type}) async {
    final db = await instance.database;
    final result = type != null
        ? await db.query('categories', where: 'type = ?', whereArgs: [type])
        : await db.query('categories');
    return result.map((json) => Category.fromMap(json)).toList();
  }

  Future<List<Category>> readCategoriesByType(String type) async {
    return readAllCategories(type: type);
  }

  // --- TRANSACTION OPERATIONS ---
  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    final id = await db.insert('transactions', transaction.toMap());
    notifyDataChanged();
    return id;
  }

  Future<int> createExpenseTransaction({
    required int accountId,
    required int categoryId,
    required double amount,
    required String date,
    String note = '',
  }) async {
    return _createTransaction(
      accountId: accountId,
      categoryId: categoryId,
      amount: amount,
      date: date,
      note: note,
      type: 'expense',
      updateAccount: -amount,
    );
  }

  Future<int> createIncomeTransaction({
    required int accountId,
    required double amount,
    required String date,
    int? categoryId,
    String note = '',
  }) async {
    return _createTransaction(
      accountId: accountId,
      categoryId: categoryId,
      amount: amount,
      date: date,
      note: note,
      type: 'income',
      updateAccount: amount,
    );
  }

  Future<int> createTransferTransaction({
    required int sourceAccountId,
    required int destinationAccountId,
    required double amount,
    required String date,
    String note = '',
  }) async {
    _validateAmount(amount);
    if (sourceAccountId == destinationAccountId) {
      throw ArgumentError('Transfer accounts must be different');
    }

    final db = await instance.database;
    final id = await db.transaction((txn) async {
      await _requireAccount(txn, sourceAccountId);
      await _requireAccount(txn, destinationAccountId);
      await _adjustAccountBalance(txn, sourceAccountId, -amount);
      await _adjustAccountBalance(txn, destinationAccountId, amount);
      return txn.insert('transactions', {
        'account_id': sourceAccountId,
        'destination_account_id': destinationAccountId,
        'category_id': null,
        'goal_id': null,
        'amount': amount,
        'date': date,
        'note': note,
        'type': 'transfer',
      });
    });
    notifyDataChanged();
    return id;
  }

  Future<int> createGoalLockTransaction({
    required int goalId,
    required int accountId,
    required double amount,
    required String date,
    String note = '',
  }) async {
    _validateAmount(amount);
    final db = await instance.database;
    final id = await db.transaction((txn) async {
      final account = await txn.query(
        'accounts',
        columns: ['id', 'balance'],
        where: 'id = ?',
        whereArgs: [accountId],
      );
      if (account.isEmpty) throw StateError('Account not found: $accountId');
      final accountBalance = (account.first['balance'] as num).toDouble();
      final lockedResult = await txn.rawQuery(
        'SELECT SUM(amount) as total FROM locked_allocations WHERE account_id = ?',
        [accountId],
      );
      final currentLocked = (lockedResult.first['total'] as num? ?? 0)
          .toDouble();
      if (currentLocked + amount > accountBalance) {
        throw StateError('Insufficient account funds to lock');
      }

      await _requireGoal(txn, goalId);
      await txn.insert('locked_allocations', {
        'goal_id': goalId,
        'account_id': accountId,
        'amount': amount,
      });
      await txn.rawUpdate(
        'UPDATE goals SET current_saved = current_saved + ? WHERE id = ?',
        [amount, goalId],
      );
      return txn.insert('transactions', {
        'account_id': accountId,
        'destination_account_id': null,
        'category_id': null,
        'goal_id': goalId,
        'amount': amount,
        'date': date,
        'note': note,
        'type': 'goal_lock',
      });
    });
    notifyDataChanged();
    return id;
  }

  Future<List<int>> createMultiAccountGoalUnlockTransactions({
    required int goalId,
    required Map<int, double> amountsPerAccount,
    required String date,
    String note = '',
  }) async {
    if (amountsPerAccount.isEmpty) {
      throw ArgumentError('Amounts per account cannot be empty');
    }
    double totalAmount = 0.0;
    for (final entry in amountsPerAccount.entries) {
      _validateAmount(entry.value);
      totalAmount += entry.value;
    }

    final db = await instance.database;
    final ids = await db.transaction((txn) async {
      await _requireGoal(txn, goalId);

      final createdIds = <int>[];
      for (final entry in amountsPerAccount.entries) {
        final accountId = entry.key;
        final amount = entry.value;

        await _requireAccount(txn, accountId);
        final lock = await _requireLockedAllocation(txn, goalId, accountId);
        final lockedAmount = (lock['amount'] as num).toDouble();
        if (lockedAmount < amount) {
          throw StateError('Insufficient locked funds in account $accountId');
        }

        await _reduceLockedAllocation(txn, lock, amount);

        final id = await txn.insert('transactions', {
          'account_id': accountId,
          'destination_account_id': null,
          'category_id': null,
          'goal_id': goalId,
          'amount': amount,
          'date': date,
          'note': note,
          'type': 'goal_unlock',
        });
        createdIds.add(id);
      }

      await txn.rawUpdate(
        'UPDATE goals SET current_saved = MAX(0.0, current_saved - ?) WHERE id = ?',
        [totalAmount, goalId],
      );

      return createdIds;
    });

    notifyDataChanged();
    return ids;
  }

  Future<int> createGoalUnlockTransaction({
    required int goalId,
    required int accountId,
    required double amount,
    required String date,
    String note = '',
  }) async {
    final ids = await createMultiAccountGoalUnlockTransactions(
      goalId: goalId,
      amountsPerAccount: {accountId: amount},
      date: date,
      note: note,
    );
    return ids.first;
  }

  Future<List<int>> createMultiAccountGoalPaymentTransactions({
    required int goalId,
    required Map<int, double> amountsPerAccount,
    required String date,
    int? categoryId,
    String note = '',
  }) async {
    if (amountsPerAccount.isEmpty) {
      throw ArgumentError('Amounts per account cannot be empty');
    }
    double totalAmount = 0.0;
    for (final entry in amountsPerAccount.entries) {
      _validateAmount(entry.value);
      totalAmount += entry.value;
    }

    final db = await instance.database;
    final ids = await db.transaction((txn) async {
      await _requireGoal(txn, goalId);
      if (categoryId != null) {
        await _requireCategory(txn, categoryId);
      }

      final createdIds = <int>[];
      for (final entry in amountsPerAccount.entries) {
        final accountId = entry.key;
        final amount = entry.value;

        await _requireAccount(txn, accountId);
        final accRes = await txn.query(
          'accounts',
          columns: ['balance'],
          where: 'id = ?',
          whereArgs: [accountId],
        );
        final accountBalance = (accRes.first['balance'] as num).toDouble();
        if (accountBalance < amount) {
          throw StateError('Insufficient account balance in account $accountId');
        }

        final lock = await _requireLockedAllocation(txn, goalId, accountId);
        final lockedAmount = (lock['amount'] as num).toDouble();
        if (lockedAmount < amount) {
          throw StateError('Insufficient locked funds in account $accountId');
        }

        await _adjustAccountBalance(txn, accountId, -amount);
        await _reduceLockedAllocation(txn, lock, amount);

        final id = await txn.insert('transactions', {
          'account_id': accountId,
          'destination_account_id': null,
          'category_id': categoryId,
          'goal_id': goalId,
          'amount': amount,
          'date': date,
          'note': note,
          'type': 'goal_payment',
        });
        createdIds.add(id);
      }

      await txn.rawUpdate(
        'UPDATE goals SET current_saved = MAX(0.0, current_saved - ?) WHERE id = ?',
        [totalAmount, goalId],
      );

      return createdIds;
    });

    notifyDataChanged();
    return ids;
  }

  Future<int> createGoalPaymentTransaction({
    required int goalId,
    required int accountId,
    required double amount,
    required String date,
    int? categoryId,
    String note = '',
  }) async {
    final ids = await createMultiAccountGoalPaymentTransactions(
      goalId: goalId,
      amountsPerAccount: {accountId: amount},
      date: date,
      categoryId: categoryId,
      note: note,
    );
    return ids.first;
  }

  Future<int> _createTransaction({
    required int accountId,
    int? categoryId,
    required double amount,
    required String date,
    required String note,
    required String type,
    required double updateAccount,
  }) async {
    _validateAmount(amount);
    final db = await instance.database;
    final id = await db.transaction((txn) async {
      await _requireAccount(txn, accountId);
      if (categoryId != null) {
        await _requireCategory(txn, categoryId);
      }
      await _adjustAccountBalance(txn, accountId, updateAccount);
      return txn.insert('transactions', {
        'account_id': accountId,
        'destination_account_id': null,
        'category_id': categoryId,
        'goal_id': null,
        'amount': amount,
        'date': date,
        'note': note,
        'type': type,
      });
    });
    notifyDataChanged();
    return id;
  }

  void _validateAmount(double amount) {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('Amount must be greater than zero');
    }
  }

  Future<void> _requireAccount(Transaction txn, int accountId) async {
    final result = await txn.query(
      'accounts',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [accountId],
    );
    if (result.isEmpty) throw StateError('Account not found: $accountId');
  }

  Future<void> _requireCategory(Transaction txn, int categoryId) async {
    final result = await txn.query(
      'categories',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [categoryId],
    );
    if (result.isEmpty) throw StateError('Category not found: $categoryId');
  }

  Future<void> _requireGoal(Transaction txn, int goalId) async {
    final result = await txn.query(
      'goals',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [goalId],
    );
    if (result.isEmpty) throw StateError('Goal not found: $goalId');
  }

  Future<Map<String, Object?>> _requireLockedAllocation(
    Transaction txn,
    int goalId,
    int accountId,
  ) async {
    final result = await txn.query(
      'locked_allocations',
      where: 'goal_id = ? AND account_id = ?',
      whereArgs: [goalId, accountId],
      limit: 1,
    );
    if (result.isEmpty) {
      throw StateError('No locked funds found for this goal and account');
    }
    return Map<String, Object?>.from(result.first);
  }

  Future<void> _adjustAccountBalance(
    Transaction txn,
    int accountId,
    double adjustment,
  ) async {
    final acc = await txn.query(
      'accounts',
      columns: ['type'],
      where: 'id = ?',
      whereArgs: [accountId],
    );
    if (acc.isNotEmpty && acc.first['type'] == 'Credit Card') {
      // For credit cards, balance is liability.
      // Negative adjustment (expense) increases liability; positive adjustment (payment) decreases liability.
      await txn.rawUpdate(
        'UPDATE accounts SET balance = MAX(0.0, balance - ?) WHERE id = ?',
        [adjustment, accountId],
      );
    } else {
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [adjustment, accountId],
      );
    }
  }

  Future<void> _reduceLockedAllocationByCreditCard(
    Transaction txn,
    int creditCardId,
    double amount,
  ) async {
    final locks = await txn.query(
      'locked_allocations',
      where: 'credit_card_id = ?',
      whereArgs: [creditCardId],
      orderBy: 'id DESC',
    );
    double remaining = amount;
    for (final lock in locks) {
      if (remaining <= 0) break;
      final lockId = lock['id'] as int;
      final lockAmount = (lock['amount'] as num).toDouble();
      if (lockAmount <= remaining) {
        await txn.delete(
          'locked_allocations',
          where: 'id = ?',
          whereArgs: [lockId],
        );
        remaining -= lockAmount;
      } else {
        await txn.update(
          'locked_allocations',
          {'amount': lockAmount - remaining},
          where: 'id = ?',
          whereArgs: [lockId],
        );
        remaining = 0;
      }
    }
  }

  Future<void> _reduceLockedAllocation(
    Transaction txn,
    Map<String, Object?> lock,
    double amount,
  ) async {
    final lockId = lock['id'];
    final currentAmount = (lock['amount'] as num).toDouble();
    if (currentAmount == amount) {
      await txn.delete(
        'locked_allocations',
        where: 'id = ?',
        whereArgs: [lockId],
      );
    } else {
      await txn.update(
        'locked_allocations',
        {'amount': currentAmount - amount},
        where: 'id = ?',
        whereArgs: [lockId],
      );
    }
  }

  /// Fetches transactions with optional type and calendar-period filters.
  Future<List<Map<String, dynamic>>> getTransactionHistory({
    String? type,
    int? month,
    int? year,
    DateTime? startDate,
    DateTime? endDate,
    int? goalId,
  }) async {
    final db = await instance.database;
    final where = <String>[];
    final whereArgs = <Object?>[];

    if (goalId != null) {
      where.add('t.goal_id = ?');
      whereArgs.add(goalId);
    }
    if (type != null) {
      where.add('t.type = ?');
      whereArgs.add(type);
    }
    if (month != null) {
      where.add("CAST(strftime('%m', t.date) AS INTEGER) = ?");
      whereArgs.add(month);
    }
    if (year != null) {
      where.add("CAST(strftime('%Y', t.date) AS INTEGER) = ?");
      whereArgs.add(year);
    }
    if (startDate != null) {
      where.add('t.date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      where.add('t.date < ?');
      whereArgs.add(endDate.add(const Duration(days: 1)).toIso8601String());
    }

    return await db.rawQuery('''
      SELECT 
        t.id,
        t.account_id,
        t.destination_account_id,
        t.category_id,
        t.goal_id,
        t.amount,
        t.date,
        t.note,
        t.type,
        a.name AS account_name,
        destination.name AS destination_account_name,
        c.name AS category_name,
        g.name AS goal_name
      FROM transactions t
      JOIN accounts a ON t.account_id = a.id
      LEFT JOIN accounts destination ON t.destination_account_id = destination.id
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN goals g ON t.goal_id = g.id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY t.date DESC, t.id DESC
    ''', whereArgs);
  }

  /// Fetches transactions associated with a specific goal, ordered newest first.
  Future<List<Map<String, dynamic>>> getGoalTransactions(int goalId) async {
    return getTransactionHistory(goalId: goalId);
  }

  // Helper method to subtract money from an account
  Future<void> subtractFromAccount(int accountId, double amount) async {
    final db = await instance.database;

    // 1. Get current balance and type
    List<Map> result = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [accountId],
    );
    if (result.isEmpty) return;
    double currentBalance = (result.first['balance'] as num).toDouble();
    String type = result.first['type'] as String? ?? 'Bank';

    final newBalance = type == 'Credit Card'
        ? currentBalance + amount
        : currentBalance - amount;

    // 2. Update with new balance
    await db.update(
      'accounts',
      {'balance': newBalance},
      where: 'id = ?',
      whereArgs: [accountId],
    );
    notifyDataChanged();
  }

  Future<void> _restoreLockedAllocation(
    Transaction txn,
    int goalId,
    int accountId,
    double amount,
  ) async {
    final existing = await txn.query(
      'locked_allocations',
      where: 'goal_id = ? AND account_id = ?',
      whereArgs: [goalId, accountId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await txn.rawUpdate(
        'UPDATE locked_allocations SET amount = amount + ? WHERE id = ?',
        [amount, existing.first['id']],
      );
    } else {
      await txn.insert('locked_allocations', {
        'goal_id': goalId,
        'account_id': accountId,
        'amount': amount,
      });
    }
  }

  Future<void> _reduceLockedAllocationByGoalAndAccount(
    Transaction txn,
    int goalId,
    int accountId,
    double amount,
  ) async {
    final existing = await txn.query(
      'locked_allocations',
      where: 'goal_id = ? AND account_id = ?',
      whereArgs: [goalId, accountId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final lock = existing.first;
      final current = (lock['amount'] as num).toDouble();
      if (current <= amount) {
        await txn.delete(
          'locked_allocations',
          where: 'id = ?',
          whereArgs: [lock['id']],
        );
      } else {
        await txn.rawUpdate(
          'UPDATE locked_allocations SET amount = amount - ? WHERE id = ?',
          [amount, lock['id']],
        );
      }
    }
  }

  Future<void> _checkUsableFunds(
    Transaction txn,
    int accountId,
    double requiredAmount,
  ) async {
    final account = await txn.query(
      'accounts',
      columns: ['id', 'balance'],
      where: 'id = ?',
      whereArgs: [accountId],
    );
    if (account.isEmpty) throw StateError('Account not found: $accountId');
    final accountBalance = (account.first['balance'] as num).toDouble();
    final lockedResult = await txn.rawQuery(
      'SELECT SUM(amount) as total FROM locked_allocations WHERE account_id = ?',
      [accountId],
    );
    final currentLocked =
        (lockedResult.first['total'] as num? ?? 0).toDouble();
    if (currentLocked + requiredAmount > accountBalance) {
      throw StateError('Insufficient account funds to lock');
    }
  }

  Future<double> _getLockedAmountForGoal(
    Transaction txn,
    int goalId,
    int accountId,
  ) async {
    final res = await txn.query(
      'locked_allocations',
      columns: ['amount'],
      where: 'goal_id = ? AND account_id = ?',
      whereArgs: [goalId, accountId],
      limit: 1,
    );
    if (res.isEmpty) return 0.0;
    return (res.first['amount'] as num).toDouble();
  }

  /// Deletes a transaction and atomically reverses its effects on accounts, budgets, and goals.
  Future<void> deleteTransaction(int transactionId) async {
    final db = await instance.database;

    final result = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
    );

    if (result.isEmpty) return;

    final tx = result.first;
    final type = tx['type'] as String? ?? 'expense';
    final accountId = tx['account_id'] as int;
    final destinationAccountId = tx['destination_account_id'] as int?;
    final goalId = tx['goal_id'] as int?;
    final double amount = (tx['amount'] as num).toDouble();

    await db.transaction((txn) async {
      switch (type) {
        case 'expense':
          await _adjustAccountBalance(txn, accountId, amount);
          final ccRows = await txn.query(
            'credit_cards',
            where: 'account_id = ?',
            whereArgs: [accountId],
          );
          if (ccRows.isNotEmpty) {
            final ccId = ccRows.first['id'] as int;
            await _reduceLockedAllocationByCreditCard(txn, ccId, amount);
          }
          break;

        case 'cc_payment':
          await _adjustAccountBalance(txn, accountId, amount);
          if (destinationAccountId != null) {
            await _adjustAccountBalance(txn, destinationAccountId, -amount);
          }
          break;

        case 'cc_lock':
          final ccRows = await txn.query(
            'credit_cards',
            where: 'account_id = ?',
            whereArgs: [accountId],
          );
          if (ccRows.isNotEmpty) {
            final ccId = ccRows.first['id'] as int;
            await _reduceLockedAllocationByCreditCard(txn, ccId, amount);
          }
          break;

        case 'income':
          await _adjustAccountBalance(txn, accountId, -amount);
          break;

        case 'transfer':
          await _adjustAccountBalance(txn, accountId, amount);
          if (destinationAccountId != null) {
            await _adjustAccountBalance(txn, destinationAccountId, -amount);
          }
          break;

        case 'goal_lock':
          if (goalId != null) {
            await _reduceLockedAllocationByGoalAndAccount(
              txn,
              goalId,
              accountId,
              amount,
            );
            await txn.rawUpdate(
              'UPDATE goals SET current_saved = MAX(0.0, current_saved - ?) WHERE id = ?',
              [amount, goalId],
            );
          }
          break;

        case 'goal_unlock':
          if (goalId != null) {
            await _restoreLockedAllocation(txn, goalId, accountId, amount);
            await txn.rawUpdate(
              'UPDATE goals SET current_saved = current_saved + ? WHERE id = ?',
              [amount, goalId],
            );
          }
          break;

        case 'goal_payment':
          await _adjustAccountBalance(txn, accountId, amount);
          if (goalId != null) {
            await _restoreLockedAllocation(txn, goalId, accountId, amount);
            await txn.rawUpdate(
              'UPDATE goals SET current_saved = current_saved + ? WHERE id = ?',
              [amount, goalId],
            );
          }
          break;

        default:
          await _adjustAccountBalance(txn, accountId, amount);
          break;
      }

      await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });

    notifyDataChanged();
  }

  /// Updates an existing transaction and atomically adjusts balances and allocations.
  Future<void> updateTransaction({
    required int id,
    required double amount,
    required String date,
    required int accountId,
    int? categoryId,
    String? note,
    int? destinationAccountId,
  }) async {
    _validateAmount(amount);
    final db = await instance.database;

    await db.transaction((txn) async {
      final existing = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isEmpty) throw StateError('Transaction not found: $id');

      final oldTx = existing.first;
      final type = oldTx['type'] as String? ?? 'expense';
      final oldAmount = (oldTx['amount'] as num).toDouble();
      final oldAccountId = oldTx['account_id'] as int;
      final oldDestId = oldTx['destination_account_id'] as int?;
      final goalId = oldTx['goal_id'] as int?;

      await _requireAccount(txn, accountId);
      if (categoryId != null) {
        await _requireCategory(txn, categoryId);
      }

      switch (type) {
        case 'expense':
          if (oldAccountId == accountId) {
            final balanceDelta = oldAmount - amount;
            await _adjustAccountBalance(txn, accountId, balanceDelta);
          } else {
            await _adjustAccountBalance(txn, oldAccountId, oldAmount);
            await _adjustAccountBalance(txn, accountId, -amount);
          }
          break;

        case 'income':
          if (oldAccountId == accountId) {
            final balanceDelta = amount - oldAmount;
            await _adjustAccountBalance(txn, accountId, balanceDelta);
          } else {
            await _adjustAccountBalance(txn, oldAccountId, -oldAmount);
            await _adjustAccountBalance(txn, accountId, amount);
          }
          break;

        case 'transfer':
          final targetDestId = destinationAccountId ?? oldDestId;
          if (targetDestId == null) {
            throw ArgumentError('Transfer requires destination account');
          }
          if (accountId == targetDestId) {
            throw ArgumentError('Transfer accounts must be different');
          }
          await _requireAccount(txn, targetDestId);

          await _adjustAccountBalance(txn, oldAccountId, oldAmount);
          if (oldDestId != null) {
            await _adjustAccountBalance(txn, oldDestId, -oldAmount);
          }
          await _adjustAccountBalance(txn, accountId, -amount);
          await _adjustAccountBalance(txn, targetDestId, amount);
          break;

        case 'goal_lock':
          if (goalId != null) {
            if (oldAccountId == accountId) {
              if (amount > oldAmount) {
                final diff = amount - oldAmount;
                await _checkUsableFunds(txn, accountId, diff);
                await _restoreLockedAllocation(txn, goalId, accountId, diff);
                await txn.rawUpdate(
                  'UPDATE goals SET current_saved = current_saved + ? WHERE id = ?',
                  [diff, goalId],
                );
              } else if (amount < oldAmount) {
                final diff = oldAmount - amount;
                await _reduceLockedAllocationByGoalAndAccount(
                  txn,
                  goalId,
                  accountId,
                  diff,
                );
                await txn.rawUpdate(
                  'UPDATE goals SET current_saved = MAX(0.0, current_saved - ?) WHERE id = ?',
                  [diff, goalId],
                );
              }
            } else {
              await _reduceLockedAllocationByGoalAndAccount(
                txn,
                goalId,
                oldAccountId,
                oldAmount,
              );
              await _checkUsableFunds(txn, accountId, amount);
              await _restoreLockedAllocation(txn, goalId, accountId, amount);
              final diff = amount - oldAmount;
              if (diff != 0) {
                await txn.rawUpdate(
                  'UPDATE goals SET current_saved = MAX(0.0, current_saved + ?) WHERE id = ?',
                  [diff, goalId],
                );
              }
            }
          }
          break;

        case 'goal_unlock':
          if (goalId != null) {
            if (oldAccountId == accountId) {
              if (amount > oldAmount) {
                final diff = amount - oldAmount;
                final locked = await _getLockedAmountForGoal(txn, goalId, accountId);
                if (locked < diff) {
                  throw StateError('Insufficient locked funds to unlock');
                }
                await _reduceLockedAllocationByGoalAndAccount(
                  txn,
                  goalId,
                  accountId,
                  diff,
                );
                await txn.rawUpdate(
                  'UPDATE goals SET current_saved = MAX(0.0, current_saved - ?) WHERE id = ?',
                  [diff, goalId],
                );
              } else if (amount < oldAmount) {
                final diff = oldAmount - amount;
                await _checkUsableFunds(txn, accountId, diff);
                await _restoreLockedAllocation(txn, goalId, accountId, diff);
                await txn.rawUpdate(
                  'UPDATE goals SET current_saved = current_saved + ? WHERE id = ?',
                  [diff, goalId],
                );
              }
            } else {
              await _checkUsableFunds(txn, oldAccountId, oldAmount);
              await _restoreLockedAllocation(txn, goalId, oldAccountId, oldAmount);
              final locked = await _getLockedAmountForGoal(txn, goalId, accountId);
              if (locked < amount) {
                throw StateError('Insufficient locked funds on target account');
              }
              await _reduceLockedAllocationByGoalAndAccount(
                txn,
                goalId,
                accountId,
                amount,
              );
              final diff = oldAmount - amount;
              if (diff != 0) {
                await txn.rawUpdate(
                  'UPDATE goals SET current_saved = MAX(0.0, current_saved + ?) WHERE id = ?',
                  [diff, goalId],
                );
              }
            }
          }
          break;

        case 'goal_payment':
          if (goalId != null) {
            if (oldAccountId == accountId) {
              final balanceDelta = oldAmount - amount;
              await _adjustAccountBalance(txn, accountId, balanceDelta);
              if (amount > oldAmount) {
                final diff = amount - oldAmount;
                final locked = await _getLockedAmountForGoal(txn, goalId, accountId);
                if (locked < diff) {
                  throw StateError('Insufficient locked funds for goal payment');
                }
                await _reduceLockedAllocationByGoalAndAccount(
                  txn,
                  goalId,
                  accountId,
                  diff,
                );
                await txn.rawUpdate(
                  'UPDATE goals SET current_saved = MAX(0.0, current_saved - ?) WHERE id = ?',
                  [diff, goalId],
                );
              } else if (amount < oldAmount) {
                final diff = oldAmount - amount;
                await _restoreLockedAllocation(txn, goalId, accountId, diff);
                await txn.rawUpdate(
                  'UPDATE goals SET current_saved = current_saved + ? WHERE id = ?',
                  [diff, goalId],
                );
              }
            } else {
              await _adjustAccountBalance(txn, oldAccountId, oldAmount);
              await _restoreLockedAllocation(txn, goalId, oldAccountId, oldAmount);
              final newAcc = await txn.query(
                'accounts',
                columns: ['balance'],
                where: 'id = ?',
                whereArgs: [accountId],
              );
              if (newAcc.isEmpty) throw StateError('Account not found: $accountId');
              final newBal = (newAcc.first['balance'] as num).toDouble();
              if (newBal < amount) {
                throw StateError('Insufficient account funds for payment');
              }
              final locked = await _getLockedAmountForGoal(txn, goalId, accountId);
              if (locked < amount) {
                throw StateError('Insufficient locked funds on target account');
              }
              await _adjustAccountBalance(txn, accountId, -amount);
              await _reduceLockedAllocationByGoalAndAccount(
                txn,
                goalId,
                accountId,
                amount,
              );
              final diff = oldAmount - amount;
              if (diff != 0) {
                await txn.rawUpdate(
                  'UPDATE goals SET current_saved = MAX(0.0, current_saved + ?) WHERE id = ?',
                  [diff, goalId],
                );
              }
            }
          }
          break;
      }

      await txn.update(
        'transactions',
        {
          'account_id': accountId,
          'destination_account_id': destinationAccountId ?? oldDestId,
          'category_id': categoryId,
          'amount': amount,
          'date': date,
          'note': note ?? '',
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    notifyDataChanged();
  }

  // SEED DATA: Call this once to add default categories
  Future<void> seedDatabase() async {
    final categories = [
      Category(name: 'Groceries', monthlyBudget: 15000, type: 'expense'),
      Category(name: 'Dining Out', monthlyBudget: 8000, type: 'expense'),
      Category(name: 'Transport', monthlyBudget: 5000, type: 'expense'),
      Category(name: 'Entertainment', monthlyBudget: 4000, type: 'expense'),
      Category(name: 'Utilities & Bills', monthlyBudget: 10000, type: 'expense'),
      Category(name: 'Shopping', monthlyBudget: 6000, type: 'expense'),
      Category(name: 'Salary', type: 'income'),
      Category(name: 'Freelance', type: 'income'),
      Category(name: 'Investments', type: 'income'),
      Category(name: 'Rental', type: 'income'),
      Category(name: 'Gifts', type: 'income'),
      Category(name: 'Other Income', type: 'income'),
    ];
    for (var cat in categories) {
      await createCategory(cat);
    }
    notifyDataChanged();
  }

  /// Populates comprehensive sample data (Accounts, Goals, Categories, Transactions) for demo & testing
  Future<void> seedSampleData() async {
    await resetDatabase();

    // 1. Accounts
    final salaryAccId = await createAccount(
      Account(name: 'Salary Account (HDFC)', balance: 125000.0, type: 'Bank'),
    );
    final savingsAccId = await createAccount(
      Account(
        name: 'Emergency Savings (SBI)',
        balance: 180000.0,
        type: 'Savings',
      ),
    );
    final walletAccId = await createAccount(
      Account(name: 'Cash Wallet', balance: 8500.0, type: 'Cash'),
    );

    // 2. Categories
    final catGroceries = await createCategory(
      Category(name: 'Groceries', monthlyBudget: 15000),
    );
    final catDining = await createCategory(
      Category(name: 'Dining Out', monthlyBudget: 8000),
    );
    final catShopping = await createCategory(
      Category(name: 'Shopping', monthlyBudget: 7000),
    );
    final catUtilities = await createCategory(
      Category(name: 'Utilities & Bills', monthlyBudget: 10000),
    );
    final catTransport = await createCategory(
      Category(name: 'Transport & Fuel', monthlyBudget: 5000),
    );
    final catHealth = await createCategory(
      Category(name: 'Health & Medical', monthlyBudget: 4000),
    );
    final catEntertainment = await createCategory(
      Category(name: 'Entertainment & Leisure'), // Unbudgeted optional category
    );
    final catSalary = await createCategory(
      Category(name: 'Salary', type: 'income'),
    );
    final catFreelance = await createCategory(
      Category(name: 'Freelance & Consulting', type: 'income'),
    );
    final catInvestments = await createCategory(
      Category(name: 'Investments & Dividends', type: 'income'),
    );

    // Date generation helpers
    DateTime monthOffset(
      DateTime base,
      int monthsBack,
      int day, [
      int hour = 12,
      int minute = 0,
    ]) {
      int year = base.year;
      int month = base.month - monthsBack;
      while (month <= 0) {
        month += 12;
        year -= 1;
      }
      while (month > 12) {
        month -= 12;
        year += 1;
      }
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final clampedDay = day > daysInMonth ? daysInMonth : day;
      return DateTime(year, month, clampedDay, hour, minute);
    }

    final now = DateTime.now();
    final salaryDay = await getSalaryDay();
    final currentCycle = SalaryCycle.resolve(salaryDay: salaryDay, today: now);
    final cycleStart = currentCycle.cycleStart;

    DateTime currentCycleDate(int dayOffset, [int hour = 12, int minute = 0]) {
      final d = cycleStart.add(Duration(days: dayOffset));
      final candidate = DateTime(d.year, d.month, d.day, hour, minute);
      return candidate.isAfter(now) ? now : candidate;
    }

    // 3. Sinking Funds / Goals
    final goalInsurance = await createGoal(
      Goal(
        name: 'Annual Car Insurance',
        totalTarget: 25000.0,
        targetDate:
            monthOffset(now, -2, 28).toIso8601String().substring(0, 10),
        currentSaved: 0.0,
      ),
    );
    final goalVacation = await createGoal(
      Goal(
        name: 'Goa Vacation Fund',
        totalTarget: 40000.0,
        targetDate:
            monthOffset(now, -3, 25).toIso8601String().substring(0, 10),
        currentSaved: 0.0,
      ),
    );
    final goalGadget = await createGoal(
      Goal(
        name: 'New Laptop (M3 Pro)',
        totalTarget: 80000.0,
        targetDate:
            monthOffset(now, -6, 28).toIso8601String().substring(0, 10),
        currentSaved: 0.0,
      ),
    );
    final goalAppliance = await createGoal(
      Goal(
        name: 'Home Appliance Upgrade',
        totalTarget: 20000.0,
        targetDate:
            monthOffset(now, -1, 15).toIso8601String().substring(0, 10),
        currentSaved: 0.0,
      ),
    );

    // 4. Historical Monthly Activity (Months M-5 through M-1)
    // Generates realistic spending trends, recurring salaries, and transfers.
    for (int m = 5; m >= 1; m--) {
      // Monthly Salary Credit (Day 1)
      await createIncomeTransaction(
        accountId: salaryAccId,
        categoryId: catSalary,
        amount: 95000.0,
        date: monthOffset(now, m, 1, 9, 30).toIso8601String(),
        note: 'Monthly salary deposit',
      );

      // Monthly Savings Transfer (Day 2)
      await createTransferTransaction(
        sourceAccountId: salaryAccId,
        destinationAccountId: savingsAccId,
        amount: 15000.0,
        date: monthOffset(now, m, 2, 10, 0).toIso8601String(),
        note: 'Monthly recurring savings transfer',
      );

      // Cash Withdrawal to Wallet (Day 3)
      await createTransferTransaction(
        sourceAccountId: salaryAccId,
        destinationAccountId: walletAccId,
        amount: 4000.0,
        date: monthOffset(now, m, 3, 11, 0).toIso8601String(),
        note: 'ATM cash withdrawal',
      );

      // Category Expenses with natural monthly variance for realistic trend curves
      final groceryAmounts = [12100.0, 13600.0, 11800.0, 14200.0, 12400.0];
      await createExpenseTransaction(
        accountId: salaryAccId,
        categoryId: catGroceries,
        amount: groceryAmounts[5 - m],
        date: monthOffset(now, m, 7, 18, 30).toIso8601String(),
        note: 'Supermarket bulk groceries & pantry stock',
      );

      final utilityAmounts = [8500.0, 9100.0, 8200.0, 9400.0, 8900.0];
      await createExpenseTransaction(
        accountId: salaryAccId,
        categoryId: catUtilities,
        amount: utilityAmounts[5 - m],
        date: monthOffset(now, m, 10, 14, 0).toIso8601String(),
        note: 'Electricity, water & fiber internet bill',
      );

      final transportAmounts = [3900.0, 4800.0, 3800.0, 4600.0, 4200.0];
      await createExpenseTransaction(
        accountId: salaryAccId,
        categoryId: catTransport,
        amount: transportAmounts[5 - m],
        date: monthOffset(now, m, 14, 8, 45).toIso8601String(),
        note: 'Monthly fuel fill-up & metro smart card',
      );

      final diningAmounts = [6200.0, 7400.0, 5900.0, 9100.0, 6800.0];
      await createExpenseTransaction(
        accountId: salaryAccId,
        categoryId: catDining,
        amount: (diningAmounts[5 - m] * 0.7).roundToDouble(),
        date: monthOffset(now, m, 18, 20, 15).toIso8601String(),
        note: 'Restaurants & team dinner',
      );
      await createExpenseTransaction(
        accountId: walletAccId,
        categoryId: catDining,
        amount: (diningAmounts[5 - m] * 0.3).roundToDouble(),
        date: monthOffset(now, m, 22, 13, 0).toIso8601String(),
        note: 'Weekend cafe & casual lunch',
      );

      final shoppingAmounts = [5100.0, 6900.0, 4500.0, 11200.0, 5600.0];
      await createExpenseTransaction(
        accountId: salaryAccId,
        categoryId: catShopping,
        amount: shoppingAmounts[5 - m],
        date: monthOffset(now, m, 24, 16, 30).toIso8601String(),
        note: m == 2
            ? 'Festive season electronics & apparel'
            : 'Clothing & household essentials',
      );

      await createExpenseTransaction(
        accountId: salaryAccId,
        categoryId: catEntertainment,
        amount: 5500.0,
        date: monthOffset(now, m, 15, 15, 0).toIso8601String(),
        note: 'Online apparel & home items',
      );

      // Cash Wallet expenses
      await createExpenseTransaction(
        accountId: walletAccId,
        categoryId: catDining,
        amount: 650.0,
        date: monthOffset(now, m, 10, 13, 0).toIso8601String(),
        note: 'Street food and coffee with colleagues',
      );
      await createExpenseTransaction(
        accountId: walletAccId,
        categoryId: catTransport,
        amount: 450.0,
        date: monthOffset(now, m, 18, 17, 30).toIso8601String(),
        note: 'Local metro & auto rickshaw rides',
      );

      // Occasional Health & Leisure spends in select months
      if (m == 1 || m == 3 || m == 5) {
        await createExpenseTransaction(
          accountId: salaryAccId,
          categoryId: catEntertainment,
          amount: 2200.0,
          date: monthOffset(now, m, 24, 19, 0).toIso8601String(),
          note: 'Movie night tickets & weekend arcade',
        );
      }
      if (m == 2 || m == 4) {
        await createExpenseTransaction(
          accountId: walletAccId,
          categoryId: catHealth,
          amount: m == 4 ? 3200.0 : 2100.0,
          date: monthOffset(now, m, 16, 11, 20).toIso8601String(),
          note: 'Pharmacy medicines & routine health checkup',
        );
      }

      if (m == 2) {
        await createIncomeTransaction(
          accountId: salaryAccId,
          categoryId: catFreelance,
          amount: 28000.0,
          date: monthOffset(now, m, 12, 15, 0).toIso8601String(),
          note: 'Freelance consulting retainer fee',
        );
      }
      if (m == 3) {
        await createIncomeTransaction(
          accountId: salaryAccId,
          categoryId: catInvestments,
          amount: 6500.0,
          date: monthOffset(now, m, 20, 14, 0).toIso8601String(),
          note: 'Quarterly dividend payout',
        );
      }
    }

    // 5. Current Month Active Activity (M0)
    // Exercises all scenario states: over-budget, full budget, on-track, untouched, unbudgeted.
    final d1 = currentCycleDate(0, 9, 0).toIso8601String();
    final d2 = currentCycleDate(1, 10, 0).toIso8601String();
    final d3 = currentCycleDate(2, 11, 0).toIso8601String();

    await createIncomeTransaction(
      accountId: salaryAccId,
      categoryId: catSalary,
      amount: 95000.0,
      date: d1,
      note: 'Monthly salary deposit',
    );
    await createTransferTransaction(
      sourceAccountId: salaryAccId,
      destinationAccountId: savingsAccId,
      amount: 12000.0,
      date: d2,
      note: 'Monthly savings transfer',
    );
    await createTransferTransaction(
      sourceAccountId: salaryAccId,
      destinationAccountId: walletAccId,
      amount: 4000.0,
      date: d3,
      note: 'ATM cash withdrawal',
    );

    // Scenario 1: On-Track Budget - Groceries (Cap: 15,000 | Spent: 7,850 | 52% on track)
    await createExpenseTransaction(
      accountId: salaryAccId,
      categoryId: catGroceries,
      amount: 4250.0,
      date: currentCycleDate(1, 17, 30).toIso8601String(),
      note: 'Supermarket weekly grocery stock',
    );
    await createExpenseTransaction(
      accountId: salaryAccId,
      categoryId: catGroceries,
      amount: 3600.0,
      date: currentCycleDate(3, 11, 15).toIso8601String(),
      note: 'Fresh produce & organic supplies',
    );

    // Scenario 2: Over-Budget Category - Dining Out (Cap: 8,000 | Spent: 8,850 | Over by 850)
    await createExpenseTransaction(
      accountId: salaryAccId,
      categoryId: catDining,
      amount: 2850.0,
      date: currentCycleDate(2, 20, 0).toIso8601String(),
      note: 'Weekend family dinner',
    );
    await createExpenseTransaction(
      accountId: salaryAccId,
      categoryId: catDining,
      amount: 3400.0,
      date: currentCycleDate(4, 21, 0).toIso8601String(),
      note: 'Team outing & dinner celebration',
    );
    await createExpenseTransaction(
      accountId: walletAccId,
      categoryId: catDining,
      amount: 2600.0,
      date: currentCycleDate(5, 13, 15).toIso8601String(),
      note: 'Bistro cafe & artisan bakery',
    );

    // Scenario 3: 100% Full Budget - Shopping (Cap: 7,000 | Spent: 7,000 | 0 remaining)
    await createExpenseTransaction(
      accountId: salaryAccId,
      categoryId: catShopping,
      amount: 4200.0,
      date: currentCycleDate(2, 16, 0).toIso8601String(),
      note: 'Wardrobe seasonal apparel essentials',
    );
    await createExpenseTransaction(
      accountId: salaryAccId,
      categoryId: catShopping,
      amount: 2800.0,
      date: currentCycleDate(4, 15, 30).toIso8601String(),
      note: 'Home decor & organizer storage',
    );

    // Scenario 4: Low-Spend Budget - Transport & Fuel (Cap: 5,000 | Spent: 1,800 | 36% used)
    await createExpenseTransaction(
      accountId: salaryAccId,
      categoryId: catTransport,
      amount: 1800.0,
      date: currentCycleDate(3, 8, 30).toIso8601String(),
      note: 'Fuel station refill & metro card recharge',
    );

    // Scenario 5: Active Budget - Utilities & Bills (Cap: 10,000 | Spent: 4,800 | 48% used)
    await createExpenseTransaction(
      accountId: salaryAccId,
      categoryId: catUtilities,
      amount: 4800.0,
      date: currentCycleDate(1, 14, 0).toIso8601String(),
      note: 'Electricity & high-speed fiber broadband bill',
    );

    // Scenario 6: Untouched Category - Health & Medical (Cap: 4,000 | Spent: 0 | 100% remaining)
    // Intentionally 0 expenses in current cycle to showcase untouched category state.

    // Scenario 7: Unbudgeted Category - Entertainment & Leisure (Cap: null | Spent: 2,399)
    await createExpenseTransaction(
      accountId: salaryAccId,
      categoryId: catEntertainment,
      amount: 1499.0,
      date: currentCycleDate(2, 19, 0).toIso8601String(),
      note: 'Streaming video & music bundle subscription',
    );
    await createExpenseTransaction(
      accountId: walletAccId,
      categoryId: catEntertainment,
      amount: 900.0,
      date: currentCycleDate(5, 19, 30).toIso8601String(),
      note: 'Weekend IMAX cinema movie tickets',
    );

    // 6. Goal Sinking Fund Transactions
    // Goal 1: 100% Funded / Completed - Annual Car Insurance (Target 25k, Saved 25k) 🎉
    await createGoalLockTransaction(
      goalId: goalInsurance,
      accountId: savingsAccId,
      amount: 25000.0,
      date: currentCycleDate(1, 12, 0).toIso8601String(),
      note: 'Reserve complete annual car insurance target',
    );

    // Goal 2: In-Progress with Unlock - Goa Vacation Fund (Target 40k | Lock 20k, Unlock 3k -> Net 17k)
    await createGoalLockTransaction(
      goalId: goalVacation,
      accountId: salaryAccId,
      amount: 20000.0,
      date: currentCycleDate(2, 11, 0).toIso8601String(),
      note: 'Reserve vacation flight & hotel fund',
    );
    await createGoalUnlockTransaction(
      goalId: goalVacation,
      accountId: salaryAccId,
      amount: 3000.0,
      date: currentCycleDate(4, 14, 0).toIso8601String(),
      note: 'Release adjusted vacation booking buffer',
    );

    // Goal 3: Long-term Goal with Pacing Advice - New Laptop (Target 80k | Locked 35k)
    await createGoalLockTransaction(
      goalId: goalGadget,
      accountId: savingsAccId,
      amount: 35000.0,
      date: currentCycleDate(2, 10, 30).toIso8601String(),
      note: 'Reserve laptop upgrade allocation',
    );

    // Goal 4: Goal with Payment Executed - Home Appliance Upgrade (Target 20k | Lock 14k, Pay 5k -> Net 9k)
    await createGoalLockTransaction(
      goalId: goalAppliance,
      accountId: salaryAccId,
      amount: 14000.0,
      date: currentCycleDate(1, 11, 30).toIso8601String(),
      note: 'Reserve kitchen appliance installation fund',
    );
    await createGoalPaymentTransaction(
      goalId: goalAppliance,
      accountId: salaryAccId,
      amount: 5000.0,
      date: currentCycleDate(3, 16, 0).toIso8601String(),
      note: 'Pay advance appliance installation invoice',
    );

    notifyDataChanged();
  }

  // --- GOAL OPERATIONS ---
  Future<int> createGoal(Goal goal) async {
    final db = await instance.database;
    final id = await db.insert('goals', goal.toMap());
    notifyDataChanged();
    return id;
  }

  Future<int> updateGoal(Goal goal) async {
    final db = await instance.database;
    final res = await db.update(
      'goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
    notifyDataChanged();
    return res;
  }

  Future<void> deleteGoal(int goalId) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      // 1. Find all locked allocations for this goal
      final locks = await txn.query(
        'locked_allocations',
        where: 'goal_id = ?',
        whereArgs: [goalId],
      );

      // 2. For each lock, refund the amount to the respective account
      for (var lock in locks) {
        final int accountId = lock['account_id'] as int;
        final double amount = (lock['amount'] as num).toDouble();

        List<Map> accRes = await txn.query(
          'accounts',
          where: 'id = ?',
          whereArgs: [accountId],
        );

        if (accRes.isNotEmpty) {
          double currentBalance = accRes.first['balance'];
          await txn.update(
            'accounts',
            {'balance': currentBalance + amount},
            where: 'id = ?',
            whereArgs: [accountId],
          );
        }
      }

      // 3. Delete the goal itself
      await txn.delete('goals', where: 'id = ?', whereArgs: [goalId]);

      // 4. Delete all associated locked allocations
      await txn.delete(
        'locked_allocations',
        where: 'goal_id = ?',
        whereArgs: [goalId],
      );
    });
    notifyDataChanged();
  }

  Future<Goal?> readGoal(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'goals',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Goal.fromMap(result.first);
  }

  Future<List<Goal>> readAllGoals() async {
    final db = await instance.database;
    final result = await db.query('goals');
    return result.map((json) => Goal.fromMap(json)).toList();
  }

  // Lock funds: This does TWO things:
  // 1. Adds a record to locked_allocations
  // 2. Updates the current_saved amount in goals
  Future<void> lockFunds(int goalId, int accountId, double amount) async {
    final db = await instance.database;

    // 1. Insert the allocation
    await db.insert('locked_allocations', {
      'goal_id': goalId,
      'account_id': accountId,
      'amount': amount,
    });

    // 2. Update the goal's total saved amount
    List<Map> goalResult = await db.query(
      'goals',
      where: 'id = ?',
      whereArgs: [goalId],
    );
    double currentSaved = goalResult.first['current_saved'];

    await db.update(
      'goals',
      {'current_saved': currentSaved + amount},
      where: 'id = ?',
      whereArgs: [goalId],
    );
    notifyDataChanged();
  }

  // Get total locked amount across all accounts (for Dashboard usable balance)
  Future<double> getTotalLockedAmount() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM locked_allocations',
    );
    return (result.first['total'] as num? ?? 0).toDouble();
  }

  /// Gets total locked amount specifically for goals (excluding credit card locks).
  Future<double> getTotalGoalLockedAmount() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM locked_allocations WHERE goal_id IS NOT NULL',
    );
    return (result.first['total'] as num? ?? 0).toDouble();
  }

  /// Gets total locked amount specifically for credit card reserves.
  Future<double> getTotalCreditCardLockedAmount() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM locked_allocations WHERE credit_card_id IS NOT NULL',
    );
    return (result.first['total'] as num? ?? 0).toDouble();
  }

  /// Gets the free unreserved funds available to lock in a physical account.
  Future<double> getAccountAvailableToLock(int accountId) async {
    final account = await readAccount(accountId);
    if (account == null || account.isCreditCard) return 0.0;
    final locks = await getLocksForAccount(accountId);
    final totalLocked = locks.fold<double>(0.0, (sum, l) => sum + l.amount);
    return (account.balance - totalLocked).clamp(0.0, double.infinity);
  }

  /// Gets the usable balance for an account (balance - total locked allocations).
  Future<double> getUsableBalanceForAccount(int accountId) async {
    return getAccountAvailableToLock(accountId);
  }

  // Get locked breakdown for a specific account (for Accounts screen)
  Future<List<LockedAllocation>> getLocksForAccount(int accountId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
      SELECT 
        la.*, 
        g.name as goal_name,
        acc.name as credit_card_name
      FROM locked_allocations la 
      LEFT JOIN goals g ON la.goal_id = g.id 
      LEFT JOIN credit_cards cc ON la.credit_card_id = cc.id
      LEFT JOIN accounts acc ON cc.account_id = acc.id
      WHERE la.account_id = ?
    ''',
      [accountId],
    );

    return result.map((json) => LockedAllocation.fromMap(json)).toList();
  }

  // --- CREDIT CARD OPERATIONS ---

  Future<int> createCreditCard(CreditCard card) async {
    final db = await instance.database;
    final id = await db.insert('credit_cards', card.toMap());
    notifyDataChanged();
    return id;
  }

  Future<CreditCard?> getCreditCardByAccountId(int accountId) async {
    final db = await instance.database;
    final result = await db.query(
      'credit_cards',
      where: 'account_id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return CreditCard.fromMap(result.first);
  }

  Future<List<CreditCard>> readAllCreditCards() async {
    final db = await instance.database;
    final result = await db.query('credit_cards');
    return result.map((m) => CreditCard.fromMap(m)).toList();
  }

  Future<int> updateCreditCard(CreditCard card) async {
    if (card.id == null) throw ArgumentError('Credit card ID cannot be null');
    final db = await instance.database;
    final res = await db.update(
      'credit_cards',
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
    notifyDataChanged();
    return res;
  }

  Future<int> deleteCreditCard(int id) async {
    final db = await instance.database;
    final res = await db.delete(
      'credit_cards',
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyDataChanged();
    return res;
  }

  /// Returns total locked funds reserved for a specific credit card.
  Future<double> getLockedAmountForCreditCard(int creditCardId) async {
    final db = await instance.database;
    final res = await db.rawQuery(
      'SELECT SUM(amount) as total FROM locked_allocations WHERE credit_card_id = ?',
      [creditCardId],
    );
    return (res.first['total'] as num? ?? 0.0).toDouble();
  }

  /// Records a credit card expense and optionally locks funds in a bank account.
  Future<int> createCreditCardExpenseTransaction({
    required int ccAccountId,
    required int? categoryId,
    required double amount,
    required String date,
    required String note,
    int? lockBankAccountId,
  }) async {
    _validateAmount(amount);
    final db = await instance.database;

    final txId = await db.transaction((txn) async {
      await _requireAccount(txn, ccAccountId);
      if (categoryId != null) {
        await _requireCategory(txn, categoryId);
      }

      // 1. Adjust CC balance (increases liability)
      await _adjustAccountBalance(txn, ccAccountId, -amount);

      // 2. Insert expense transaction
      final id = await txn.insert('transactions', {
        'account_id': ccAccountId,
        'destination_account_id': null,
        'category_id': categoryId,
        'goal_id': null,
        'amount': amount,
        'date': date,
        'note': note,
        'type': 'expense',
      });

      // 3. Lock funds in bank account if specified
      if (lockBankAccountId != null) {
        final ccRows = await txn.query(
          'credit_cards',
          where: 'account_id = ?',
          whereArgs: [ccAccountId],
        );
        if (ccRows.isNotEmpty) {
          final ccId = ccRows.first['id'] as int;
          await txn.insert('locked_allocations', {
            'goal_id': null,
            'credit_card_id': ccId,
            'account_id': lockBankAccountId,
            'amount': amount,
          });
        }
      }

      return id;
    });

    notifyDataChanged();
    return txId;
  }

  /// Pays a credit card bill from a bank account, releasing matching locked funds.
  Future<int> payCreditCardBill({
    required int ccAccountId,
    required int bankAccountId,
    required double amount,
    String? date,
    String? note,
  }) async {
    _validateAmount(amount);
    final db = await instance.database;

    final txId = await db.transaction((txn) async {
      await _requireAccount(txn, ccAccountId);
      await _requireAccount(txn, bankAccountId);

      // 1. Deduct money from bank account
      await _adjustAccountBalance(txn, bankAccountId, -amount);

      // 2. Reduce credit card outstanding liability
      await _adjustAccountBalance(txn, ccAccountId, amount);

      // 3. Release locked funds for this credit card
      final ccRows = await txn.query(
        'credit_cards',
        where: 'account_id = ?',
        whereArgs: [ccAccountId],
      );
      if (ccRows.isNotEmpty) {
        final ccId = ccRows.first['id'] as int;
        await _reduceLockedAllocationByCreditCard(txn, ccId, amount);
      }

      // 4. Record cc_payment transaction
      return await txn.insert('transactions', {
        'account_id': bankAccountId,
        'destination_account_id': ccAccountId,
        'category_id': null,
        'goal_id': null,
        'amount': amount,
        'date': date ?? DateTime.now().toIso8601String(),
        'note': note != null && note.isNotEmpty ? note : 'Credit Card Bill Payment',
        'type': 'cc_payment',
      });
    });

    notifyDataChanged();
    return txId;
  }

  Future<List<Map<String, dynamic>>> getGoalContributions(int goalId) async {
    final db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT la.amount, a.name as account_name, la.id as lock_id, la.account_id
      FROM locked_allocations la
      JOIN accounts a ON la.account_id = a.id
      WHERE la.goal_id = ?
      ''',
      [goalId],
    );
  }

  /// Processes a payment for a goal.
  /// Moves money from "Locked" to "Spent" atomically and logs a typed goal_payment transaction.
  Future<int> payBill(
    int goalId,
    int accountId,
    double amount, {
    int? categoryId,
    String? date,
    String note = '',
  }) async {
    return createGoalPaymentTransaction(
      goalId: goalId,
      accountId: accountId,
      amount: amount,
      date: date ?? DateTime.now().toIso8601String(),
      categoryId: categoryId,
      note: note.isNotEmpty ? note : 'Payment for goal',
    );
  }

  // --- CORE CALCULATION LOGIC ---

  /// Calculates usable cash after excluding funds locked for goals.
  /// Calculates usable cash after excluding funds locked for goals and CC bills.
  /// Credit card balances represent liabilities and are excluded from physical cash.
  Future<double> calculateUsableBalance() async {
    final db = await instance.database;

    // 1. Sum of all physical cash / bank account balances
    final accountResult = await db.rawQuery(
      "SELECT SUM(balance) as total FROM accounts WHERE type != 'Credit Card'",
    );
    double totalPhysical = (accountResult.first['total'] as num? ?? 0)
        .toDouble();

    // 2. Total locked for goals and CC bills
    final lockedResult = await db.rawQuery(
      'SELECT SUM(amount) as total FROM locked_allocations',
    );
    double totalLocked = (lockedResult.first['total'] as num? ?? 0).toDouble();

    return (totalPhysical - totalLocked).clamp(0.0, double.infinity);
  }

  /// Calculates total physical cash (excluding credit card liabilities).
  Future<double> calculatePhysicalBalance() async {
    final db = await instance.database;
    final res = await db.rawQuery(
      "SELECT SUM(balance) as total FROM accounts WHERE type != 'Credit Card'",
    );
    return (res.first['total'] as num? ?? 0.0).toDouble();
  }

  /// Calculates total outstanding credit card liabilities.
  Future<double> getTotalCreditCardOutstanding() async {
    final db = await instance.database;
    final res = await db.rawQuery(
      "SELECT SUM(balance) as total FROM accounts WHERE type = 'Credit Card'",
    );
    return (res.first['total'] as num? ?? 0.0).toDouble();
  }

  /// Gets the total spent in a specific category for the specified calendar month and year,
  /// or for a given [SalaryCycle].
  /// Only includes transactions with type 'expense'.
  /// Defaults to the current month and year if both [cycle] and [month] are omitted.
  Future<double> getCategorySpendingForMonth(
    int categoryId, {
    int? month,
    int? year,
    SalaryCycle? cycle,
  }) async {
    final db = await instance.database;
    String whereClause;
    List<dynamic> whereArgs;

    if (cycle != null) {
      whereClause =
          "WHERE category_id = ? AND type = 'expense' AND SUBSTR(date, 1, 10) >= ? AND SUBSTR(date, 1, 10) <= ?";
      whereArgs = [categoryId, cycle.startDateString, cycle.endDateString];
    } else {
      final now = DateTime.now();
      final targetYear = year ?? now.year;
      final targetMonth = month ?? now.month;
      final monthStr = '$targetYear-${targetMonth.toString().padLeft(2, '0')}';
      whereClause =
          "WHERE category_id = ? AND type = 'expense' AND SUBSTR(date, 1, 7) = ?";
      whereArgs = [categoryId, monthStr];
    }

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions $whereClause',
      whereArgs,
    );

    return (result.first['total'] as num? ?? 0).toDouble();
  }

  /// Gets the total spent in a specific category for the current month or active salary cycle.
  /// Used to calculate budget progress.
  Future<double> getCategorySpendingForCurrentMonth(
    int categoryId, {
    SalaryCycle? cycle,
  }) async {
    return getCategorySpendingForMonth(categoryId, cycle: cycle);
  }

  /// Gets monthly expense spending for all categories for a given calendar month and year,
  /// or for a given [SalaryCycle].
  /// Returns a `Map<categoryId, totalExpense>`.
  /// Only includes transactions with type 'expense'.
  Future<Map<int, double>> getMonthlySpendingByCategoryId({
    int? month,
    int? year,
    SalaryCycle? cycle,
  }) async {
    final db = await instance.database;
    String whereClause;
    List<dynamic> whereArgs;

    if (cycle != null) {
      whereClause =
          "WHERE category_id IS NOT NULL AND type = 'expense' AND SUBSTR(date, 1, 10) >= ? AND SUBSTR(date, 1, 10) <= ?";
      whereArgs = [cycle.startDateString, cycle.endDateString];
    } else {
      final now = DateTime.now();
      final targetYear = year ?? now.year;
      final targetMonth = month ?? now.month;
      final monthStr = '$targetYear-${targetMonth.toString().padLeft(2, '0')}';
      whereClause =
          "WHERE category_id IS NOT NULL AND type = 'expense' AND SUBSTR(date, 1, 7) = ?";
      whereArgs = [monthStr];
    }

    final result = await db.rawQuery(
      'SELECT category_id, SUM(amount) as total FROM transactions '
      '$whereClause '
      'GROUP BY category_id',
      whereArgs,
    );

    final map = <int, double>{};
    for (final row in result) {
      final catId = row['category_id'] as int?;
      if (catId != null) {
        map[catId] = (row['total'] as num? ?? 0).toDouble();
      }
    }
    return map;
  }

  /// Gets income totals grouped by category_id for a given cycle or month.
  Future<Map<int, double>> getMonthlyIncomeByCategoryId({
    int? month,
    int? year,
    SalaryCycle? cycle,
  }) async {
    final db = await instance.database;
    String whereClause;
    List<dynamic> whereArgs;

    if (cycle != null) {
      whereClause =
          "WHERE category_id IS NOT NULL AND type = 'income' AND SUBSTR(date, 1, 10) >= ? AND SUBSTR(date, 1, 10) <= ?";
      whereArgs = [cycle.startDateString, cycle.endDateString];
    } else {
      final now = DateTime.now();
      final targetYear = year ?? now.year;
      final targetMonth = month ?? now.month;
      final monthStr = '$targetYear-${targetMonth.toString().padLeft(2, '0')}';
      whereClause =
          "WHERE category_id IS NOT NULL AND type = 'income' AND SUBSTR(date, 1, 7) = ?";
      whereArgs = [monthStr];
    }

    final result = await db.rawQuery(
      'SELECT category_id, SUM(amount) as total FROM transactions '
      '$whereClause '
      'GROUP BY category_id',
      whereArgs,
    );

    final map = <int, double>{};
    for (final row in result) {
      final catId = row['category_id'] as int?;
      if (catId != null) {
        map[catId] = (row['total'] as num? ?? 0).toDouble();
      }
    }
    return map;
  }

  /// Gets total expense spending across all categories for a given salary cycle.
  Future<double> getTotalSpendingForSalaryCycle(SalaryCycle cycle) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions "
      "WHERE type = 'expense' AND SUBSTR(date, 1, 10) >= ? AND SUBSTR(date, 1, 10) <= ?",
      [cycle.startDateString, cycle.endDateString],
    );
    return (result.first['total'] as num? ?? 0.0).toDouble();
  }

  // --- JSON EXPORT/IMPORT ---
  /// Exports all database tables to a JSON file.
  Future<String?> exportDatabaseAsJSON({
    String? destinationDirectory,
    String? fileName,
  }) async {
    try {
      final db = await instance.database;

      final accounts = await db.query('accounts');
      final categories = await db.query('categories');
      final transactions = await db.query('transactions');
      final goals = await db.query('goals');
      final lockedAllocations = await db.query('locked_allocations');
      final creditCards = await db.query('credit_cards');

      final jsonString = BackupCodec.encode(
        accounts: accounts.map(Map<String, dynamic>.from).toList(),
        categories: categories.map(Map<String, dynamic>.from).toList(),
        transactions: transactions.map(Map<String, dynamic>.from).toList(),
        goals: goals.map(Map<String, dynamic>.from).toList(),
        lockedAllocations: lockedAllocations
            .map(Map<String, dynamic>.from)
            .toList(),
        creditCards: creditCards
            .map(Map<String, dynamic>.from)
            .toList(),
      );

      final targetDir = destinationDirectory ?? await getEffectiveBackupDirectory();
      final name = fileName ?? 'cashflow_backup.json';

      final path = await saveBackupBytes(
        name,
        utf8.encode(jsonString),
        destinationDirectory: targetDir,
      );
      if (path != null) {
        await setLastBackupTimestamp(DateTime.now());
      }
      return path;
    } catch (e, stackTrace) {
      developer.log(
        'JSON export error',
        name: 'DatabaseHelper',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Imports database from a JSON file.
  Future<bool> importDatabaseFromJSON() async {
    try {
      final bytes = await pickBackupBytes();
      if (bytes == null) return false;

      final jsonString = utf8.decode(bytes);
      final data = BackupCodec.decode(jsonString);
      final db = await instance.database;

      await db.transaction((txn) async {
        await txn.delete('locked_allocations');
        await txn.delete('transactions');
        await txn.delete('goals');
        await txn.delete('credit_cards');
        await txn.delete('categories');
        await txn.delete('accounts');

        for (final account in data['accounts'] as List<Map<String, dynamic>>) {
          await txn.insert('accounts', account);
        }
        if (data['credit_cards'] != null) {
          for (final cc in data['credit_cards'] as List<Map<String, dynamic>>) {
            await txn.insert('credit_cards', cc);
          }
        }
        for (final category
            in data['categories'] as List<Map<String, dynamic>>) {
          final catMap = Map<String, dynamic>.from(category);
          catMap['type'] ??= 'expense';
          await txn.insert('categories', catMap);
        }

        final incomeCats = await txn.rawQuery(
          "SELECT id FROM categories WHERE type = 'income'",
        );
        if (incomeCats.isEmpty) {
          const defaultIncome = [
            'Salary',
            'Freelance',
            'Investments',
            'Rental',
            'Gifts',
            'Other Income',
          ];
          for (final name in defaultIncome) {
            await txn.insert('categories', {
              'name': name,
              'monthly_budget': null,
              'type': 'income',
            });
          }
        }
        for (final goal in data['goals'] as List<Map<String, dynamic>>) {
          await txn.insert('goals', goal);
        }
        for (final transaction
            in data['transactions'] as List<Map<String, dynamic>>) {
          await txn.insert('transactions', transaction);
        }
        for (final lock
            in data['locked_allocations'] as List<Map<String, dynamic>>) {
          await txn.insert('locked_allocations', lock);
        }
      });

      notifyDataChanged();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'JSON import error',
        name: 'DatabaseHelper',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // --- CSV EXPORT ---
  /// Exports transactions to a CSV file.
  Future<String?> exportTransactionsAsCSV({
    String? destinationDirectory,
    String? fileName,
  }) async {
    try {
      final transactions = await getTransactionHistory();

      final csv = BackupCodec.transactionsCsv(transactions);
      final targetDir = destinationDirectory ?? await getEffectiveBackupDirectory();
      final name = fileName ?? 'cashflow_transactions.csv';

      return await saveBackupBytes(
        name,
        utf8.encode(csv),
        destinationDirectory: targetDir,
      );
    } catch (e, stackTrace) {
      developer.log(
        'CSV export error',
        name: 'DatabaseHelper',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // --- ANALYTICS QUERIES ---
  /// Gets spending by category for current month or all-time.
  /// Returns a `Map<categoryName, totalAmount>`
  Future<Map<String, double>> getSpendingByCategory({
    bool currentMonthOnly = true,
  }) async {
    final db = await instance.database;

    String whereClause = "WHERE t.type = 'expense'";
    List<dynamic> whereArgs = [];
    if (currentMonthOnly) {
      final now = DateTime.now();
      final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      whereClause = "WHERE t.type = 'expense' AND SUBSTR(t.date, 1, 7) = ?";
      whereArgs = [monthStr];
    }

    final result = await db.rawQuery('''
      SELECT c.name, SUM(t.amount) as total
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      $whereClause
      GROUP BY t.category_id
      ORDER BY total DESC
    ''', whereArgs.isNotEmpty ? whereArgs : null);

    final map = <String, double>{};
    for (var row in result) {
      map[row['name'] as String] = (row['total'] as num? ?? 0).toDouble();
    }
    return map;
  }

  /// Gets monthly spending totals for the last N months.
  /// Returns a Map<"YYYY-MM", totalAmount>
  Future<Map<String, double>> getMonthlySpendings({int months = 12}) async {
    final db = await instance.database;

    final result = await db.rawQuery('''
      SELECT 
        SUBSTR(date, 1, 7) as month,
        SUM(amount) as total
      FROM transactions
      WHERE type = 'expense' AND date >= datetime('now', '-$months months')
      GROUP BY month
      ORDER BY month ASC
    ''');

    final map = <String, double>{};
    for (var row in result) {
      map[row['month'] as String] = (row['total'] as num? ?? 0).toDouble();
    }
    return map;
  }

  /// Gets spending by category for a specific month.
  /// Month format: "YYYY-MM"
  Future<Map<String, double>> getSpendingByCategoryForMonth(
    String month,
  ) async {
    final db = await instance.database;

    final result = await db.rawQuery(
      '''
      SELECT c.name, SUM(t.amount) as total
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      WHERE SUBSTR(t.date, 1, 7) = ? AND t.type = 'expense'
      GROUP BY t.category_id
      ORDER BY total DESC
    ''',
      [month],
    );

    final map = <String, double>{};
    for (var row in result) {
      map[row['name'] as String] = (row['total'] as num? ?? 0).toDouble();
    }
    return map;
  }

  Future<Map<String, double>> getSpendingByCategoryForDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
      SELECT c.name, SUM(t.amount) as total
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'expense' AND t.date >= ? AND t.date < ?
      GROUP BY t.category_id
      ORDER BY total DESC
    ''',
      [
        startDate.toIso8601String(),
        endDate.add(const Duration(days: 1)).toIso8601String(),
      ],
    );

    return {
      for (final row in result)
        row['name'] as String: (row['total'] as num? ?? 0).toDouble(),
    };
  }

  /// Gets total spending for a specific month.
  Future<double> getTotalSpendingForMonth(String month) async {
    final db = await instance.database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) as total
      FROM transactions
      WHERE SUBSTR(date, 1, 7) = ? AND type = 'expense'
    ''',
      [month],
    );

    return (result.first['total'] as num? ?? 0).toDouble();
  }

  // --- YEAR-TO-DATE (YTD) ANALYTICS ---

  /// Computes cumulative expense spending from Jan 1 of [year] through current date.
  Future<double> getYtdSpending({int? year}) async {
    final db = await instance.database;
    final targetYear = year ?? DateTime.now().year;
    final yearPrefix = '$targetYear-';

    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions "
      "WHERE type = 'expense' AND SUBSTR(date, 1, 5) = ?",
      [yearPrefix],
    );
    return (result.first['total'] as num? ?? 0.0).toDouble();
  }

  /// Returns cumulative spending by category for the full year to date.
  Future<Map<String, double>> getYtdSpendingByCategory({int? year}) async {
    final db = await instance.database;
    final targetYear = year ?? DateTime.now().year;
    final yearPrefix = '$targetYear-';

    final result = await db.rawQuery(
      '''
      SELECT c.name, SUM(t.amount) as total
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'expense' AND SUBSTR(t.date, 1, 5) = ?
      GROUP BY t.category_id
      ORDER BY total DESC
    ''',
      [yearPrefix],
    );

    return {
      for (final row in result)
        row['name'] as String: (row['total'] as num? ?? 0.0).toDouble(),
    };
  }

  /// Gets month-by-month spending for the given year (Jan through Dec).
  Future<Map<String, double>> getYtdMonthlySpendings({int? year}) async {
    final db = await instance.database;
    final targetYear = year ?? DateTime.now().year;
    final yearPrefix = '$targetYear-';

    final result = await db.rawQuery(
      '''
      SELECT 
        SUBSTR(date, 1, 7) as month,
        SUM(amount) as total
      FROM transactions
      WHERE type = 'expense' AND SUBSTR(date, 1, 5) = ?
      GROUP BY month
      ORDER BY month ASC
    ''',
      [yearPrefix],
    );

    final map = <String, double>{};
    for (var row in result) {
      map[row['month'] as String] = (row['total'] as num? ?? 0.0).toDouble();
    }
    return map;
  }

  /// Computes cumulative Inflow (income), Outflow (expenses), Net Savings, and Savings Rate for the year to date.
  Future<Map<String, double>> getYtdCashflowSummary({int? year}) async {
    final db = await instance.database;
    final targetYear = year ?? DateTime.now().year;
    final yearPrefix = '$targetYear-';

    final incomeResult = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type = 'income' AND SUBSTR(date, 1, 5) = ?",
      [yearPrefix],
    );
    final expenseResult = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type = 'expense' AND SUBSTR(date, 1, 5) = ?",
      [yearPrefix],
    );

    final totalIncome = (incomeResult.first['total'] as num? ?? 0.0).toDouble();
    final totalExpense = (expenseResult.first['total'] as num? ?? 0.0).toDouble();
    final netSavings = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? (netSavings / totalIncome) * 100.0 : 0.0;

    return {
      'inflow': totalIncome,
      'outflow': totalExpense,
      'netSavings': netSavings,
      'income': totalIncome,
      'expense': totalExpense,
      'net': netSavings,
      'savingsRate': savingsRate,
    };
  }

  // --- APP SETTINGS OPERATIONS ---

  /// Retrieves a persisted string setting by key.
  Future<String?> getSetting(String key, {String? defaultValue}) async {
    final db = await instance.database;
    final result = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return defaultValue;
  }

  /// Persists a string setting by key using upsert semantics.
  Future<void> setSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves dashboard privacy mode (defaults to false).
  Future<bool> getPrivacyMode() async {
    final val = await getSetting('dashboard_privacy_mode', defaultValue: 'false');
    return val == 'true';
  }

  /// Persists dashboard privacy mode.
  Future<void> setPrivacyMode(bool isPrivate) async {
    await setSetting('dashboard_privacy_mode', isPrivate ? 'true' : 'false');
  }

  /// Retrieves configured startup privacy mode preference (defaults to false).
  Future<bool> getStartInPrivacyMode() async {
    final val = await getSetting('start_in_privacy_mode', defaultValue: 'false');
    return val == 'true';
  }

  /// Persists configured startup privacy mode preference.
  Future<void> setStartInPrivacyMode(bool enabled) async {
    await setSetting('start_in_privacy_mode', enabled ? 'true' : 'false');
    notifyDataChanged();
  }

  /// Synchronizes runtime dashboard privacy mode on application startup
  /// according to the startup privacy mode preference.
  Future<void> initStartupPrivacyMode() async {
    final startInPrivacy = await getStartInPrivacyMode();
    await setPrivacyMode(startInPrivacy);
  }

  /// Retrieves configured salary / income payday of the month (1-31, defaults to 1).
  Future<int> getSalaryDay() async {
    final val = await getSetting('salary_day', defaultValue: '1');
    final parsed = int.tryParse(val ?? '1') ?? 1;
    return parsed.clamp(1, 31);
  }

  /// Persists configured salary / income payday of the month.
  Future<void> setSalaryDay(int day) async {
    final clamped = day.clamp(1, 31);
    await setSetting('salary_day', clamped.toString());
    notifyDataChanged();
  }

  /// Retrieves timestamp string (ISO-8601) of last successful backup export.
  Future<String?> getLastBackupTimestamp() async {
    return getSetting('last_backup_timestamp');
  }

  /// Persists timestamp of last successful backup export.
  Future<void> setLastBackupTimestamp(DateTime timestamp) async {
    await setSetting('last_backup_timestamp', timestamp.toIso8601String());
    notifyDataChanged();
  }

  /// Retrieves configured custom backup directory, or null if using system default.
  Future<String?> getCustomBackupPath() async {
    return getSetting('custom_backup_path');
  }

  /// Persists or clears configured custom backup directory.
  Future<void> setCustomBackupPath(String? path) async {
    if (path == null || path.trim().isEmpty) {
      final db = await instance.database;
      await db.delete(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['custom_backup_path'],
      );
    } else {
      await setSetting('custom_backup_path', path.trim());
    }
    notifyDataChanged();
  }

  /// Retrieves the default backup directory for this platform.
  Future<String> getDefaultBackupDirectory() async {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        return await getDatabasesPath();
      } catch (_) {
        return Directory.systemTemp.path;
      }
    }
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      return documentsDir.path;
    } catch (_) {
      try {
        return await getDatabasesPath();
      } catch (_) {
        return Directory.systemTemp.path;
      }
    }
  }

  /// Retrieves effective backup directory (custom if set, otherwise default).
  Future<String> getEffectiveBackupDirectory() async {
    final custom = await getCustomBackupPath();
    if (custom != null && custom.trim().isNotEmpty) {
      return custom.trim();
    }
    return getDefaultBackupDirectory();
  }
}
