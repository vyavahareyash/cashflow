# Cashflow Open Issues Implementation Sequence

This document defines the deterministic implementation sequence for all open GitHub issues in `vyavahareyash/cashflow`. It reconciles the stable product specification (`docs/PRODUCT_SPECIFICATION.md`), roadmap phases (`docs/IMPLEMENTATION_ROADMAP.md`), and actual codebase status.

---

## Active Execution Queue (7 Remaining Open Issues)

| Order | Issue # | Title | Priority | Sprint | Status | Owning Files |
| :---: | :---: | :--- | :---: | :---: | :---: | :--- |
| **1** | **#8** | `LEGACY-008: Edit, delete, and filter transactions` | P0 | Sprint 2.3 | Partial (Bug) | `lib/services/database_helper.dart`, `lib/screens/history_screen.dart` |
| **2** | **#6** | `LEGACY-006: Goal transaction history and editing` | P0 | Sprint 2.3 | Partial | `lib/services/database_helper.dart`, `lib/screens/history_screen.dart` |
| **3** | **#36** | `NEW-021: Goal payment transaction flow` | P1 | Sprint 2.1 | Partial | `lib/services/database_helper.dart`, `lib/screens/goals_screen.dart` |
| **4** | **#48** | `feat(ux): implement remaining UI report enhancements` | P1/P2 | Polish | Planned | `lib/screens/analytics_screen.dart`, `lib/screens/budget_screen.dart`, `lib/screens/backup_restore_screen.dart` |
| **5** | **#11** | `LEGACY-011: Month-end budget reset and YTD behavior` | P0 | Sprint 2.4 | Partial | `lib/services/database_helper.dart`, `lib/screens/analytics_screen.dart` |
| **6** | **#27** | `NEW-015: Dashboard calculation integration tests` | P1 | Sprint 1.5 | Partial | `test/dashboard_integration_test.dart` |
| **7** | **#9** | `LEGACY-009: Complete project documentation` | P1 | Sprint 3.2 | Partial | `docs/`, `README.md` |

---

## Closed Issues (Verified & Administratively Completed)

The following 9 issues were verified against all acceptance criteria, documented with PR links and test passes, and closed on GitHub:

| Issue # | Title | Closed Date | Resolution Details |
| :---: | :--- | :---: | :--- |
| **#12** | `LEGACY-012: Dashboard privacy show-hide behavior` | 2026-09-14 | Delivered in PR #50 (app_settings persistence, compactCurrency masking, test/dashboard_privacy_test.dart) |
| **#32** | `NEW-020: Implement goal unlock transaction flow` | 2026-09-13 | Delivered in PR #49 (`_showUnlockFundsDialog`, `test/goal_unlock_flow_test.dart` 5/5 passing) |
| **#20** | `NEW-011: Use real usable balance on dashboard` | 2026-09-13 | Real calculations wired via `DatabaseHelper.instance.calculateUsableBalance()` |
| **#25** | `NEW-010: Update category screens for optional budgets` | 2026-09-13 | Delivered in PR #46 (`Category.monthlyBudget` nullable, `test/category_model_test.dart`) |
| **#34** | `NEW-012: Fix budget consumption display` | 2026-09-13 | Delivered in PR #46 (`test/monthly_budget_spend_calculator_test.dart` 6/6 passing) |
| **#29** | `NEW-022: Show all transaction types in history` | 2026-09-13 | Delivered in PR #47 & PR #49 (distinct badges, transfer accounts, goal names, quick chips) |
| **#28** | `NEW-013: Verify analytics charts use persisted data` | 2026-09-13 | Delivered in PR #47 (pie & bar charts bound to database queries) |
| **#23** | `NEW-014: Add database-layer regression coverage` | 2026-09-13 | Delivered in PR #47 & PR #49 (76 tests passing across all 6 transaction types) |
| **#21** | `NEW-016: Polish dashboard and budget screens` | 2026-09-13 | Delivered in PR #47 & PR #49 (48dp touch targets, smooth animations, formula pill decoupling) |

---

## Detailed Implementation Wave Plan

### Wave 1: Immediate Critical Fixes (P0 Data Integrity & Privacy)

