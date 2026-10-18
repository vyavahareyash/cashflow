# Cashflow: Comprehensive App Design & Functionality Context for Stitch AI

> **Authoritative Specification & Screen Inventory for UI/UX Redesign**  
> *Targeted for Google Stitch AI (Text-to-UI, Sketch/Image-to-UI, Design Systems, and Prototyping Flows)*

---

## 1. Executive Summary & Recommended Strategy for Stitch AI

When redesigning an offline-first financial application with an AI design tool like **Google Stitch AI**, passing raw code or vague descriptions often leads to generic, non-functional banking templates. Stitch AI performs best when fed:
1. **Design System & Global Tokens first**: Color hierarchy, elevation, border-radii, typography, and core navigation shell.
2. **Screen-by-Screen Micro-Specifications**: Distinct cards, inputs (types, labels, default placeholders, validations), action controls (toggles, chips, buttons), and dynamic feedback badges.
3. **Visual Image-to-UI References**: Cashflow includes **43 verified high-resolution screenshots** in [`screenshots/`](../../screenshots) mapped by [`screenshots/manifest.json`](../../screenshots/manifest.json). Uploading these existing screens directly into Stitch AI's image prompt box allows Stitch to recognize layout semantics instantly and iterate on modern visual styles while preserving 100% of the functional controls.

---

## 2. Core Architectural & Financial Domain Invariants

Stitch AI must adhere to Cashflow's core product philosophy to avoid generating misleading financial controls:

- **100% Local & Offline**: Cashflow has zero cloud backend, zero login/signup screens, and zero remote telemetry ([`AGENTS.md`](../../AGENTS.md), [`docs/engineering/ARCHITECTURE.md`](../engineering/ARCHITECTURE.md)). Never generate cloud synchronization logins or third-party bank OAuth links.
- **The Safe-to-Spend Usable Balance**:
  $$\text{Usable Balance} = \max\left(\sum \text{Physical Account Balances} - \sum \text{Locked Goal Allocations},\, 0.0\right)$$
  - *Physical Accounts*: Real bank accounts, cash wallets, or salary deposits ([`lib/models/account_model.dart`](../../lib/models/account_model.dart)).
  - *Locked Goal Allocations*: Logical reservations held in real accounts earmarked for future goals without moving money ([`lib/models/locked_allocation_model.dart`](../../lib/models/locked_allocation_model.dart)).
- **Tracking-Only Budgets**: Category monthly budget caps are pacing gauges, not escrow locks ([`docs/adr/0003-tracking-only-budget-model.md`](../adr/0003-tracking-only-budget-model.md)). Exceeding a budget shows warning alerts (`+₹850 over limit`) rather than blocking transactions.
- **Payday-Anchored Cycles**: Spending and daily burn rates are anchored to a configurable monthly payday (Day 1–31) rather than rigid calendar months ([`lib/models/salary_cycle.dart`](../../lib/models/salary_cycle.dart)).
- **Daily Burn Pace**:
  $$\text{Burn Pace} = \frac{\text{Remaining Cycle Budget}}{\text{Days Left Until Payday}}$$
- **Credit Card Backing**: Credit card balances track outstanding debt; cash can be locked from a bank account to back credit card debt, displaying as "backed" or "unbacked" ([`lib/models/credit_card_model.dart`](../../lib/models/credit_card_model.dart)).
- **6 Transaction Types**: `expense`, `income`, `transfer`, `goal_lock`, `goal_unlock`, and `goal_payment` ([`lib/models/transaction_model.dart`](../../lib/models/transaction_model.dart)).

---

## 3. Current Design System & UI Tokens

Source: [`lib/theme/theme_constants.dart`](../../lib/theme/theme_constants.dart)

### A. Color Palette
| Token | Hex | Role / Semantic Usage |
| :--- | :--- | :--- |
| `emerald900` | `#064E3B` | Dark surface accents, deepest brand shadow |
| `emerald800` | `#065F46` | Active tab icon/text, high-contrast dark accents |
| `emerald700` | `#047857` | **Primary Brand Color**, buttons, app bar accents |
| `emerald600` | `#059669` | Interactive links, secondary progress bars |
| `emerald500` | `#10B981` | Success indicators, goal complete, positive cashflow |
| `emerald400` | `#34D399` | Dark mode primary brand color & highlights |
| `emerald100` | `#D1FAE5` | Selected tab indicator pill, light badge backgrounds |
| `emerald50` | `#ECFDF5` | Hero balance card sub-pills, notification banners |
| `danger` | `#EF4444` | Negative cashflow, over-budget indicators, delete buttons |
| `warning` | `#F59E0B` | Inferred fields, locked funds, overdue deadlines |
| `accent` | `#0EA5E9` | Secondary actions, transfers, info highlights |
| `gray900` | `#0F172A` | Slate primary text (light mode) |
| `gray500` | `#64748B` | Unselected tab icons, secondary captions |
| `gray50` | `#F8FAFC` | Main light scaffold background |
| `white` | `#FFFFFF` | Card backgrounds, dialog surfaces (light mode) |
| `darkBg` | `#0B0F19` | Main dark scaffold background |
| `darkSurface` | `#131C2E` | Card & modal background (dark mode) |
| `darkBorder` | `#24324D` | Card border & dividers (dark mode) |

