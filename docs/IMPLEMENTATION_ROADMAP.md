# IMPLEMENTATION_ROADMAP.md

# Cashflow: Implementation Roadmap & GitHub Issues Map

**Version:** 1.0  
**Timeline:** 12 weeks (3 phases)  
**Last Updated:** 2026-09-05  
**Status:** 🟢 READY FOR SPRINT PLANNING

---

## Overview: 3-Phase Delivery

```
Phase 1 (Weeks 1-4)     Phase 2 (Weeks 5-8)      Phase 3 (Weeks 9-12)
MVP Core               Extended MVP              1.0 Release
├─ Accounts            ├─ All Tx Types          ├─ Data Export/Import
├─ Categories          ├─ Goal Suggestions      ├─ Full Documentation
├─ Expenses            ├─ Tx Filtering          ├─ UI Polish
├─ Dashboard           ├─ Month-end Logic       ├─ Platform Releases
└─ Basic Analytics     └─ Goal History          └─ Production Ready
```

---

## PHASE 1: MVP Core (Weeks 1-4)

### Sprint 1.1: Foundation & Schema (Week 1)

**Goal:** Database v2 + models ready; unblocks all feature work

| Issue # | Title | Scope | Effort | Status |
|---------|-------|-------|--------|--------|
| NEW-001 | Schema v2: Add transaction type field | Add `type` field to transactions; add `destination_account_id`, `goal_id` | 1 day | ✅ DONE |
| NEW-002 | Schema v2: Make category budgets optional | Change `monthly_budget` to nullable | 0.5 day | ✅ DONE |
| NEW-003 | Implement v1→v2 database migration | Auto-migration for existing users | 1 day | ✅ DONE |
| NEW-004 | Update TransactionModel with 6 types | Dart model + toMap/fromMap | 0.5 day | ✅ DONE |
| NEW-005 | Update Category model (optional budget) | Dart model + nullable monthlyBudget | 0.5 day | ✅ DONE |

**Deliverable:** Database v2, models ready, migrations tested

---

### Sprint 1.2: Database Helpers & CRUD (Week 1.5)

**Goal:** Database layer supports all transaction types and operations

| Issue # | Title | Scope | Effort | Status |
|---------|-------|-------|--------|--------|
| NEW-006 | Add DB helpers for 6 transaction types | createExpenseTransaction(), createIncomeTransaction(), etc. | 2 days | 🔴 NOT STARTED |
| NEW-007 | Implement transaction history with type filtering | Query joins transactions + accounts + categories + goals | 1 day | 🔴 NOT STARTED |
| NEW-008 | Add budget monthly spend calculator | Query: sum(transactions) by category for current month | 0.5 day | 🔴 NOT STARTED |
| NEW-009 | Implement usable balance calculation | Formula: accounts - locked - reserved | 1 day | 🔴 NOT STARTED |

**Deliverable:** All database operations working; testable via unit tests

---

### Sprint 1.3: UI Fix & Categories (Week 2)

**Goal:** Fix outstanding UI bugs; complete category feature

| Issue # | Title | Scope | Effort | Status |
|---------|-------|-------|--------|--------|
| #12 | Fix show/hide button on dashboard | Ensure all numbers hidden when toggled | 1 day | 🟡 IN PROGRESS |
| #13 | Categories without budget (make optional) | UI for category creation/edit without budget | 1 day | 🔴 NOT STARTED |
| NEW-010 | Update category screens for optional budget | Edit/create UI validation | 0.5 day | 🔴 NOT STARTED |

**Deliverable:** Dashboard toggle works; categories can be created without budgets

---

### Sprint 1.4: Core Dashboard & Analytics (Week 2-3)

**Goal:** Dashboard shows correct numbers; basic charts working

| Issue # | Title | Scope | Effort | Status |
|---------|-------|-------|--------|--------|
| NEW-011 | Update dashboard to use real usable balance | Wire up calculation; show physical/locked/reserved breakdown | 1 day | 🔴 NOT STARTED |
| NEW-012 | Fix budget consumption display | Real data from transactions; visual % indicator | 1 day | 🔴 NOT STARTED |
| NEW-013 | Verify all analytics charts working | Category spending, trends, goal progress | 1 day | 🔴 NOT STARTED |

**Deliverable:** Dashboard is source of truth; all numbers accurate

---

### Sprint 1.5: Testing & Polish (Week 3-4)

