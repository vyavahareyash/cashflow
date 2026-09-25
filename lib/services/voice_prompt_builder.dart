import 'dart:convert';

import 'package:intl/intl.dart';

import '../models/account_model.dart';
import '../models/category_model.dart';

/// Constructs dynamically grounded ChatML prompts for SmolLM2-360M-Instruct (ADR-0005).
///
/// Injects current calendar anchor and active SQLite accounts and categories
/// so the SLM directly outputs corresponding SQLite foreign keys.
class VoicePromptBuilder {
  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// Formats anchor date as `YYYY-MM-DD (DayOfWeek)`.
  static String formatAnchorDate(DateTime anchorDate) {
    final ymd = DateFormat('yyyy-MM-dd').format(anchorDate);
    final dayOfWeek = _weekdays[anchorDate.weekday - 1];
    return '$ymd ($dayOfWeek)';
  }

  static String _sanitizeChatMl(String input) {
    return input
        .replaceAll('<|im_start|>', '')
        .replaceAll('<|im_end|>', '')
        .replaceAll('<|endoftext|>', '');
  }

  /// Builds a grounded ChatML prompt for entity extraction.
  static String buildPrompt({
    required String transcript,
    required DateTime anchorDate,
    required List<Account> accounts,
    required List<Category> categories,
  }) {
    final cleanTranscript = _sanitizeChatMl(transcript);
    final anchorStr = formatAnchorDate(anchorDate);

    final accountsPayload = accounts.map((a) {
      return {'id': a.id, 'name': _sanitizeChatMl(a.name), 'type': a.type};
    }).toList();

    final categoriesPayload = categories.map((c) {
      return {'id': c.id, 'name': _sanitizeChatMl(c.name), 'type': c.type};
    }).toList();

    final accountsJson = jsonEncode(accountsPayload);
    final categoriesJson = jsonEncode(categoriesPayload);

    return '''<|im_start|>system
You are an offline personal finance transaction extraction engine.
Extract all spoken financial transactions from the user speech into a JSON array of objects.

Calendar Anchor:
today: $anchorStr

Active User Accounts:
$accountsJson

Active User Categories:
$categoriesJson

Extraction Instructions:
1. "type": Classify as "expense", "income", or "transfer".
   - If salary, paycheck, deposit, or income received -> "income".
   - If moving funds between accounts (e.g., "moved 100 from Checking to Savings") -> "transfer".
   - Otherwise -> "expense".
2. "amount": A positive decimal number representing the monetary value.
3. "account_id": Integer ID of the active user account used. If account cannot be identified, emit null.
4. "destination_account_id": Integer ID of the destination account if type is "transfer", otherwise null.
5. "category_id": Integer ID of the matching user category if type is "expense", otherwise null.
6. "date": ISO date "YYYY-MM-DD". Calculate relative dates ("yesterday", "last Friday", "today") deterministically using the calendar anchor.
7. "note": Concise 1-4 word contextual label for the transaction:
   - For expenses: The specific item, merchant, or service (e.g., "Starbucks Coffee", "Walmart Groceries", "Gas").
   - For transfers: "Transfer: [Source Account] -> [Destination Account]" (e.g., "Transfer: Checking -> Savings").
   - For incomes: Purpose or source (e.g., "Salary", "Freelance Payment").
   - CRITICAL: "note" must NEVER be the raw voice transcript or full sentence. Do NOT include amounts, currency words, dates, or payment account names in "note".

Multi-Transaction Rules:
- If user dictates multiple transactions in a monologue, emit a separate JSON object for each transaction.
- Example: "Spent 5 on coffee at Starbucks with Chase and 45 for groceries at Walmart on Checking yesterday"
  -> notes must be "Starbucks Coffee" and "Walmart Groceries".
- Example: "Moved 200 from Checking to Savings and received 3000 salary into Checking"
  -> notes must be "Transfer: Checking -> Savings" and "Salary".

Output MUST strictly be a JSON array conforming to the grammar without any Markdown formatting or commentary.
<|im_end|>
<|im_start|>user
$cleanTranscript
<|im_end|>
<|im_start|>assistant
''';
  }
}
