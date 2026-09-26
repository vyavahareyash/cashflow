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

    final sampleSourceAcc = accounts.isNotEmpty
        ? _sanitizeChatMl(accounts.first.name)
        : 'Primary Account';
    final sampleDestAcc = accounts.length > 1
        ? _sanitizeChatMl(accounts[1].name)
        : 'Secondary Account';
    final sampleIncomeCat = categories
        .where((c) => c.isIncome)
        .firstOrNull
        ?.name;
    final incomeCatExample = sampleIncomeCat != null
        ? _sanitizeChatMl(sampleIncomeCat)
        : 'Salary';

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
   - If salary, paycheck, deposit, cashback, refund, reimbursement, or income received -> "income".
   - If moving funds between accounts (e.g., "moved 100 from $sampleSourceAcc to $sampleDestAcc") -> "transfer".
   - Otherwise -> "expense".
2. "amount": A positive decimal number representing the monetary value.
3. "account_id": Integer ID of the active user account used. If account cannot be identified, emit null.
4. "destination_account_id": Integer ID of the destination account if type is "transfer", otherwise null.
5. "category_id": Integer ID of the matching user category if type is "expense" or "income", otherwise null.
6. "date": ISO date "YYYY-MM-DD". Calculate relative dates ("yesterday", "last Friday", "today") deterministically using the calendar anchor.
7. "note": Concise 1-4 word contextual label specifying the exact product, service, merchant, or income source:
   - For expenses: ALWAYS include the specific product name, service name, or merchant purchased (e.g., "Starbucks Coffee", "Milk", "Bike", "Uber Ride", "Netflix Subscription", "iPhone Charger"). Extract ONLY the product/service name, NEVER account info. If the user specifies an item or merchant, put that exact product/service name in the note.
   - For incomes: Specific source or service (e.g., "$incomeCatExample", "Salary", "Freelance Design", "Cashback", "Tax Refund").
   - For transfers: "Transfer: [Source Account] -> [Destination Account]" (e.g., "Transfer: $sampleSourceAcc -> $sampleDestAcc").
   - CRITICAL: "note" must NEVER be the raw voice transcript or full sentence. Do NOT include amounts, currency words, dates, prepositions like "from [Account]" or "with [Account]", or payment account names in "note".
     Example: "spent 150 on bike from $sampleSourceAcc" -> "note" MUST be "Bike" (NEVER "Bike from $sampleSourceAcc").

Examples & Multi-Transaction Rules:
- Example: "Spent 150 on bike from $sampleSourceAcc"
  -> note must be "Bike" (product only, never include account info like "$sampleSourceAcc" in note).
- Example: "Spent 5 on coffee with $sampleSourceAcc and 45 for groceries on $sampleSourceAcc yesterday"
  -> notes must be specific product/service ("Coffee", "Groceries").
- Example: "Moved 200 from $sampleSourceAcc to $sampleDestAcc and received 3000 $incomeCatExample into $sampleSourceAcc"
  -> notes must be "Transfer: $sampleSourceAcc -> $sampleDestAcc" and "$incomeCatExample".
- If user dictates multiple transactions in a monologue, emit a separate JSON object for each transaction.

Output MUST strictly be a JSON array conforming to the grammar without any Markdown formatting or commentary.
<|im_end|>
<|im_start|>user
$cleanTranscript
<|im_end|>
<|im_start|>assistant
''';
  }
}