### B. Typography Hierarchy
- `displayLarge`: 32px / Bold / -0.5 letter spacing (Hero Usable Balance)
- `headlineLarge`: 26px / Bold / -0.3 letter spacing (Section hero titles)
- `headlineMedium`: 22px / Semi-bold (App bar titles)
- `titleLarge`: 18px / Semi-bold (Card titles, modal titles)
- `titleMedium`: 16px / Semi-bold (Form section headers, account names)
- `bodyLarge`: 15px / Regular (List item subtitles, input fields)
- `bodyMedium`: 14px / Regular (Secondary descriptions, modal labels)
- `bodySmall`: 12px / Regular (Captions, helper hints, timestamps)
- `labelSmall`: 11px / Medium (Pill badges, category chips, navigation labels)

### C. Layout Shell & Navigation Components
- **Floating Bottom Navigation Bar**:
  - Floating pill anchored at bottom (`padding: 16px horizontal, 12px bottom`, `height: 68px`).
  - Frosted glassmorphism (`BackdropFilter` blur 20px, semi-transparent background `#FFFFFF` @ 82% or `#14201C` @ 78%).
  - 5 interactive items:
    1. **Home**: Dashboard overview (`Icons.dashboard_outlined` / `Icons.dashboard_rounded`)
    2. **Activity**: Transaction history (`Icons.receipt_long_outlined` / `Icons.receipt_long_rounded`)
    3. **Voice (Center Mic)**: Elevated circular floating button with multi-stop emerald gradient (`#34D399` $\to$ `#047857`) and white border.
    4. **Analytics**: Spending breakdown charts (`Icons.pie_chart_outline_rounded` / `Icons.pie_chart_rounded`)
    5. **Accounts**: Multi-tab wealth, budgets & sinking funds (`Icons.account_balance_outlined` / `Icons.account_balance_rounded`)
- **Top App Bar**:
  - Left: App icon + dynamic title depending on active tab.
  - Right Actions:
    - **Settings & Data Backup** (`Icons.settings_outlined`)
    - **Theme Toggle** (`Icons.dark_mode_rounded` / `Icons.light_mode_rounded`)
- **Desktop & Tablet Adaptability**:
  - Viewports $\ge 640\text{px}$ transition to a persistent left-hand `NavigationRail` with multi-column layout support.

---

## 4. Comprehensive Screen-by-Screen Inventory

---

### Screen 1: Dashboard (`/dashboard`)
*Primary Code Source: [`lib/screens/dashboard_screen.dart`](../../lib/screens/dashboard_screen.dart)*  
*Visual Reference: [`screenshots/01-dashboard-light.png`](../../screenshots/01-dashboard-light.png) & [`screenshots/19-dashboard-dark.png`](../../screenshots/19-dashboard-dark.png)*

#### Purpose & Layout
The central financial command center presenting real-time liquidity, upcoming budget limits, active goal progress, and recent transactions.

#### Components & Controls
1. **Hero Safe-to-Spend Balance Card**:
   - Header: Wallet icon, title `"Safe-to-Spend Balance"`, info tooltip icon `(i)`, and **Privacy Mode Eye Icon** (`👁️` / `👁️‍🗨️`).
   - Primary Metric: Large formatted balance (e.g., `₹551,201` or masked `₹••••••`).
   - Formula Breakdown Capsule Bar:
     - `Physical: ₹6.4L` (sum of non-credit physical accounts).
     - `-` subtraction separator.
     - `Locked: ₹86.0k` (sum of funds reserved for goals).
     - `|` vertical divider.
     - `Budget Cap: ₹49.0k` (total active monthly expense budgets).
2. **Quick Actions Grid** (3 rounded action cards):
   - `(+) Log Transaction`: Opens the Transaction modal.
   - `(🔒) Lock Goal`: Quick shortcut to allocate funds to a sinking fund.
   - `(📊) Add Budget`: Opens the category budget creation modal.
3. **Monthly Budget Pace Snapshot Card**:
   - Header: `"Monthly Budget Pace"`, `"Details >"` text link (navigates to Budgets tab).
   - Linear Progress Gauge: Two-tone bar (emerald on-track, red if over-limit).
   - Left sub-stat: `"Spent so far ₹30,300"`, `"⏱ 8 days left"`.
   - Right sub-stat: `"Remaining ₹18.7k left of ₹49.0k"`, `"₹2.3k/day pace"`.
4. **Sinking Funds & Goals Carousel**:
   - Header: `"Sinking Funds & Goals"`, `"View All (4) >"` link (navigates to Goals tab).
   - Horizontal scrollable goal cards:
     - Goal title, completion percentage badge (`100%`, `43%`).
     - Progress bar.
     - Footers: `"Goal Reached"` or `"3 months left"`, and locked amount vs target (e.g., `₹25.0k / ₹25.0k`).
5. **Physical Accounts Quick List**:
   - Header: `"Physical Accounts"`, `"Manage (3) >"` link.
   - Summarized list of bank & cash accounts with balances and usable amount pills.
6. **Recent Activity Feed**:
   - Header: `"Recent Activity"`, `"View All >"`.
   - 5 most recent transactions with category icon, note/title, account, date, and colored amount (`-₹900`, `+₹10,000`).
   - Tapping any transaction opens the Edit Transaction modal.
7. **Pending SMS Banner** (Conditional):
   - Appears at the very top if unreviewed bank SMS messages were detected.
   - Shows pending count, dismiss button, and "Review" button.

---

### Screen 2: Dashboard in Privacy Mode
*Visual Reference: [`screenshots/01b-dashboard-privacy-light.png`](../../screenshots/01b-dashboard-privacy-light.png) & [`screenshots/19b-dashboard-privacy-dark.png`](../../screenshots/19b-dashboard-privacy-dark.png)*

