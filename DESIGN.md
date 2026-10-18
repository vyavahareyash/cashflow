# Cashflow Design System & UI Specification (`DESIGN.md`)

> **Authoritative Design System, Screen Architecture, Component Specifications, and Interaction Rules.**  
> *Structured for AI UI generation engines (Google Stitch AI), design system tooling, and production frontend engineering.*

---

## 1. Product Philosophy & Domain Mental Model

Cashflow is a 100% offline, local-first personal finance application built on a core mathematical principle: **Safe-to-Spend Usable Balance**.

```
Usable Balance = max(Physical Cash - Locked for Goals, 0.0)
```

### Core Business & UX Invariants
1. **Zero Cloud / Offline-First**: No remote authentication, no cloud telemetry, no third-party bank scrapers. Everything runs on local SQLite.
2. **Physical vs Logical Separation**: 
   - *Physical Accounts*: Bank accounts, cash wallets, physical assets.
   - *Logical Reserves (Sinking Funds)*: Virtual envelopes that earmark money inside an existing bank account without transferring cash.
   - *Category Budgets*: Tracking & pacing gauges that calculate daily burn velocity ($\text{Burn Pace} = \frac{\text{Remaining}}{\text{Days Left Until Payday}}$). Budgets never escrow or lock cash in advance.
3. **Credit Card Backing**: Debt on credit cards can be backed by reserving bank cash, tracking whether debt is "Backed" or "Unbacked".
4. **Instant Privacy Mode**: A single tap masks all financial balances, formula pills, and transactions with dots (`••••`).
5. **Frictionless Voice Journaling**: Speak continuous multi-transaction monologues parsed locally by on-device neural SLM with an ephemeral, inline-editable staging review sheet.

---

## 2. Design System Tokens & Style Guide

### A. Color Palette
Cashflow features a modern **Emerald Fintech** aesthetic with Slate neutrals and high-contrast semantic alerts.

#### Primary Brand Colors (Emerald)
- `emerald-900`: `#064E3B` (Deepest forest green, brand shadows, dark accent)
- `emerald-800`: `#065F46` (Active navigation text & icons in light mode)
- `emerald-700`: `#047857` (**Primary Brand Accent**, action buttons, hero headers)
- `emerald-600`: `#059669` (Interactive links, secondary progress bars)
- `emerald-500`: `#10B981` (Success indicators, goal completed, positive cashflow)
- `emerald-400`: `#34D399` (Dark mode primary brand accent, high-contrast highlights)
- `emerald-300`: `#6EE7B7` (Light borders on dark surfaces)
- `emerald-100`: `#D1FAE5` (Selected navigation indicator, subtle badge background)
- `emerald-50`: `#ECFDF5` (Formula pill background, notification alert fills)

#### Semantic Colors
- `danger` (Red): `#EF4444` (Negative cashflow, over-budget indicators, delete actions)
- `danger-light`: `#FEE2E2` (Over-budget warning pill fill)
- `warning` (Amber): `#F59E0B` (Locked goal funds, inferred fields, overdue deadlines)
- `warning-light`: `#FEF3C7` (Amber pill fill)
- `accent` (Ocean Blue): `#0EA5E9` (Transfers, information badges, secondary links)
- `purple`: `#8B5CF6` (Special categories, entertainment badges)
- `pink`: `#EC4899` (Shopping categories)

#### Light Mode Neutrals (Slate)
- `bg-light`: `#F8FAFC` (Main scaffold background)
- `surface-light`: `#FFFFFF` (Card surfaces, modals, dialogs)
- `border-light`: `#E2E8F0` (Card borders, dividers)
- `text-primary-light`: `#0F172A` (Headings, primary figures)
- `text-secondary-light`: `#64748B` (Subtitles, labels, captions)
- `text-muted-light`: `#94A3B8` (Placeholders, inactive icons)

#### Dark Mode Surfaces (Deep Space)
- `bg-dark`: `#0B0F19` (Main scaffold background)
- `surface-dark`: `#131C2E` (Card surfaces, modals, bottom sheets)
- `surface-elevated-dark`: `#1A263D` (Elevated cards, popovers)
- `border-dark`: `#24324D` (Card borders, dividers)
- `text-primary-dark`: `#F8FAFC` (High-contrast headings, figures)
- `text-secondary-dark`: `#94A3B8` (Subtitles, secondary labels)

