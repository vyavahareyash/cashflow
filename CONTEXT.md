# Cashflow

A private, offline-first personal finance application for tracking real-time disposable cash, payday cycles, and virtual envelope savings goals.

## Language

**Safe-to-Spend Usable Balance**:
The unallocated cash remaining across physical accounts after deducting active goal locks, clamped at zero.
_Avoid_: Total balance, available credit, bank balance, net worth

**Physical Balance**:
The actual sum of money held in real-world bank, wallet, and cash accounts.
_Avoid_: Ledger balance, nominal funds, paper balance

**Locked Allocation**:
A logical reservation of funds within an account earmarked for a specific savings goal without moving money between banks.
_Avoid_: Escrow, hold, freeze, separate sub-account

**Savings Goal**:
A target savings objective (sinking fund) with a target amount, optional target date, and accumulated locked allocations.
_Avoid_: Pot, vault, piggy bank, deposit

**Category Budget**:
An intentional monthly spending target used for pacing and awareness rather than an escrow reserve.
_Avoid_: Hard limit, allowance, expense cap

**Payday Cycle**:
A spending period anchored to the user's monthly salary date rather than the first day of the calendar month.
_Avoid_: Billing cycle, statement period, calendar month

**Daily Burn Pace**:
The ratio comparing allowable daily spending against actual average daily spend within the active payday cycle.
_Avoid_: Run rate, velocity, burn down

**Privacy Mode**:
A toggleable UI state that obscures numerical balances and transaction amounts with bullet masks for public confidentiality.
_Avoid_: Incognito, secret mode, hidden mode

**Inter-Account Transfer**:
An atomic dual-entry transaction moving funds between two physical accounts without altering net worth or category spending.
_Avoid_: Payment, rebalance, wire

**Draft Transaction**:
An uncommitted, ephemeral in-memory transaction record parsed from voice or text input awaiting user review, editing, and approval before database insertion.
_Avoid_: Pending transaction, unapproved log, temp entry, provisional transaction

**Offline AI Model Pack**:
A verified, locally stored neural weight bundle (Whisper STT and GBNF-constrained SLM) downloaded via explicit user initiation to perform zero-telemetry local inference.
_Avoid_: Cloud AI, backend service, remote model, telemetry bundle

**Voice Transaction Staging**:
An interactive in-memory review interface displaying parsed Draft Transactions for visual audit, inline correction, and atomic commit to SQLite.
_Avoid_: Voice recorder, auto-commit log, staging database