#### Controls & State
- Toggled via the eye icon on the Hero card or auto-activated on launch via settings.
- All sensitive figures are replaced with uniform bullet masks (`••••`):
  - Hero balance becomes `₹••••••`.
  - Formula capsule values become `••••`.
  - Budget pace spent, remaining, and daily burn rates become `••••`.
  - Goal locked amounts and account balances become `••••`.
  - Activity ledger amounts become `••••`.

---

### Screen 3: Log Transaction Modal (Expense, Income, Transfer)
*Primary Code Source: [`lib/screens/dashboard_screen.dart`](../../lib/screens/dashboard_screen.dart)*  
*Visual Reference: [`screenshots/02-modal-expense-light.png`](../../screenshots/02-modal-expense-light.png), [`03-modal-income-light.png`](../../screenshots/03-modal-income-light.png), [`04-modal-transfer-light.png`](../../screenshots/04-modal-transfer-light.png)*

#### Purpose & Modal Architecture
Bottom sheet modal with drag handle bar, title `"Log Transaction"`, and close (`✕`) button.

#### Inputs & Controls
1. **Transaction Type Picker**:
   - Dropdown or Segmented control: `Expense`, `Income`, `Transfer`.
2. **Amount Input**:
   - Text field with large numeric font, prefix currency `₹`, placeholder `0.00`.
   - Numeric keyboard with decimal point support.
   - Validation: Must be $> 0$.
3. **Category Picker** (Visible for `Expense` and `Income`):
   - Custom dropdown selector with category icon badge, category title, and type.
   - Option to create a new category inline.
4. **Source Account Picker ("From Account")**:
   - Dropdown showing Account Name, Bank/Type badge, and current available balance.
5. **Destination Account Picker ("To Account")** (Visible only for `Transfer`):
   - Dropdown of target accounts to receive transferred funds.
6. **Note / Description (Optional)**:
   - Text field with leading icon (`Icons.notes_rounded`), placeholder `"e.g. Weekly grocery shopping"`.
7. **Date Picker**:
   - Box with calendar icon, formatted as `"Wednesday, Sep 23, 2026"`. Tapping opens modal date picker.
8. **Primary Action Button**:
   - Full-width button: `"Save Expense"`, `"Save Income"`, or `"Save Transfer"`.

---

### Screen 4: Activity Ledger (`/ledger`)
*Primary Code Source: [`lib/screens/history_screen.dart`](../../lib/screens/history_screen.dart)*  
*Visual Reference: [`screenshots/15-activity-ledger-light.png`](../../screenshots/15-activity-ledger-light.png) & [`screenshots/26-activity-ledger-dark.png`](../../screenshots/26-activity-ledger-dark.png)*

#### Purpose & Layout
Chronological ledger of every transaction with advanced filtering, full-text note search, and financial period summaries.

#### Components & Controls
1. **Search & Action Header**:
   - Search bar: `"Search ledger by note, category, account..."`.
   - **Export CSV Button** (`Icons.download_rounded`): Opens CSV destination dialog.
   - **Filter Button** (`Icons.tune_rounded`): Opens multi-select filter bottom sheet.
2. **Horizontal Quick-Filter Pills**:
   - Single-tap filter chips: `[✓ All]`, `[Expenses]`, `[Income]`, `[Transfers]`, `[Goal Locks]`, `[Card Payments]`.
3. **Period Summary Hero Card**:
   - Date range selector: `< [∞ All Time] >` or `"Show Month"` button.
   - 4-metric horizontal readout:
     - **Outflow**: `-₹3.7L` (danger red)
     - **Inflow**: `+₹6.1L` (emerald green)
     - **Net**: `+₹2.3L` (emerald or red)
     - **Count**: `87` (slate)
4. **Grouped Chronological Transaction List**:
   - Group headers: Month & Year (e.g., `"September 2026"`), Subtotal for that month (`"Total: ₹245,699"`).
   - Transaction list items:
     - Left: Category circular icon in tinted background.
     - Center: Note / Payee title (e.g., `"Weekend IMAX cinema movie"`), Subtitle with Category, Account, and Date.
     - Right: Amount formatted with direction sign (`-₹900`, `+₹15,000`).
     - Overflow 3-dots icon (`⋮`): Options for **Edit** (reopens form) and **Delete** (with atomic balance rollback).

---

### Screen 5: Ledger Filters Bottom Sheet
*Visual Reference: [`screenshots/15b-modal-ledger-filters-light.png`](../../screenshots/15b-modal-ledger-filters-light.png) & [`screenshots/26b-modal-ledger-filters-dark.png`](../../screenshots/26b-modal-ledger-filters-dark.png)*

#### Inputs & Controls
- **Tabs**: `Category` tab vs `Type` tab.
- **Date Range Picker**: Quick options for `All Time`, `This Month`, `Last Month`, `This Year`, or `Custom Date Range`.
- **Multi-select Checkbox List**: List of categories or transaction types with checkmarks.
- **Actions**: `"Reset Filters"` (text button) and `"Apply Filters"` (primary emerald button).

---

### Screen 6: Spending Analytics (`/analytics`)
*Primary Code Source: [`lib/screens/analytics_screen.dart`](../../lib/screens/analytics_screen.dart)*  
*Visual Reference: [`screenshots/16-analytics-trends-light.png`](../../screenshots/16-analytics-trends-light.png) & [`screenshots/16b-analytics-trends-scroll-light.png`](../../screenshots/16b-analytics-trends-scroll-light.png)*

