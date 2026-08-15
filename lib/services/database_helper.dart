import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/transaction_model.dart';
import 'package:cashflow/models/plan_model.dart';
import 'package:cashflow/models/locked_allocation_model.dart';

class DatabaseHelper {
  // Singleton pattern: ensures only one database connection exists
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('money_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
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
        monthly_budget REAL NOT NULL
      )
    ''');

    // 3. Transactions Table
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

    // 4. Planned Spends Table
    await db.execute('''
      CREATE TABLE planned_spends (
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
        plan_id INTEGER NOT NULL,
        account_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY (plan_id) REFERENCES planned_spends (id),
        FOREIGN KEY (account_id) REFERENCES accounts (id)
      )
    ''');
  }

  // --- ACCOUNT OPERATIONS ---
  Future<int> createAccount(Account account) async {
    final db = await instance.database;
    return await db.insert('accounts', account.toMap());
  }

  Future<List<Account>> readAllAccounts() async {
    final db = await instance.database;
    final result = await db.query('accounts');
    return result.map((json) => Account.fromMap(json)).toList();
  }

  Future<int> updateAccountBalance(int id, double newBalance) async {
    final db = await instance.database;
    return await db.update(
      'accounts',
      {'balance': newBalance},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Close database
  Future close() async {
    final db = await instance.database;
    db.close();
  }

  // --- CATEGORY OPERATIONS ---
  Future<int> createCategory(Category category) async {
    final db = await instance.database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<Category>> readAllCategories() async {
    final db = await instance.database;
    final result = await db.query('categories');
    return result.map((json) => Category.fromMap(json)).toList();
  }

  // --- TRANSACTION OPERATIONS ---
  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    return await db.insert('transactions', transaction.toMap());
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
  }

  // SEED DATA: Call this once to add default categories
  Future<void> seedDatabase() async {
    final categories = [
      Category(name: 'Groceries', monthlyBudget: 300),
      Category(name: 'Transport', monthlyBudget: 100),
      Category(name: 'Entertainment', monthlyBudget: 200),
      Category(name: 'Dining Out', monthlyBudget: 200),
    ];
    for (var cat in categories) {
      await createCategory(cat);
    }
  }

  // --- PLANNER OPERATIONS ---
  Future<int> createPlan(Plan plan) async {
    final db = await instance.database;
    return await db.insert('planned_spends', plan.toMap());
  }

  Future<List<Plan>> readAllPlans() async {
    final db = await instance.database;
    final result = await db.query('planned_spends');
    return result.map((json) => Plan.fromMap(json)).toList();
  }

  // Lock funds: This does TWO things:
  // 1. Adds a record to locked_allocations
  // 2. Updates the current_saved amount in planned_spends
  Future<void> lockFunds(int planId, int accountId, double amount) async {
    final db = await instance.database;

    // 1. Insert the allocation
    await db.insert('locked_allocations', {
      'plan_id': planId,
      'account_id': accountId,
      'amount': amount,
    });

    // 2. Update the plan's total saved amount
    List<Map> planResult = await db.query(
      'planned_spends',
      where: 'id = ?',
      whereArgs: [planId],
    );
    double currentSaved = planResult.first['current_saved'];

    await db.update(
      'planned_spends',
      {'current_saved': currentSaved + amount},
      where: 'id = ?',
      whereArgs: [planId],
    );
  }

  // Get total locked amount across all accounts (for Dashboard)
  Future<double> getTotalLockedAmount() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM locked_allocations',
    );
    return (result.first['total'] as int? ?? 0).toDouble();
  }

  // Get locked breakdown for a specific account (for Accounts screen)
  Future<List<LockedAllocation>> getLocksForAccount(int accountId) async {
    final db = await instance.database;
    // JOIN query to get the plan name along with the amount
    final result = await db.rawQuery(
      '''
      SELECT la.*, ps.name as plan_name 
      FROM locked_allocations la 
      JOIN planned_spends ps ON la.plan_id = ps.id 
      WHERE la.account_id = ?
    ''',
      [accountId],
    );

    return result.map((json) => LockedAllocation.fromMap(json)).toList();
  }

  // --- CORE CALCULATION LOGIC ---

  /// Calculates the "Usable Balance" based on the formula:
  /// Usable Balance = (Sum of all Accounts) - (Total Locked for Plans) - (Total Reserved for Monthly Budgets)
  Future<double> calculateUsableBalance() async {
    final db = await instance.database;

    // 1. Sum of all account balances
    final accountResult = await db.rawQuery(
      'SELECT SUM(balance) as total FROM accounts',
    );
    double totalPhysical = (accountResult.first['total'] as num? ?? 0)
        .toDouble();

    // 2. Total locked for plans
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
}
