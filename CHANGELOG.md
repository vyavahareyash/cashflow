# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.0] - 2026-09-14

### Added
- **Custom Destination Directory for Backups**: User-configurable backup folder path with system file picker, persistent storage in `app_settings`, and automatic fallback to platform documents/databases directory (#59, #64).
- **Export Confirmation Dialog**: Modal confirmation before exporting SQLite (`.db`), JSON, or CSV files, with format selection, directory picker, editable filename, and live destination path preview (#59, #64).
- **Isolated Backup Path Testing**: Comprehensive automated test suite (`test/custom_backup_path_test.dart`) covering default resolution, custom path overrides, directory creation, reset to default, and all export formats (#59, #64).

### Changed
- **Consolidated Settings & Data UI**: Replaced cluttered granular export/import tiles and directory settings with two streamlined cards: "Export Data & Backups" and "Import & Restore Data" (#59, #64).
- **Stateful Dialog Architecture**: Refactored export dialog into `_ExportBackupDialog` to guarantee clean controller lifecycle and prevent memory leaks (#64).

---

## [2.1.0] - 2026-09-14

### Added
- **Multi-Account Goal Settlement**: Settle goals funded by multiple accounts simultaneously, debiting physical balances and locked allocations proportionally and recording individual `goal_payment` transactions per account (#63).
- **Account-Specific Goal Unlock with Real-Time Validation**: Select specific accounts to unlock funds to with strict real-time balance limit checks, instant "Max" quick-fill action, and an "Unlock All Accounts" batch release option (#63).
- **Multi-Month Timeline Demo Data**: Expanded demo dataset across 6 historical months ($M_{-5} \dots M_0$) exercising over-budget, untouched, completed goals, goal unlocks, and goal payments (#63).
- **Scrolled Analytics Visual Testing**: Added scrolled trend chart capture markers (`16b`, `26b`) for complete automated screenshot coverage (#63).

### Changed
- **Activity Ledger Row Optimization**: Consolidated transaction edit and delete actions into a clean popup menu button (`⋮`), freeing ~40px horizontal space per row for long notes and accounts (#63).
- **Visual Capture Timing**: Added a 4-second delay before dashboard capture to ensure sample data SnackBars cleanly dismiss (#63).

### Fixed
- **Budget Screen Cycle Metadata Layout**: Resolved RenderFlex overflow and text clipping on total monthly budget card; cycle metadata now spans full width with informative Tooltips (#63).

---

## [2.0.0] - 2026-09-14

### Added
- **Configurable Payday Salary Cycle**: Custom salary cycle start day (1–31) with an interactive calendar grid picker in Settings, dynamically scoping category budgets, spending summaries, and Daily Burn Pace to actual payday schedules (#48, #54).
- **Payday Cycle Budget Reset & Zero Rollover**: Monthly budget calculations strictly scoped to the active salary cycle window with zero rollover into subsequent periods, and visual over-budget warning badges on exceeded categories (#11, #55).
- **Year-to-Date (YTD) Cumulative Analytics**: Comprehensive YTD spending aggregates by category and net cashflow indicators in Analytics (#11, #55).
- **Goal Payment Flow**: Dedicated "Pay from Goal" bottom sheet modal to spend accumulated sinking funds directly from goals with atomic SQLite consistency, reducing physical account balance, locked allocation, and goal current saved simultaneously (#36, #53).
- **Goal Transaction History & Editing**: Full bidirectional synchronization between goal allocations and activity ledger, complete with in-place goal editing and live reactive dashboard updates (#6, #52).
- **Transaction Edit, Delete & Rollback**: Full transaction edit modal with automatic balance difference adjustment, transaction deletion with atomic mathematical account balance reversal, soft-undo SnackBar feedback, and period ledger filter chips (This Cycle, Last Cycle, All Time) (#8, #51).
- **Privacy Mode Masking**: Persistent one-tap privacy toggle on the dashboard app bar masking all currency figures (`$••••••`) across the entire app for discreet usage in public (#12, #50).
- **Goal Completion Celebratory Flair**: Interactive celebratory dialog with confetti burst animation when a savings goal reaches 100% completion (#48, #56).
- **Backup Freshness Indicator**: Visual freshness badge in Settings displaying "Last backup: X ago" or "Never backed up" with actionable status coloring (#48, #56).
- **Comprehensive Integration Testing**: Isolated SQLite integration test suite covering balance invariants, mutations, cycle boundaries, empty states, and reactive notifications, plus backup export/import roundtrip verification with in-progress UI indicators (#27, #57).
- **Complete Project Documentation**: End-to-end user manuals (`FEATURE_GUIDE.md`, `CALCULATIONS.md`, `FAQ_AND_ONBOARDING.md`), three-tier system architecture guide (`ARCHITECTURE.md`) with Mermaid SQLite ER diagrams and `dataRevision` reactive state model, and updated documentation index (#9, #58).

### Changed
- **Root README & Documentation Overhaul**: Modern badges, corrected Safe-to-Spend formula ($\text{Usable} = \text{Physical} - \text{Locked}$), responsive screenshot showcase, and developer quickstart instructions (#9, #58).
- **Database Reset & Import Ordering**: Hardened foreign key cascade and insertion sequence to prevent constraint violations with goal-linked transactions (#27, #57).
- **Cleaned Intermediate Documentation**: Removed obsolete development planning files to keep the repository clean and presentable (#9, #58).

---

## [1.2.0] - 2026-09-13

### Added
- **Goal Unlock Flow**: Added dedicated bottom sheet modal and action button to release locked sinking funds back to usable liquidity without deleting goals (`DatabaseHelper.createGoalUnlockTransaction`) (#32, #49).
- **Account-to-Account Quick Transfer**: Fast transfer action button directly on `AccountCard` in the Accounts screen with pre-filled source accounts (#49).
- **Activity Ledger Quick-Filter Chips & CSV Export**: Added horizontal scrolling filter chips (`All`, `Expenses`, `Income`, `Transfers`, `Goal Locks`) and direct CSV export button to the activity ledger toolbar (#49).
- **Exhaustive 27-Marker Visual Testing Suite**: Expanded automated screenshot runner (`scripts/capture_screenshots.mjs`) covering all modals, tabs, and interaction states across both Light and Dark modes with structured JSON manifest (#47).
- **Interactive Review Gallery**: Added standalone comparison gallery (`screenshots/index.html`) featuring side-by-side theme comparison, image zoom lightbox, and audit checklist (#47).
- **UI Design & Feature Gap Audit**: Complete audit report (`screenshots/ui_report.html`) cataloging screen-by-screen UX, WCAG contrast parity, and backend feature opportunities (#49).

### Changed
- **Dashboard Formula Clarity**: Decoupled monthly tracking budget limits from usable balance formula with a vertical separator pill (`Physical - Locked | Budget cap`) to reinforce that budgets are tracking ceilings (#49).
- **Accessible Touch Targets**: Standardized all icon buttons and interactive controls to satisfy the WCAG minimum $48 \times 48\text{ dp}$ touch target standard (`AppComponentSizes.minTouchTarget`).
- **Smooth Micro-Animations**: Wrapped account locked funds accordion in `AnimatedSize` (250ms, `Curves.easeInOut`) and budget progress bars in `TweenAnimationBuilder`.

### Fixed
- **Keyboard Viewport Protection**: Protected modal bottom sheets against soft keyboard occlusion with dynamic `viewInsets.bottom` scrolling.
- **Material 3 Theme Compatibility**: Removed deprecated `background` color properties in favor of modern M3 color tokens.

---

## [1.1.0] - 2026-09-13

### Added
- **Income Transaction Flow**: Added a unified "Log Transaction" bottom sheet with an expense/income selector. Income transactions validate amounts and target accounts, execute atomically, and credit account balances accurately (#31, #40).
- **Transfer Transaction Flow**: Full account-to-account transfer support, atomically debiting the source account and crediting the destination account with validation preventing self-transfers and invalid balances (#41).
- **Transaction History Filtering**: Multi-criteria filtering on the History screen by month, year, and transaction types (all, expense, income, transfer, goal lock/unlock) (#38).
- **Optional Category Budgets**: Allowed expense categories to exist without mandatory monthly budgets, enabling flexible tracking without forced limits (#14, #37).
- **Web & Browser Support**: Web platform compatibility using `sqlite3.wasm` and `sqflite_common_ffi_web` for full in-browser local database execution.
- **Backup & Restore**: Cross-platform JSON backup export and restore mechanisms across mobile, desktop, and web environments with data validation.
- **Integration & Screenshot Tooling**: Added automated Android screenshot runner (`scripts/capture_screenshots.mjs`) and Flutter integration test suite (`integration_test/screenshots_test.dart`).
- **Multi-Platform Automated Releases**: Extended CI/CD workflow to compile and distribute Android APKs (split and universal), Web application bundles (ZIP), and iOS application bundles (unsigned IPA).
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
