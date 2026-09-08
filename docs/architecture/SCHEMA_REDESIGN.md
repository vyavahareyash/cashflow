# Cashflow: Schema Redesign Analysis

**Date:** 2026-09-05  
**Status:** Ready for Implementation  
**Scope:** Align current SQLite schema with PRODUCT_SPECIFICATION.md

---

## 📊 Current Schema State

### Tables Defined
```sql
accounts (id, name, balance, type)
categories (id, name, monthly_budget) -- NOT NULL, must be made optional
transactions (id, account_id, category_id, amount, date, note)
goals (id, name, total_target, target_date, current_saved)
locked_allocations (id, goal_id, account_id, amount)
```

### Models Defined
- `Account` ✅
- `Category` ❌ (but monthlyBudget is required, needs optional)
- `TransactionModel` ❌ (missing `type` field)
- `Goal` ✅
- `LockedAllocation` ✅

---

## 🔍 Alignment Check: Product Decisions vs. Schema

### ✅ **ALIGNED** (No Changes Needed)
| Feature | Current | Product Spec | Gap |
|---------|---------|--------------|-----|
| Accounts tracking | ✅ Present | ✅ Required | — |
| Categories | ✅ Present | ✅ Required | — |
| Planned spends (goals) | ✅ Present | ✅ Required | — |
| Logical locking | ✅ Present | ✅ Required | — |
| Transaction basic fields | ✅ Present | ✅ Required | — |

### ⚠️ **MISALIGNED** (Requires Changes)

#### 1. **Transaction Type Field** — CRITICAL
- **Current:** No `type` field; transactions only distinguish by having/not having category_id
- **Product Spec:** 6 transaction types (Expense, Income, Transfer, Goal Lock, Goal Unlock, Goal Payment)
- **Gap:** Cannot distinguish transaction purpose; goal contributions not logged as transactions
- **Impact:** Blocks issues #6 (show goal locks in history) and #10 (contribution suggestions)
- **Action:** Add `type` TEXT field to transactions table

