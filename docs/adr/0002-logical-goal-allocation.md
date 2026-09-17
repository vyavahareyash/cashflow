# 2. Logical Sinking Fund Goal Allocations

## Status
Accepted

## Context
Savings goals and sinking funds often require users to open distinct bank accounts in traditional banking setups. In personal budgeting apps, forcing 1:1 physical account-to-goal mapping creates friction when users hold money in a single checking or savings account.

## Decision
We implemented virtual envelope reservations via the `locked_allocations` table. Allocating money to a goal logically commits funds from an existing physical account without altering the account's physical balance row. Safe-to-Spend Usable Balance subtracts these locked allocations in real-time.

## Consequences
- Users can create unlimited goals and allocate money across any combination of accounts without moving real bank funds.
- Physical balances reflect real-world bank statements at all times.
- Spending money against a goal reduces both physical balance and locked balance simultaneously, keeping Usable Balance invariant.
