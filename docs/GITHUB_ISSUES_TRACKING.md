# GitHub Issues Tracking & Implementation Sequence

**Document Purpose:** Map all Cashflow features and fixes to GitHub issues in implementation order

**Last Updated:** 2026-09-05  
**Total Issues:** 44 (13 existing + 31 new)

---

## 🎯 Issue Numbering Scheme

- **#1-#13:** Existing issues (pre-planned)
- **NEW-001 to NEW-044:** New issues created per IMPLEMENTATION_ROADMAP.md
- **Labels:** `sprint-X.Y`, `P0-critical`, `P1-high`, `P2-medium`, etc.

---

## ✅ Critical Blockers (Must Complete First) 

These issues form the critical path and block all other work:

```
Sequence: #13 → #11 → NEW-001 → NEW-002 → NEW-003 → NEW-004 → #12 → #8 → #6 → #10
```

### Sprint 1.1: Database Schema v2 (Week 1)

| Issue | Title | Effort | Blocker | Created? |
|-------|-------|--------|---------|----------|
| NEW-001 | Schema v2: Add transaction type field | 1 day | YES | ❌ FAILED |
| NEW-002 | Schema v2: Add destination_account_id | 0.5 day | YES | ✅ #16 |
| NEW-003 | Schema v2: Add plan_id for goals | 0.5 day | YES | ❌ FAILED |
| NEW-004 | Schema v2: Make category budgets optional | 0.5 day | YES | ❌ FAILED |
| NEW-005 | Implement v1→v2 database migration | 1 day | YES | ✅ #15 |

### Sprint 1.2: Database Helpers & CRUD (Week 1.5)

| Issue | Title | Effort | Dependencies |
|-------|-------|--------|--------------|
| NEW-006 | Add DB helpers for 6 transaction types | 2 days | NEW-005 |
| NEW-007 | Implement transaction history with type filtering | 1 day | NEW-005 |
| NEW-008 | Add budget monthly spend calculator | 0.5 day | NEW-005 |
| NEW-009 | Implement usable balance calculation | 1 day | NEW-005 |

### Sprint 1.3: UI Fixes & Categories (Week 2)

| Issue | Title | Effort | Dependencies |
|-------|-------|--------|--------------|
| #12 | Fix show/hide button on dashboard | 1 day | NEW-009 |
| #13 | Categories without budget (make optional) | 1 day | NEW-005 |
| NEW-010 | Update category screens for optional budget | 0.5 day | #13 |

---

## 📅 Phase 1: MVP Core (Weeks 1-4)

### Sprint 1.4: Core Dashboard & Analytics

| Issue | Title | Effort | Sprint | Status |
|-------|-------|--------|--------|--------|
| NEW-011 | Update dashboard to use real usable balance | 1 day | 1.4 | 🔴 NOT CREATED |
| NEW-012 | Fix budget consumption display | 1 day | 1.4 | 🔴 NOT CREATED |
| NEW-013 | Verify all analytics charts working | 1 day | 1.4 | 🔴 NOT CREATED |

### Sprint 1.5: Testing & Polish

| Issue | Title | Effort | Sprint | Status |
|-------|-------|--------|--------|--------|
| NEW-014 | Unit tests: Database layer (v2) | 2 days | 1.5 | 🔴 NOT CREATED |
| NEW-015 | Integration tests: Dashboard calculations | 1 day | 1.5 | 🔴 NOT CREATED |
| NEW-016 | UI Polish: Dashboard & budget screens | 1 day | 1.5 | 🔴 NOT CREATED |

---

## 📅 Phase 2: Extended MVP (Weeks 5-8)

### Sprint 2.1: All Transaction Types

| Issue | Title | Effort | Sprint | Status |
|-------|-------|--------|--------|--------|
| NEW-017 | Implement income transaction flow | 1.5 days | 2.1 | 🔴 NOT CREATED |
| NEW-018 | Implement transfer transaction flow | 2 days | 2.1 | 🔴 NOT CREATED |
| NEW-019 | Implement goal lock transaction flow | 1.5 days | 2.1 | 🔴 NOT CREATED |
| NEW-020 | Implement goal unlock transaction flow | 1 day | 2.1 | 🔴 NOT CREATED |
| NEW-021 | Implement goal payment transaction flow | 1 day | 2.1 | 🔴 NOT CREATED |
| NEW-022 | Update transaction history to show all types | 1.5 days | 2.1 | 🔴 NOT CREATED |