#### 2. **Category Budget Optionality** — HIGH
- **Current:** `monthly_budget REAL NOT NULL` — always required
- **Product Spec:** Budget should be optional (Issue #13)
- **Gap:** Cannot create categories without budgets
- **Impact:** Limits user flexibility; forces budget tracking on all categories
- **Action:** Change `monthly_budget` to nullable (`REAL DEFAULT NULL`)

#### 3. **Transaction Account References** — MEDIUM
- **Current:** Foreign key `account_id` references source account only
- **Product Spec:** Transfers need both source AND destination accounts
- **Gap:** Transfer type cannot be fully represented
- **Action:** Add optional `destination_account_id` field for transfers

#### 4. **Transaction Goal References** — MEDIUM
- **Current:** No way to link transactions to goals
- **Product Spec:** Goal lock/unlock/payment transactions reference goals
- **Gap:** Goal transactions not connected to goals; can't show history
- **Action:** Add optional `goal_id` field for goal transactions

---

## 📋 Schema Redesign Summary (Minimal + Complete)

### **Immediate Changes (MVP Requirement)**

#### Table: `transactions` — Add `type` field
```sql
ALTER TABLE transactions ADD COLUMN type TEXT DEFAULT 'expense' CHECK (type IN ('expense', 'income', 'transfer', 'goal_lock', 'goal_unlock', 'goal_payment'));
```

#### Table: `transactions` — Add destination account for transfers
```sql
ALTER TABLE transactions ADD COLUMN destination_account_id INTEGER DEFAULT NULL;
-- Add foreign key: FOREIGN KEY (destination_account_id) REFERENCES accounts (id)
```

#### Table: `transactions` — Add goal_id for goal-related transactions
```sql
ALTER TABLE transactions ADD COLUMN goal_id INTEGER DEFAULT NULL;
-- Add foreign key: FOREIGN KEY (goal_id) REFERENCES goals (id)
```

#### Table: `categories` — Make budget optional
```sql
ALTER TABLE categories MODIFY monthly_budget REAL DEFAULT NULL;
-- Or in SQLite: No MODIFY, so recreate table or use UPDATE
```

---

## 🔄 Migration Strategy

### **For Existing Users (Database Preservation)**
When updating Cashflow to v2.0, need a migration:

```dart
// In database_helper.dart _initDB onUpgrade:
Future<Database> _initDB(String filePath) async {
  return await openDatabase(
    path,
    version: 2,  // Bump from 1 to 2
    onCreate: _createDB,
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await _migrateV1toV2(db);
      }
    },
  );
}

Future<void> _migrateV1toV2(Database db) async {
  // 1. Add type field (default to 'expense')
  await db.execute('ALTER TABLE transactions ADD COLUMN type TEXT DEFAULT "expense"');
  
  // 2. Add destination_account_id for transfers
  await db.execute('ALTER TABLE transactions ADD COLUMN destination_account_id INTEGER DEFAULT NULL');
  
  // 3. Add plan_id for goal transactions
  await db.execute('ALTER TABLE transactions ADD COLUMN plan_id INTEGER DEFAULT NULL');
  
  // 4. Make category budget nullable (create new table, copy, drop old, rename)
  await db.execute('''
    CREATE TABLE categories_new (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      monthly_budget REAL DEFAULT NULL
    )
  ''');
  
  await db.execute('''
    INSERT INTO categories_new (id, name, monthly_budget)
    SELECT id, name, monthly_budget FROM categories
  ''');
  
  await db.execute('DROP TABLE categories');
  await db.execute('ALTER TABLE categories_new RENAME TO categories');
}
```

---

## 📊 Updated Data Models (Dart)

### **TransactionModel** — MUST UPDATE
```dart
class TransactionModel {
  final int? id;
  final int accountId;                    // Source account
  final int? destinationAccountId;        // For 'transfer' type
  final int? categoryId;                  // For 'expense' type only
  final int? planId;                      // For goal lock/unlock types
  final double amount;
  final String date;
  final String note;
  final String type;                      // expense|income|transfer|goal_lock|goal_unlock|goal_payment

  TransactionModel({
    this.id,
    required this.accountId,
    this.destinationAccountId,
    this.categoryId,
    this.planId,
    required this.amount,
    required this.date,
    required this.note,
    this.type = 'expense',
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      accountId: map['account_id'],
      destinationAccountId: map['destination_account_id'],
      categoryId: map['category_id'],
      planId: map['plan_id'],
      amount: map['amount'],
      date: map['date'],
      note: map['note'],
      type: map['type'] ?? 'expense',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'account_id': accountId,
      'destination_account_id': destinationAccountId,
      'category_id': categoryId,
      'plan_id': planId,
      'amount': amount,
      'date': date,
      'note': note,
      'type': type,
    };
  }
}
```

### **Category Model** — SHOULD UPDATE
```dart
class Category {
  final int? id;
  final String name;
  final double? monthlyBudget;  // Now nullable

  Category({
    this.id,
    required this.name,
    this.monthlyBudget,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      monthlyBudget: map['monthly_budget'] as double?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'monthly_budget': monthlyBudget,
    };
  }
}
```

---

## ✨ Final Schema (After Redesign)

```sql
-- CORE TABLES (No major changes)
accounts (id, name, balance, type)
categories (id, name, monthly_budget) -- nullable now
goals (id, name, total_target, target_date, current_saved)
locked_allocations (id, goal_id, account_id, amount)

-- ENHANCED TABLE
transactions (
  id,
  account_id,                    -- Source account (FK)
  destination_account_id,        -- For transfers only (FK, nullable)
  category_id,                   -- For expenses only (FK, nullable)
  plan_id,                       -- For goal locks (FK, nullable)
  amount,
  date,
  note,
  type                           -- expense|income|transfer|goal_lock|goal_unlock|goal_payment
)
```

---

## ✅ Conclusion

**Schema Redesign Status:** ✅ **READY**

**Required Changes:**
1. Add `type` field to transactions (critical)
2. Add `destination_account_id` field to transactions (critical)
3. Add `goal_id` field to transactions (critical)
4. Make `monthly_budget` nullable in categories (critical)

**Impact:** Medium (non-breaking changes; migrations required for existing data)

**Timeline:** Can be implemented in **1 sprint** (1-2 weeks)

**Next Step:** Implement Phase 1 schema changes + update models + create migrations

---

**Related:** [../IMPLEMENTATION_ROADMAP.md](../IMPLEMENTATION_ROADMAP.md) | [../PRODUCT_SPECIFICATION.md](../PRODUCT_SPECIFICATION.md)