#### 1. Issue #12: `LEGACY-012: Dashboard privacy show-hide behavior` (CLOSED - PR #50)
- **Status**: Completed and merged in PR #50. Persisted privacy state in DB, masked all daily velocity pills and goal amounts, added 6 tests in `test/dashboard_privacy_test.dart`, and added visual parity markers `01b` & `18b`.
- **Problem**: `_isPrivate` toggle hides main balances, but misses `perDayLeft` in the budget snapshot card (`'$daysLeft days left (₹${perDayLeft.toStringAsFixed(0)}/day)'`) and goal target cards (`'₹${goal.currentSaved.toStringAsFixed(0)} / ₹${goal.totalTarget.toStringAsFixed(0)}'`).
- **Fix**: Wrap remaining visible numbers in `AppFormatters.currency(..., isPrivate: _isPrivate)`.
- **Validation**: `flutter test test/widget_test.dart`.

#### 2. Issue #8: `LEGACY-008: Edit, delete, and filter transactions`
- **Priority**: P0-Critical | **Sprint**: 2.3
- **Why Now**: Critical data-integrity bug. `DatabaseHelper.deleteTransaction` currently assumes every transaction is an expense and blindly refunds balance:
  - Deleting `income` adds to balance instead of subtracting.
  - Deleting `transfer` refunds the source account without reversing the destination.
  - Deleting `goal_lock` does not restore the locked allocation.
  - Furthermore, editing transactions (amount, date, category, note) is completely missing.
- **Fix**:
  - Update `deleteTransaction` in `database_helper.dart` to branch on `tx['type']` and atomically reverse the exact legs of each transaction type.
  - Implement `updateTransaction` in `database_helper.dart` with balance diff adjustment.
  - Add Edit Transaction modal in `HistoryScreen`.
- **Validation**: `flutter test test/transaction_helpers_test.dart` + new deletion/edit tests.

#### 3. Issue #6: `LEGACY-006: Goal transaction history and editing`
- **Priority**: P0-Critical | **Sprint**: 2.3
- **Why Now**: Dependent on #8. Ensures editing or deleting goal lock transactions correctly synchronizes `locked_allocations` and `goals.current_saved`.
- **Validation**: `flutter test test/goal_lock_flow_test.dart`.

---

### Wave 2: Transaction Flow Completion & UX Polish

#### 4. Issue #36: `NEW-021: Goal payment transaction flow` & #48 Item 1
- **Priority**: P1-High | **Sprint**: 2.1
- **Why Now**: Sinking funds can currently be settled, but the resulting transaction has hardcoded category (`category_id: 1`) and default note.
- **Fix**: Update `DatabaseHelper.payBill` and `_showPaymentDialog` in `goals_screen.dart` to accept category selection and merchant note.
- **Validation**: `flutter test test/goal_lock_flow_test.dart`.

#### 5. Issue #48: `feat(ux): implement remaining UI report enhancements`
- **Priority**: P1/P2 | **Sprint**: Polish
- **Why Now**: Complete remaining visual audit wins:
  - Net cashflow summary card (`Total Inflow - Total Outflow`) & savings rate in `AnalyticsScreen`.
  - Monthly budget reset cycle label (`Resets in X days`) and over-budget delta badge (`+₹X over limit`).
  - Backup freshness indicator (`Last backup created: X ago`) in `BackupRestoreScreen`.
  - Goal 100% completion celebration styling.
- **Validation**: `flutter test --concurrency=1` and screenshot gallery verification.

---

### Wave 3: Month-End Behavior, Integration Tests & Release Readiness

#### 6. Issue #11: `LEGACY-011: Month-end budget reset and YTD behavior`
- **Priority**: P0-Critical | **Sprint**: 2.4
- **Why Now**: Verify calendar boundary behavior (zero rollover) and add YTD spend trend tests.
- **Validation**: `flutter test test/monthly_budget_spend_calculator_test.dart`.

#### 7. Issue #27: `NEW-015: Add dashboard calculation integration tests`
- **Priority**: P1-High | **Sprint**: 1.5
- **Why Now**: Final regression safety net verifying dashboard state across complex multi-step transaction mutations.
- **Validation**: `flutter test test/dashboard_calculation_integration_test.dart`.

#### 8. Issue #9: `LEGACY-009: Complete project documentation`
- **Priority**: P1-High | **Sprint**: 3.2
- **Why Now**: Final release deliverable documenting architecture, calculations, and user guides.