**Goal:** Phase 1 features stable and ready for users

| Issue # | Title | Scope | Effort | Status |
|---------|-------|-------|--------|--------|
| NEW-014 | Unit tests: Database layer (v2) | Test CRUD, migrations, calculations | 2 days | 🔴 NOT STARTED |
| NEW-015 | Integration tests: Dashboard calculations | Test formulas with sample data | 1 day | 🔴 NOT STARTED |
| NEW-016 | UI Polish: Dashboard & budget screens | Visual refinement, spacing, colors | 1 day | 🔴 NOT STARTED |

**Deliverable:** Phase 1 MVP complete; 70%+ test coverage

**Phase 1 Acceptance Criteria:**
- ✅ Database v2 deployed with migrations
- ✅ Dashboard shows correct usable balance
- ✅ Categories optional (no forced budgets)
- ✅ All budget tracking real-time accurate
- ✅ Basic analytics functional
- ✅ No critical bugs

---

## PHASE 2: Extended MVP (Weeks 5-8)

### Sprint 2.1: All Transaction Types (Week 5)

**Goal:** Users can log all 6 transaction types; transactions visible in history

| Issue # | Title | Scope | Effort | Status |
|---------|-------|-------|--------|--------|
| NEW-017 | Implement income transaction flow | Create screen, DB helper, validation | 1.5 days | 🔴 NOT STARTED |
| NEW-018 | Implement transfer transaction flow | Create screen, dual-account update, DB helper | 2 days | 🔴 NOT STARTED |
| NEW-019 | Implement goal lock transaction flow | Create screen, goal selection, locked_allocations + transactions | 1.5 days | 🔴 NOT STARTED |
| NEW-020 | Implement goal unlock transaction flow | Modal/screen for releasing locked money | 1 day | 🔴 NOT STARTED |
| NEW-021 | Implement goal payment transaction flow | Mark goal as complete, archive | 1 day | 🔴 NOT STARTED |
| NEW-022 | Update transaction history to show all types | Display type badges; show accounts for transfers | 1.5 days | 🔴 NOT STARTED |

**Deliverable:** All 6 transaction types fully functional with UI

---

### Sprint 2.2: Goal Contributions & Suggestions (Week 5-6)

**Goal:** Users see recommended monthly contributions; can track goal progress

| Issue # | Title | Scope | Effort | Status |
|---------|-------|-------|--------|--------|
| #10 (Part A) | Calculate monthly contribution recommendation | Formula: (target - current) / months_left | 0.5 day | 🔴 NOT STARTED |
| #10 (Part B) | Display recommendation in goal details | Show on goals screen | 0.5 day | 🔴 NOT STARTED |
| #10 (Part C) | Show goal contribution history | List of goal_lock transactions for this goal | 1 day | 🔴 NOT STARTED |
| NEW-023 | Allow editing goal allocations | Modify locked amounts, unwind locks | 1.5 days | 🔴 NOT STARTED |
| NEW-024 | Settings: Configure salary date | For contribution recommendation accuracy | 0.5 day | 🔴 NOT STARTED |

**Deliverable:** Goal planning complete; recommendations shown

---

### Sprint 2.3: Transaction History & Filtering (Week 6-7)

**Goal:** Users can navigate transaction history; see full details per transaction

| Issue # | Title | Scope | Effort | Status |
|---------|-------|-------|--------|--------|
| #8 (Part A) | Enable transaction edit | Update amount, date, category, note; refund changes | 2 days | 🔴 NOT STARTED |
| #8 (Part B) | Enable transaction delete | Delete transaction; refund to account | 0.5 day | 🔴 NOT STARTED |
| #8 (Part C) | Add period filtering (month/year) | Filter UI; query by date range | 1 day | 🔴 NOT STARTED |
| NEW-025 | Show totals per filtered period | Sum of all transactions in selected period | 0.5 day | 🔴 NOT STARTED |
| #6 | Show goal locks in transaction history | goal_lock txs appear with goal details | 1 day | 🔴 NOT STARTED |

**Deliverable:** Full transaction ledger accessible; editable/deletable

---

### Sprint 2.4: Month-End Logic & Budget Reset (Week 7-8)

**Goal:** Budgets reset monthly; system ready for recurring cycles