---

### B. Typography Scale
Clean modern sans-serif (Inter / SF Pro Display) with tabular figures for currency numbers:

| Token | Size | Weight | Line Height | Letter Spacing | Primary Usage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `display-large` | 32px | Bold (700) | 38px | -0.5px | Hero Safe-to-Spend Balance figure |
| `headline-large` | 26px | Bold (700) | 32px | -0.3px | Section hero balances, major totals |
| `headline-medium` | 22px | Semi-Bold (600) | 28px | -0.2px | Top App Bar titles |
| `title-large` | 18px | Semi-Bold (600) | 24px | -0.1px | Card titles, modal sheet titles |
| `title-medium` | 16px | Semi-Bold (600) | 22px | 0.0px | Form section titles, account names |
| `body-large` | 15px | Regular (400) | 22px | 0.0px | List item primary text, input values |
| `body-medium` | 14px | Regular (400) | 20px | 0.0px | Secondary captions, modal descriptions |
| `body-small` | 12px | Regular (400) | 16px | 0.0px | Date stamps, helper hints, sub-stats |
| `label-small` | 11px | Semi-Bold (600) | 14px | +0.2px | Status badges, category pills, nav labels |

---

### C. Spacing, Borders & Shadows

#### Spacing Scale (Base 4px / 8px Grid)
- `xxs`: 2px | `xs`: 4px | `sm`: 8px | `md`: 12px | `lg`: 16px | `xl`: 20px | `xxl`: 24px | `xxxl`: 32px | `huge`: 48px

#### Corner Radius
- `radius-sm`: 6px (Badges, mini tags)
- `radius-md`: 12px (Form inputs, action buttons, chips)
- `radius-lg`: 16px (Dialogs, secondary cards)
- `radius-xl`: 20px (Primary cards, hero widgets)
- `radius-sheet`: 24px (Top corners of bottom modal sheets)
- `radius-full`: 9999px (Floating navigation pill, circular mic button, pills)

#### Shadows & Elevation
- **Card Shadow (Light)**: `0 2px 8px rgba(15, 23, 42, 0.05)`, border `1px solid #E2E8F0`
- **Hero Card Shadow**: `0 8px 24px rgba(4, 120, 87, 0.12)`, border `1px solid rgba(4, 120, 87, 0.2)`
- **Glassmorphic Floating Nav**:
  - Light: Background `rgba(255, 255, 255, 0.82)`, `backdrop-filter: blur(20px)`, border `1.5px solid rgba(255, 255, 255, 0.9)`, shadow `0 6px 24px rgba(0, 0, 0, 0.08)`.
  - Dark: Background `rgba(20, 32, 28, 0.78)`, `backdrop-filter: blur(20px)`, border `1.5px solid rgba(40, 65, 54, 0.85)`, shadow `0 6px 24px rgba(0, 0, 0, 0.40)`.

---

## 3. Universal App Shell & Navigation

### A. Floating Navigation Bar (Mobile / Compact)
- **Positioning**: Fixed at bottom, `padding: 16px horizontal, 12px bottom`, `height: 68px`.
- **Anatomy**: Rounded pill (`radius: 34px`) with frosted glassmorphism containing 5 equal-spaced action zones:
  1. **Home**: `Icons.dashboard_outlined` $\to$ `Icons.dashboard_rounded`, label `"Home"`.
  2. **Activity**: `Icons.receipt_long_outlined` $\to$ `Icons.receipt_long_rounded`, label `"Activity"`.
  3. **Voice (Center Mic Action)**: 
     - Elevated circular button (`diameter: 46px`).
     - Multi-stop emerald gradient (`#34D399` $\to$ `#10B981` $\to$ `#059669` $\to$ `#047857`).
     - White border `2px`, glowing drop shadow.
     - Center microphone icon (`Icons.mic_rounded`, white, 24px).
     - Tap triggers Voice AI recording modal or download sheet.
  4. **Analytics**: `Icons.pie_chart_outline_rounded` $\to$ `Icons.pie_chart_rounded`, label `"Analytics"`.
  5. **Accounts**: `Icons.account_balance_outlined` $\to$ `Icons.account_balance_rounded`, label `"Accounts"`.

### B. Persistent Navigation Rail (Desktop & Tablet $\ge 640\text{px}$)
- Left rail with vertical branding, active selection indicator, center Voice button, and bottom Settings shortcut.