### Sprint 2.2: Goal Contributions

| Issue | Title | Effort | Sprint | Status |
|-------|-------|--------|--------|--------|
| #10A | Calculate monthly contribution recommendation | 0.5 day | 2.2 | 🔴 NOT CREATED |
| #10B | Display recommendation in goal details | 0.5 day | 2.2 | 🔴 NOT CREATED |
| #10C | Show goal contribution history | 1 day | 2.2 | 🔴 NOT CREATED |
| NEW-023 | Allow editing goal allocations | 1.5 days | 2.2 | 🔴 NOT CREATED |
| NEW-024 | Settings: Configure salary date | 0.5 day | 2.2 | 🔴 NOT CREATED |

### Sprint 2.3: Transaction History & Filtering

| Issue | Title | Effort | Sprint | Status |
|-------|-------|--------|--------|--------|
| #8A | Enable transaction edit | 2 days | 2.3 | 🔴 NOT CREATED |
| #8B | Enable transaction delete | 0.5 day | 2.3 | 🔴 NOT CREATED |
| #8C | Add period filtering (month/year) | 1 day | 2.3 | 🔴 NOT CREATED |
| NEW-025 | Show totals per filtered period | 0.5 day | 2.3 | 🔴 NOT CREATED |
| #6 | Show goal locks in transaction history | 1 day | 2.3 | 🔴 EXISTING |

### Sprint 2.4: Month-End Logic & Budget Reset

| Issue | Title | Effort | Sprint | Status |
|-------|-------|--------|--------|--------|
| #11 | Implement monthly budget reset logic | 1 day | 2.4 | 🔴 EXISTING |
| NEW-026 | Show over/under budget warnings | 1 day | 2.4 | 🔴 NOT CREATED |
| NEW-027 | Year-to-date analytics tracking | 1 day | 2.4 | 🔴 NOT CREATED |
| NEW-028 | Handle edge cases (month transitions) | 1 day | 2.4 | 🔴 NOT CREATED |

---

## 📅 Phase 3: 1.0 Release (Weeks 9-12)

### Sprint 3.1: Data Export/Import

| Issue | Title | Effort | Sprint | Status |
|-------|-------|--------|--------|--------|
| NEW-029 | Implement data export to JSON | 1.5 days | 3.1 | 🔴 NOT CREATED |
| NEW-030 | Implement data export to CSV | 1 day | 3.1 | 🔴 NOT CREATED |
| NEW-031 | Implement data import from JSON | 1.5 days | 3.1 | 🔴 NOT CREATED |
| NEW-032 | Implement data import from CSV | 1 day | 3.1 | 🔴 NOT CREATED |
| NEW-033 | Data validation on import | 1 day | 3.1 | 🔴 NOT CREATED |

### Sprint 3.2: Documentation

| Issue | Title | Effort | Sprint | Status |
|-------|-------|--------|--------|--------|
| #9A | User documentation | 3 days | 3.2 | 🔴 EXISTING |
| #9B | Developer documentation | 2 days | 3.2 | 🔴 EXISTING |
| NEW-034 | Video tutorials (optional) | 2 days | 3.2 | 🔴 NOT CREATED |
| NEW-035 | Update README | 1 day | 3.2 | 🔴 NOT CREATED |

### Sprint 3.3: UI Polish & UX

| Issue | Title | Effort | Sprint | Status |
|-------|-------|--------|--------|--------|
| #7 | Improve locked funds display in accounts | 1.5 days | 3.3 | 🔴 EXISTING |
| NEW-036 | Consistent spacing & alignment | 1 day | 3.3 | 🔴 NOT CREATED |
| NEW-037 | Error handling & user feedback | 1.5 days | 3.3 | 🔴 NOT CREATED |
| NEW-038 | Accessibility audit | 1 day | 3.3 | 🔴 NOT CREATED |
| NEW-039 | Performance optimization | 1 day | 3.3 | 🔴 NOT CREATED |

### Sprint 3.4: Platform Releases

| Issue | Title | Effort | Sprint | Status |
|-------|-------|--------|--------|--------|
| NEW-040 | Android release build & optimization | 2 days | 3.4 | 🔴 NOT CREATED |
| NEW-041 | iOS release build & optimization | 2 days | 3.4 | 🔴 NOT CREATED |
| NEW-042 | Web deployment & testing | 1 day | 3.4 | 🔴 NOT CREATED |
| NEW-043 | Final end-to-end testing | 2 days | 3.4 | 🔴 NOT CREATED |
| NEW-044 | App store submissions | 1 day | 3.4 | 🔴 NOT CREATED |

