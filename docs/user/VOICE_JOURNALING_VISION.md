# Upcoming Feature: Offline Voice Journaling

Manual expense logging can be tedious and repetitive. To make tracking effortless while preserving Cashflow's core privacy guarantees, we are designing **Offline Voice Journaling**—a fast, natural way to speak your daily transactions and log them in seconds.

---

## The Vision: Speak Your Day, Review in Seconds

Instead of opening forms, selecting accounts, and typing notes for each transaction one by one, you simply speak naturally:

> *"Paid \$4 for coffee on my credit card, spent \$65 on groceries with debit, and received \$150 freelance payment into checking."*

### How It Works

```
 🎙️ Speak Daily Note  ──►  🧠 On-Device AI  ──►  📋 Quick Review Sheet  ──►  💾 Save to Ledger
 (Natural voice stream)    (100% offline parsing)  (Tap to adjust chips)     (One-tap batch add)
```

1. **Speak Naturally**: Dictate one transaction or recap your entire day's spending in a single voice note.
2. **On-Device Intelligence**: The app transcribes your voice and extracts the amounts, accounts, categories, dates, and transaction types without sending a single byte over the internet.
3. **Interactive Review Staging**: Parsed transactions appear as draft cards. Missing or inferred fields are clearly highlighted for quick review.
4. **One-Tap Approval**: Tweak any details directly on screen, then tap **Approve All** to commit them directly to your local ledger.

---

## 100% Private, 100% Offline

Most voice assistants send your audio to remote cloud servers for transcription and processing. Cashflow refuses to compromise your personal financial privacy:

* **Zero Cloud Backends**: Audio transcription and entity extraction run directly on your smartphone's hardware.
* **Zero Audio Persistence**: Your voice recordings are processed in memory and permanently deleted immediately after transcription. No voice memos or audio files are kept on disk.
* **Optional, Opt-in Setup**: Base app remains lightweight (~30MB). You choose whether and when to download the compact offline AI model pack over Wi-Fi.
* **No Subscriptions or Accounts**: Fully open-source and free, with zero external service dependencies.

---

## Current Status & Next Steps

This feature is currently in design and architecture planning:
* Architectural specifications and benchmark evaluations are detailed in [ADR-0005](../adr/0005-offline-voice-transaction-entry.md) and [AI Stack Research](../engineering/RESEARCH_VOICE_AI_SELECTION.md).
* Follow along or contribute feedback on the [GitHub Repository](https://github.com/vyavahareyash/cashflow).