### C. Top App Bar
- Left: App icon (`assets/icon/app_icon.jpeg`, 28x28 rounded) + Screen Title (`headlineMedium`, 20px, bold).
- Right Actions:
  - **Settings & Data Backup Icon Button** (`Icons.settings_outlined`, 22px).
  - **Theme Toggle Icon Button** (`Icons.dark_mode_rounded` in light, `Icons.light_mode_rounded` in dark).

---

## 4. UI Component Library Specifications

### A. Buttons
1. **Primary Button**:
   - Background `#047857` (Light) / `#10B981` (Dark), Text `#FFFFFF` / `#0F172A`, Height 48px, Radius 12px, font-weight 600.
2. **Outlined / Secondary Button**:
   - Border `1px solid #E2E8F0` (Light) / `#24324D` (Dark), Background transparent, Height 44px, Radius 12px.
3. **Danger Button**:
   - Background `#EF4444`, Text `#FFFFFF`, Height 44px, Radius 12px.
4. **Action Pills & Filter Chips**:
   - Unselected: Background transparent, border `1px solid #E2E8F0`, text `#64748B`.
   - Selected: Background `#D1FAE5`, border `1px solid #059669`, text `#065F46`, font-weight 600.

### B. Form Inputs
1. **Currency Input**:
   - Large numeric input, leading currency symbol (`₹`), placeholder `0.00`, numeric decimal keyboard.
2. **Standard Text Input**:
   - Height 52px, Radius 12px, Border `1px solid #E2E8F0` (focused `#047857`), leading icon (20px slate).
3. **Choice Pickers & Dropdowns**:
   - Tap opens select sheet or popover, displaying icon, title, balance/subtitle, and right checkmark.
4. **Date Selector Tile**:
   - Surface container with calendar icon (`Icons.calendar_today_rounded`), formatted date string, tap triggers modal date picker.

### C. Cards & Containers
1. **Hero Balance Card**:
   - Rounded rectangle (`radius: 20px`), background deep emerald `#047857` or gradient `#064E3B` $\to$ `#047857`.
   - Contrast text `#FFFFFF`. Formula capsule bar with translucent background (`rgba(255, 255, 255, 0.15)`).
2. **Standard Card**:
   - White surface (`#FFFFFF` in light, `#131C2E` in dark), border `1px solid #E2E8F0` / `#24324D`, radius 16px, padding 16px.
3. **Progress Gauges**:
   - Track height 8px, radius 4px. Fill emerald `#059669` if on-track; Fill red `#EF4444` if over budget.

---

## 5. Screen-by-Screen Anatomy & Controls

---

### Screen 1: Dashboard (`/dashboard`)
*Screenshot Reference: `screenshots/01-dashboard-light.png` & `19-dashboard-dark.png`*

- **Top Bar**:
  - Title: `"Cashflow"`, Settings gear, Theme toggle moon/sun.
- **Card 1: Hero Safe-to-Spend Balance Card**:
  - Top row: Wallet icon + `"Safe-to-Spend Balance"` + info icon `(i)` + **Privacy Toggle Eye Icon** (`👁️`).
  - Giant Number: `₹551,201` (or masked `₹••••••`).
  - Formula Capsule: `[Physical ₹6.4L] - [Locked ₹86.0k] | [Budget cap ₹49.0k]`.
- **Card 2: Quick Action Bar (3 Grid Cards)**:
  - `(+) Log Transaction` $\to$ Opens Transaction Modal.
  - `(🔒) Lock Goal` $\to$ Opens Sinking Fund Allocation Modal.
  - `(📊) Add Budget` $\to$ Opens Category Budget Modal.
- **Card 3: Monthly Budget Pace Snapshot**:
  - Header: `"Monthly Budget Pace"`, `"Details >"`.
  - Dual-tone progress bar (62% used).
  - Left: `"Spent so far ₹30,300"`, `"⏱ 8 days left"`.
  - Right: `"Remaining ₹18.7k left of ₹49.0k"`, `"₹2.3k/day pace"`.
- **Card 4: Sinking Funds & Goals Carousel**:
  - Header: `"Sinking Funds & Goals"`, `"View All (4) >"`.
  - Horizontal cards:
    - *Goal A*: `"Annual Car Insurance"`, `100%`, celebratory flair `🎉 Ready to Settle`, `₹25.0k / ₹25.0k`.
    - *Goal B*: `"Goa Vacation Fund"`, `43%`, `"3 months left"`, `₹17.0k of ₹40.0k`.
