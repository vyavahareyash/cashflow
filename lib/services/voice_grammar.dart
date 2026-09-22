import 'dart:convert';

/// Authoritative GBNF (GGML BNF) grammar specification for token-level
/// constrained decoding of financial transactions from SLM inference (ADR-0005).
class VoiceGrammar {
  /// Token-level GBNF grammar specification matching ADR-0005 contract.
  ///
  /// Forces SmolLM2-360M-Instruct logits to generate 100% syntactically valid
  /// JSON arrays containing transaction maps adhering strictly to [TransactionModel]
  /// fields and foreign keys.
  static const String transactionGrammar = r'''
root ::= "[" space (transaction ("," space transaction)*)? "]" space
transaction ::= "{" space "\"amount\"" space ":" space number "," space "\"type\"" space ":" space ("\"expense\"" | "\"income\"" | "\"transfer\"") "," space "\"account_id\"" space ":" space ([0-9]+ | "null") "," space "\"destination_account_id\"" space ":" space ([0-9]+ | "null") "," space "\"category_id\"" space ":" space ([0-9]+ | "null") "," space "\"date\"" space ":" space "\"20" [0-9] [0-9] "-" [0-1] [0-9] "-" [0-3] [0-9] "\"" "," space "\"note\"" space ":" space string space "}"
number ::= ("-"? [0-9]+ ("." [0-9]+)?)
string ::= "\"" ([^"\\] | "\\" (["\\/bfnrt] | "u" [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]))* "\""
space ::= [ \t\n\r]*
''';

  /// Validates whether a raw string conforms to the expected JSON schema emitted
  /// by [transactionGrammar]. Returns parsed maps if valid, null otherwise.
  static List<Map<String, dynamic>>? tryParseGrammarJson(String jsonString) {
    try {
      final trimmed = jsonString.trim();
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) return null;

      final result = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is! Map) return null;
        final map = Map<String, dynamic>.from(item);

        // Required schema keys
        if (!map.containsKey('amount') || map['amount'] is! num) return null;
        if (!map.containsKey('type') ||
            !['expense', 'income', 'transfer'].contains(map['type'])) {
          return null;
        }
        if (!map.containsKey('date') || map['date'] is! String) return null;
        if (!RegExp(r'^20\d{2}-[0-1]\d-[0-3]\d$').hasMatch(map['date'])) {
          return null;
        }
        if (!map.containsKey('note') || map['note'] is! String) return null;

        result.add(map);
      }
      return result;
    } catch (_) {
      return null;
    }
  }
}