#### Purpose & Layout
Visual expenditure breakdowns, category distribution donut charts, month-over-month trend bar charts, and net cashflow telemetry.

#### Components & Controls
1. **Period Segmented Control**:
   - `[Monthly Range]` vs `[Year-to-Date (YTD)]`.
2. **Spending Period Card**:
   - Displays active date bounds (e.g., `"Sep 1, 2026 - Sep 23, 2026"`) with calendar edit icon.
3. **Spending by Category Donut Chart Card**:
   - Header: `"Spending by Category"`, `"Total: ₹32,699"`.
   - Center Donut Chart (`fl_chart`): Interactive slices with percentage labels inside.
   - Category Legend List:
     - Colored circular indicator matching donut slice.
     - Category name (e.g., `Dining Out`, `Groceries`, `Shopping`).
     - Percentage share (e.g., `27.1%`, `24.0%`).
     - Exact expenditure (e.g., `₹8,850`, `₹7,850`).
4. **Monthly Spending Trends Bar/Line Chart Card** (Scrolled view):
   - Multi-month trend visualization (3, 6, or 12 months).
   - Category filter dropdown to inspect specific category trends over time.
   - Bar columns displaying monthly spend volume.
5. **Net Cashflow Summary Card**:
   - Total Income vs Total Expense comparison.
   - Net Savings calculation with percentage savings rate.

---

### Screen 7: My Accounts Screen (`/accounts`)
*Primary Code Source: [`lib/screens/accounts_screen.dart`](../../lib/screens/accounts_screen.dart)*  
*Visual Reference: [`screenshots/12-accounts-light.png`](../../screenshots/12-accounts-light.png) & [`screenshots/24-accounts-dark.png`](../../screenshots/24-accounts-dark.png)*

#### Purpose & Sub-Tab Architecture
Three distinct top sub-tabs:
1. **My Accounts** (Active tab)
2. **Monthly Budgets** (Direct embed of Screen 9)
3. **Sinking Funds** (Direct embed of Screen 11)

#### Components & Controls on "My Accounts" Tab
1. **Total Physical Wealth Hero Card**:
   - Primary Metric: Large total balance across all bank and cash accounts (`₹637,201`).
   - Sub-stat Left: `"Locked in Sinking Funds ₹86,000"` (amber text with lock icon).
   - Sub-stat Right: `"Available Liquidity ₹551,201"` (emerald green).
2. **Bank & Cash Accounts Section**:
   - Header: `"Bank & Cash Accounts"`, count badge (`"3 Total"`), `+ Add Account` action.
   - Account Cards:
     - Bank icon in colored circle (`Icons.account_balance_rounded`).
     - Account name (e.g., `"Salary Account (HDFC)"`), Subtitle (`"Bank"` or `"Cash"`).
     - Physical Balance (`₹362,621`).
     - Usable Balance Pill (`₹3.4L usable`).
     - 3-dots menu (`⋮`): Edit, Delete, Adjust Balance.
     - **Locked Funds Accordion Dropdown** ([`screenshots/13-accounts-dropdown-expanded-light.png`](../../screenshots/13-accounts-dropdown-expanded-light.png)):
       - Expandable chevron showing all active sinking funds locking cash in this specific bank account.
3. **Credit Cards Section**:
   - Header: `"Credit Cards"`, count badge.
   - Credit Card Cards:
     - Card name, last 4 digits suffix (`•••• 4821`).
     - Outstanding statement balance (debt).
     - Available credit limit.
     - **Backed Status Indicator**: Green badge if funds are locked in bank to pay this bill; Amber if unbacked.
     - Actions: `[Lock Funds]`, `[Pay Bill]`, `[Unlock]`.

---

### Screen 8: Account Modals (Add / Edit Account)
*Visual Reference: [`screenshots/14-modal-add-account-light.png`](../../screenshots/14-modal-add-account-light.png) & [`screenshots/14b-modal-edit-account-light.png`](../../screenshots/14b-modal-edit-account-light.png)*

#### Inputs & Controls
- **Account Type Selector**: Segmented or Dropdown: `Bank`, `Cash`, `Credit Card`.
- **Account Name**: Text field, e.g., `"HDFC Salary"`.
- **Starting Balance**: Currency input (`₹`).
- **Credit Card Specific Fields** (if Credit Card selected):
  - Credit Limit input.
  - Statement Generation Day (Day 1–31).
  - Payment Due Day (Day 1–31).
  - Last 4 Digits Suffix (e.g., `1234`).
  - Default Backing Bank Account (dropdown of bank accounts).
  - Auto-lock funds toggle switch.
- **Buttons**: `"Cancel"`, `"Save Account"`, or `"Delete Account"` (with transfer check).

---

### Screen 9: Monthly Budgets (`/accounts/budgets`)
*Primary Code Source: [`lib/screens/budget_screen.dart`](../../lib/screens/budget_screen.dart)*  
*Visual Reference: [`screenshots/05-budget-light.png`](../../screenshots/05-budget-light.png) & [`screenshots/21-budget-dark.png`](../../screenshots/21-budget-dark.png)*

#### Purpose & Layout
Tracking monthly category spending caps against actual paycheck cycles.

#### Components & Controls
1. **Category Type Segmented Toggle**:
   - `[✓ Expense Budgets]` vs `[Income Categories]`.
2. **Total Monthly Budget Hero Card**:
   - Header: `"Total Monthly Budget"`, info icon, status pill (`On Track` green or `Over Budget` red).
   - Total Target: Large text `₹49,000`.
   - Progress Bar: Visual representation of cycle spending.
   - Sub-stats: `"Spent so far ₹30,300"`, `"Remaining ₹18,700"`.
