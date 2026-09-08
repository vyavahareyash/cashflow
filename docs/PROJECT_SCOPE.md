# PROJECT_SCOPE.md

# Cashflow: Complete Project Scope

**Version:** 1.0  
**Last Updated:** 2026-09-05  
**Status:** 🟢 LOCKED & READY FOR IMPLEMENTATION

---

## 1. Product Vision

**Cashflow** is an offline-first personal finance tracker that answers the question: *"How much money do I actually have to spend right now?"*

Unlike simple expense trackers, Cashflow calculates the **true usable balance** by accounting for:
- Physical money in accounts
- Money locked for future goals (sinking funds)
- Money reserved for monthly budgets

### Core Formula (The "Magic")
```
Usable Balance = Physical Accounts 
               - Locked for Goals 
               - Reserved for Budgets
```

---

## 2. Full Feature Scope

### **A. Account Management**
| Feature | Status | Priority |
|---------|--------|----------|
| Create accounts (Bank/Cash) | ✅ DONE | P0 |
| View account list with balances | ✅ DONE | P0 |
| Edit account details | ✅ DONE | P0 |
| Delete accounts | ✅ DONE | P0 |
| Show locked & available amounts per account | 🟡 PARTIAL | P1 |

### **B. Categories & Budgeting**
| Feature | Status | Priority |
|---------|--------|----------|
| Create categories | ✅ DONE | P0 |
| Edit category details | ✅ DONE | P0 |
| Set optional monthly budgets | ❌ TODO | P0 |
| Delete categories | ✅ DONE | P0 |
| View budget consumption vs. limit | ✅ DONE | P0 |
| Monthly budget reset | ❌ TODO | P0 |
| Show over/under budget warnings | 🟡 PARTIAL | P1 |

### **C. Transaction Management**
| Feature | Status | Priority |
|---------|--------|----------|
| Log expense transactions | ✅ DONE | P0 |
| Log income transactions | ❌ TODO | P0 |
| Log transfers between accounts | ❌ TODO | P0 |
| Log goal lock transactions | ❌ TODO | P0 |
| Log goal unlock transactions | ❌ TODO | P0 |
| Log goal payment transactions | ❌ TODO | P0 |
| View transaction history | ✅ DONE | P0 |
| Filter history by period (month/year) | ❌ TODO | P1 |
| Edit transactions | ❌ TODO | P1 |
| Delete transactions | ✅ DONE | P1 |
| Show transaction type icon/badge | ❌ TODO | P1 |

### **D. Goals & Savings Planning**
| Feature | Status | Priority |
|---------|---------|----------|
| Create savings goals | ✅ DONE | P0 |
| Set goal target amount & date | ✅ DONE | P0 |
| Lock money toward goals | ✅ DONE | P0 |
| Show goal progress | ✅ DONE | P0 |
| Calculate recommended monthly contribution | ❌ TODO | P0 |
| View goal contribution history | ❌ TODO | P1 |
| Edit goal allocations | ❌ TODO | P1 |
| Mark goals as complete | ❌ TODO | P1 |
| Archive completed goals | ❌ TODO | P2 |
| Show goal unlock/release money | ❌ TODO | P1 |

### **E. Analytics & Reporting**
| Feature | Status | Priority |
|---------|--------|----------|
| Spending breakdown by category (pie/bar) | ✅ DONE | P0 |
| Monthly spending trend (line chart) | ✅ DONE | P0 |
| Budget utilization by category | ✅ DONE | P0 |
| Top spending categories | ✅ DONE | P0 |
| Goal progress visualization | ✅ DONE | P1 |
| Year-to-date spending summary | 🟡 PARTIAL | P2 |
| Spending forecasts | ❌ TODO | P3 |

### **F. Dashboard & Core Displays**
| Feature | Status | Priority |
|---------|--------|----------|
| Show usable balance (primary number) | ✅ DONE | P0 |
| Show physical balance breakdown | ✅ DONE | P0 |
| Show locked amount | ✅ DONE | P0 |
| Show reserved amount | ✅ DONE | P0 |
| Hide sensitive numbers (show/hide toggle) | 🟡 PARTIAL | P1 |
| Quick access to add transaction | ✅ DONE | P0 |
| Recent transactions widget | ✅ DONE | P1 |

### **G. Data Management**
| Feature | Status | Priority |
|---------|--------|----------|
| Export database to JSON/CSV | ❌ TODO | P1 |
| Import data from JSON/CSV | ❌ TODO | P1 |
| Backup/restore functionality | 🟡 PARTIAL | P1 |
| Data validation on import | ❌ TODO | P2 |
| Clear all data (reset) | ✅ DONE | P2 |

### **H. Settings & Customization**
| Feature | Status | Priority |
|---------|--------|----------|
| Configure salary date (for recommendations) | ❌ TODO | P2 |
| Set default currency | ❌ TODO | P2 |
| Toggle budget reset behavior | ❌ TODO | P3 |
| Dark mode | ❌ TODO | P3 |
| Decimal precision settings | ❌ TODO | P3 |

