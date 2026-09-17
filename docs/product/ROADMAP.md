# Cashflow Implementation Roadmap

**Timeline:** 12 weeks across three phases
**Source of Truth for Execution:** [GitHub Issues](https://github.com/vyavahareyash/cashflow/issues) · [GitHub Pull Requests](https://github.com/vyavahareyash/cashflow/pulls)

---

## Delivery Shape

| Phase | Weeks | Product Outcome |
| :--- | :--- | :--- |
| **Phase 1** | 1–4 | MVP core: accounts, categories, expenses, dashboard, and analytics |
| **Phase 2** | 5–8 | Complete transaction lifecycle, goals, history, and payday-anchored budget behavior |
| **Phase 3** | 9–12 | Data portability, documentation, polish, accessibility, and platform release readiness |

---

## Phase 1: MVP Core

### Sprint 1.1: Foundation and Schema
- Six typed transactions: expense, income, transfer, goal lock, goal unlock, and goal payment.
- Nullable transaction category and destination account fields.
- Goals and locked allocations represented in local SQLite.
- Migration coverage from v1 schema.

### Sprint 1.2: Database Helpers and CRUD
- Atomic helpers for all six transaction types.
- Transaction history queries with type and period filtering.
- Usable balance calculation: physical accounts minus locked goal funds, clamped at zero; monthly budgets remain tracking limits.

### Sprint 1.3: Categories and Dashboard Fixes
- Allow categories without a monthly budget.
- Complete the dashboard balance show/hide privacy behavior.
- Present physical, goal-locked, monthly budget, and usable balances accurately.

### Sprint 1.4: Dashboard and Analytics
- Replace mock budget progress with transaction-backed values.
- Show category spending, trends, and goal progress from real data.
- Keep calculations consistent with tracking-only budget model.

### Sprint 1.5: Phase 1 Stability
- Cover database operations, migrations, and balance calculations with automated tests.
- Add dashboard calculation integration test coverage.

---

## Phase 2: Extended MVP

### Sprint 2.1: Complete Transaction Lifecycle
- Expose all six transaction types through UI quick actions and modals.
- Account details for transfers and goal details for goal operations.

### Sprint 2.2: Goal Contributions & Sinking Funds
- Recommended monthly savings pace based on target amount and target date.
- Contribution history and allocations visible in goal details.
- Editing goal allocations and configuring custom salary date.

### Sprint 2.3: History and Filtering
- Edit and delete transactions with atomic balance reversal.
- Filter by month, year, and transaction type.
- Period totals and ledger summary cards.

### Sprint 2.4: Payday-Anchored Budget Cycles
- Reset monthly budgets at payday boundaries without rollover.
- Daily Burn Pace calculation and visual warning indicators.
- Year-to-date analytics and cycle edge-case test coverage.

---

## Phase 3: Release Readiness

### Sprint 3.1: Data Portability
- Support portable JSON and raw SQLite database backup and restore with referential integrity validation.

### Sprint 3.2: Documentation & Invariants
- Provide user guides, FAQs, onboarding material, architecture documentation, data-model explanations, and calculation references.

### Sprint 3.3: UI, Accessibility & Polish
- Locked-funds visibility, responsive spacing, error feedback, a11y semantic labels, and confetti celebration flair.

### Sprint 3.4: Platform Release
- Validate Android, iOS, and web builds, complete end-to-end coverage, resolve release blockers, and prepare platform artifacts.

---

## Product Acceptance Principles

- **Tracking-only budgets**: spending is never hard-blocked; overspending is surfaced with clear warnings.
- **Logical goal locking**: locked money remains physically in its account and is excluded from usable balance.
- **Physical balance correctness**: only income, expense, transfer, and goal payment operations change physical account balances.
- **Offline-first privacy**: SQLite remains the local source of user data; export is explicit.
- **Cross-platform parity**: Android, iOS, and web are first-class targets.
- **Regression discipline**: database migrations, calculations, and user-visible workflows require focused tests before release.

---

## Related References

- [Product Specification](SPECIFICATION.md) — Authoritative product rules and feature inventory
- [Calculations & Formulas](../engineering/CALCULATIONS.md) — Mathematical definitions
- [System Architecture](../engineering/ARCHITECTURE.md) — Three-tier architecture and SQLite schema
- [Development Guide](../engineering/DEVELOPMENT.md) — Setup and test guidelines