3. **Category Allocations List**:
   - Header: `"Category Allocations"`, category count.
   - Individual Category Cards:
     - Left: Category icon (Groceries bag, Dining fork, Shopping bag, etc.).
     - Center: Name, subtitle with remaining amount (`"₹7,150 left of ₹15,000"`).
     - Right: Spent vs Target (`"₹7,850 of ₹15,000"`), edit pencil icon.
     - Progress Bar: Emerald if $\le 100\%$; Red if $> 100\%$.
     - Percentage label: e.g., `52%` or `111%`.
     - **Overbudget Pill Badge**: If spending exceeds target, displays red badge: `+₹850 over limit`.
4. **Floating Action Button**:
   - `[+ Add Budget]` (opens category creation dialog).

---

### Screen 10: Sinking Funds & Goals (`/accounts/sinking-funds`)
*Primary Code Source: [`lib/screens/goals_screen.dart`](../../lib/screens/goals_screen.dart)*  
*Visual Reference: [`screenshots/08-goals-light.png`](../../screenshots/08-goals-light.png) & [`screenshots/22-goals-dark.png`](../../screenshots/22-goals-dark.png)*

#### Purpose & Layout
Dedicated screen for managing multi-month savings goals, tracking deadlines, calculating monthly recommended savings pace, and settling purchases.

#### Components & Controls
1. **Total Locked Funds Hero Card**:
   - Header: `"Total Locked Funds"`, badge `(🔒) Reserved for Goals` (amber).
   - Large Locked Amount: `₹86,000`.
   - Overall progress meter against total targets (`Target: ₹165,000`).
   - Summary: `"52% of total targets saved"`.
2. **Active Sinking Funds List**:
   - Header: `"Active Sinking Funds"`, goal count (`"4 Goals"`).
   - Sinking Fund Card Architecture:
     - Top row: Goal icon, Goal Name (`"Annual Car Insurance"`), Subtitle status, lock icon, history clock icon (`Icons.history_rounded`), edit pencil (`Icons.edit_rounded`).
     - Progress bar with percentage (`100%`, `43%`).
     - Amounts: `"Locked: ₹25,000"`, `"Target: ₹25,000"`.
     - Deadline Row: Calendar icon + `"Due Nov 28, 2026"`, Status pill (`Goal Reached` or `3 months left`).
     - **Dynamic Motivational Banners**:
       - *When 100% funded*: Celebratory emerald banner: `🎉 Ready to Settle • Sinking fund 100% funded`.
       - *When in-progress*: Velocity advice banner: `📈 Save ~₹7,666.67 / paycheck (3 paydays left)`.
       - *When overdue*: Red alert banner: `⚠️ Target date passed • ₹5,000 remaining`.
     - **Card Action Buttons** (2 side-by-side outlined buttons):
       - `(🔒) Lock Funds`: Allocates additional money from bank account.
       - `(💳) Pay / Settle`: Atomically settles the purchase, deducting both bank balance and locked allocation.
3. **Floating Action Button**:
   - `[+ New Goal]` (opens Sinking Fund creation dialog).

---

### Screen 11: Goal Contributions & Activity Bottom Sheet
*Visual Reference: [`screenshots/10-modal-lock-funds-light.png`](../../screenshots/10-modal-lock-funds-light.png) & [`screenshots/23-modal-lock-funds-dark.png`](../../screenshots/23-modal-lock-funds-dark.png)*

#### Components & Controls
- Header: Goal icon, Goal Name, Subtitle `"Goal Contributions & Activity"`, close button `✕`.
- Summary Card: Total saved vs target, percentage saved badge, target date.
- **Locked Funds by Account Section**:
  - Breakdown of which physical bank accounts are holding the locked money (e.g., `Emergency Savings (SBI): ₹25,000 (100% of total saved)`).
- **Contribution & Activity History**:
  - Chronological audit ledger of all `goal_lock`, `goal_unlock`, and `goal_payment` entries.
  - Shows date, account, user note, amount (`+₹25,000`), edit icon, and delete icon.

---

### Screen 12: Credit Card Action Modals (Lock, Pay, Unlock)
*Primary Code Source: [`lib/components/lock_cc_funds_modal.dart`](../../lib/components/lock_cc_funds_modal.dart) & [`lib/components/pay_cc_bill_modal.dart`](../../lib/components/pay_cc_bill_modal.dart)*

#### Lock CC Funds Modal
- Header: `"Lock Funds for Credit Card"`.
- Explanatory note: *"Reserves cash in your bank account so your Safe-to-Spend balance reflects what you owe."*
- Source Bank Account selector dropdown.
- Amount to Lock input (defaults to unbacked card balance).
- Notes input.
- Button: `"Lock Cash for Card"`.

#### Pay CC Bill Modal
- Header: `"Pay Credit Card Bill"`.
- Radio options:
  1. `Pay from Locked Cash (₹X,XXX)` (Uses pre-reserved funds without impacting usable balance).
  2. `Pay Full Outstanding Balance (₹X,XXX)`.
  3. `Custom Amount`.
- Source Bank Account selector.
- Button: `"Confirm Payment"`.

---

### Screen 13: Offline AI Voice Journaling (3-Step Modal Flow)