### **I. Platform Support**
| Platform | Status | Priority |
|----------|--------|----------|
| Android | 🟡 PARTIAL | P0 |
| iOS | 🟡 PARTIAL | P0 |
| Web | 🟡 PARTIAL | P0 |
| Desktop (Windows/macOS/Linux) | ❌ TODO | P3 |

---

## 3. Data Schema

### Core Tables
```
accounts (id, name, balance, type)
categories (id, name, monthly_budget [OPTIONAL])
transactions (id, account_id, destination_account_id?, category_id?, goal_id?, 
              amount, date, note, type)
goals (id, name, total_target, target_date, current_saved)
locked_allocations (id, goal_id, account_id, amount)
```

### Transaction Types Supported
- `expense` — Spending from a category
- `income` — Adding money to an account
- `transfer` — Moving money between accounts
- `goal_lock` — Locking money for a goal
- `goal_unlock` — Releasing locked money
- `goal_payment` — Paying/completing a goal

---

## 4. Technical Constraints

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| **Storage** | Local SQLite only | Privacy-first; offline-capable |
| **Sync** | None (for MVP) | Offline-first; optional in future |
| **Auth** | None | Local device, no server needed |
| **Permissions** | File system access | For backup/restore only |
| **Connectivity** | Works fully offline | No internet required |
| **Data Format** | SQLite + JSON export | Standard, portable, testable |

---

## 5. Non-Functional Requirements

| Requirement | Target |
|-------------|--------|
| **Performance** | Operations complete in <500ms; display in <2s |
| **Data Integrity** | No loss of data; ACID transactions |
| **Scalability** | Support 1000+ transactions without slowdown |
| **Reliability** | 99.9% uptime (no server dependency) |
| **Accessibility** | WCAG 2.1 AA compliance |
| **Localization** | English only (MVP); multi-language ready |
| **Testing** | 80%+ code coverage |

---

## 6. Success Metrics

### User Adoption
- [ ] First 100 downloads/installs
- [ ] 50% monthly active user rate
- [ ] <4.5 star app store rating

### Feature Adoption
- [ ] 80% of users create at least 1 goal
- [ ] 60% of users set category budgets
- [ ] 40% of users export their data

### Quality
- [ ] <1% crash rate
- [ ] <100ms average transaction latency
- [ ] Zero data loss incidents

---

## 7. Release Strategy

### **MVP (Phase 1)** — Week 1-4
- Core accounts + categories + budgeting
- Basic transactions (expense only)
- Dashboard with usable balance
- Simple analytics

### **Extended MVP (Phase 2)** — Week 5-8
- All 6 transaction types
- Goal contributions with suggestions
- Transaction history & filtering
- Budget month-end logic

### **1.0 Release (Phase 3)** — Week 9-12
- Data export/import
- Full documentation
- Polish UI/UX
- Platform releases (Android, iOS, Web)

### **Post-1.0 (Future)** — Week 13+
- Settings & customization
- Advanced analytics
- Cloud sync (optional)
- Desktop apps

---

## 8. Known Limitations & Decisions

### What Cashflow Does NOT Do (By Design)
- ❌ Connect to bank accounts (manual entry only)
- ❌ Sync to cloud (offline-only for MVP)
- ❌ Multi-user/family sharing
- ❌ Recurring transactions (create manually each time)
- ❌ Bill pay / payment scheduling
- ❌ Investing / asset tracking
- ❌ Tax calculations / reporting

### Design Decisions
| Decision | Alternative Considered | Why We Chose |
|----------|----------------------|----------------|
| Logical locking (not separate accounts) | Separate savings account per goal | Simpler UX; less account clutter |
| Tracking-only budgets (not envelope) | Envelope-style with hard limits | Real-world flexibility; less frustration |
| Monthly budget reset (not carryover) | Carryover unused budget | Simpler mental model; matches calendar |
| Local SQLite (not cloud) | Cloud-first approach | Privacy; works offline; simpler architecture |
| Manual transaction entry | Auto-fetch from bank | No API complexity; intentional tracking |

---

## 9. Out of Scope (Future Versions)

- Cloud sync & backup
- Multi-device sync
- Family/shared budgets
- Investment tracking
- Cryptocurrency
- Tax integration
- Mobile notifications
- Widgets
- Dark mode
- Multiple currencies per account

---

## 10. Glossary

| Term | Definition |
|------|-----------|
| **Usable Balance** | Money available to spend after reservations |
| **Physical Balance** | Sum of all account balances |
| **Locked Amount** | Money reserved for goals |
| **Reserved Amount** | Money allocated to category budgets |
| **Sinking Fund** | Goal for a known future expense |
| **Transaction Type** | Category of money movement (expense, income, etc.) |
| **Budget Reset** | Monthly clearing of budget tracking |
| **Goal Lock** | Reserving money from account for a goal |

---

**Next Document:** [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md)  
**Related:** [PRODUCT_SPECIFICATION.md](PRODUCT_SPECIFICATION.md) | [SCHEMA_REDESIGN.md](architecture/SCHEMA_REDESIGN.md)