- **Card 5: Physical Accounts Overview**:
  - Header: `"Physical Accounts"`, `"Manage (3) >"`.
  - Summary row: HDFC Salary (`₹362,621`), SBI Emergency (`₹267,000`), Cash Wallet (`₹7,580`).
- **Card 6: Recent Activity Feed**:
  - 5 recent entries with category icon, title, account name, date, and signed amount (`-₹900`, `+₹10,000`).

---

### Screen 2: Log Transaction Modal (Expense, Income, Transfer)
*Screenshot Reference: `screenshots/02-modal-expense-light.png`, `03-modal-income-light.png`, `04-modal-transfer-light.png`*

- **Modal Shell**: Bottom sheet, top grab handle, title `"Log Transaction"`, close `✕`.
- **Input 1: Transaction Type Dropdown**: `Expense`, `Income`, `Transfer`.
- **Input 2: Amount Field**: Currency prefix `₹`, numeric decimal keyboard, validation $> 0$.
- **Input 3: Category Picker** (for Expense/Income): Dropdown with icon badges.
- **Input 4: From Account Selector**: Shows bank/cash account name and current physical balance.
- **Input 5: To Account Selector** (visible only for Transfer): Destination account picker.
- **Input 6: Note Field (Optional)**: Free-text with leading note icon (`Icons.notes_rounded`).
- **Input 7: Date Picker**: Formatted date box with calendar trigger.
- **Action Button**: Primary full-width button: `"Save Expense"`, `"Save Income"`, or `"Save Transfer"`.

---

### Screen 3: Activity Ledger (`/ledger`)
*Screenshot Reference: `screenshots/15-activity-ledger-light.png` & `26-activity-ledger-dark.png`*

- **Search & Filter Bar**:
  - Text input: `"Search ledger by note, category, account..."`.
  - Export CSV Button (`Icons.download_rounded`).
  - Filter Drawer Button (`Icons.tune_rounded`).
- **Quick-Filter Pills Bar**:
  - Horizontal chips: `[✓ All]`, `[Expenses]`, `[Income]`, `[Transfers]`, `[Goal Locks]`, `[Card Payments]`.
- **Period Summary Hero Card**:
  - Period Navigator: `< [∞ All Time] >`, `"Show Month"`.
  - 4-column metrics: **Outflow** (`-₹3.7L` red), **Inflow** (`+₹6.1L` green), **Net** (`+₹2.3L`), **Count** (`87`).
- **Grouped Transaction List**:
  - Header: Month name (e.g. `"September 2026"`), Subtotal (`"Total: ₹245,699"`).
  - Item Row: Category circle icon, Title, Account + Date subtitle, formatted signed amount, 3-dots menu (`Edit`, `Delete`).

---

### Screen 4: Spending Analytics (`/analytics`)
*Screenshot Reference: `screenshots/16-analytics-trends-light.png` & `16b-analytics-trends-scroll-light.png`*

- **Segmented Time Range**: `[Monthly Range]` vs `[Year-to-Date (YTD)]`.
- **Date Range Selector Card**: Active bounds (`Sep 1, 2026 - Sep 23, 2026`) with calendar picker.
- **Spending by Category Donut Chart**:
  - Center Donut Chart with percentage slices.
  - Total figure in corner (`"Total: ₹32,699"`).
  - Category Breakdown Legend: Color dot, category name, share %, and amount (e.g. `Dining Out 27.1% ₹8,850`).
- **Monthly Spending Trends Bar/Line Chart**:
  - 6-month comparative bar chart with monthly spend velocity.
  - Dropdown filter to view trends for a single specific category.
- **Net Cashflow Summary**:
  - Total Income vs Total Expense, net monthly savings rate %.

---

### Screen 5: My Accounts (`/accounts`)
*Screenshot Reference: `screenshots/12-accounts-light.png` & `24-accounts-dark.png`*

- **Sub-Tabs**: `[My Accounts (Active)]` | `[Monthly Budgets]` | `[Sinking Funds]`.
- **Total Physical Wealth Hero Card**:
  - Main balance: `₹637,201`.
  - Sub-stats: `"Locked in Sinking Funds ₹86,000"` (amber lock), `"Available Liquidity ₹551,201"` (green).
