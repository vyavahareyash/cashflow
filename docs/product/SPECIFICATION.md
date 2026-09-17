# Cashflow Product Specification

Authoritative behavioral specifications, product boundaries, and business rules for Cashflow.

---

## 1. Product Vision & Philosophy

**Cashflow** is a private, offline-first personal finance application that answers one practical question:
> *"How much money can I actually spend right now without sabotaging my future bills or goals?"*

Unlike conventional expense trackers, Cashflow differentiates physical cash holdings from committed logical reserves.

### Core Formula (The Safe-to-Spend Balance)

$$\text{Usable Balance} = \max\left(\sum \text{Physical Account Balances} - \sum \text{Locked Goal Allocations},\, 0.0\right)$$

- **Physical Accounts**: Real balances across bank, cash, and wallet accounts.
- **Locked Goal Allocations**: Virtual envelope reserves earmarked for specific savings targets (sinking funds).
- **Category Budgets**: Flexible tracking and pacing limits. Budgets do not deduct cash in advance; spending reduces balance when it actually occurs.

---

## 2. Minimal Complete Transaction System

Cashflow supports six distinct transaction types:

| Type | Balance Impact | Category Required | Destination Account | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Expense** | Deducts from source | Yes | No | Direct spending |
| **Income** | Credits source | No | No | Earnings or deposits |
| **Transfer** | Neutral (dual-entry) | No | Yes | Inter-account fund movement |
| **Goal Lock** | Physical neutral; increases locked | No | No | Commits cash toward a goal envelope |
| **Goal Unlock** | Physical neutral; decreases locked | No | No | Releases reserved cash back to usable |
| **Goal Payment**| Deducts physical & locked | No | No | Settles expense directly from saved goal |

---

## 3. Feature Inventory & Current Status

### A. Account Management
- [x] Create bank, cash, or wallet accounts with starting balances
- [x] View account list with real-time physical balances
- [x] Edit account details (name, balance adjustments)
- [x] Delete accounts (with referential integrity validation)
- [x] Atomic inter-account transfers

### B. Categories & Budgeting
- [x] Create and edit custom categories with icons and color themes
- [x] Optional monthly budget caps per category
- [x] Configurable payday cycle start day (Day 1–31)
- [x] Daily Burn Pace indicator (sustainable daily spend velocity)
- [x] Visual overspend warnings without blocking transactions

### C. Savings Goals & Sinking Funds
- [x] Create savings goals with target amount and target completion date
- [x] Logical fund locking from existing accounts (no separate bank account required)
- [x] Progress visualization and recommended monthly savings velocity
- [x] Celebratory flair on goal achievement
- [x] Releasing locked funds back to usable balance

### D. Security & Privacy
- [x] 100% offline local SQLite storage (`cashflow.db`)
- [x] Zero network requests, zero tracking, zero analytics
- [x] Quick-toggle Privacy Mode to mask numerical balances (`$••••••`)
- [x] Portable JSON and raw SQLite database backup/restore

---

## 4. Platform Availability

- **Android**: First-class support with native APK builds
- **Web**: Progressive Web Application build
- **iOS / macOS / Desktop**: Cross-platform support via Flutter engine