#### Step 1: Model Pack Download Sheet (If Not Installed)
*Primary Code Source: [`lib/components/voice_model_download_sheet.dart`](../../lib/components/voice_model_download_sheet.dart)*  
*Visual Reference: [`screenshots/17-voice-ai-modal-light.png`](../../screenshots/17-voice-ai-modal-light.png) & [`screenshots/28-voice-ai-modal-dark.png`](../../screenshots/28-voice-ai-modal-dark.png)*
- Explanation card detailing 100% on-device AI models (Whisper/Speech STT + SmolLM2 SLM).
- Download size info (~95 MB), SHA-256 verification guarantee, Wi-Fi only toggle switch.
- Action: `[Download AI Model Pack]`.

#### Step 2: Active Voice Recording Modal
*Primary Code Source: [`lib/components/voice_recording_modal.dart`](../../lib/components/voice_recording_modal.dart)*  
*Visual Reference: [`screenshots/17b-voice-listening-light.png`](../../screenshots/17b-voice-listening-light.png) & [`screenshots/28b-voice-listening-dark.png`](../../screenshots/28b-voice-listening-dark.png)*
- Title: `"Voice Transaction Journaling"`.
- Subtitle: `"Listening... Speak your transactions in rupees"`.
- **Live Streaming Transcript Box**:
  - Header: Sparkle icon `✨ Offline AI Voice Engine`, green status dot `"Hearing Voice"`.
  - Body: Live text transcript updating in real time as the user speaks.
  - Interactive feature: When paused, user can tap to edit transcript directly.
- **Audio Waveform Visualizer**:
  - Reactive animated sine waves reflecting live microphone amplitude.
- **Center Glowing Mic Button**:
  - Tap to pause/resume recording. Status pill: `"MIC ON"`.
- Natural speech hint: `e.g. "Lunch 250 rupees on HDFC, 1200 rupees groceries yesterday"`.
- Action Buttons: `[✕ Cancel]` and `[✓ Done]`.

#### Step 3: Ephemeral Transaction Staging Review Sheet
*Primary Code Source: [`lib/components/voice_transaction_staging_sheet.dart`](../../lib/components/voice_transaction_staging_sheet.dart)*  
*Visual Reference: [`screenshots/17c-voice-staging-light.png`](../../screenshots/17c-voice-staging-light.png) & [`screenshots/28c-voice-staging-dark.png`](../../screenshots/28c-voice-staging-dark.png)*
- Header: AI Voice Icon, `"Staged Transactions (count)"`, eye privacy icon, close button `✕`.
- **Audit Warning Banner**:
  - `⚠️ Some entries have missing or inferred fields. Tap tiles to adjust.`
- **Draft Transaction Cards**:
  - Top row: Editable title with pencil icon, Amount pill with pencil icon (`₹250`), trash icon.
  - Inferred field highlight: Amber warning chip (e.g., `"Default Account Inferred: Review Account"`).
  - 4 Inline Interactive Tiles (tap to change in place):
    - `[ACCOUNT]`: e.g., `"Salary Account (HDFC)"` or highlighted `"Select Account"`.
    - `[CATEGORY]`: e.g., `"Dining Out"`.
    - `[DATE]`: e.g., `"2026-09-23"`.
    - `[TYPE]`: e.g., `"EXPENSE"`.
  - Swipe-to-dismiss gesture on individual cards.
- **Batch Action Footer**:
  - `[Discard All]` (outlined).
  - `[Approve Valid (N)]` (emerald green).
  - `[Approve All (Total)]` (disabled if missing fields exist).

---

### Screen 14: Settings & Data Backup (`/settings`)
*Primary Code Source: [`lib/screens/backup_restore_screen.dart`](../../lib/screens/backup_restore_screen.dart)*  
*Visual Reference: [`screenshots/18-backup-restore-light.png`](../../screenshots/18-backup-restore-light.png) & [`screenshots/29-backup-restore-dark.png`](../../screenshots/29-backup-restore-dark.png)*

#### Purpose & Grouped Settings Cards
1. **Offline Guarantee Banner**:
   - Shield icon, title `"100% Local & Offline"`, subtitle confirming zero remote telemetry.
2. **Privacy & Security Settings**:
   - `"Start in Privacy Mode"` toggle switch.
   - `"App Lock & Biometrics"` toggle switch (FaceID / Fingerprint / PIN).
3. **Financial & Cycle Preferences**:
   - `"Salary & Payday Preferences"`:
     - Day badge (e.g., `1st`), title `"Day 1 of month"`, `"Resets in 8 days"`, `[1-31 Calendar]` picker.
     - Active Financial Cycle summary card: `"Current Cycle: Sep 1 - Sep 30"`.
4. **Storage & Record Count Card**:
   - 4-metric summary: Accounts count, Budgets count, Goals count, Transactions count.
5. **Backup & Data Portability**:
   - Backup status badge (`Unsaved` or relative time e.g., `"2 hours ago"`).
   - `"Export Data & Backups"` (opens Export Dialog for `.db`, `.json`, `.csv`).
   - `"Custom Backup Directory"` file path picker.
   - `"Restore Data from Backup"` (file picker for SQLite/JSON restore).
6. **Voice AI Offline Models** ([`screenshots/18b-backup-restore-voice-scroll-light.png`](../../screenshots/18b-backup-restore-voice-scroll-light.png)):
   - Storage usage indicator (e.g., `95.4 MB on disk`).
   - Wi-Fi only download toggle switch.
   - Delete model files / Re-download buttons.
7. **Peer-to-Peer Live Sync (`/settings/live-sync`)**:
   - Direct link to local network sync screen.
