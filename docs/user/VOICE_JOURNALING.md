# Offline Voice Journaling (AI-Powered)

Cashflow is more than a manual logbook and safe-to-spend planning calculator. It features **100% Offline Voice Journaling**—an on-device AI system that eliminates the primary reason people abandon budgeting apps: **manual transaction friction**.

---

## Why Voice Journaling?

The #1 point of failure in personal finance tracking is **form fatigue**. At the end of a busy day, opening multiple forms, typing amounts, picking accounts, and categorizing transactions one-by-one leads to skipped entries, delayed logging, and eventually app abandonment.

Existing voice assistants and AI expense apps "solve" this by harvesting your audio streams and personal financial data to remote cloud servers.

**Cashflow gives you the best of both worlds**:
- **Effortless Capture**: Speak your day naturally in a single spoken monologue.
- **Total Privacy**: 100% on-device processing with zero cloud backends, zero telemetry, and zero audio persistence.

---

## The Workflow: Speak Naturally, Review in Seconds

```
 🎙️ Speak Naturally  ──►  🧠 On-Device AI  ──►  📋 Staging Sheet  ──►  💾 Atomic Commit
 (Continuous monologue)   (Speech & Neural Model)   (Interactive chips)     (One-tap batch save)
```

Instead of filling out form after form, simply tap the **Microphone** button and speak naturally:

> *"Spent \$4 on coffee with Chase, bought groceries for \$65 using debit, and received a \$150 freelance payment into checking yesterday."*

### 1. Continuous Monologue Capture
Dictate one transaction or recap your entire day's spending in a single voice note. The recording modal displays a live audio visualizer and real-time streaming transcript as you speak.

### 2. Intelligent On-Device Extraction
When you tap stop, Cashflow's on-device neural model:
- **Grounds entities**: Matches spoken payment methods against your active accounts (*e.g., "Chase", "Cash", "Debit"*).
- **Categorizes expenses**: Maps items (*"coffee", "groceries", "fuel"*) directly to your existing budget categories.
- **Resolves relative dates**: Converts phrases like *"yesterday"*, *"last Friday"*, or *"two days ago"* into exact calendar dates.
- **Classifies transaction types**: Distinguishes between expenses, income, and inter-account transfers from conversational context.
- **Applies smart defaults**: Automatically defaults unassigned accounts to your primary account with an audit flag.

### 3. Interactive Review Staging Sheet
Extracted transactions appear as draft cards in a structured staging sheet:
- **Visual Warning Badges**: Missing or inferred accounts/categories are highlighted with distinct badges so you know what needs verification.
- **Interactive Inline Chips**: Tap any chip (**Amount**, **Account**, **Category**, **Date**) to adjust values in-place without leaving the sheet.
- **Swipe to Delete**: Swipe away any erroneous or duplicate card.
- **Privacy Mode Compatible**: When Privacy Mode is active, monetary values on draft cards display bullet masks (`$••••••`).

### 4. Flexible Batch Commit
- **Approve All**: Tap once to commit all validated transactions into your local SQLite ledger in a single atomic transaction.
- **Approve Valid**: If one card needs clarification, tap "Approve Valid" to commit completed entries while retaining incomplete ones on screen so you never lose progress.
- **Clean Discard**: Dismissing the sheet without approving discards in-memory drafts cleanly, leaving zero orphaned records in your database.

---

## Privacy & Invariants

Cashflow adheres to uncompromising privacy guarantees:

| Principle | Guarantee |
| :--- | :--- |
| **Zero Cloud Backends** | All speech recognition and neural extraction execute locally on your device's hardware. |
| **Zero Audio Persistence** | Audio recordings are held in temporary memory and permanently purged immediately upon transcription completion or session cancel. |
| **Opt-in Setup** | Base app download is ultra-lightweight (~30 MB). The neural model pack is strictly opt-in and downloaded only when you request it. |
| **Wi-Fi Gated Downloads** | Model downloads default to Wi-Fi only, with explicit mobile data warnings to prevent surprise cellular bandwidth consumption. |
| **Cryptographic Integrity** | Downloaded neural model weights undergo SHA-256 cryptographic verification before loading. Corrupted files are rejected and purged. |
| **On-Demand Memory Lifecycle** | Model weights are loaded into device RAM only while the voice session is active and deallocated immediately upon dismissal to prevent background battery drain. |

---

## Getting Started

### Step 1: Enable Voice AI & Download Models
1. Open Cashflow and navigate to **Settings & Data** (or tap the microphone button on the dashboard).
2. Scroll to the **Voice AI & Offline Models** section.
3. Tap **Download Model Pack (~270 MB)** over Wi-Fi.
4. Cashflow downloads the quantized `SmolLM2-360M` neural model with verified SHA-256 integrity. Speech recognition utilizes your device's built-in platform engine (Android SpeechRecognizer / iOS SFSpeechRecognizer) with zero additional weights needed.

### Step 2: Dictate Transactions
1. Tap the prominent **Microphone** button at the center of the bottom navigation bar.
2. Grant microphone permissions if prompted.
3. Speak your transactions naturally, then tap the checkmark when done.
4. Review your draft cards in the staging sheet, edit any chips as desired, and tap **Approve All**.
5. Your transactions instantly appear in your Activity Ledger and Safe-to-Spend Usable Balance.

---

## Technical Specifications & Architecture

For engineering details, schema contracts, and benchmark evaluations:
- **Architectural Specification**: [Offline Voice Journaling Spec](../product/SPEC_OFFLINE_VOICE_JOURNALING.md)
- **ADR-0005**: [Offline Voice Transaction Entry](../adr/0005-offline-voice-transaction-entry.md)
- **ADR-0006**: [Platform-Native On-Device Speech Recognition](../adr/0006-platform-native-on-device-stt.md)
- **Model Selection & Benchmarks**: [Edge Voice AI Evaluation](../engineering/RESEARCH_VOICE_AI_SELECTION.md)
