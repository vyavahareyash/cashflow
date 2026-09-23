# Cashflow Feature Guide

A complete walkthrough of Cashflow's features, interfaces, and core concepts.

---

## Table of Contents
1. [Core Philosophy: Safe-to-Spend Balance](#1-core-philosophy-safe-to-spend-balance)
2. [Dashboard Overview & Privacy Mode](#2-dashboard-overview--privacy-mode)
3. [Payday-Anchored Budget Cycles & Burn Pace](#3-payday-anchored-budget-cycles--burn-pace)
4. [Sinking Funds & Savings Goals](#4-sinking-funds--savings-goals)
5. [Accounts & Inter-Account Transfers](#5-accounts--inter-account-transfers)
6. [Activity Ledger & Transaction Filtering](#6-activity-ledger--transaction-filtering)
7. [Analytics, Trends & YTD Cashflow](#7-analytics-trends--ytd-cashflow)
8. [Settings, Data Portability & Backup](#8-settings-data-portability--backup)
9. [Offline Voice Journaling & AI Assistant](#9-offline-voice-journaling--ai-assistant)

---

## 1. Core Philosophy: Safe-to-Spend Balance

Most budgeting apps tell you what you spent last month. Cashflow answers the real-time financial question:
> **"How much money can I safely spend right now without sabotaging future bills or goals?"**

Cashflow separates money you hold physically from money that is logically committed:
- **Physical Balance**: Total funds across all your physical accounts (Bank accounts, Wallets, Cash).
- **Locked Funds**: Money physically in an account but earmarked for future sinking funds/goals.
- **Safe-to-Spend Usable Balance**:
  $$\text{Usable Balance} = \max(\text{Physical Accounts Balance} - \text{Total Locked for Goals}, 0)$$

Budgets in Cashflow serve as **tracking and pacing limits**, not physical locks. Exceeding a budget displays visual warnings rather than blocking transactions.

---

## 2. Dashboard Overview & Privacy Mode

The Dashboard is your financial control center:

- **Hero Usable Balance Card**:
  - Displays your Safe-to-Spend balance in large, clear figures.
  - Formula breakdown pill bar: `[Physical] - [Locked] | [Budget Cap]`.
  - Gradient styling with subtle depth and elevation.
- **Privacy Mode**:
  - Tap the visibility eye icon (`👁️` / `👁️‍🗨️`) in the top right of the hero card to toggle privacy mode.
  - Instantly masks all sensitive balances, formula pills, goal targets, and pace figures with discreet dots (`••••`).
  - Privacy preference is saved locally across app restarts.
- **Quick Action Bar**:
  - Quick-log buttons for Expense, Income, Transfer, and Goal Lock allocations.
- **Pull-to-Refresh**:
  - Swipe down on the dashboard anytime to trigger a data sync and recalculate all metrics.

---

## 3. Payday-Anchored Budget Cycles & Burn Pace

Traditional apps force calendar month boundaries (1st to 30th/31st). Cashflow anchors budget cycles to your **actual payday**:

- **Custom Payday (Day 1–31)**:
  - Configure your monthly payday in **Settings & Data**.
  - Cycle automatically spans from your chosen payday to the day before the next payday (e.g., Sept 15 to Oct 14).
  - Handles variable month lengths (28, 29, 30, 31 days) and leap years without drifting.
- **Daily Burn Pace (`₹/day`)**:
  - Shows how much remaining budget you have left to spend per day until next payday:
    $$\text{Daily Burn Pace} = \frac{\text{Remaining Cycle Budget}}{\text{Days Left in Cycle}}$$
- **Budget Categories**:
  - Categories can have an optional monthly budget target or remain unbudgeted (tracking-only).
  - Progress bar turns emerald when on track, and red (`danger`) when spending exceeds 100% of the target.
  - Zero rollover: At payday, monthly spending resets to ₹0 for the new cycle, while cumulative history is preserved in YTD reports.

---

## 4. Sinking Funds & Savings Goals

Plan large irregular expenses (insurance, vacation, gadget purchases, tax payments) without opening separate bank accounts:

- **Logical Locking**:
  - Lock money toward a goal directly from any bank or cash account.
  - The funds remain in your real bank account earning interest, but are deducted from your dashboard usable balance.
- **Target Dates & Pacing Advice**:
  - Set an optional deadline for your goal.
  - Cashflow calculates the recommended monthly savings pace to reach your goal on time.
  - Overdue warnings appear if the target date has passed and the goal is incomplete.
- **Contribution History & Activity Modal**:
  - Tap on any goal card to inspect its contribution ledger.
  - View all lock, unlock, and payment transactions linked to the goal.
- **Goal Actions**:
  - **Lock Funds**: Add more savings to the goal.
  - **Unlock Funds**: Release locked funds back into your usable balance without moving money.
  - **Pay / Settle**: When you make the purchase, pay directly from the goal. Atomically reduces both the physical account balance and the locked allocation.
- **Celebratory Ready-to-Settle Flair**:
  - When savings reach 100% of the target, the goal card highlights with emerald accents, celebratory confetti icon, and a `🎉 Ready to Settle` badge.

---

## 5. Accounts & Inter-Account Transfers

Manage all your physical money repositories in one offline space:

- **Account Types**:
  - **Bank Accounts**: Checking, Savings, Salary accounts.
  - **Cash Wallets**: Physical cash, emergency cash stash.
- **Account Detail Breakdown**:
  - Total physical balance.
  - Funds currently locked in sinking funds.
  - Available free cash in this specific account.
- **Atomic Transfers**:
  - Move money between accounts (e.g., ATM withdrawal from Bank to Cash, or transfer between two banks).
  - Atomically updates source and destination balances in a single transaction.
  - Net physical and usable balance across the app remains identical.

---

## 6. Activity Ledger & Transaction Filtering

Inspect and edit your entire financial ledger:

- **6 Distinct Transaction Types**:
  - `expense`: Spending against an account and category.
  - `income`: Inflow into an account.
  - `transfer`: Movement between two accounts.
  - `goal_lock`: Logical reservation for a sinking fund.
  - `goal_unlock`: Release of reserved funds back to usable balance.
  - `goal_payment`: Direct settlement from a sinking fund.
- **Visual Type Badges**:
  - Color-coded badges with clear directional icons for instant recognition.
- **Date & Period Filters**:
  - Filter transactions by `This Month`, `Last Month`, `This Year`, or `All Time`.
- **Atomic Edit & Deletion**:
  - Edit transaction amount, date, account, category, or note.
  - Deleting or editing a transaction automatically rolls back and adjusts all account balances and locked allocations atomically.

---

## 7. Analytics, Trends & YTD Cashflow

Understand spending habits and track long-term net savings:

- **Category Spending Donut Chart**:
  - Interactive breakdown of current cycle expenses by category.
- **Month-over-Month Spending Trends**:
  - Multi-month comparative bar chart showing total monthly spending trajectory.
- **Net Cashflow Summary**:
  - Total Income − Total Expenses = Net Savings.
  - Positive cashflow highlighted in emerald; negative cashflow in danger red.
- **Year-to-Date (YTD) Cumulative View**:
  - View cumulative spending and income across the calendar year.

---

## 8. Settings, Data Portability & Backup

Complete privacy, control, and zero vendor lock-in:

- **100% Offline**:
  - No internet connection required. All data resides in local SQLite database on your device.
- **Backup & Portability Formats**:
  - **SQLite Binary (.db)**: Complete bit-for-bit snapshot of your database.
  - **JSON Export / Import**: Human-readable, structured data backup compatible across platforms.
  - **CSV Transactions**: Export transaction history to Excel, Google Sheets, or Numbers.
- **Backup Freshness Timestamp**:
  - Displays relative and absolute time of your last backup (e.g., *"Just now"*, *"2 hours ago"*, or *"Yesterday"*).
- **Demo Data Generator**:
  - One-tap demo population to load realistic sample accounts, budgets, goals, and multi-month transactions for exploration.
- **Reset All Data**:
  - Securely wipe and reinitialize the local database with clean defaults.

---

## 9. Offline Voice Journaling & AI Assistant

Cashflow transcends traditional expense trackers that serve merely as static logbooks or planning calculators. By embedding an **intelligent on-device AI voice system**, Cashflow eliminates the #1 friction point in personal finance: **daily manual transaction entry fatigue**.

### Why Voice AI Matters
- **The Manual Logging Trap**: Opening multiple modal forms, typing numbers on numeric keyboards, selecting accounts, and picking categories 3–5 times a day leads to journaling fatigue and neglected budgets.
- **Zero-Friction Dictation**: Speak your entire day's spending in a single conversational monologue.
- **Total Privacy Invariant**: Unlike commercial voice assistants, all speech recognition and neural entity extraction happen **100% on your device**. No audio or financial data ever touches the cloud.

### The Voice Journaling Flow
1. **Prominent Entry Point**:
   - Tap the prominent **Microphone FAB** anchored in the center of the bottom navigation bar.
2. **Natural Monologue Recording**:
   - Speak naturally: *"Paid \$12 for lunch with Chase, spent \$45 on groceries with debit, and received \$200 freelance payment into savings yesterday."*
   - Watch live audio waveforms and real-time streaming transcripts validate your input on screen.
3. **Smart Entity Grounding & Extraction**:
   - On-device neural model (SmolLM2 with GBNF grammar constraints) parses entities against your actual SQLite accounts and categories.
   - Automatically maps relative dates (*"yesterday"*, *"last Friday"*) to exact calendar dates.
   - Defaults missing accounts to your primary account with an audit flag.
4. **Interactive Review Staging Sheet**:
   - Review draft cards before saving.
   - Inferred or unassigned fields are highlighted with amber warning badges.
   - Tap inline interactive chips (**Amount**, **Account**, **Category**, **Date**) to adjust values in place.
   - Swipe away erroneous or unwanted draft cards.
5. **Atomic Batch Commit**:
   - Tap **Approve All** to insert all valid items into SQLite in a single atomic database transaction.
   - Tap **Approve Valid** to commit finished items while keeping items needing review on screen.
   - Closing the sheet discards drafts from RAM, leaving zero orphaned records in your database.
6. **Zero Audio Persistence**:
   - Temporary audio buffers are purged from disk immediately after transcription or on session cancel.

