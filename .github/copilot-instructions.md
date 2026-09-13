# Copilot Instructions for cashflow

## Build, Test, and Lint Commands

- **Run Application**: `flutter run`
- **Build Application**: `flutter build apk` (Android) or `flutter build ios` (iOS)
- **Run All Tests**: `flutter test --concurrency=1`
- **Run Single Test**: `flutter test test/path/to/test_file.dart`
- **Lint Code**: `flutter analyze`
- **Format Code**: `dart format .`

## High-Level Architecture

`cashflow` is a local-first cash-flow management application built with Flutter.

### Core Logic: Physical vs. Logical Balance
The app differentiates between money actually held and money allocated for specific purposes:
- **Physical Balance**: The actual sum of all funds in `accounts` (Bank/Cash).
- **Logical Balance (Locked)**: Funds physically present but "tagged" for future expenses via `goals` and `locked_allocations`.
- **Logical Balance (Reserved)**: Funds allocated to `categories` for the current month's budget.

**Usable Balance Formula**:
`Usable Balance = (Sum of all Accounts) - (Total Locked for Goals) - (Total Reserved for Monthly Budgets)`

### Project Structure
- `lib/models/`: Data structures for Accounts, Categories, Transactions, Goals, and Locked Allocations.
- `lib/services/`: Contains `database_helper.dart` for SQLite (sqflite) SQLite CRUD operations.
- `lib/screens/`: UI layer (Dashboard, Budget, Goals, Accounts, History).

### Data Schema (SQLite)
- `accounts`: Tracks physical fund locations.
- `categories`: Defines monthly budget targets.
- `transactions`: Logs spending/income linked to accounts and categories.
- `goals`: Future financial goals/obligations.
- `locked_allocations`: Bridge table linking a `goal_id` to an `account_id` to track where "locked" money is physically stored.

## Key Conventions

## Testing

- **Concurrency**: Always run test suites with `flutter test --concurrency=1` to prevent SQLite file-lock conflicts in `sqflite_common_ffi`.
- **No Async DB I/O in `testWidgets`**: `testWidgets` executes inside a `fakeAsync` zone. Invoking `sqflite_common_ffi` queries or async DB operations inside `testWidgets` causes deadlocks and hangs indefinitely. Keep all database logic, queries, and transaction invariants in standard async `test()` blocks. In `testWidgets`, test purely UI rendering using in-memory model instances.
- **Avoid Unbounded `pumpAndSettle()`**: Screens with animations, tickers, or active listeners will hang `pumpAndSettle()`. Use bounded pumps (`await tester.pump()`, `await tester.pump(const Duration(milliseconds: 100))`).
- **Follow Nearest Passing Pattern**: Model SQLite tests after `test/income_flow_test.dart` or `test/goal_payment_flow_test.dart`.
- **Database Cleanup**: Every database test must close and delete its test database in both `setUp` and `tearDown` so tests remain isolated.
- **Form Field Conventions**: Use `initialValue` instead of deprecated `value` on `DropdownButtonFormField`.
- **Early Verification**: Run single test files immediately after adding changes (`flutter test test/path/to/test.dart`). If a test hangs or fails due to harness complexity, simplify the harness or move assertions to unit tests.

## GitHub Work Tracking

- GitHub issues are the source of truth for execution status, ownership, priorities, milestones, dependencies, and progress.
- Use the repository issue form for new roadmap work; include scope, acceptance criteria, validation, and related issues or pull requests.
- Use pull requests to link delivered work with `Closes #<issue>` or `Fixes #<issue>` only when the pull request fully satisfies that issue.
- Treat `NEW-*` identifiers as temporary roadmap aliases during migration, not as GitHub issue numbers.
- Do not add live status tables, issue counts, or dependency trackers to Markdown documentation; link to GitHub instead.

- **Database Access**: All database calls must be `async/await`.
- **Numeric Input**: Always use `double.tryParse()` for numeric inputs to ensure null safety and prevent crashes.
- **UI Design**: 
  - Theme: Green-themed Material Design 3.
  - Spacing: Use `SizedBox` for consistent margins/padding.
  - Containers: Use `Card` for content grouping.
- **State Management**: Use `setState` for local screen state or `Provider` for global state.