| Issue # | Title | Scope | Effort | Status |
|---------|-------|-------|--------|--------|
| #11 | Implement monthly budget reset logic | Automated reset at month boundary | 1 day | 🔴 NOT STARTED |
| NEW-026 | Show over/under budget warnings | Visual indicators when spending > limit | 1 day | 🔴 NOT STARTED |
| NEW-027 | Year-to-date analytics tracking | Cumulative view separate from monthly | 1 day | 🔴 NOT STARTED |
| NEW-028 | Handle edge cases (month transitions) | Ensure no data loss; accurate calculations | 1 day | 🔴 NOT STARTED |

**Deliverable:** Budget cycles work correctly; no edge case bugs

**Phase 2 Acceptance Criteria:**
- ✅ All 6 transaction types implemented
- ✅ Goal contributions trackable with history
- ✅ Transaction editing & deletion working
- ✅ Period filtering functional
- ✅ Monthly budget resets properly
- ✅ No regression from Phase 1
- ✅ 80%+ test coverage

---

## PHASE 3: 1.0 Release (Weeks 9-12)

### Sprint 3.1: Data Export/Import (Week 9)

**Goal:** Users can backup and restore their data

| Issue # | Title | Scope | Effort | Status |
|---------|-------|-------|--------|--------|
| NEW-029 | Implement data export to JSON | Full database dump in portable format | 1.5 days | 🔴 NOT STARTED |
| NEW-030 | Implement data export to CSV | Transactions + accounts + goals in CSV format | 1 day | 🔴 NOT STARTED |
| NEW-031 | Implement data import from JSON | Parse, validate, import into database | 1.5 days | 🔴 NOT STARTED |
| NEW-032 | Implement data import from CSV | Parse CSV; handle validation errors | 1 day | 🔴 NOT STARTED |
| NEW-033 | Data validation on import | Check referential integrity; warn of issues | 1 day | 🔴 NOT STARTED |

**Deliverable:** Full data portability; users can backup anytime

---

### Sprint 3.2: Documentation (Week 10)

**Goal:** Comprehensive user + developer docs

| Issue # | Title | Scope | Effort | Status |
|---------|-------|-------|--------|--------|
| #9 (Part A) | User documentation | Feature guides, FAQs, onboarding | 3 days | 🔴 NOT STARTED |
| #9 (Part B) | Developer documentation | Architecture, data model, calculation logic | 2 days | 🔴 NOT STARTED |
| NEW-034 | Video tutorials (optional) | 3-5 short videos for core workflows | 2 days | 🔴 NOT STARTED |
| NEW-035 | Update README | Attractive project description, motivation, features | 1 day | 🔴 NOT STARTED |

**Deliverable:** Complete docs; users self-sufficient

---

### Sprint 3.3: UI Polish & UX (Week 10-11)

**Goal:** App feels production-ready; consistent design

| Issue # | Title | Scope | Effort | Status |
|---------|-------|-------|--------|--------|
| #7 | Improve locked funds display in accounts | Dropdown/aggregation; show goal totals; add thousand separators | 1.5 days | 🔴 NOT STARTED |
| NEW-036 | Consistent spacing & alignment | Review all screens for visual harmony | 1 day | 🔴 NOT STARTED |
| NEW-037 | Error handling & user feedback | Toast messages, error dialogs, validation | 1.5 days | 🔴 NOT STARTED |
| NEW-038 | Accessibility audit | WCAG 2.1 AA compliance check | 1 day | 🔴 NOT STARTED |
| NEW-039 | Performance optimization | Reduce animation lag, optimize queries | 1 day | 🔴 NOT STARTED |

**Deliverable:** Polished, accessible, performant app

---

### Sprint 3.4: Platform Releases & Launch (Week 11-12)

**Goal:** App ready for app stores; production deployment

| Issue # | Title | Scope | Effort | Status |
|---------|-------|-------|--------|--------|
| NEW-040 | Android release build & optimization | Build APK; test on real devices; optimize APK size | 2 days | 🔴 NOT STARTED |
| NEW-041 | iOS release build & optimization | Build IPA; test on real devices; certificates | 2 days | 🔴 NOT STARTED |
| NEW-042 | Web deployment & testing | Build web version; test on browsers; deploy to hosting | 1 day | 🔴 NOT STARTED |
| NEW-043 | Final end-to-end testing | Full QA on all platforms; bug fixes | 2 days | 🔴 NOT STARTED |
| NEW-044 | App store submissions | Google Play, Apple App Store, web launch | 1 day | 🔴 NOT STARTED |

