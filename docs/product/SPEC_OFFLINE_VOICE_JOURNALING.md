# Specification: Offline Voice Transaction Journaling

**Document**: `docs/product/SPEC_OFFLINE_VOICE_JOURNALING.md`  
**Reference**: [ADR-0005](../adr/0005-offline-voice-transaction-entry.md), [AI Stack Research](../engineering/RESEARCH_VOICE_AI_SELECTION.md)  
**Status**: Ready for Implementation  
**Triage Label**: `ready-for-agent`

---

## Problem Statement

Manual expense and income logging creates friction for users. At the end of a busy day, opening forms, typing amounts, selecting accounts, and picking categories for several transactions in sequence leads to journaling fatigue, delayed entries, and abandonment. Existing voice logging alternatives rely on remote cloud APIs that harvest personal financial data and audio streams, directly violating user privacy and requiring continuous internet access.

---

## Solution

A private, 100% offline voice journaling system integrated directly into the Cashflow mobile app. Users tap a microphone button and speak their daily financial activity naturally in an unstructured monologue. On-device AI models transcribe the audio and extract structured draft transactions anchored to the user's existing accounts and categories. Extracted transactions are presented in an interactive staging sheet for rapid review, inline chip editing, and one-tap atomic commit to the local SQLite database.

---

## User Stories

1. As a busy user, I want to dictate multiple transactions in a single continuous spoken monologue, so that I do not have to record each expense individually.
2. As a privacy-focused user, I want all speech transcription and entity extraction to run 100% locally on my phone, so that my voice audio and financial records are never sent over the internet.
3. As a user on the move, I want a prominent microphone entry point accessible from the main dashboard, so that I can start dictating with a single tap.
4. As a user with multiple payment methods, I want the system to match spoken account names (e.g., "Chase", "Cash", "Debit") against my active accounts, so that funds are deducted from the correct balance automatically.
5. As a user tracking monthly category budgets, I want the system to map spoken items (e.g., "coffee", "gas", "groceries") to my existing categories, so that category pacing and burn rates stay up to date.
6. As a user catching up on past expenses, I want to speak relative dates such as "yesterday" or "last Friday", so that the app calculates and assigns the correct calendar date without manual calendar picking.
7. As a user who frequently omits the account name when speaking, I want the app to default unassigned accounts to my primary account, so that I can speak quickly without repetitive phrasing.
8. As a user auditing extracted transactions, I want missing or inferred fields to be highlighted with distinct warning badges, so that I immediately know which items require review before saving.
9. As a user making quick corrections, I want interactive inline chips for Amount, Account, Category, and Date on each draft card, so that I can adjust values directly in place without navigating away.
10. As a user reviewing extracted entries, I want to swipe away or delete any duplicate or erroneous draft card, so that incorrect entries are discarded prior to database insertion.
11. As a user with accurate transcriptions, I want an "Approve All" action that commits all valid drafts in a single batch, so that I can finish logging in seconds.
12. As a user with one incomplete draft among several valid ones, I want to commit all valid entries while keeping the incomplete entry on screen, so that I do not lose progress while fixing the remaining item.
13. As a user conscious of device storage, I want raw audio files to be deleted immediately from disk once transcription completes, so that voice memos never accumulate on my device.
14. As a user on a metered mobile plan, I want model downloads to be strictly opt-in with explicit Wi-Fi toggles and progress indicators, so that the app never consumes cellular data unexpectedly.
15. As a security-conscious user, I want downloaded neural model weights to undergo cryptographic SHA-256 verification before being loaded, so that corrupted or malicious files are never executed.
16. As a user with a budget smartphone, I want AI model weights loaded into memory on-demand and deallocated immediately upon closing the voice modal, so that the app avoids out-of-memory crashes and battery drain.
17. As a user logging non-expense transactions, I want the voice parser to recognize income and inter-account transfers from context, so that diverse transaction types are staged accurately.
18. As a user operating the app in public with Privacy Mode enabled, I want monetary amounts in the voice staging sheet to respect bullet masks (`$••••••`), so that bystanders cannot view transaction amounts.
19. As a user who prefers manual input, I want the voice feature to remain entirely optional and non-intrusive, so that manual form entry remains fully functional without downloading any AI models.
20. As a user recovering from an interrupted session, I want closing the staging sheet to discard uncommitted draft transactions cleanly, preventing orphaned draft records in SQLite.

---

## Implementation Decisions

