# Cashflow: Agreed Product Specification (2026-09-05)

## 🎯 Product Direction (LOCKED)

### 1. **Budget Model: Tracking-Only**
- User logs spending and Cashflow calculates actual spend vs. budget limit
- **No hard limits** — overspend is allowed with visual warnings
- Flexible, forgiving, intentional tracking (not enforcement-based)
- *Reasoning:* Real-world spending is unpredictable; strict envelopes create frustration

### 2. **Transaction Types (Minimal Complete Set)**
Cashflow will distinguish 6 transaction types:
```
1. Expense     → Spending from a category; reduces account balance
2. Income      → Money added to account; increases balance
3. Transfer    → Move money between accounts (neutral total)
4. Goal Lock   → Reserve money from account for a planned spend
5. Goal Unlock → Release reserved money back to usable balance
6. Goal Payment → Mark a locked goal as paid/complete (move to history)
```
Each transaction has: account(s), amount, date, category (if expense), notes.

### 3. **Goal Model: Logical Locking (Current)**
- Users lock money *within existing accounts* for goals
- No separate "savings account per goal" required
- Locked money is *logically reserved* in locked_allocations table
- Physical money stays in the original account
- *Reasoning:* Simpler mental model; users may not have separate accounts

### 4. **Budget Rollover: Monthly Reset**
- At month boundary: all category budgets reset to zero
- Unused budget does NOT carry over
- User sees monthly spend vs. monthly limit (fresh each month)
- Year-to-date analytics show cumulative trends separately
- *Reasoning:* Simpler, matches user expectations (calendar month = budget cycle)

### 5. **MVP Scope: FULL FEATURE SET**
All critical features for a complete, user-ready app:
- ✅ Accounts (create, read, update, delete)
- ✅ Categories (with optional budgets per issue #13)
- ✅ Monthly budget tracking
- ✅ Transactions (log, edit, delete, filter by period)
- ✅ Planned spends / savings goals
- ✅ Goal contributions with locking
- ✅ Transaction history with goal allocations visible
- ✅ Analytics (spending by category, trends, goal progress)
- ✅ Data export/import for backup
- ✅ Usable balance calculation (core "magic")

### 6. **Target Platforms: ALL EQUAL**
- **Android** (Priority 1)
- **iOS** (Priority 1)
- **Web** (Priority 1)
- Desktop may be added later if time permits

### 7. **Offline Stance: Offline-First, Optional Sync Later**
- Launch with **fully offline SQLite** (no server required)
- Architecture designed to allow optional cloud sync in future (post-MVP)
- User data never leaves device unless explicitly exported
- No authentication until sync is added

### 8. **Documentation: Both User + Internal**
- **User-facing:** Feature guides, FAQ, onboarding, calculation explanations
- **Internal:** Code docs, data model diagrams, design decisions, calculation logic
- Launch with both; prioritize user docs for first impressions

---

## 📊 Data Schema (Refined)

### Core Tables (UPDATED for v2)
```sql
accounts (id, name, balance, type)

categories (id, name, monthly_budget) 
-- budget now NULLABLE (was required)

transactions (
  id, 
  account_id, 
  destination_account_id,  -- NEW (for transfers)
  category_id,             -- NOW NULLABLE (not all txs have categories)
  plan_id,                 -- NEW (for goal txs)
  amount, 
  date, 
  note, 
  type                     -- NEW (expense|income|transfer|goal_lock|goal_unlock|goal_payment)
)

planned_spends (id, name, total_target, target_date, current_saved)

locked_allocations (id, plan_id, account_id, amount)
```

---

## 🎯 Core Formula (Locked)

```
Usable Balance = (Sum of all Accounts) 
               - (Total Locked for Goals)
               - (Total Reserved for Monthly Budgets)
```

This is the app's core "magic" — users should see this number prominently and understand how it's calculated.

---

## ✅ Consensus Summary

| Decision | Resolution | Rationale |
|----------|-----------|-----------|
| **Budget Philosophy** | Tracking-only (flexible) | Real-world spending needs flexibility; warnings > hard limits |
| **Transaction Types** | 6-type system | Covers all money movements: spend, earn, move, reserve |
| **Goal Locking** | Logical (in-account) | Simpler UX; no separate account requirements |
| **Month Boundaries** | Reset each month | Clean, predictable, user-friendly |
| **Scope** | Full feature set | Prioritize user-ready completeness |
| **Platforms** | Mobile + Web equally | Maximum reach; desktop later if capacity |
| **Data Strategy** | Offline-first, sync-ready | Privacy by default; extensible for future |
| **Docs** | Both user + internal | Support adoption + developer understanding |

---

## 📚 Related Documents

- [../PROJECT_SCOPE.md](../PROJECT_SCOPE.md) — Complete feature inventory
- [../IMPLEMENTATION_ROADMAP.md](../IMPLEMENTATION_ROADMAP.md) — Sprint plan with GitHub issues
- [../architecture/SCHEMA_REDESIGN.md](../architecture/SCHEMA_REDESIGN.md) — Database v2 design