- **Bank & Cash Accounts Section**:
  - Header: `"Bank & Cash Accounts (3 Total)"`, `+ Add Account` button.
  - Account Card: Bank icon, Name (`Salary Account (HDFC)`), Subtitle (`Bank`), Balance (`₹362,621`), Usable pill (`₹3.4L usable`), 3-dots menu.
  - **Expandable Accordion Dropdown**:
    - Tap chevron $\to$ reveals breakdown of all sinking funds locking cash in this bank account.
- **Credit Cards Section**:
  - Header: `"Credit Cards"`.
  - Card: Card name, last 4 digits (`•••• 4821`), statement balance, credit limit, Backed / Unbacked status pill.
  - Actions: `[Lock Funds]`, `[Pay Bill]`, `[Unlock]`.

---

### Screen 6: Monthly Budgets (`/accounts/budgets`)
*Screenshot Reference: `screenshots/05-budget-light.png` & `21-budget-dark.png`*

- **Category Type Switch**: `[✓ Expense Budgets]` vs `[Income Categories]`.
- **Budget Hero Card**:
  - Total Monthly Budget: `₹49,000`, status pill (`On Track` green).
  - Progress bar.
  - Sub-stats: `"Spent so far ₹30,300"`, `"Remaining ₹18,700"`.
- **Category Allocation Cards**:
  - Icon, Name (`Groceries`), Subtitle (`₹7,150 left of ₹15,000`), Spent/Target (`₹7,850 of ₹15,000`), edit icon.
  - Progress bar (52%).
  - **Over-Budget Warning State**:
    - For `Dining Out`: Red progress bar, `"Over budget by ₹850"`, red badge: `+₹850 over limit` (`111%`).
- **FAB**: `[+ Add Budget]`.

---

### Screen 7: Sinking Funds & Savings Goals (`/accounts/sinking-funds`)
*Screenshot Reference: `screenshots/08-goals-light.png` & `22-goals-dark.png`*

- **Hero Card: Total Locked Funds**:
  - `₹86,000`, amber badge `(🔒) Reserved for Goals`, overall progress meter against `Target: ₹165,000`.
- **Active Sinking Funds Cards**:
  - Header row: Goal icon, Name (`Annual Car Insurance`), status, lock icon, history clock icon, edit icon.
  - Progress bar with percentage (`100%`, `43%`).
  - Amounts: `"Locked: ₹25,000"`, `"Target: ₹25,000"`.
  - Deadline: `[calendar] Due Nov 28, 2026`, status pill (`Goal Reached` or `3 months left`).
  - **Dynamic State Banners**:
    - *When complete*: Celebratory banner `🎉 Ready to Settle • Sinking fund 100% funded`.
    - *When in-progress*: Velocity advice `📈 Save ~₹7,666.67 / paycheck (3 paydays left)`.
    - *When overdue*: Alert banner `⚠️ Target date passed • ₹5,000 remaining`.
  - **Action Buttons**: `(🔒) Lock Funds` (add savings) and `(💳) Pay / Settle` (atomically settle expense).
- **FAB**: `[+ New Goal]`.

---

### Screen 8: Goal Contributions & Activity Bottom Sheet
*Screenshot Reference: `screenshots/10-modal-lock-funds-light.png` & `23-modal-lock-funds-dark.png`*

- Header: Goal icon, Name, Subtitle `"Goal Contributions & Activity"`, close `✕`.
- Summary Card: Total saved vs target, percentage badge, due date.
- **Section: Locked Funds by Account**: Shows which physical bank accounts hold the cash (e.g. `Emergency Savings (SBI): ₹25,000 (100%)`).
- **Section: Contribution & Activity History**: Chronological ledger of all lock/unlock/settlement transactions with amounts, dates, notes, and delete buttons.

---

### Screen 9: Offline Voice AI Journaling (3-Step Flow)

#### 9.1 Model Pack Download Sheet (First-Run)
*Screenshot Reference: `screenshots/17-voice-ai-modal-light.png`*
- Explains 100% on-device AI models (~95MB Whisper STT + SmolLM2 SLM with GBNF grammar).
- Download size info, SHA-256 verification indicator, Wi-Fi only toggle switch, `[Download Model Pack]` button.