8. **Danger Zone & Utilities**:
   - `"Seed Demo Data"`: Generates realistic accounts, goals, and history.
   - `"Reset All Data"`: Securely wipes the SQLite database after double confirmation.
   - `"Replay Feature Tour"`: Restarts the onboarding walkthrough spotlight.

---

### Screen 15: Peer-to-Peer Live Sync (`/settings/live-sync`)
*Primary Code Source: [`lib/screens/live_sync_screen.dart`](../../lib/screens/live_sync_screen.dart)*

#### Purpose & Controls
Synchronizes financial records locally between two devices over local Wi-Fi without any third-party cloud.
- Mode Toggle: `[Host Mode (Show QR)]` vs `[Client Mode (Scan QR)]`.
- **Host View**: Generates a dynamic QR code containing local IP, port, and temporary pairing token.
- **Client View**: Full-screen camera scanner (`mobile_scanner`) with visual target reticle.
- Manual Fallback: Dialog to enter IP address, port (`48921`), and PIN manually.
- Live sync status indicator with animated transfer progress.

---

### Screen 16: Interactive Walkthrough Spotlight Overlay
*Primary Code Source: [`lib/components/walkthrough/`](../../lib/components/walkthrough/)*

#### Components & Controls
- Modal spotlight with translucent dark overlay carving out a glowing highlight over target UI controls.
- Interactive tooltip card with title, explanation, step counter (`Step 2 of 5`), `"Previous"`, `"Next"`, and `"Skip Tour"` actions.
- Intro carousel with financial philosophy illustrations.

---

## 5. How to Pass This Context to Stitch AI

### Workflow A: Uploading Existing Visual Screenshots (Image-to-UI Mode)
*Fastest, highest visual fidelity approach.*
1. Open Google Stitch AI workspace.
2. Under Stitch's multi-modal prompt, attach the primary screenshots from [`screenshots/`](../../screenshots):
   - Hero/Home: `01-dashboard-light.png`
   - Activity: `15-activity-ledger-light.png`
   - Accounts: `12-accounts-light.png`
   - Budgets: `05-budget-light.png`
   - Goals: `08-goals-light.png`
   - Voice Staging: `17c-voice-staging-light.png`
3. Prompt Stitch:
   > *"Here are the exact screenshots of the Cashflow app. Redesign this mobile app with a cleaner, ultra-modern luxury fintech visual design system. Retain every single card, metric, badge, formula breakdown pill, and interactive input tile shown in these screenshots."*

---

### Workflow B: Master Design System Prompt (Seed First in Stitch AI)
Paste this prompt into Stitch AI before generating individual screens to establish the design language:

```markdown
Design System Specification for "Cashflow" - Modern Private Personal Finance

Design Aesthetic:
- Clean, refined, luxury modern fintech (reminiscent of Linear / Apple design).
- Card surfaces: subtle 1px border (#E2E8F0 in light, #24324D in dark), 20px rounded corners, subtle soft shadows.
- Primary Theme: Deep Emerald Green (#047857), Emerald Mint highlights (#34D399), Slate darks (#0F172A).
- Semantic Accents: Alert Red (#EF4444) for budget overruns, Warm Amber (#F59E0B) for locked goal funds.
- Typography: SF Pro / Inter-style clean sans-serif with bold numerical figures.
- Navigation: Floating frosted glassmorphic pill bar at bottom (blur 20px, height 68px, pill radius 34px) with 5 destinations: Home, Activity, center circular gradient Voice Mic button, Analytics, Accounts.
- Header: Clean app bar with app icon, screen title, Settings gear, and Theme switch.
```

---

### Workflow C: Screen Prompt Blocks for Stitch AI

#### Stitch Prompt for Dashboard Screen:
```markdown
Create the main Dashboard screen for Cashflow (Mobile iOS/Android layout):
- Header: App logo, "Cashflow" bold title, settings gear icon, dark mode toggle.
- Hero Usable Balance Card (Deep emerald gradient background):
  - Small header: Wallet icon + "Safe-to-Spend Balance" + info icon + eye privacy toggle icon.
  - Giant currency figure: "₹551,201".
  - Formula capsule bar: [Physical ₹6.4L] - [Locked ₹86.0k] | [Budget cap ₹49.0k].
- 3 Quick Action Cards (grid):
  - (+) Log Transaction
  - (🔒) Lock Goal
  - (📊) Add Budget
- Monthly Budget Pace Card:
  - Header: "Monthly Budget Pace" with "Details >" link.
  - Progress bar showing 62% consumed.
  - Left: "Spent so far ₹30,300", "⏱ 8 days left".
  - Right: "Remaining ₹18.7k left of ₹49.0k", "₹2.3k/day pace".
- Sinking Funds & Goals section (horizontal scroll cards):
  - Goal 1: "Annual Car Insurance", 100% progress, celebratory green badge "🎉 Ready to Settle", "₹25.0k / ₹25.0k".
  - Goal 2: "Goa Vacation Fund", 43% progress, "3 months left", "₹17.0k of ₹40.0k".
- Physical Accounts list:
  - "Salary Account (HDFC)" Bank: ₹362,621 with "₹3.4L usable" badge and locked funds accordion.
  - "Emergency Savings (SBI)" Bank: ₹267,000.
  - "Cash Wallet" Cash: ₹7,580.
- Bottom Floating Glassmorphic Navigation Pill Bar with elevated center microphone button.
```

