# 3. Tracking-Only Budget Model and Usable Balance Clamping

## Status
Accepted

## Context
Traditional envelope budgeting tools often treat category budgets as rigid escrows, artificially deducting budgeted amounts from available cash at the beginning of the month. This causes double-counting when expenses are later logged, and punishes variable real-world spending.

## Decision
We treat monthly category budgets strictly as awareness and pacing limits rather than escrow allocations. Monthly budgets do not deduct from Safe-to-Spend Usable Balance. Usable Balance is computed as `max(Total Physical - Total Locked, 0.0)` and clamped to prevent negative balance display if accounts dip temporarily.

## Consequences
- No artificial double-counting of planned expenses: funds leave usable balance only when money is physically spent or locked into a goal envelope.
- Exceeding a budget shows visual burn-pace warnings without blocking user actions or breaking math invariants.