### Core Architecture & Modules
- **Audio Capture Module**: Captures microphone audio using the `record` package configured strictly for 16kHz mono 16-bit PCM WAV into a temporary file, and executes immediate file deletion upon transcription completion.
- **Speech-to-Text Module**: Platform-native on-device speech recognition via `speech_to_text` (Android `SpeechRecognizer` / iOS `SFSpeechRecognizer`) configured for forced offline mode (ADR-0006), eliminating external model downloads and reducing RAM consumption.
- **Entity Extraction Module**: Executes `SmolLM2-360M-Instruct` (Q4_K_M, ~230MB) via `llama_cpp_dart` in an isolated background Dart thread (`LlamaParent`), with GBNF grammar-constrained decoding.
- **Model Weight Manager**: Manages explicit, user-initiated Wi-Fi downloads of verified static model bundles with SHA-256 checksum verification, stored in the application documents directory.
- **Voice Transaction Staging UI**: Modal bottom sheet presenting in-memory `Draft Transaction` cards with inline interactive chips, visual validation badges, and partial batch commit actions.

### Schema & Extraction Grammar Contract
From prototype verification, the SLM decoding is constrained at the token level by the following GBNF grammar:

```ebnf
root ::= "[\n" space (transaction (",\n" space transaction)*)? "\n]"
transaction ::= "{\n" space
  "\"amount\":" space number ",\n" space
  "\"type\":" space ("\"expense\"" | "\"income\"" | "\"transfer\"") ",\n" space
  "\"account_id\":" space [0-9]+ ",\n" space
  "\"category_id\":" space ([0-9]+ | "null") ",\n" space
  "\"date\":" space "\"20" [0-9] [0-9] "-" [0-1] [0-9] "-" [0-3] [0-9] "\",\n" space
  "\"note\":" space string "\n" space "}"
```

### Context & Prompt Grounding
- The system prompt dynamically injects the calendar anchor (`today: YYYY-MM-DD (DayOfWeek)`) along with active SQLite entities: `accounts: [{id, name}]` and `categories: [{id, name}]`.
- The SLM directly emits foreign keys matching existing SQLite records.

### Transaction Commit & State Notification
- Approved `Draft Transaction` items are committed inside a single atomic SQLite transaction (`db.transaction(...)`).
- A single increment of `DatabaseHelper.dataRevision` notifies all listening UI screens (`ListenableBuilder`) to reload fresh data simultaneously.

---

## Testing Decisions

### Test Quality & Philosophy
- Tests must strictly evaluate observable external behavior, database mutations, and UI state transitions—never private model weights or internal isolate message structures.

### Modules & Seams Tested
1. **`VoiceTransactionStagingSheet` (`WidgetTester`)**:
   - Primary seam testing the end-to-end presentation and commit flow.
   - Verifies draft card rendering, warning badge display on unassigned fields, inline chip edit mutations, and "Approve All" / "Approve Valid" batch database insertions.
2. **`VoiceEntityParser` (Headless Dart Unit Tests)**:
   - Evaluates deterministic text-to-JSON parsing against injected mock account/category lists and anchor dates without loading native neural binaries.
   - Validates relative date math ("yesterday", "last Sunday") and multi-clause transaction splitting.
3. **`ModelManagementService` (Unit Tests)**:
   - Validates SHA-256 checksum integrity verification, progress reporting streams, and corrupted file rejection.

### Prior Art in Codebase
- `test/income_flow_test.dart` & `test/transfer_flow_test.dart`: Patterns for verifying atomic SQLite transaction commits and balance updates.
- `test/p1_dialog_and_layout_test.dart`: Patterns for testing bottom sheet user interactions and validation triggers.
- `test/dashboard_privacy_test.dart`: Patterns for testing Privacy Mode bullet masking across UI components.

---

## Out of Scope

- Multi-turn conversational voice dialogue or audio question-answering.
- Cloud transcription or cloud LLM fallbacks (strictly forbidden by offline-only invariant).
- Real-time continuous live streaming transcription during speech (uses push-to-talk completed recording).
- Automated recurring transaction scheduling from voice commands.

---

## Further Notes

- Authoritative ADR: [ADR-0005: Offline Voice Transaction Entry](../adr/0005-offline-voice-transaction-entry.md).
- Detailed model benchmarks and stack comparisons: [RESEARCH_VOICE_AI_SELECTION.md](../engineering/RESEARCH_VOICE_AI_SELECTION.md).
- Canonical domain vocabulary: `Draft Transaction`, `Offline AI Model Pack`, `Voice Transaction Staging` in `CONTEXT.md`.
