# Copilot Instructions for cashflow

## Build, Test, and Lint Commands

- **Run Application**: `flutter run`
- **Build Application**: `flutter build apk` (Android) or `flutter build ios` (iOS)
- **Run All Tests**: `flutter test`
- **Run Single Test**: `flutter test test/path/to/test_file.dart`
- **Lint Code**: `flutter analyze`
- **Format Code**: `flutter format .`

## High-Level Architecture

`cashflow` is a local-first cash-flow management application built with Flutter.

### Core Logic: Physical vs. Logical Balance
The app differentiates between money actually held and money allocated for specific purposes:
- **Physical Balance**: The actual sum of all funds in `accounts` (Bank/Cash).
- **Logical Balance (Locked)**: Funds physically present but "tagged" for future expenses via `planned_spends` and `locked_allocations`.
- **Logical Balance (Reserved)**: Funds allocated to `categories` for the current month's budget.

**Usable Balance Formula**:
`Usable Balance = (Sum of all Accounts) - (Total Locked for Plans) - (Total Reserved for Monthly Budgets)`

### Project Structure
- `lib/models/`: Data structures for Accounts, Categories, Transactions, Plans, and Locked Allocations.
- `lib/services/`: Contains `database_helper.dart` for SQLite (sqflite) SQLite CRUD operations.
- `lib/screens/`: UI layer (Dashboard, Budget, Planner, Accounts, History).

### Data Schema (SQLite)
- `accounts`: Tracks physical fund locations.
- `categories`: Defines monthly budget targets.
- `transactions`: Logs spending/income linked to accounts and categories.
- `planned_spends`: Future financial goals/obligations.
- `locked_allocations`: Bridge table linking a `plan_id` to an `account_id` to track where "locked" money is physically stored.

## Key Conventions

- **Database Access**: All database calls must be `async/await`.
- **Numeric Input**: Always use `double.tryParse()` for numeric inputs to ensure null safety and prevent crashes.
- **UI Design**: 
  - Theme: Green-themed Material Design 3.
  - Spacing: Use `SizedBox` for consistent margins/padding.
  - Containers: Use `Card` for content grouping.
- **State Management**: Use `setState` for local screen state or `Provider` for global state.
