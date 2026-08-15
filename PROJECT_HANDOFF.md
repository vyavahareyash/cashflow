Project Handoff: MoneyTracker (Local-First Cash-Flow App)
1. High-Level Vision
MoneyTracker is not a simple expense logger; it is a Cash-Flow Management Tool. The primary goal is to calculate a "Usable Balance"—telling the user exactly how much money they have left after accounting for physical bank balances, future planned obligations (Sinking Funds), and reserved monthly budgets.

2. Core Business Logic (The "Magic")
The app operates on a Physical vs. Logical balance system.

The Formula:
Usable Balance = (Sum of all Accounts) - (Total Locked for Plans) - (Total Reserved for Monthly Budgets)

Physical Balance: The actual money sitting in bank accounts or cash.
Logical Balance (Locked): Money that is physically in an account but "tagged" for a specific future expense (e.g., Annual Insurance).
Logical Balance (Reserved): Money allocated to a category budget for the current month.
3. Technical Stack
Framework: Flutter (Dart)
UI System: Material Design 3
Storage: Local SQLite (sqflite package)
Architecture: Local-first, no cloud/auth required.
4. Data Schema (SQLite)
The database consists of 5 interconnected tables:

accounts: id, name, balance (REAL), type (Bank/Cash)
categories: id, name, monthly_budget (REAL)
transactions: id, account_id (FK), category_id (FK), amount (REAL), date (TEXT), note (TEXT)
planned_spends: id, name, total_target (REAL), target_date (TEXT), current_saved (REAL)
locked_allocations: id, plan_id (FK), account_id (FK), amount (REAL)
Note: This is the "Bridge Table" that tracks which account is holding the money for which plan.
5. Current Implementation Status
UI Layer: Complete. Dashboard, Budget, Planner, and Accounts screens are built.
Database Layer: DatabaseHelper implemented with CRUD for Accounts, Categories, and basic Transaction logging.
Integration:
Adding an account updates the Total Balance.
Logging a spend deducts from the Physical Account balance.
Locking funds in the Planner updates the locked_allocations table and the planned_spends total.
6. Implementation Roadmap (Remaining Tasks)
Milestone 1: Budget Consumption Logic (High Priority)
Task: Replace fake progress bars on the Budget Screen.
Logic: Sum(transactions where category_id = X and date = current_month) / category.monthly_budget.
Milestone 2: Transaction History & Management
Task: Create a "History" view.
Logic: Read the transactions table, join with accounts and categories to show names instead of IDs. Implement "Delete Transaction" (which must refund the amount back to the account balance).
Milestone 3: The "Payment" Loop
Task: Implement a "Pay Bill" action in the Planner.
Logic:
Subtract the payment amount from the Physical Account.
Delete the corresponding amount from locked_allocations.
Create a transaction record for the payment.
Milestone 4: Data Portability
Task: Export/Import data.
Logic: Since the app is local-only, implement a JSON or CSV export/import of the SQLite file.
Milestone 5: Visual Analytics
Task: Add spending trend charts.
Logic: Use fl_chart to visualize spending per category and monthly trends.
7. Coding Guidelines for AI/Copilot
State Management: Use setState for simple updates or implement Provider for global state.
Asynchronousity: All database calls must be async/await.
UI Consistency: Maintain the Green-themed Material 3 design. Use SizedBox for spacing and Card for containers.
Null Safety: Use double.tryParse() for all numeric inputs to prevent crashes.