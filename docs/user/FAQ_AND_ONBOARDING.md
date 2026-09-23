# Cashflow Onboarding & FAQ

This guide gets you started with Cashflow in three quick steps and answers frequently asked questions about privacy, payday cycles, virtual envelopes, and data management.

---

## 3-Step Quickstart Guide

### Step 1: Set Up Your Accounts
1. Navigate to **Accounts** from the bottom navigation bar.
2. Tap **Add Account** (`+`).
3. Enter account names reflecting your actual money storage (e.g., *Main Checking*, *Emergency Savings*, *Physical Cash*).
4. Enter your current starting balance for each account.

> [!TIP]
> Grouping your accounts realistically gives you an accurate **Physical Total Balance** right away.

### Step 2: Configure Your Payday Cycle & Category Budgets
1. Open **Settings** (gear icon in the top app bar).
2. Tap **Salary Cycle Start Day** and select your payday (e.g., `25` if you are paid on the 25th of every month, or `1` for standard calendar months).
3. Switch to **Budgets** from the bottom bar.
4. Set optional monthly spending limits on recurring categories like *Groceries*, *Dining*, or *Utilities*.

### Step 3: Create Savings Goals & Log Your First Spend
1. Navigate to **Goals**.
2. Tap **Add Goal** (`+`), choose a target name (e.g., *Vacation Fund* or *Emergency Fund*), target amount, and target completion date.
3. Tap **Lock Funds** to assign money from one of your accounts to this goal without physically moving money between bank accounts.
4. Go back to the **Dashboard** and tap the Floating Action Button (`+`) to record your first expense or transfer. Notice how your **Safe-to-Spend Usable Balance** immediately updates!

---

## Frequently Asked Questions (FAQ)

### Privacy & Security

#### Is my financial data private?
**Yes, 100%.** Cashflow does not use any cloud servers, user accounts, analytics trackers, or telemetry. All data is saved strictly on your local device in a secure SQLite database file (`cashflow.db`).

#### Does Cashflow connect to my bank accounts?
**No, by design.** Automatic bank scraping requires giving third-party services your banking credentials. Cashflow uses intentional manual logging, ensuring zero credential exposure, zero third-party tracking, and 100% offline capability.

#### Can I hide my balances when opening the app in public?
**Yes.** Tap the eye icon in the top dashboard bar to toggle **Privacy Mode**. When enabled:
- All sensitive balances, budgets, account totals, and transaction amounts are masked (`$••••••`).
- Your preference persists across app relaunches until you tap the eye icon again to unmask.

---

### Balances & Calculations

#### What is the difference between "Total Balance" and "Usable Balance"?
- **Total Physical Balance**: The actual sum of money across all your real-world bank and cash accounts.
- **Safe-to-Spend Usable Balance**: Total Physical Balance minus **Locked Goal Funds**. This is the exact amount of discretionary cash you can safely spend without raiding your savings goals.

$$\\text{Usable Balance} = \\text{Total Account Balance} - \\text{Total Locked Goal Allocations}$$

#### Why aren't category budgets subtracted from my Usable Balance?
In Cashflow, category budgets represent **spending targets**, not pre-allocated funds. When you record an expense, it deducts from your physical account balance (and therefore your usable balance) at the moment the expense occurs. Treating budgets as tracking targets prevents double-deducting planned expenses.

#### How does the Payday Cycle work?
Instead of forcing a rigid 1st-to-31st calendar month, Cashflow supports custom salary cycles (e.g., 25th to 24th).
- If your cycle starts on the 25th and today is October 10th, your current cycle runs from September 25th to October 24th.
- Category spending totals, monthly progress bars, and Daily Burn Pace automatically calculate against this active salary window.

#### What is Daily Burn Pace?
Daily Burn Pace tracks whether you are spending faster or slower than your cycle allows:
- **Allowable Daily Spend**: Remaining monthly budget divided by remaining days in your payday cycle.
- **Actual Daily Spend**: Total cycle spending divided by elapsed cycle days.
- **Pace Ratio**: $\\text{Actual Daily} / \\text{Allowable Daily}$.
  - $\\le 1.0$: Healthy spending pace (green/teal).
  - $> 1.0$: Accelerated spending pace (amber/coral alert).

---

### Savings Goals & Sinking Funds

#### How do "Locked Allocations" work?
Cashflow uses virtual envelope allocation. When you lock $500 toward a *Car Repair* goal from your *Checking Account*:
1. The physical balance of your *Checking Account* remains unchanged.
2. The $500 is marked as locked in the database.
3. Your **Safe-to-Spend Usable Balance** decreases by $500.
4. You don't need to open separate bank accounts for each savings objective.

#### What happens when a goal reaches 100%?
When locked funds meet or exceed the goal target:
- A celebratory confetti flair triggers in the UI.
- The goal card displays a green "Goal Achieved" badge.
- You can unlock funds to spend on the target item, or archive the goal.

---

### Transactions & Data Management

#### What is an Account Transfer?
An **Account Transfer** moves money between two local accounts (e.g., from *Checking* to *Cash ATM Withdrawal*).
- Cashflow records this as an atomic paired transaction: an expense from the source account and an income into the destination account.
- Because net funds do not leave your ecosystem, transfers do not inflate your category expense reports.

#### How do I back up my data or switch phones?
Navigate to **Settings** > **Data Management**:
- **Export Backup (JSON)**: Creates a portable, human-readable JSON export of all accounts, categories, transactions, goals, and locks.
- **Export Database (SQLite)**: Copies the raw `cashflow.db` file for full byte-level fidelity.
- **Import Backup / Restore Database**: Select your previously saved JSON or `.db` file to restore your entire history. Clear feedback messages validate the operation before applying changes.

---

### Voice AI Journaling

#### Does voice journaling send my audio or financial data to the cloud?
**No, never.** All voice recognition and entity extraction run 100% locally on your device hardware:
- Speech recognition uses your operating system's built-in on-device engine (`SpeechRecognizer` on Android, `SFSpeechRecognizer` on iOS).
- Entity extraction runs a local quantized neural model (SmolLM2-360M) via `llama_cpp_dart`.
- Temporary recording audio files (WAV) are deleted immediately upon transcription completion or session cancel.

#### How do I set up Voice AI Journaling?
1. Tap the **Microphone** button at the center of the navigation bar, or go to **Settings & Data** > **Voice AI & Offline Models**.
2. Tap **Download Model Pack (~270 MB)** over Wi-Fi.
3. Once downloaded and cryptographically verified via SHA-256, you can dictate transactions instantly.

#### Does voice journaling support languages other than English?
**No, not currently.** Voice journaling is strictly English-only:
- Speech-to-text defaults to device locale, but the downstream entity extraction model (`SmolLM2-360M-Instruct`) and prompting pipeline are tuned exclusively for English dictation.
- Relative date math (*"yesterday"*, *"last Friday"*), currency terms, and category matching rules are hardcoded for English.
- Multilingual models (`Qwen2.5-0.5B`) were evaluated but are not packaged to minimize app storage and memory pressure on lower-tier mobile hardware.

#### What if I prefer manual entry?
Voice AI is completely opt-in. If you don't download the model pack, Cashflow works normally as a manual expense tracker and safe-to-spend calculator without consuming extra device storage.