**Deliverable:** v1.0 released on all platforms

**Phase 3 Acceptance Criteria:**
- ✅ Data export/import fully functional
- ✅ Complete documentation available
- ✅ UI/UX polished & accessible
- ✅ 80%+ test coverage
- ✅ All platforms tested & released
- ✅ <4.5 star rating on app stores
- ✅ Zero critical bugs

---

## GitHub Issues Mapping

### Critical Blockers (Must Complete First)
```
Sequence: #13 → #11 → NEW-001 → NEW-002 → NEW-003 → #12 → #8 → #6 → #10
```

| Priority | GitHub Issue | Epic | Sprint | Blockers |
|----------|--------------|------|--------|----------|
| **CRITICAL** | NEW-001 | Schema v2 | 1.1 | None |
| **CRITICAL** | NEW-002 | Schema v2 | 1.1 | NEW-001 |
| **CRITICAL** | NEW-003 | Schema v2 | 1.1 | NEW-001, NEW-002 |
| **CRITICAL** | #13 | Categories | 1.3 | NEW-005 |
| **CRITICAL** | #11 | Budget Logic | 2.4 | NEW-008 |
| **HIGH** | #12 | Dashboard | 1.3 | NEW-011 |
| **HIGH** | #8 | Transactions | 2.3 | NEW-007 |
| **HIGH** | #6 | Goals | 2.3 | NEW-007, NEW-019 |
| **HIGH** | #10 | Goals | 2.2 | NEW-009 |
| **HIGH** | #9 | Documentation | 3.2 | All above |
| **MEDIUM** | #7 | Accounts UI | 3.3 | All above |

---

## Issue Dependencies Graph

```
NEW-001 (type field)
  ├─→ NEW-004 (TransactionModel)
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
  │                 └─→ #12 (Show/hide toggle)
  │
  ├─→ NEW-009 (Usable balance)
  │     └─→ NEW-011 (Dashboard calculation)
  │           └─→ NEW-026 (Warnings)
  │
  └─→ #11 (Budget reset)
        └─→ NEW-027 (YTD tracking)
             └─→ NEW-028 (Edge cases)
```

---

## Resource Allocation

### Team Size: 1 Full-Time Developer + AI Assistant

| Phase | Duration | Dev Weeks | AI Weeks | Overlap |
|-------|----------|-----------|----------|---------|
| Phase 1 | 4 weeks | 4 | 3 | High (planning, reviews) |
| Phase 2 | 4 weeks | 4 | 2.5 | Medium (implementation) |
| Phase 3 | 4 weeks | 4 | 2 | Medium (docs, testing) |
| **Total** | **12 weeks** | **12** | **7.5** | |

### Recommended Schedule
- **Monday-Wednesday:** Feature implementation
- **Wednesday-Friday:** Testing, reviews, documentation
- **Weekly sync:** Review blockers, adjust priorities

---

## Success Criteria per Phase

### Phase 1
- [ ] No critical bugs
- [ ] All core features usable
- [ ] Database migrations tested
- [ ] 70%+ test coverage

### Phase 2
- [ ] All transaction types working
- [ ] Goal planning complete
- [ ] Transaction history editable
- [ ] 80%+ test coverage

### Phase 3
- [ ] Data export/import working
- [ ] Docs complete
- [ ] UI polished
- [ ] Published on app stores
- [ ] 4.5+ star rating (target)

---

## Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Database migration fails | Medium | High | Test migrations early; backup strategy |
| UI regression from schema changes | Medium | Medium | Comprehensive testing; gradual rollout |
| Performance issues at scale | Low | Medium | Optimize queries; test with 1000+ records |
| Platform build issues | Medium | High | Test builds early; document process |
| Scope creep on features | High | High | Strict issue tracking; no new features mid-sprint |

---

## Sign-Off

**Product Owner:** [To be filled]  
**Tech Lead:** [To be filled]  
**Sprint Start Date:** [To be determined]  
**Expected MVP Date:** Week 4 (4 weeks from start)  
**Expected 1.0 Date:** Week 12 (12 weeks from start)

---

**Related Documents:**
- [PROJECT_SCOPE.md](PROJECT_SCOPE.md) — Feature breakdown
- [PRODUCT_SPECIFICATION.md](PRODUCT_SPECIFICATION.md) — Product decisions
- [SCHEMA_REDESIGN.md](../architecture/SCHEMA_REDESIGN.md) — Database design