#### 9.2 Active Voice Recording Modal
*Screenshot Reference: `screenshots/17b-voice-listening-light.png` & `28b-voice-listening-dark.png`*
- Title: `"Voice Transaction Journaling"`, subtitle `"Listening... Speak your transactions in rupees"`.
- **Streaming Transcript Box**:
  - Sparkle badge: `✨ Offline AI Voice Engine`, green dot `"Hearing Voice"`.
  - Real-time streaming transcription text box (tap to edit when paused).
- **Animated Sine Waveform Visualizer**:
  - Reactive amplitude waves behind the center glowing mic button.
- **Center Glowing Mic Button**:
  - Tap to pause/resume recording, status pill `"MIC ON"`.
- Helper speech hint: `e.g., "Lunch 250 rupees on HDFC, 1200 rupees groceries yesterday"`.
- Action Buttons: `[✕ Cancel]` and `[✓ Done]`.

#### 9.3 Ephemeral Staged Transactions Review Sheet
*Screenshot Reference: `screenshots/17c-voice-staging-light.png` & `28c-voice-staging-dark.png`*
- Header: Voice icon, `"Staged Transactions (count)"`, eye privacy toggle, close button `✕`.
- Audit Alert Banner: `⚠️ Some entries have missing or inferred fields. Tap tiles to adjust.`
- **Draft Cards**:
  - Editable title with pencil icon, Amount pill with pencil (`₹250`), trash delete icon.
  - Inferred Field Alert Badge: Amber banner `⚠️ Default Account Inferred: Review Account`.
  - **4 Inline Interactive Tiles (Tap to edit in place)**:
    - `[ACCOUNT]`: Bank name or amber highlighted `"Select Account"`.
    - `[CATEGORY]`: Category name (e.g., `Dining Out`).
    - `[DATE]`: Calendar date (e.g., `2026-09-23`).
    - `[TYPE]`: Transaction type (`EXPENSE`).
  - Swipe-to-dismiss gesture on individual cards.
- **Batch Actions**: `[Discard All]` (outlined), `[Approve Valid (N)]` (emerald primary), `[Approve All]` (disabled if missing fields exist).

---

### Screen 10: Settings & Data Backup (`/settings`)
*Screenshot Reference: `screenshots/18-backup-restore-light.png` & `29-backup-restore-dark.png`*

- **Banner: 100% Local & Offline**: Shield icon confirming zero telemetry and local SQLite storage.
- **Privacy & Security Card**:
  - `"Start in Privacy Mode"` toggle switch.
  - `"App Lock & Biometrics"` toggle switch (FaceID / Fingerprint / Device PIN).
- **Financial & Payday Cycle Card**:
  - Payday selector: Day badge (`1st`), `"Day 1 of month"`, `"Resets in 8 days"`, `[1-31 Calendar]` picker.
  - Active cycle summary card: `"Current Cycle: Sep 1 - Sep 30"`.
- **Storage & Record Count Card**: 4 counters: Accounts, Budgets, Goals, Transactions.
- **Backup & Data Portability**:
  - Freshness timestamp badge (`Unsaved` or `"2 hours ago"`).
  - Export Data button (`.db`, `.json`, `.csv`).
  - Custom backup folder directory picker.
  - Restore Data from file.
- **Voice AI Offline Models Section**:
  - Disk usage badge (`95.4 MB`), Wi-Fi only switch, Delete/Re-download models.
- **Peer-to-Peer Local Sync Shortcut**: Direct link to local Wi-Fi sync screen.
- **Danger Zone**: `"Seed Demo Data"`, `"Reset All Data"`, `"Replay Feature Tour"`.

---

### Screen 11: Peer-to-Peer Live Sync (`/settings/live-sync`)
*Code Reference: `lib/screens/live_sync_screen.dart`*

- Mode Selector: `[Host Mode (Show QR)]` vs `[Client Mode (Scan QR)]`.
- **Host Screen**: Displays dynamic QR code with local IP address, port (`48921`), and ephemeral security PIN.
- **Client Screen**: Camera scanner viewfinder with target reticle to scan host QR.
- Fallback manual IP/PIN connection dialog.
- Live encrypted sync progress indicator.

---

### Screen 12: Biometric App Lock Gate (`lib/main.dart`)
- Minimalist lock screen with app icon, lock badge, and prompt to authenticate via FaceID / Fingerprint / PIN.

