# Cashflow Agent Instructions

Guidance for autonomous agents working in this repository. Keep modifications tightly scoped, preserve offline-first guarantees, and run tests sequentially.

## Invariants & Rules

- **Offline-only**: Cashflow has zero cloud backends and zero network dependencies. Never add remote telemetry, analytics, or network-dependent packages.
- **SQLite Concurrency**: Always run tests with `--concurrency=1` (`flutter test --concurrency=1`) to prevent database file lock collisions.
- **State Flow**: State mutations must increment `DatabaseHelper.dataRevision`. UI screens listen via `ListenableBuilder` or `AnimatedBuilder`.
- **Domain Terms**: Consult [CONTEXT.md](./CONTEXT.md) before naming new concepts, models, or UI copy.

## Context Pointers

Consult detailed references on demand when handling specific feature areas:

- **Architecture & State**: See [ARCHITECTURE.md](docs/engineering/ARCHITECTURE.md) when altering database models, tables, reactive state flow, or transaction integrity.
- **Calculations & Formulas**: See [CALCULATIONS.md](docs/engineering/CALCULATIONS.md) when updating Safe-to-Spend Usable Balance, salary cycle boundaries, or daily burn pace ratios.
- **Development & Commands**: See [DEVELOPMENT.md](docs/engineering/DEVELOPMENT.md) when setting up environments, running emulators, executing static checks, or managing screenshot automation.
- **Architectural Decisions**: See [docs/adr/](docs/adr/) when revisiting or evaluating trade-offs for core state, goal locking, or budget tracking.
- **Product Specification**: See [SPECIFICATION.md](docs/product/SPECIFICATION.md) when verifying user-facing feature requirements and transaction lifecycle rules.
- **User Experience & Walkthrough**: See [FEATURE_GUIDE.md](docs/user/FEATURE_GUIDE.md) when modifying UI flows, privacy mode, or settings.
