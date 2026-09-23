# Voice AI Journaling: Manual Testing Scripts (Indian Context)

This document provides ready-to-read spoken test scripts tailored to Indian financial workflows (UPI, HDFC, SBI, Blinkit, Swiggy, Zepto, Chai, Metro). Use these scenarios to manually verify multi-transaction parsing, contextual note generation, relative date math, and edge-case performance.

---

## Prerequisites & Setup

1. Open **Settings & Data** > **Data Management**.
2. Tap **Populate Sample Data** (seeds `Salary Account (HDFC)`, `Emergency Savings (SBI)`, `Cash Wallet`, and Indian expense categories).
3. Ensure the Offline AI Model Pack (~270 MB) is downloaded via **Settings** > **Voice AI & Offline Models** (or tap the microphone icon on the dashboard).
4. Tap the central **Microphone FAB** on the bottom navigation bar to launch the voice recording modal.

---

## Test Scenarios & Spoken Scripts

### Scenario 1: Standard Daily Multi-Transaction (Chai + Groceries + Salary)
Tests multi-transaction isolation, merchant extraction, and income classification.

- **Spoken Script (Read Aloud)**:
  > *"Paid 20 rupees for chai on UPI, bought 450 rupees of groceries from Blinkit using HDFC, and received 75000 salary into HDFC yesterday."*

- **Expected Draft Cards**:
  | # | Type | Amount | Account | Category | Date | Contextual Note |
  |---|---|---|---|---|---|---|
  | 1 | Expense | ₹20.00 | HDFC (or Primary) | Dining Out | Today | `Chai` |
  | 2 | Expense | ₹450.00 | Salary Account (HDFC) | Groceries | Today | `Groceries from Blinkit` |
  | 3 | Income | ₹75,000.00 | Salary Account (HDFC) | *None* | Yesterday | `Salary` |

- **Verification Points**:
  - `note` contains only clean item/merchant descriptions (no amounts, no `"rupees"`, no verbs like `"paid"` or `"bought"`).
  - Draft 1 and Draft 2 notes do not bleed into each other.
  - Card 3 is classified as **Income** with yesterday's calendar date.

---

### Scenario 2: Inter-Account Transfer & Food Delivery
Tests standardized transfer note formatting and merchant title casing.

- **Spoken Script (Read Aloud)**:
  > *"Moved 15000 from HDFC to SBI yesterday, and paid 650 on Swiggy for dinner using HDFC today."*

- **Expected Draft Cards**:
  | # | Type | Amount | Source Account | Dest Account | Category | Contextual Note |
  |---|---|---|---|---|---|---|
  | 1 | Transfer | ₹15,000.00 | Salary Account (HDFC) | Emergency Savings (SBI) | *N/A* | `Transfer: Salary Account (HDFC) → Emergency Savings (SBI)` |
  | 2 | Expense | ₹650.00 | Salary Account (HDFC) | *N/A* | Dining Out | `Dinner on Swiggy` |

- **Verification Points**:
  - Transfer card has both Source and Destination chips assigned without warning badges.
  - Transfer note is cleanly standardized with arrow notation (`→`).
  - Swiggy dinner expense is mapped to `Dining Out`.

---

### Scenario 3: Commute & Utilities (Category Fallback)
Tests category name fallback when no specific merchant brand is spoken.

- **Spoken Script (Read Aloud)**:
  > *"Spent 250 on metro recharge with card, and paid 1800 for electricity bill yesterday on HDFC."*

- **Expected Draft Cards**:
  | # | Type | Amount | Account | Category | Date | Contextual Note |
  |---|---|---|---|---|---|---|
  | 1 | Expense | ₹250.00 | Salary Account (HDFC) | Transport & Fuel | Today | `Metro Recharge` |
  | 2 | Expense | ₹1,800.00 | Salary Account (HDFC) | Utilities & Bills | Yesterday | `Electricity Bill` |

- **Verification Points**:
  - Payment method phrases (*"with card"*, *"on HDFC"*) are excluded from notes.
  - Dates resolve deterministically (*"yesterday"* maps to previous calendar day).

---

### Scenario 4: Rapid 5-Clause Stress & Performance Monologue
Tests continuous rapid dictation, comma/connector parsing, memory stability, and latency.

- **Spoken Script (Read Aloud without pausing)**:
  > *"Chai 20 rupees on UPI, 120 for auto rickshaw with cash, 450 on Zepto groceries, moved 5000 from HDFC to SBI, and received 12000 freelance payment into HDFC yesterday."*

- **Expected Draft Cards**:
  1. `Chai` — Expense, ₹20.00, Dining Out
  2. `Auto Rickshaw` — Expense, ₹120.00, Cash Wallet, Transport
  3. `Zepto Groceries` — Expense, ₹450.00, HDFC, Groceries
  4. `Transfer: Salary Account (HDFC) → Emergency Savings (SBI)` — Transfer, ₹5,000.00
  5. `Freelance Payment` — Income, ₹12,000.00, HDFC, Yesterday

- **Performance Benchmarks to Validate**:
  - **Inference Latency**: All 5 drafts parsed and staged within ≤1.5s on modern ARM hardware.
  - **RAM Headroom**: Peak SLM inference consumes ≤350 MB; app experiences zero frame stutters or out-of-memory kills.
  - **Zero Audio Persistence**: Temporary WAV audio is purged immediately upon staging sheet display.

---

### Scenario 5: Colloquial Phrasing & Slang Stripping
Tests resilience against informal currency words, mixed casing, and generic payment fillers.

- **Spoken Script (Read Aloud)**:
  > *"Spent 40 bucks on coffee at Blue Tokai with HDFC, 850 for medicine at Apollo Pharmacy, and 100 in cash for parking."*

- **Expected Draft Cards**:
  | # | Type | Amount | Account | Category | Contextual Note |
  |---|---|---|---|---|---|
  | 1 | Expense | ₹40.00 | HDFC | Dining Out | `Coffee at Blue Tokai` |
  | 2 | Expense | ₹850.00 | HDFC | Health & Medical | `Medicine at Apollo Pharmacy` |
  | 3 | Expense | ₹100.00 | Cash Wallet | Transport & Fuel | `Parking` |

- **Verification Points**:
  - Slang units (*"bucks"*) are correctly parsed as monetary value and stripped from the note.
  - Cash payment method routes account chip to `Cash Wallet`.
  - Brand names (*"Blue Tokai"*, *"Apollo Pharmacy"*) retain proper Title Casing.

---

## Staging Sheet Review & Commit Checklist

When validating drafts in the **Voice Transaction Staging Sheet**:
- [ ] **Note Title**: Inspect the bold title of each card. Ensure it displays concise item/merchant context rather than the raw transcription.
- [ ] **Warning Badges**: Verify unassigned fields (e.g. unknown accounts or categories) show orange audit badges.
- [ ] **Inline Editing**: Tap any chip (**Amount**, **Account**, **Category**, **Date**) to verify in-place bottom sheet updates.
- [ ] **Approve All**: Tap "Approve All" to commit all drafts into SQLite in a single atomic transaction.
- [ ] **Ledger Refresh**: Verify all committed transactions appear immediately on the Dashboard and Activity Ledger.
