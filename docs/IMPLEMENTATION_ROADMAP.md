# Cashflow Implementation Roadmap

**Timeline:** 12 weeks across three phases
**Last updated:** 2026-09-08

GitHub is the source of truth for execution. Use the [open issues](https://github.com/vyavahareyash/cashflow/issues), [pull requests](https://github.com/vyavahareyash/cashflow/pulls), labels, milestones, and project views for current status, ownership, dependencies, priorities, and progress.

This document describes stable product scope and intended sequencing. It deliberately does not mirror GitHub issue status or counts.

## Delivery Shape

| Phase | Weeks | Product outcome |
|-------|-------|-----------------|
| Phase 1 | 1-4 | MVP core: accounts, categories, expenses, dashboard, and analytics |
| Phase 2 | 5-8 | Complete transaction lifecycle, goals, history, and monthly budget behavior |
| Phase 3 | 9-12 | Data portability, documentation, polish, accessibility, and platform release readiness |

## Phase 1: MVP Core

### Sprint 1.1: Foundation and Schema

Establish the v2 database and model contracts needed by feature work:

- Six typed transactions: expense, income, transfer, goal lock, goal unlock, and goal payment.
- Nullable transaction category and destination account fields where the transaction type does not require them.
- Goals and locked allocations represented in the database.
- Migration coverage from the v1 schema.

### Sprint 1.2: Database Helpers and CRUD

Build the testable database operations used by the UI:

- Atomic helpers for all six transaction types.
- Transaction history queries with type and period filtering.
- Monthly category spending calculations.
- Usable balance calculation: physical accounts minus locked goal funds, clamped at zero; monthly budgets remain tracking limits.

The transaction-helper work is tracked in [issue #18](https://github.com/vyavahareyash/cashflow/issues/18) and delivered for review in [PR #19](https://github.com/vyavahareyash/cashflow/pull/19).

### Sprint 1.3: Categories and Dashboard Fixes

- Allow categories without a monthly budget.
- Complete the dashboard show/hide behavior.
- Present physical, goal-locked, monthly budget, and usable balances accurately.

### Sprint 1.4: Dashboard and Analytics

- Replace mock budget progress with transaction-backed values.
- Show category spending, trends, and goal progress from real data.
- Keep calculations consistent with the tracking-only budget model and locked product specification.

### Sprint 1.5: Phase 1 Stability

- Cover database operations, migrations, and balance calculations with tests.
- Add dashboard calculation integration coverage.
- Refine dashboard and budget screen layout without changing product semantics.

## Phase 2: Extended MVP

### Sprint 2.1: Complete Transaction Lifecycle

Expose all six transaction types through the UI and make them visible in history, including account details for transfers and goal details for goal operations.

### Sprint 2.2: Goal Contributions

- Calculate recommended contributions from target, current progress, and remaining time.
- Show contribution history and recommendations in goal details.
- Support editing goal allocations and configuring the salary date used by recommendations.

### Sprint 2.3: History and Filtering

- Edit and delete transactions with correct balance and allocation effects.
- Filter by month and year.
- Show totals for the selected period.
- Include goal locks in the transaction ledger.

### Sprint 2.4: Month-End Budget Behavior

- Reset monthly budgets at the calendar boundary without rollover.
- Show over- and under-budget warnings.
- Add year-to-date analytics and month-transition edge-case coverage.

## Phase 3: Release Readiness

### Sprint 3.1: Data Portability

Support JSON and CSV export/import with validation of referential integrity and actionable import errors.

### Sprint 3.2: Documentation

Provide user guides, FAQs, onboarding material, architecture documentation, data-model explanations, and calculation references.

### Sprint 3.3: UI and UX Quality

Improve locked-funds visibility, spacing, error feedback, accessibility, and query/performance behavior across supported screens.

### Sprint 3.4: Platform Release

Validate Android, iOS, and web builds, complete end-to-end coverage, resolve release blockers, and prepare platform submissions.

## Product Acceptance Principles

- **Tracking-only budgets:** spending is never hard-blocked; overspending is surfaced with clear warnings.
- **Logical goal locking:** locked money remains physically in its account and is excluded from usable balance.
- **Physical balance correctness:** only income, expense, transfer, and goal payment operations change physical account balances.
- **Offline-first privacy:** SQLite remains the local source of user data; export is explicit.
- **Cross-platform parity:** Android, iOS, and web are first-class targets.
- **Regression discipline:** database migrations, calculations, and user-visible workflows require focused tests before release.

## Related References

- [Product specification](PRODUCT_SPECIFICATION.md) — locked product behavior and formulas.
- [Project scope](PROJECT_SCOPE.md) — complete feature inventory.
- [Schema redesign](architecture/SCHEMA_REDESIGN.md) — database authority.
- [GitHub issues](https://github.com/vyavahareyash/cashflow/issues) — live execution queue.
- [GitHub pull requests](https://github.com/vyavahareyash/cashflow/pulls) — implementation and review history.