---

## 6. Micro-Interactions & Dynamic Visual States

1. **Privacy Mode Masking**:
   - Tapping eye icon on hero card instantly transforms numbers $\to$ `••••` with smooth fade transition.
2. **Over-Budget Warning**:
   - When spending in a category exceeds monthly budget cap, the gauge turns from emerald to danger red, and a pill badge `+₹XXX over limit` appears.
3. **Goal Achievement Celebratory Flair**:
   - Reaching 100% of a sinking fund triggers celebratory badge `🎉 Ready to Settle`, confetti accent, and highlighted card border.
4. **Voice Audio Waveform Animation**:
   - Dynamic sinusoidal audio visualizer responds to live microphone decibel amplitude.
5. **Swipe-to-Dismiss**:
   - Staged voice draft cards and activity ledger items support horizontal swipe gesture to delete.
6. **Accordion Expand/Collapse**:
   - Bank account cards expand with smooth spring physics to reveal locked fund allocations per goal.

---

## 7. Screenshot Index for Stitch AI Image-to-UI Mode

When prompting Stitch AI, pair the screen specifications above with these repository image assets:

| Screen Name | Light Theme File | Dark Theme File |
| :--- | :--- | :--- |
| **Main Dashboard** | `screenshots/01-dashboard-light.png` | `screenshots/19-dashboard-dark.png` |
| **Dashboard (Privacy Mode)** | `screenshots/01b-dashboard-privacy-light.png` | `screenshots/19b-dashboard-privacy-dark.png` |
| **Log Expense Modal** | `screenshots/02-modal-expense-light.png` | `screenshots/20-modal-expense-dark.png` |
| **Log Income Modal** | `screenshots/03-modal-income-light.png` | — |
| **Log Transfer Modal** | `screenshots/04-modal-transfer-light.png` | — |
| **Monthly Budgets** | `screenshots/05-budget-light.png` | `screenshots/21-budget-dark.png` |
| **Add Budget Category** | `screenshots/06-modal-add-category-light.png` | — |
| **Edit Budget Category** | `screenshots/07-modal-edit-category-light.png` | — |
| **Sinking Funds / Goals** | `screenshots/08-goals-light.png` | `screenshots/22-goals-dark.png` |
| **Create Sinking Fund** | `screenshots/09-modal-add-goal-light.png` | — |
| **Goal Contributions Modal**| `screenshots/10-modal-lock-funds-light.png` | `screenshots/23-modal-lock-funds-dark.png` |
| **My Accounts** | `screenshots/12-accounts-light.png` | `screenshots/24-accounts-dark.png` |
| **Account Locks Accordion** | `screenshots/13-accounts-dropdown-expanded-light.png` | `screenshots/25-accounts-dropdown-expanded-dark.png` |
| **Add / Edit Account** | `screenshots/14-modal-add-account-light.png` | — |
| **Activity Ledger** | `screenshots/15-activity-ledger-light.png` | `screenshots/26-activity-ledger-dark.png` |
| **Ledger Filter Modal** | `screenshots/15b-modal-ledger-filters-light.png` | `screenshots/26b-modal-ledger-filters-dark.png` |
| **Export CSV Dialog** | `screenshots/15c-modal-export-csv-light.png` | — |
| **Spending Analytics** | `screenshots/16-analytics-trends-light.png` | `screenshots/27-analytics-trends-dark.png` |
| **Monthly Trends Chart** | `screenshots/16b-analytics-trends-scroll-light.png` | `screenshots/27b-analytics-trends-scroll-dark.png` |
| **Voice AI Model Sheet** | `screenshots/17-voice-ai-modal-light.png` | `screenshots/28-voice-ai-modal-dark.png` |
| **Voice Active Recording** | `screenshots/17b-voice-listening-light.png` | `screenshots/28b-voice-listening-dark.png` |
| **Voice Staging Sheet** | `screenshots/17c-voice-staging-light.png` | `screenshots/28c-voice-staging-dark.png` |
| **Settings & Data Backup** | `screenshots/18-backup-restore-light.png` | `screenshots/29-backup-restore-dark.png` |
| **Settings (Voice AI Card)**| `screenshots/18b-backup-restore-voice-scroll-light.png` | `screenshots/29b-backup-restore-voice-scroll-dark.png` |
