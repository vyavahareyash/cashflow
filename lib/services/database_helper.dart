import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

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
    if (_database == null) return;
    final db = _database!;
    await db.close();
    _database = null;
  }

  // --- DATABASE MANAGEMENT ---

  /// Exports the database file to a user-selected location.
  Future<String?> exportDatabase() async {
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
    } catch (e) {
      print('Export error: $e');
      return null;
    }
  }

  /// Imports a database file from a user-selected location.
  Future<bool> importDatabase() async {
    try {
      // Change FilePickerResult to dynamic if the type is not found
      dynamic result = await FilePicker.pickFiles(type: FileType.any);

      if (result == null || result.files.single.path == null) return false;

      final sourceFile = File(result.files.single.path!);

      await close();
      _database = null;

      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'money_tracker.db');

      await sourceFile.copy(path);
      await instance.database;

      return true;
    } catch (e) {
      print('Import error: $e');
      return false;
    }
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
    // Only fetch plans that are not yet fully paid (current_saved < total_target)
    // Or we can add a 'is_completed' flag. For now, let's assume if target is met and
    // locked allocations are gone, it's done.
    // Actually, the cleanest way is to filter out plans where current_saved <= 0
    // AND total_target was previously something, but that's tricky.
    // Let's implement a simple filter: if the payment makes current_saved 0 and total_target was met.
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
    return (result.first['total'] as num? ?? 0).toDouble();
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

  /// Processes a payment for a planned spend.
  /// This moves money from "Locked" to "Spent".
  Future<void> payBill(int planId, int accountId, double amount) async {
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
      // We find the allocation for this plan and account and reduce it.
      List<Map> lockRes = await txn.query(
        'locked_allocations',
        where: 'plan_id = ? AND account_id = ?',
        whereArgs: [planId, accountId],
      );
      if (lockRes.isEmpty)
        throw Exception('No locked funds found for this plan in this account');

      double currentLock = lockRes.first['amount'];
      if (currentLock < amount)
        throw Exception('Insufficient locked funds in this account');

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

      // 3. Update planned_spends total saved
      List<Map> planRes = await txn.query(
        'planned_spends',
        where: 'id = ?',
        whereArgs: [planId],
      );
      if (planRes.isEmpty) throw Exception('Plan not found');
      double currentSaved = planRes.first['current_saved'];
      double newSaved = currentSaved - amount;

      if (newSaved <= 0) {
        // Plan is fully paid/consumed, delete it
        await txn.delete(
          'planned_spends',
          where: 'id = ?',
          whereArgs: [planId],
        );
      } else {
        await txn.update(
          'planned_spends',
          {'current_saved': newSaved},
          where: 'id = ?',
          whereArgs: [planId],
        );
      }

      // 4. Create a transaction record
      await txn.insert('transactions', {
        'account_id': accountId,
        'category_id': 1, // Using a default 'General' or similar category, or passed as param
        'amount': amount,
        'date': DateTime.now().toIso8601String(),
        'note': 'Payment for plan id $planId',
      });
    });
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

  // --- JSON EXPORT/IMPORT ---
  /// Exports all database tables to a JSON file.
  Future<String?> exportDatabaseAsJSON() async {
    try {
      final db = await instance.database;

      final accounts = await db.query('accounts');
      final categories = await db.query('categories');
      final transactions = await db.query('transactions');
      final plannedSpends = await db.query('planned_spends');
      final lockedAllocations = await db.query('locked_allocations');

      final data = {
        'accounts': accounts,
        'categories': categories,
        'transactions': transactions,
        'planned_spends': plannedSpends,
        'locked_allocations': lockedAllocations,
      };

      final jsonString = _jsonEncode(data);

      final documentsDir = await getApplicationDocumentsDirectory();
      final jsonPath = join(documentsDir.path, 'cashflow_backup.json');
      final jsonFile = File(jsonPath);
      await jsonFile.writeAsString(jsonString);

      return jsonFile.path;
    } catch (e) {
      print('JSON export error: $e');
      return null;
    }
  }

  /// Imports database from a JSON file.
  Future<bool> importDatabaseFromJSON() async {
    try {
      dynamic result = await FilePicker.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) return false;

      final sourceFile = File(result.files.single.path!);
      final jsonString = await sourceFile.readAsString();
      final data = _jsonDecode(jsonString);

      await close();
      _database = null;

      final db = await instance.database;

      // Clear existing data
      await db.delete('locked_allocations');
      await db.delete('planned_spends');
      await db.delete('transactions');
      await db.delete('categories');
      await db.delete('accounts');

      // Insert data
      if (data['accounts'] != null) {
        for (var account in data['accounts']) {
          await db.insert('accounts', account);
        }
      }
      if (data['categories'] != null) {
        for (var category in data['categories']) {
          await db.insert('categories', category);
        }
      }
      if (data['transactions'] != null) {
        for (var transaction in data['transactions']) {
          await db.insert('transactions', transaction);
        }
      }
      if (data['planned_spends'] != null) {
        for (var plan in data['planned_spends']) {
          await db.insert('planned_spends', plan);
        }
      }
      if (data['locked_allocations'] != null) {
        for (var lock in data['locked_allocations']) {
          await db.insert('locked_allocations', lock);
        }
      }

      return true;
    } catch (e) {
      print('JSON import error: $e');
      return false;
    }
  }

  // --- CSV EXPORT ---
  /// Exports transactions to a CSV file.
  Future<String?> exportTransactionsAsCSV() async {
    try {
      final transactions = await getTransactionHistory();

      String csv = 'Amount,Category,Account,Date,Note\n';
      for (var tx in transactions) {
        csv += '${tx['amount']},${tx['category_name']},${tx['account_name']},${tx['date']},${tx['note'] ?? ''}\n';
      }

      final documentsDir = await getApplicationDocumentsDirectory();
      final csvPath = join(documentsDir.path, 'cashflow_transactions.csv');
      final csvFile = File(csvPath);
      await csvFile.writeAsString(csv);

      return csvFile.path;
    } catch (e) {
      print('CSV export error: $e');
      return null;
    }
  }

  // Helper methods for JSON encoding/decoding
  String _jsonEncode(Map<String, dynamic> data) {
    return _mapToJson(data);
  }

  Map<String, dynamic> _jsonDecode(String jsonString) {
    return _parseJson(jsonString);
  }

  String _mapToJson(Map<String, dynamic> map) {
    final entries = map.entries.map((e) {
      final value = e.value;
      if (value is List) {
        final listJson = '[${value.map((item) {
          if (item is Map) {
            return _mapToJson(item as Map<String, dynamic>);
          }
          return item is String ? '"$item"' : item;
        }).join(',')}]';
        return '"${e.key}":$listJson';
      } else if (value is Map) {
        return '"${e.key}":${_mapToJson(value as Map<String, dynamic>)}';
      }
      return '"${e.key}":${value is String ? '"$value"' : value}';
    }).join(',');
    return '{$entries}';
  }

  Map<String, dynamic> _parseJson(String json) {
    json = json.trim();
    if (json.startsWith('{') && json.endsWith('}')) {
      json = json.substring(1, json.length - 1);
    }

    final map = <String, dynamic>{};
    final parts = _splitJson(json);

    for (var part in parts) {
      final colonIndex = part.indexOf(':');
      if (colonIndex == -1) continue;

      String key = part.substring(0, colonIndex).trim();
      String value = part.substring(colonIndex + 1).trim();

      if (key.startsWith('"') && key.endsWith('"')) {
        key = key.substring(1, key.length - 1);
      }

      if (value.startsWith('[') && value.endsWith(']')) {
        map[key] = _parseJsonArray(value);
      } else if (value.startsWith('{') && value.endsWith('}')) {
        map[key] = _parseJson(value);
      } else if (value.startsWith('"') && value.endsWith('"')) {
        map[key] = value.substring(1, value.length - 1);
      } else if (value == 'null') {
        map[key] = null;
      } else if (value == 'true') {
        map[key] = true;
      } else if (value == 'false') {
        map[key] = false;
      } else {
        map[key] = double.tryParse(value) ?? int.tryParse(value) ?? value;
      }
    }

    return map;
  }

  List<dynamic> _parseJsonArray(String json) {
    json = json.substring(1, json.length - 1).trim();
    if (json.isEmpty) return [];

    final list = <dynamic>[];
    final parts = _splitJson(json);

    for (var part in parts) {
      part = part.trim();
      if (part.startsWith('{') && part.endsWith('}')) {
        list.add(_parseJson(part));
      } else if (part.startsWith('"') && part.endsWith('"')) {
        list.add(part.substring(1, part.length - 1));
      } else if (part == 'null') {
        list.add(null);
      } else if (part == 'true') {
        list.add(true);
      } else if (part == 'false') {
        list.add(false);
      } else {
        list.add(double.tryParse(part) ?? int.tryParse(part) ?? part);
      }
    }

    return list;
  }

  List<String> _splitJson(String json) {
    final parts = <String>[];
    var current = '';
    var depth = 0;
    var inString = false;
    var escape = false;

    for (var i = 0; i < json.length; i++) {
      final char = json[i];

      if (escape) {
        current += char;
        escape = false;
        continue;
      }

      if (char == '\\') {
        current += char;
        escape = true;
        continue;
      }

      if (char == '"') {
        inString = !inString;
        current += char;
        continue;
      }

      if (!inString) {
        if (char == '{' || char == '[') {
          depth++;
        } else if (char == '}' || char == ']') {
          depth--;
        } else if (char == ',' && depth == 0) {
          parts.add(current);
          current = '';
          continue;
        }
      }

      current += char;
    }

    if (current.isNotEmpty) {
      parts.add(current);
    }

    return parts;
  }

  // --- ANALYTICS QUERIES ---
  /// Gets spending by category for current month or all-time.
  /// Returns a Map<categoryName, totalAmount>
  Future<Map<String, double>> getSpendingByCategory(
      {bool currentMonthOnly = true}) async {
    final db = await instance.database;

    String whereClause = '';
    if (currentMonthOnly) {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
      final monthEnd =
          DateTime(now.year, now.month + 1, 0, 23, 59, 59).toIso8601String();
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
      map[row['name'] as String] =
          (row['total'] as num? ?? 0).toDouble();
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
      map[row['month'] as String] =
          (row['total'] as num? ?? 0).toDouble();
    }
    return map;
  }

  /// Gets spending by category for a specific month.
  /// Month format: "YYYY-MM"
  Future<Map<String, double>> getSpendingByCategoryForMonth(
      String month) async {
    final db = await instance.database;

    final result = await db.rawQuery('''
      SELECT c.name, SUM(t.amount) as total
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      WHERE SUBSTR(t.date, 1, 7) = ?
      GROUP BY t.category_id
      ORDER BY total DESC
    ''', [month]);

    final map = <String, double>{};
    for (var row in result) {
      map[row['name'] as String] =
          (row['total'] as num? ?? 0).toDouble();
    }
    return map;
  }

  /// Gets total spending for a specific month.
  Future<double> getTotalSpendingForMonth(String month) async {
    final db = await instance.database;

    final result = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM transactions
      WHERE SUBSTR(date, 1, 7) = ?
    ''', [month]);

    return (result.first['total'] as num? ?? 0).toDouble();
  }
}