---

## 🔗 Issue Dependencies Graph

```
NEW-001 (type field)
  ├─→ NEW-004 (models)
  │     ├─→ NEW-006 (DB helpers)
  │     │     ├─→ NEW-017..021 (All Tx Types)
  │     │     ├─→ NEW-007 (History)
  │     │     └─→ NEW-022 (Show in UI)
  │     └─→ NEW-007 (History queries)
  │           ├─→ #8 (Edit/Delete)
  │           └─→ #6 (Show goals)
  │
  ├─→ NEW-002 (nullable budget)
  │     └─→ #13 (UI for optional budget)
  │
  ├─→ NEW-003 (Migration)
  │     └─→ NEW-008 (Budget calculator)
  │           └─→ NEW-012 (Dashboard)
  │                 └─→ #12 (Show/hide)
  │
  ├─→ NEW-009 (Usable balance)
  │     └─→ NEW-011 (Dashboard)
  │           └─→ NEW-026 (Warnings)
  │
  └─→ #11 (Budget reset)
        └─→ NEW-027 (YTD tracking)
             └─→ NEW-028 (Edge cases)
```

---

## 📊 Summary Statistics

| Category | Count | Effort |
|----------|-------|--------|
| Existing Issues | 13 | ~20 days |
| New Issues (Phase 1) | 16 | ~16 days |
| New Issues (Phase 2) | 20 | ~24 days |
| New Issues (Phase 3) | 12 | ~20 days |
| **TOTAL** | **44** | **~80 days** |

### By Priority
- **P0-Critical:** 5 issues (weeks 1-2)
- **P1-High:** 20 issues (weeks 3-8)
- **P2-Medium:** 15 issues (weeks 9-12)
- **P3-Low:** 4 issues (post-release)

### By Sprint
- **Sprint 1.1:** 5 issues (5 days)
- **Sprint 1.2:** 4 issues (5 days)
- **Sprint 1.3:** 3 issues (2.5 days)
- **Sprint 1.4:** 3 issues (3 days)
- **Sprint 1.5:** 3 issues (4 days)
- **Sprints 2-3:** 23 issues (60+ days)

---

## GitHub Labels Used

| Label | Purpose |
|-------|---------|
| `P0-critical` | Must complete before moving forward; unblocks multiple features |
| `P1-high` | Important; completes a major feature set |
| `P2-medium` | Nice-to-have; polish and enhancement |
| `P3-low` | Post-MVP; backlog |
| `sprint-1.1` | Sprint assignment (X.Y) |
| `schema` | Database changes |
| `models` | Data model changes |
| `database` | Database operations |
| `UI` | User interface |
| `testing` | QA and tests |
| `documentation` | Docs and guides |

---

## ⚙️ GitHub Workflow

1. **Creation:** Issues created with detailed acceptance criteria
2. **Labeling:** Sprint, priority, and category labels assigned
3. **Ordering:** Numbered in dependency/implementation order
4. **Linking:** Dependencies documented in issue bodies
5. **Tracking:** Status updated as work progresses

---

## 📋 How to Use This Document

**For Developers:**
- Use "Sequence" to know what to build next
- Use "Dependencies" to understand blockers
- Use "Sprint" to plan your week

**For Project Managers:**
- Use "Summary Statistics" for timeline estimates
- Use "Dependencies Graph" to spot risks
- Use "GitHub Labels" to track progress

**For Stakeholders:**
- Use "Phase" breakdown to see feature releases
- Use "Priority" to understand criticality
- Use "Effort" to estimate delivery dates

---

## 🚀 Next Steps

1. **Immediately:** Create remaining NEW-* issues in GitHub
2. **This week:** Start Sprint 1.1 (schema v2)
3. **Track:** Update issue status weekly
4. **Adjust:** Reprioritize based on blockers/progress
5. **Release:** Track Phase completions

---

**Related Documents:**
- [docs/PROJECT_SCOPE.md](docs/PROJECT_SCOPE.md) — Feature inventory
- [docs/IMPLEMENTATION_ROADMAP.md](docs/IMPLEMENTATION_ROADMAP.md) — Detailed plan
- [docs/PRODUCT_SPECIFICATION.md](docs/PRODUCT_SPECIFICATION.md) — Product decisions
