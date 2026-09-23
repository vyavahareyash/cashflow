# Cashflow Documentation Hub

This directory is the central documentation hub for Cashflow, containing user guides, mathematical specifications, system architecture, decision records, and product roadmaps.

---

## 📖 User Documentation

- [User Feature Guide](user/FEATURE_GUIDE.md) — Walkthrough of all capabilities (Safe-to-Spend balance, privacy mode, payday cycles, burn pace, sinking funds, celebratory flair, atomic transfers, analytics, and backup tools).
- [Onboarding & FAQ](user/FAQ_AND_ONBOARDING.md) — 3-step quickstart guide and answers to frequently asked questions about privacy, offline guarantees, bank decoupling, and envelope locking.
- [Future Vision: Offline Voice Journaling](user/VOICE_JOURNALING_VISION.md) — Upcoming on-device AI voice logging without forms or cloud backends.

---

## 🛠️ Engineering & Architecture

- [System Architecture & Schema Design](engineering/ARCHITECTURE.md) — Detailed three-tier architecture, reactive state flow (`DatabaseHelper.dataRevision`), Mermaid SQLite ER diagrams, and core business invariants.
- [Calculations & Mathematical Specifications](engineering/CALCULATIONS.md) — Authoritative mathematical definitions for Safe-to-Spend Usable Balance, salary cycle date boundaries, Daily Burn Pace ratios, and sinking fund allocations.
- [Development & Testing Guide](engineering/DEVELOPMENT.md) — Local developer environment setup, Flutter commands, Android emulator tips, screenshot automation, and SQLite concurrency testing rules.
- [Edge Voice AI Evaluation](engineering/RESEARCH_VOICE_AI_SELECTION.md) — Benchmark comparison and stack selection for on-device STT and SLMs.

---

## 🏛️ Architecture Decision Records (ADR)

- [ADR-0001: Reactive State Model](adr/0001-reactive-state-model.md) — Rationale for choosing `DatabaseHelper.dataRevision` with `ListenableBuilder` over external state frameworks.
- [ADR-0002: Logical Goal Allocations](adr/0002-logical-goal-allocation.md) — Implementing virtual envelope reservations without physical inter-bank account splitting.
- [ADR-0003: Tracking-Only Budget Model](adr/0003-tracking-only-budget-model.md) — Treating category budgets as pacing limits rather than escrow cash deductions.
- [ADR-0004: Single Concurrency SQLite Testing](adr/0004-single-concurrency-sqlite-testing.md) — Mandating `--concurrency=1` to eliminate SQLite file locking race conditions in tests.
- [ADR-0005: Offline Voice Transaction Entry](adr/0005-offline-voice-transaction-entry.md) — On-device Sherpa-ONNX (Moonshine) STT and GBNF-constrained SmolLM2 for voice journaling.
- [ADR-0006: Platform-Native On-Device STT](adr/0006-platform-native-on-device-stt.md) — Platform-native on-device speech recognition (Android SpeechRecognizer / iOS SFSpeechRecognizer) superseding custom Moonshine STT.

---

## 📋 Product & Planning

- [Product Specification](product/SPECIFICATION.md) — Locked behavioral contracts, 6-transaction type system, and feature inventory.
- [Offline Voice Journaling Specification](product/SPEC_OFFLINE_VOICE_JOURNALING.md) — Architectural spec, user stories, GBNF schema, and testing seams for offline voice logging.
- [Implementation Roadmap](product/ROADMAP.md) — Milestone phases, delivery sequencing, and acceptance principles.

---

## 🤖 Agent & Contributor Guidance

- [Domain Glossary (CONTEXT.md)](../CONTEXT.md) — Canonical domain glossary and terms to avoid.
- [Agent Guidance (AGENTS.md)](../AGENTS.md) — Lean instructions and progressive disclosure context pointers for AI agents.

---

## 🌐 Live Execution

GitHub is the source of truth for work that changes over time:

- [Issues](https://github.com/vyavahareyash/cashflow/issues) — Status, priorities, milestones, and dependencies.
- [Pull Requests](https://github.com/vyavahareyash/cashflow/pulls) — Implementation, review, and delivery history.
- [Repository](https://github.com/vyavahareyash/cashflow) — Source code, releases, and project configuration.
