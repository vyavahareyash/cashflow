# 1. Reactive State Model via Database Revision Notifier

## Status
Accepted

## Context
Cashflow is a local-first SQLite application where mutations occur across various screens (quick actions, modals, details screens). We needed a lightweight reactive state mechanism to trigger asynchronous queries on active screens without heavy third-party state managers like Bloc, Riverpod, or Redux.

## Decision
We chose a global `ValueNotifier<int> DatabaseHelper.dataRevision` incremented atomically after successful SQLite write transactions. Active presentation screens wrap their content in `ListenableBuilder` or `AnimatedBuilder` to reload fresh SQLite data on change.

## Consequences
- Zero external state management dependencies in `pubspec.yaml`.
- Guarantees zero stale-cache bugs across tabs because data is always queried fresh from SQLite on mutation.
- Does not scale to millions of micro-updates per second, which is non-applicable for personal manual expense logging.
