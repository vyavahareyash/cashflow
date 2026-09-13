# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-09-13

### Added
- **Income Transaction Flow**: Added a unified "Log Transaction" bottom sheet with an expense/income selector. Income transactions validate amounts and target accounts, execute atomically, and credit account balances accurately (#31, #40).
- **Transfer Transaction Flow**: Full account-to-account transfer support, atomically debiting the source account and crediting the destination account with validation preventing self-transfers and invalid balances (#41).
- **Transaction History Filtering**: Multi-criteria filtering on the History screen by month, year, and transaction types (all, expense, income, transfer, goal lock/unlock) (#38).
- **Optional Category Budgets**: Allowed expense categories to exist without mandatory monthly budgets, enabling flexible tracking without forced limits (#14, #37).
- **Web & Browser Support**: Web platform compatibility using `sqlite3.wasm` and `sqflite_common_ffi_web` for full in-browser local database execution.
- **Backup & Restore**: Cross-platform JSON backup export and restore mechanisms across mobile, desktop, and web environments with data validation.
- **Integration & Screenshot Tooling**: Added automated Android screenshot runner (`scripts/capture_screenshots.mjs`) and Flutter integration test suite (`integration_test/screenshots_test.dart`).
- **Comprehensive Documentation Hub**: Complete project documentation suite including `INDEX.md`, `PRODUCT_SPECIFICATION.md`, `PROJECT_SCOPE.md`, `SCHEMA_REDESIGN.md`, and `development.md`.

### Changed
- **Goal System Refactor**: Completely migrated terminology, data models, database tables, and UI from "planned spends" to "goals" (`GoalModel`, `goals` table).
- **Atomic Transaction Architecture**: Introduced ACID-compliant atomic transaction execution helpers with automatic rollback across all 6 transaction types in `DatabaseHelper` (#19).
- **Modern Color Styling**: Updated deprecated `withOpacity()` usages to Flutter's recommended `withValues(alpha: ...)` across all screens.
- **Structured Error Logging**: Replaced raw `print` statements in database routines with structured `dart:developer` logging.

### Fixed
- **Usable Cash Alignment**: Aligned usable balance calculations strictly to physical cash balances minus locked goal funds, ensuring monthly budgets function as tracking limits rather than deductions (#39).
- **Monthly Budget Nullability**: Corrected category monthly budget defaults and nullability handling.

---

## [1.0.1] - 2026-08-16

### Changed
- Updated application launcher icons across Android and iOS configurations.

---

## [1.0.0] - 2026-08-16

### Added
- Initial public release of Cashflow.
- Offline-first personal finance tracking with local SQLite storage.
- Account balance tracking (cash and bank accounts).
- Category management and monthly spending budgets.
- Expense logging with receipt notes and dates.
- Planned spends reservation and locked fund tracking.
- Analytics and spending breakdown charts.
- Automated CI/CD workflow for building release APKs.
