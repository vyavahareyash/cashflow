# Cashflow Mathematical Formulas & Calculation Logic

This document specifies the exact mathematical formulas, constraints, boundary logic, and invariants governing all financial calculations in Cashflow.

---

## 1. Safe-to-Spend Usable Balance

The core metric displayed on the dashboard hero card.

### Mathematical Definition

$$\text{Total Physical} = \sum_{a \in \text{Accounts}} a.\text{balance}$$

$$\text{Total Locked} = \sum_{l \in \text{LockedAllocations}} l.\text{amount}$$

$$\text{Usable Balance} = \max(\text{Total Physical} - \text{Total Locked},\, 0.0)$$

### Properties & Invariants
- **Non-negative guarantee**: Usable balance is clamped at `0.0` and can never become negative, even if physical accounts drop below locked allocations due to manual balance overrides or fees.
- **Budget independence**: Category monthly budgets do **not** deduct physical cash from usable balance. They represent spending awareness limits, not escrow accounts.
- **Goal Payment Invariance**: When settling a bill from a goal with amount $X$:
  $$\Delta \text{Physical} = -X, \quad \Delta \text{Locked} = -X$$
  $$\text{New Usable} = (\text{Physical} - X) - (\text{Locked} - X) = \text{Physical} - \text{Locked} = \text{Unchanged}$$
  Because the cash was already excluded from your usable balance when first locked, spending it to settle the goal does not lower your usable balance a second time.

---

## 2. Salary Cycle Boundary Resolution

Cashflow computes budget periods according to your chosen monthly payday ($S \in [1, 31]$) rather than arbitrary calendar months.

### Algorithm (`SalaryCycle.resolve`)

Let $T$ be the current date with year $Y_t$, month $M_t$, and day $D_t$.

1. **Active Cycle Start Date ($C_{\text{start}}$)**:
   - If $D_t \ge S$:
     $$\text{Start Year} = Y_t, \quad \text{Start Month} = M_t$$
   - If $D_t < S$:
     - If $M_t = 1$: $\text{Start Year} = Y_t - 1, \quad \text{Start Month} = 12$
     - If $M_t > 1$: $\text{Start Year} = Y_t, \quad \text{Start Month} = M_t - 1$
   - Let $D_{\max}$ be the number of days in the calculated start month.
   - $\text{Start Day} = \min(S, D_{\max})$.

2. **Next Cycle Payday ($C_{\text{next}}$)**:
   - The cycle that follows $C_{\text{start}}$ begins on payday of the month after $C_{\text{start}}$:
     - If $\text{Start Month} = 12$: $\text{Next Year} = \text{Start Year} + 1, \quad \text{Next Month} = 1$
     - Otherwise: $\text{Next Year} = \text{Start Year}, \quad \text{Next Month} = \text{Start Month} + 1$
   - $\text{Next Day} = \min(S, \text{DaysInMonth}(\text{Next Year}, \text{Next Month}))$.

3. **Active Cycle End Date ($C_{\text{end}}$)**:
   - The day immediately preceding $C_{\text{next}}$:
     $$C_{\text{end}} = C_{\text{next}} - 1\text{ day}$$

4. **Days Remaining in Cycle**:
   $$d_{\text{left}} = \max(C_{\text{end}}.\text{difference}(T).\text{inDays} + 1,\, 0)$$

---

## 3. Monthly Budget Spending & Daily Burn Pace

### Category Monthly Spending

For an active salary cycle $[C_{\text{start}}, C_{\text{end}}]$:

$$\text{Spent}_{\text{cat}} = \sum \Big\{ t.\text{amount} \;\Big|\; t.\text{category\_id} = \text{cat}.\text{id} \;\land\; t.\text{type} = \text{'expense'} \;\land\; t.\text{date} \in [C_{\text{start}}, C_{\text{end}}] \Big\}$$

$$\text{Total Spent This Month} = \sum_{\text{cat} \in \text{Categories}} \text{Spent}_{\text{cat}}$$

### Total Budget Limit & Remaining Budget

$$\text{Total Budget Limit} = \sum_{\text{cat} \in \text{Categories}} (\text{cat}.\text{monthly\_budget} \mathbin{??} 0.0)$$

$$\text{Remaining Budget} = \max(\text{Total Budget Limit} - \text{Total Spent This Month},\, 0.0)$$

### Daily Burn Pace

The sustainable daily expenditure rate remaining for the current cycle:

$$\text{Daily Burn Pace} = \begin{cases} 
\dfrac{\text{Remaining Budget}}{d_{\text{left}}}, & \text{if } d_{\text{left}} > 0 \\[1ex]
0.0, & \text{otherwise}
\end{cases}$$

---

## 4. Sinking Fund Pacing & Deadlines

For a goal with target amount $G_{\text{target}}$, current saved amount $G_{\text{saved}}$, and optional target date $D_{\text{target}}$:

### Remaining Target

$$G_{\text{remaining}} = \max(G_{\text{target}} - G_{\text{saved}},\, 0.0)$$

### Completion & Overdue Status

$$\text{isCompleted} \iff G_{\text{saved}} \ge G_{\text{target}}$$

$$\text{isOverdue} \iff (\lnot \text{isCompleted}) \land (D_{\text{target}} \ne \text{null}) \land (D_{\text{target}} < T)$$

### Recommended Monthly Savings Pace

If $D_{\text{target}}$ is set and in the future:

$$m_{\text{remaining}} = \max\Big((D_{\text{target}}.\text{year} - T.\text{year}) \times 12 + (D_{\text{target}}.\text{month} - T.\text{month}),\, 1\Big)$$

$$\text{Recommended Monthly Pace} = \frac{G_{\text{remaining}}}{m_{\text{remaining}}}$$

---

## 5. Analytics & Net Cashflow

### Net Cashflow (Monthly or YTD)

$$\text{Net Cashflow} = \sum t_{\text{income}}.\text{amount} - \sum t_{\text{expense}}.\text{amount}$$

- If $\text{Net Cashflow} \ge 0$: Positive cashflow (emerald theme accent).
- If $\text{Net Cashflow} < 0$: Deficit spending (danger red accent).

### Year-to-Date (YTD) Cumulative Metrics

Scoped strictly to calendar year $Y_t$:

$$\text{YTD Spending} = \sum \Big\{ t.\text{amount} \;\Big|\; t.\text{type} = \text{'expense'} \;\land\; t.\text{date}.\text{startsWith}(Y_t) \Big\}$$

$$\text{YTD Income} = \sum \Big\{ t.\text{amount} \;\Big|\; t.\text{type} = \text{'income'} \;\land\; t.\text{date}.\text{startsWith}(Y_t) \Big\}$$
