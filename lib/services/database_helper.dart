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
import 'package:cashflow/models/locked_allocation_model.dart';

class DatabaseHelper {
  // Singleton pattern: ensures only one database connection exists
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  /// Global notifier that broadcasts whenever any financial data or database state changes
  static final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);

  static void notifyDataChanged() {
    dataRevision.value++;
  }

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('money_tracker.db');
    return _database!;
  }

  Future<void> resetDatabase() async {
    if (kIsWeb) {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('locked_allocations');
        await txn.delete('goals');
        await txn.delete('transactions');
        await txn.delete('categories');
        await txn.delete('accounts');
      });
      notifyDataChanged();
      return;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'money_tracker.db');
    await deleteDatabase(path);
    _database = null; // Reset the singleton instance
    notifyDataChanged();
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateV1toV2(db);
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
        monthly_budget REAL DEFAULT NULL
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
          CHECK (type IN ('expense', 'income', 'transfer', 'goal_lock', 'goal_unlock', 'goal_payment')),
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

    // 5. Locked Allocations Table (The Bridge)
    await db.execute('''
      CREATE TABLE locked_allocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        account_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY (goal_id) REFERENCES goals (id),
        FOREIGN KEY (account_id) REFERENCES accounts (id)
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
    if (_database == null) return;
    final db = _database!;
    await db.close();
    _database = null;
  }

  // --- DATABASE MANAGEMENT ---

  /// Exports the database file to a user-selected location.
  Future<String?> exportDatabase() async {
    if (kIsWeb) return null;

    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'money_tracker.db');
      final file = File(path);

      if (!await file.exists()) {
        throw Exception('Database file not found');
      }

      // Use the Documents directory as a default export location
      final documentsDir = await getApplicationDocumentsDirectory();
      final backupPath = join(documentsDir.path, 'cashflow_backup.db');
      final backupFile = await file.copy(backupPath);

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

  Future<List<Category>> readAllCategories() async {
    final db = await instance.database;
    final result = await db.query('categories');
    return result.map((json) => Category.fromMap(json)).toList();
  }

  // --- TRANSACTION OPERATIONS ---
  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    final id = await db.insert('transactions', transaction.toMap());
    notifyDataChanged();
    return id;
  }

  /// Fetches all transactions with their associated account and category names.
  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        t.id, 
        t.amount, 
        t.date, 
        t.note, 
        a.name as account_name, 
        c.name as category_name 
        FROM transactions t
      JOIN accounts a ON t.account_id = a.id
      JOIN categories c ON t.category_id = c.id
      ORDER BY t.date DESC
    ''');
  }

  // Helper method to subtract money from an account
  Future<void> subtractFromAccount(int accountId, double amount) async {
    final db = await instance.database;

    // 1. Get current balance
    List<Map> result = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [accountId],
    );
    double currentBalance = result.first['balance'];

    // 2. Update with new balance
    await db.update(
      'accounts',
      {'balance': currentBalance - amount},
      where: 'id = ?',
      whereArgs: [accountId],
    );
    notifyDataChanged();
  }

  /// Deletes a transaction and refunds the amount to the associated account balance.
  Future<void> deleteTransaction(int transactionId) async {
    final db = await instance.database;

    // 1. Get transaction details to know which account to refund
    final result = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
    );

    if (result.isEmpty) return;

    final transaction = result.first;
    final int accountId = transaction['account_id'] as int;
    final double amount = (transaction['amount'] as num).toDouble();

    // Use a transaction to ensure both operations succeed or fail together
    await db.transaction((txn) async {
      // 2. Refund the amount to the account
      List<Map> accountResult = await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [accountId],
      );

      if (accountResult.isNotEmpty) {
        double currentBalance = accountResult.first['balance'];
        await txn.update(
          'accounts',
          {'balance': currentBalance + amount},
          where: 'id = ?',
          whereArgs: [accountId],
        );
      }

      // 3. Delete the transaction record
      await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });
    notifyDataChanged();
  }

  // SEED DATA: Call this once to add default categories
  Future<void> seedDatabase() async {
    final categories = [
      Category(name: 'Groceries', monthlyBudget: 15000),
      Category(name: 'Dining Out', monthlyBudget: 8000),
      Category(name: 'Transport', monthlyBudget: 5000),
      Category(name: 'Entertainment', monthlyBudget: 4000),
      Category(name: 'Utilities & Bills', monthlyBudget: 10000),
      Category(name: 'Shopping', monthlyBudget: 6000),
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
      Account(name: 'Salary Account (HDFC)', balance: 85000.0, type: 'Bank'),
    );
    final savingsAccId = await createAccount(
      Account(
        name: 'Emergency Savings (SBI)',
        balance: 120000.0,
        type: 'Savings',
      ),
    );
    final walletAccId = await createAccount(
      Account(name: 'Cash Wallet', balance: 5400.0, type: 'Cash'),
    );

    // 2. Categories
    final catGroceries = await createCategory(
      Category(name: 'Groceries', monthlyBudget: 15000),
    );
    final catDining = await createCategory(
      Category(name: 'Dining Out', monthlyBudget: 8000),
    );
    final catTransport = await createCategory(
      Category(name: 'Transport & Fuel', monthlyBudget: 5000),
    );
    final catUtilities = await createCategory(
      Category(name: 'Utilities & Bills', monthlyBudget: 10000),
    );
    final catShopping = await createCategory(
      Category(name: 'Shopping', monthlyBudget: 7000),
    );
    final catHealth = await createCategory(
      Category(name: 'Health & Medical', monthlyBudget: 4000),
    );

    // 3. Sinking Funds / Goals
    final goalInsurance = await createGoal(
      Goal(
        name: 'Annual Car Insurance',
        totalTarget: 25000.0,
        targetDate: '2026-11-30',
        currentSaved: 0.0,
      ),
    );
    final goalVacation = await createGoal(
      Goal(
        name: 'Goa Vacation Fund',
        totalTarget: 40000.0,
        targetDate: '2026-12-25',
        currentSaved: 0.0,
      ),
    );
    final goalGadget = await createGoal(
      Goal(
        name: 'New Laptop',
        totalTarget: 80000.0,
        targetDate: '2027-03-31',
        currentSaved: 0.0,
      ),
    );

    // Lock funds to goals
    await lockFunds(goalInsurance, savingsAccId, 15000.0);
    await lockFunds(goalVacation, salaryAccId, 20000.0);
    await lockFunds(goalGadget, savingsAccId, 25000.0);

    // 4. Sample Transactions
    final now = DateTime.now();
    final sampleTxs = [
      TransactionModel(
        accountId: salaryAccId,
        categoryId: catGroceries,
        amount: 3250.0,
        date: now.subtract(const Duration(days: 1)).toIso8601String(),
        note: 'Supermarket weekly stock',
      ),
      TransactionModel(
        accountId: walletAccId,
        categoryId: catDining,
        amount: 850.0,
        date: now.subtract(const Duration(days: 2)).toIso8601String(),
        note: 'Lunch with team',
      ),
      TransactionModel(
        accountId: salaryAccId,
        categoryId: catTransport,
        amount: 2200.0,
        date: now.subtract(const Duration(days: 3)).toIso8601String(),
        note: 'Petrol fill up',
      ),
      TransactionModel(
        accountId: salaryAccId,
        categoryId: catUtilities,
        amount: 4800.0,
        date: now.subtract(const Duration(days: 5)).toIso8601String(),
        note: 'Electricity & Wifi bill',
      ),
      TransactionModel(
        accountId: salaryAccId,
        categoryId: catShopping,
        amount: 3100.0,
        date: now.subtract(const Duration(days: 8)).toIso8601String(),
        note: 'Weekend clothing',
      ),
      TransactionModel(
        accountId: walletAccId,
        categoryId: catHealth,
        amount: 650.0,
        date: now.subtract(const Duration(days: 10)).toIso8601String(),
        note: 'Pharmacy medicines',
      ),
    ];

    for (var tx in sampleTxs) {
      await insertTransaction(tx);
      await subtractFromAccount(tx.accountId, tx.amount);
    }
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

  // Get total locked amount across all accounts (for Dashboard)
  Future<double> getTotalLockedAmount() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM locked_allocations',
    );
    return (result.first['total'] as num? ?? 0).toDouble();
  }

  // Get locked breakdown for a specific account (for Accounts screen)
  Future<List<LockedAllocation>> getLocksForAccount(int accountId) async {
    final db = await instance.database;
    // JOIN query to get the goal name along with the amount
    final result = await db.rawQuery(
      '''
      SELECT la.*, g.name as goal_name 
      FROM locked_allocations la 
      JOIN goals g ON la.goal_id = g.id 
      WHERE la.account_id = ?
    ''',
      [accountId],
    );

    return result.map((json) => LockedAllocation.fromMap(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getGoalContributions(int goalId) async {
    final db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT la.amount, a.name as account_name, la.id as lock_id
      FROM locked_allocations la
      JOIN accounts a ON la.account_id = a.id
      WHERE la.goal_id = ?
      ''',
      [goalId],
    );
  }

  /// Processes a payment for a goal.
  /// This moves money from "Locked" to "Spent".
  Future<void> payBill(int goalId, int accountId, double amount) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      // 1. Subtract from physical account balance
      List<Map> accRes = await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [accountId],
      );
      if (accRes.isEmpty) throw Exception('Account not found');
      double currentBalance = accRes.first['balance'];
      await txn.update(
        'accounts',
        {'balance': currentBalance - amount},
        where: 'id = ?',
        whereArgs: [accountId],
      );

      // 2. Subtract from locked_allocations
      // We find the allocation for this goal and account and reduce it.
      List<Map> lockRes = await txn.query(
        'locked_allocations',
        where: 'goal_id = ? AND account_id = ?',
        whereArgs: [goalId, accountId],
      );
      if (lockRes.isEmpty) {
        throw Exception('No locked funds found for this goal in this account');
      }

      double currentLock = lockRes.first['amount'];
      if (currentLock < amount) {
        throw Exception('Insufficient locked funds in this account');
      }

      if (currentLock == amount) {
        await txn.delete(
          'locked_allocations',
          where: 'id = ?',
          whereArgs: [lockRes.first['id']],
        );
      } else {
        await txn.update(
          'locked_allocations',
          {'amount': currentLock - amount},
          where: 'id = ?',
          whereArgs: [lockRes.first['id']],
        );
      }

      // 3. Update goals total saved
      List<Map> goalRes = await txn.query(
        'goals',
        where: 'id = ?',
        whereArgs: [goalId],
      );
      if (goalRes.isEmpty) throw Exception('Goal not found');
      double currentSaved = goalRes.first['current_saved'];
      double newSaved = currentSaved - amount;

      if (newSaved <= 0) {
        // Goal is fully paid/consumed, delete it
        await txn.delete(
          'goals',
          where: 'id = ?',
          whereArgs: [goalId],
        );
      } else {
        await txn.update(
          'goals',
          {'current_saved': newSaved},
          where: 'id = ?',
          whereArgs: [goalId],
        );
      }

      // 4. Create a transaction record
      await txn.insert('transactions', {
        'account_id': accountId,
        'category_id': 1, // Using a default 'General' or similar category, or passed as param
        'amount': amount,
        'date': DateTime.now().toIso8601String(),
        'note': 'Payment for goal id $goalId',
      });
    });
    notifyDataChanged();
  }

  // --- CORE CALCULATION LOGIC ---

  /// Calculates the "Usable Balance" based on the formula:
  /// Usable Balance = (Sum of all Accounts) - (Total Locked for Goals) - (Total Reserved for Monthly Budgets)
  Future<double> calculateUsableBalance() async {
    final db = await instance.database;

    // 1. Sum of all account balances
    final accountResult = await db.rawQuery(
      'SELECT SUM(balance) as total FROM accounts',
    );
    double totalPhysical = (accountResult.first['total'] as num? ?? 0)
        .toDouble();

    // 2. Total locked for goals
    final lockedResult = await db.rawQuery(
      'SELECT SUM(amount) as total FROM locked_allocations',
    );
    double totalLocked = (lockedResult.first['total'] as num? ?? 0).toDouble();

    // 3. Total reserved for monthly budgets (Sum of monthly_budget for all categories)
    final budgetResult = await db.rawQuery(
      'SELECT SUM(monthly_budget) as total FROM categories',
    );
    double totalReserved = (budgetResult.first['total'] as num? ?? 0)
        .toDouble();

    return totalPhysical - totalLocked - totalReserved;
  }

  /// Gets the total spent in a specific category for the current month.
  /// Used to calculate budget progress.
  Future<double> getCategorySpendingForCurrentMonth(int categoryId) async {
    final db = await instance.database;

    // Get current month and year in YYYY-MM format
    final now = DateTime.now();
    final monthStart = DateTime(
      now.year,
      now.month,
      1,
    ).toIso8601String().substring(0, 7);
    final monthEnd = DateTime(now.year, now.month + 1, 0).toIso8601String();

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE category_id = ? AND date >= ? AND date <= ?',
      [categoryId, monthStart, monthEnd],
    );

    return (result.first['total'] as num? ?? 0).toDouble();
  }

  // --- JSON EXPORT/IMPORT ---
  /// Exports all database tables to a JSON file.
  Future<String?> exportDatabaseAsJSON() async {
    try {
      final db = await instance.database;

      final accounts = await db.query('accounts');
      final categories = await db.query('categories');
      final transactions = await db.query('transactions');
      final goals = await db.query('goals');
      final lockedAllocations = await db.query('locked_allocations');

      final jsonString = BackupCodec.encode(
        accounts: accounts.map(Map<String, dynamic>.from).toList(),
        categories: categories.map(Map<String, dynamic>.from).toList(),
        transactions: transactions.map(Map<String, dynamic>.from).toList(),
        goals: goals.map(Map<String, dynamic>.from).toList(),
        lockedAllocations: lockedAllocations
            .map(Map<String, dynamic>.from)
            .toList(),
      );

      return await saveBackupBytes(
        'cashflow_backup.json',
        utf8.encode(jsonString),
      );
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
        await txn.delete('goals');
        await txn.delete('transactions');
        await txn.delete('categories');
        await txn.delete('accounts');

        for (final account in data['accounts'] as List<Map<String, dynamic>>) {
          await txn.insert('accounts', account);
        }
        for (final category
            in data['categories'] as List<Map<String, dynamic>>) {
          await txn.insert('categories', category);
        }
        for (final transaction
            in data['transactions'] as List<Map<String, dynamic>>) {
          await txn.insert('transactions', transaction);
        }
        for (final goal
            in data['goals'] as List<Map<String, dynamic>>) {
          await txn.insert('goals', goal);
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
  Future<String?> exportTransactionsAsCSV() async {
    try {
      final transactions = await getTransactionHistory();

      final csv = BackupCodec.transactionsCsv(transactions);

      return await saveBackupBytes(
        'cashflow_transactions.csv',
        utf8.encode(csv),
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
  /// Returns a Map<categoryName, totalAmount>
  Future<Map<String, double>> getSpendingByCategory({
    bool currentMonthOnly = true,
  }) async {
    final db = await instance.database;

    String whereClause = '';
    if (currentMonthOnly) {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
      final monthEnd = DateTime(
        now.year,
        now.month + 1,
        0,
        23,
        59,
        59,
      ).toIso8601String();
      whereClause = 'WHERE t.date >= "$monthStart" AND t.date <= "$monthEnd"';
    }

    final result = await db.rawQuery('''
      SELECT c.name, SUM(t.amount) as total
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      $whereClause
      GROUP BY t.category_id
      ORDER BY total DESC
    ''');

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
      WHERE date >= datetime('now', '-$months months')
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
      WHERE SUBSTR(t.date, 1, 7) = ?
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

  /// Gets total spending for a specific month.
  Future<double> getTotalSpendingForMonth(String month) async {
    final db = await instance.database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) as total
      FROM transactions
      WHERE SUBSTR(date, 1, 7) = ?
    ''',
      [month],
    );

    return (result.first['total'] as num? ?? 0).toDouble();
  }
}