#### Stitch Prompt for Ephemeral Voice Staging Review Sheet:
```markdown
Create a modal bottom sheet for "Voice AI Staged Transactions":
- Handle bar at top with title "Staged Transactions (2)", eye privacy toggle, and close 'X' button.
- Warning pill banner: "⚠️ Some entries have missing or inferred fields. Tap tiles to adjust."
- Draft Card 1 (Complete):
  - Title: "Lunch at Cafe" with edit pencil icon.
  - Amount pill: "₹250" with edit pencil, trash icon on right.
  - 4 interactive chips: [Account: Salary Account (HDFC)], [Category: Dining Out], [Date: 2026-09-23], [Type: EXPENSE].
- Draft Card 2 (Needs Attention):
  - Title: "Supermarket Groceries" with edit pencil.
  - Amount pill: "₹1,200", trash icon.
  - Inferred alert chip: "⚠️ Default Account Inferred: Review Account".
  - 4 interactive chips: [Account: Select Account (amber highlighted border)], [Category: Groceries], [Date: 2026-09-23], [Type: EXPENSE].
- Footer action buttons:
  - "Discard All" (neutral outlined button).
  - "Approve Valid (1)" (primary emerald filled button).
  - "Approve All (2)" (disabled secondary button).
```

---

## 6. Verification & Cross-Reference Index

| Feature / Screen | Primary Code Source | Visual Screenshot Asset (Light & Dark) |
| :--- | :--- | :--- |
| **Dashboard Screen** | [`lib/screens/dashboard_screen.dart`](../../lib/screens/dashboard_screen.dart) | [`screenshots/01-dashboard-light.png`](../../screenshots/01-dashboard-light.png), [`19-dashboard-dark.png`](../../screenshots/19-dashboard-dark.png) |
| **Privacy Mode** | [`lib/services/database_helper.dart`](../../lib/services/database_helper.dart) | [`screenshots/01b-dashboard-privacy-light.png`](../../screenshots/01b-dashboard-privacy-light.png), [`19b-dashboard-privacy-dark.png`](../../screenshots/19b-dashboard-privacy-dark.png) |
| **Transaction Modals** | [`lib/screens/dashboard_screen.dart`](../../lib/screens/dashboard_screen.dart) | [`screenshots/02-modal-expense-light.png`](../../screenshots/02-modal-expense-light.png), [`04-modal-transfer-light.png`](../../screenshots/04-modal-transfer-light.png) |
| **Monthly Budgets** | [`lib/screens/budget_screen.dart`](../../lib/screens/budget_screen.dart) | [`screenshots/05-budget-light.png`](../../screenshots/05-budget-light.png), [`21-budget-dark.png`](../../screenshots/21-budget-dark.png) |
| **Sinking Funds** | [`lib/screens/goals_screen.dart`](../../lib/screens/goals_screen.dart) | [`screenshots/08-goals-light.png`](../../screenshots/08-goals-light.png), [`22-goals-dark.png`](../../screenshots/22-goals-dark.png) |
| **Goal Contributions** | [`lib/screens/goals_screen.dart`](../../lib/screens/goals_screen.dart) | [`screenshots/10-modal-lock-funds-light.png`](../../screenshots/10-modal-lock-funds-light.png), [`23-modal-lock-funds-dark.png`](../../screenshots/23-modal-lock-funds-dark.png) |
| **My Accounts** | [`lib/screens/accounts_screen.dart`](../../lib/screens/accounts_screen.dart) | [`screenshots/12-accounts-light.png`](../../screenshots/12-accounts-light.png), [`24-accounts-dark.png`](../../screenshots/24-accounts-dark.png) |
| **Activity Ledger** | [`lib/screens/history_screen.dart`](../../lib/screens/history_screen.dart) | [`screenshots/15-activity-ledger-light.png`](../../screenshots/15-activity-ledger-light.png), [`26-activity-ledger-dark.png`](../../screenshots/26-activity-ledger-dark.png) |
| **Spending Analytics** | [`lib/screens/analytics_screen.dart`](../../lib/screens/analytics_screen.dart) | [`screenshots/16-analytics-trends-light.png`](../../screenshots/16-analytics-trends-light.png), [`27-analytics-trends-dark.png`](../../screenshots/27-analytics-trends-dark.png) |
| **Voice Listening** | [`lib/components/voice_recording_modal.dart`](../../lib/components/voice_recording_modal.dart) | [`screenshots/17b-voice-listening-light.png`](../../screenshots/17b-voice-listening-light.png), [`28b-voice-listening-dark.png`](../../screenshots/28b-voice-listening-dark.png) |
| **Voice Staging Sheet**| [`lib/components/voice_transaction_staging_sheet.dart`](../../lib/components/voice_transaction_staging_sheet.dart) | [`screenshots/17c-voice-staging-light.png`](../../screenshots/17c-voice-staging-light.png), [`28c-voice-staging-dark.png`](../../screenshots/28c-voice-staging-dark.png) |
| **Settings & Backup** | [`lib/screens/backup_restore_screen.dart`](../../lib/screens/backup_restore_screen.dart) | [`screenshots/18-backup-restore-light.png`](../../screenshots/18-backup-restore-light.png), [`29-backup-restore-dark.png`](../../screenshots/29-backup-restore-dark.png) |
| **Credit Card Modals**| [`lib/components/pay_cc_bill_modal.dart`](../../lib/components/pay_cc_bill_modal.dart) | In [`lib/components/`](../../lib/components) |
| **P2P Live Sync** | [`lib/screens/live_sync_screen.dart`](../../lib/screens/live_sync_screen.dart) | In [`lib/screens/live_sync_screen.dart`](../../lib/screens/live_sync_screen.dart) |
