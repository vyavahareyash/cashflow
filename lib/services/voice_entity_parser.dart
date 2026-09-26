import 'dart:convert';

import 'package:intl/intl.dart';

import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/draft_transaction.dart';
import 'voice_grammar.dart';

/// Transforms speech transcription or SLM-generated JSON into structured,
/// validated [DraftTransaction] domain models (ADR-0005, US 1, 4, 5, 6, 7, 17).
class VoiceEntityParser {
  static const List<String> _weekdays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  /// Resolves relative date phrases ("today", "yesterday", "last Friday") deterministically
  /// relative to [anchorDate] (US 6). Returns formatted 'YYYY-MM-DD'.
  static String resolveRelativeDate(String phrase, DateTime anchorDate) {
    final lower = phrase.trim().toLowerCase();

    // Already in YYYY-MM-DD format
    if (RegExp(r'^20\d{2}-[0-1]\d-[0-3]\d$').hasMatch(lower)) {
      return lower;
    }

    if (lower == 'today') {
      return DateFormat('yyyy-MM-dd').format(anchorDate);
    }

    if (lower == 'yesterday') {
      final target = anchorDate.subtract(const Duration(days: 1));
      return DateFormat('yyyy-MM-dd').format(target);
    }

    if (lower == 'the day before yesterday') {
      final target = anchorDate.subtract(const Duration(days: 2));
      return DateFormat('yyyy-MM-dd').format(target);
    }

    // Check for weekday names (e.g. "last Friday", "Friday", "last Sunday")
    for (int i = 0; i < _weekdays.length; i++) {
      final weekdayName = _weekdays[i];
      if (lower.contains(weekdayName)) {
        final targetWeekday = i + 1; // 1 = Monday ... 7 = Sunday
        int daysAgo = ((anchorDate.weekday - targetWeekday) % 7 + 7) % 7;
        if (daysAgo == 0) {
          // "last [weekday]" or "[weekday]" refers strictly to previous occurrence
          daysAgo = 7;
        }
        final target = anchorDate.subtract(Duration(days: daysAgo));
        return DateFormat('yyyy-MM-dd').format(target);
      }
    }

    // Default to anchor date if unparseable
    return DateFormat('yyyy-MM-dd').format(anchorDate);
  }

  /// Identifies the default primary account ID from [accounts] (US 7).
  static int? resolvePrimaryAccountId(
    List<Account> accounts, [
    int? preferredId,
  ]) {
    if (preferredId != null && accounts.any((a) => a.id == preferredId)) {
      return preferredId;
    }
    if (accounts.isEmpty) return null;

    // Prefer non-credit-card bank/checking/cash account
    final bankOrCash = accounts.firstWhere(
      (a) => !a.isCreditCard,
      orElse: () => accounts.first,
    );
    return bankOrCash.id;
  }

  /// Matches spoken text against active [accounts] (US 4).
  static Account? matchAccount(String speech, List<Account> accounts) {
    final lower = speech.toLowerCase();

    // 1. Exact match
    for (final acc in accounts) {
      if (lower == acc.name.toLowerCase()) return acc;
    }

    // 2. Account name contained in speech
    for (final acc in accounts) {
      if (lower.contains(acc.name.toLowerCase())) return acc;
    }

    // 3. Significant word in account name contained in speech (e.g. "Chase" in "Chase Sapphire")
    const genericWords = {'bank', 'account', 'card', 'the', 'my'};
    for (final acc in accounts) {
      final words = acc.name.toLowerCase().split(RegExp(r'\s+'));
      for (final word in words) {
        if (word.length >= 3 && !genericWords.contains(word)) {
          final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b');
          if (pattern.hasMatch(lower)) {
            return acc;
          }
        }
      }
    }

    // 4. Speech contained in account name
    for (final acc in accounts) {
      if (acc.name.toLowerCase().contains(lower) && lower.length >= 3) {
        return acc;
      }
    }

    // 5. Fallback heuristics for common types
    if (RegExp(r'\b(?:credit|card)\b').hasMatch(lower)) {
      final cc = accounts.where((a) => a.isCreditCard).firstOrNull;
      if (cc != null) return cc;
    }
    if (RegExp(r'\b(?:checking|bank)\b').hasMatch(lower)) {
      final chk = accounts
          .where(
            (a) =>
                a.name.toLowerCase().contains('checking') || a.type == 'Bank',
          )
          .firstOrNull;
      if (chk != null) return chk;
    }
    if (RegExp(r'\b(?:savings|save)\b').hasMatch(lower)) {
      final sav = accounts
          .where(
            (a) =>
                a.name.toLowerCase().contains('savings') || a.type == 'Savings',
          )
          .firstOrNull;
      if (sav != null) return sav;
    }
    if (RegExp(r'\b(?:cash|wallet)\b').hasMatch(lower)) {
      final c = accounts
          .where(
            (a) => a.type == 'Cash' || a.name.toLowerCase().contains('cash'),
          )
          .firstOrNull;
      if (c != null) return c;
    }

    return null;
  }

  /// Matches spoken text or item keywords against active [categories] (US 5).
  static Category? matchCategory(String speech, List<Category> categories) {
    final lower = speech.toLowerCase();

    // 1. Exact category name match
    for (final cat in categories) {
      if (lower == cat.name.toLowerCase()) return cat;
    }

    // 2. Category name contained in speech
    for (final cat in categories) {
      if (lower.contains(cat.name.toLowerCase())) return cat;
    }

    // 3. Keyword semantic associations
    final foodKeywords = [
      'coffee',
      'latte',
      'starbucks',
      'diner',
      'lunch',
      'dinner',
      'breakfast',
      'subway',
      'mcdonalds',
      'burger',
      'pizza',
      'restaurant',
      'cafe',
      'food',
      'tea',
      'bakery',
      'snack',
    ];
    final groceryKeywords = [
      'grocery',
      'groceries',
      'walmart',
      'supermarket',
      'market',
      'target',
      'costco',
      'trader joe',
      'kroger',
      'safeway',
    ];
    final transportKeywords = [
      'gas',
      'fuel',
      'petrol',
      'uber',
      'lyft',
      'taxi',
      'transit',
      'bus',
      'train',
      'metro',
      'subway fare',
      'parking',
      'toll',
    ];
    final billKeywords = [
      'rent',
      'electricity',
      'water',
      'internet',
      'utility',
      'utilities',
      'wifi',
      'bill',
      'insurance',
    ];
    final entertainmentKeywords = [
      'movie',
      'cinema',
      'game',
      'netflix',
      'spotify',
      'concert',
      'entertainment',
      'subscription',
    ];

    bool containsAny(List<String> list) => list.any(lower.contains);

    if (containsAny(foodKeywords)) {
      final cat = categories.where((c) {
        final n = c.name.toLowerCase();
        return n.contains('food') ||
            n.contains('dining') ||
            n.contains('coffee') ||
            n.contains('restaurant');
      }).firstOrNull;
      if (cat != null) return cat;
    }

    if (containsAny(groceryKeywords)) {
      final cat = categories.where((c) {
        final n = c.name.toLowerCase();
        return n.contains('grocer') ||
            n.contains('food') ||
            n.contains('supermarket');
      }).firstOrNull;
      if (cat != null) return cat;
    }

    if (containsAny(transportKeywords)) {
      final cat = categories.where((c) {
        final n = c.name.toLowerCase();
        return n.contains('transport') ||
            n.contains('gas') ||
            n.contains('travel') ||
            n.contains('car');
      }).firstOrNull;
      if (cat != null) return cat;
    }

    if (containsAny(billKeywords)) {
      final cat = categories.where((c) {
        final n = c.name.toLowerCase();
        return n.contains('bill') || n.contains('util') || n.contains('rent');
      }).firstOrNull;
      if (cat != null) return cat;
    }

    if (containsAny(entertainmentKeywords)) {
      final cat = categories.where((c) {
        final n = c.name.toLowerCase();
        return n.contains('entertain') ||
            n.contains('leisure') ||
            n.contains('fun');
      }).firstOrNull;
      if (cat != null) return cat;
    }

    final cashbackKeywords = [
      'cashback',
      'cash back',
      'refund',
      'reimbursement',
      'reward',
      'rewards',
    ];
    final incomeKeywords = [
      'salary',
      'paycheck',
      'dividend',
      'interest',
      'freelance',
      'stipend',
      'bonus',
    ];

    if (containsAny(cashbackKeywords)) {
      final cat = categories.where((c) {
        final n = c.name.toLowerCase();
        return n.contains('cashback') ||
            n.contains('cash back') ||
            n.contains('refund') ||
            n.contains('reward');
      }).firstOrNull;
      if (cat != null) return cat;
    }

    if (containsAny(incomeKeywords)) {
      final cat = categories.where((c) {
        final n = c.name.toLowerCase();
        return n.contains('salary') ||
            n.contains('income') ||
            n.contains('dividend') ||
            n.contains('freelance') ||
            n.contains('bonus');
      }).firstOrNull;
      if (cat != null) return cat;
    }

    return null;
  }

  /// Maps SLM-generated JSON output conforming to [VoiceGrammar.transactionGrammar]
  /// into a list of [DraftTransaction] domain objects with default fallbacks (US 7, US 8).
  static List<DraftTransaction> parseJsonOutput(
    String jsonString, {
    required DateTime anchorDate,
    required List<Account> accounts,
    required List<Category> categories,
    int? primaryAccountId,
  }) {
    final effectivePrimaryId = resolvePrimaryAccountId(
      accounts,
      primaryAccountId,
    );
    var cleanJson = jsonString.trim();
    if (cleanJson.startsWith('```')) {
      cleanJson = cleanJson
          .replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*```$'), '')
          .trim();
    }

    List<dynamic> list;
    try {
      final decoded = jsonDecode(cleanJson);
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map<String, dynamic>) {
        list = [decoded];
      } else {
        return [];
      }
    } catch (_) {
      // If direct jsonDecode fails, try extracting array via regex
      final match = RegExp(r'\[[\s\S]*\]').firstMatch(cleanJson);
      if (match != null) {
        try {
          list = jsonDecode(match.group(0)!) as List;
        } catch (_) {
          return [];
        }
      } else {
        return [];
      }
    }

    final drafts = <DraftTransaction>[];

    for (final raw in list) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);

      double amount = 0.0;
      final rawAmount = map['amount'];
      if (rawAmount is num) {
        amount = rawAmount.toDouble();
      } else if (rawAmount is String) {
        amount = double.tryParse(rawAmount.replaceAll(',', '').trim()) ?? 0.0;
      }
      String type = (map['type'] as String?)?.toLowerCase() ?? 'expense';
      final String rawNote = (map['note'] as String?)?.trim() ?? '';

      // Date resolution
      String date = (map['date'] as String?) ?? '';
      if (!RegExp(r'^20\d{2}-[0-1]\d-[0-3]\d$').hasMatch(date)) {
        date = resolveRelativeDate(
          date.isNotEmpty ? date : 'today',
          anchorDate,
        );
      }

      // Account resolution & fallback (US 7)
      int? accountId = map['account_id'] as int?;
      bool hasUnassignedAccount = false;

      if (accountId == null || !accounts.any((a) => a.id == accountId)) {
        accountId = effectivePrimaryId;
        hasUnassignedAccount = true;
      }

      // Destination account for transfers (US 17)
      int? destinationAccountId;
      if (type == 'transfer') {
        destinationAccountId = map['destination_account_id'] as int?;
        if (destinationAccountId != null &&
            !accounts.any((a) => a.id == destinationAccountId)) {
          destinationAccountId = null;
        }
      }

      // Category resolution & validation (US 5, US 8)
      int? categoryId;
      bool hasUnassignedCategory = false;
      bool hasCategoryMismatch = false;

      if (type != 'transfer') {
        final rawCatId = map['category_id'] as int?;
        Category? resolvedCat;
        if (rawCatId != null) {
          resolvedCat = categories.where((c) => c.id == rawCatId).firstOrNull;
        }

        // Fallback: match category from raw speech or note if not emitted
        if (resolvedCat == null) {
          final speechOrNote = ((map['raw_speech'] as String?) ?? rawNote)
              .toLowerCase();
          if (speechOrNote.isNotEmpty) {
            resolvedCat = matchCategory(speechOrNote, categories);
          }
        }

        if (resolvedCat != null) {
          categoryId = resolvedCat.id;
          if (resolvedCat.isIncome && type == 'expense') {
            type = 'income';
          } else if (resolvedCat.isExpense && type == 'income') {
            hasCategoryMismatch = true;
          }
        } else if (type == 'expense') {
          hasUnassignedCategory = true;
        }
      }

      final sourceAcc = accounts.where((a) => a.id == accountId).firstOrNull;
      final destAcc = destinationAccountId != null
          ? accounts.where((a) => a.id == destinationAccountId).firstOrNull
          : null;
      final cat = categoryId != null
          ? categories.where((c) => c.id == categoryId).firstOrNull
          : null;

      final note =
          isContaminatedNote(
            rawNote,
            sourceAccount: sourceAcc,
            destinationAccount: destAcc,
            accounts: accounts,
          )
          ? generateContextualNote(
              rawText: rawNote,
              type: type,
              sourceAccount: sourceAcc,
              destinationAccount: destAcc,
              category: cat,
              accounts: accounts,
            )
          : rawNote;

      drafts.add(
        DraftTransaction(
          amount: amount,
          type: type,
          accountId: accountId,
          destinationAccountId: destinationAccountId,
          categoryId: categoryId,
          date: date,
          note: note,
          rawSpeech:
              (map['raw_speech'] as String?) ??
              (rawNote.isNotEmpty ? rawNote : null),
          hasUnassignedAccount: hasUnassignedAccount,
          hasUnassignedCategory: hasUnassignedCategory,
          hasCategoryMismatch: hasCategoryMismatch,
        ),
      );
    }

    return drafts;
  }

  /// Headless test input harness and offline heuristic fallback parser.
  /// Parses transcribed speech text deterministically without neural model binaries.
  static List<DraftTransaction> parseTranscriptionSample(
    String transcript, {
    required DateTime anchorDate,
    required List<Account> accounts,
    required List<Category> categories,
    int? primaryAccountId,
  }) {
    final effectivePrimaryId = resolvePrimaryAccountId(
      accounts,
      primaryAccountId,
    );
    final clauses = _splitMonologue(transcript);
    final drafts = <DraftTransaction>[];

    for (final clause in clauses) {
      final draft = _parseSingleClause(
        clause,
        anchorDate: anchorDate,
        accounts: accounts,
        categories: categories,
        primaryAccountId: effectivePrimaryId,
      );
      if (draft != null) {
        drafts.add(draft);
      }
    }

    return drafts;
  }

  /// Splits continuous monologue into distinct transaction clauses (US 1).
  static List<String> _splitMonologue(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return [];

    // Split on explicit connectors like " and ", " also ", "\n", ";", or commas preceding amounts / keywords
    final pattern = RegExp(
      r'(?:\b(?:and|also|then|plus|as well as)\b|[;\n]|,(?=\s*(?:\b(?:and|also|then|spent|paid|bought|moved|transfer|transferred|salary|deposit|received)\b|\$|\d)))',
      caseSensitive: false,
    );
    final rawParts = clean.split(pattern);

    final parts = <String>[];
    for (final part in rawParts) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) parts.add(trimmed);
    }

    return parts.isEmpty ? [clean] : parts;
  }

  /// Parses an individual clause into a [DraftTransaction].
  static DraftTransaction? _parseSingleClause(
    String clause, {
    required DateTime anchorDate,
    required List<Account> accounts,
    required List<Category> categories,
    required int? primaryAccountId,
  }) {
    final lower = clause.toLowerCase();

    // 1. Extract Amount
    final amountMatch = RegExp(
      r'(?:\$|₹|rs\.?|inr|\b)\s*(\d+(?:\.\d{1,2})?|\.\d{1,2})\s*(?:dollars?|bucks?|rupees?|rs\.?|inr|cents?|usd|\$|₹|\b)',
      caseSensitive: false,
    ).firstMatch(lower);

    double? amount;
    if (amountMatch != null) {
      amount = double.tryParse(amountMatch.group(1)!);
    } else {
      // General number match
      final numMatch = RegExp(r'\b(\d+(?:\.\d{1,2})?|\.\d{1,2})\b')
          .firstMatch(lower);
      if (numMatch != null) {
        amount = double.tryParse(numMatch.group(1)!);
      }
    }

    if (amount == null || amount <= 0) return null;

    // 2. Classify Transaction Type (US 17) & Match Category
    final matchedCat = matchCategory(lower, categories);

    final isIncome =
        lower.contains('salary') ||
        lower.contains('paycheck') ||
        lower.contains('deposited') ||
        lower.contains('deposit') ||
        lower.contains('earned') ||
        lower.contains('income') ||
        lower.contains('cashback') ||
        lower.contains('cash back') ||
        lower.contains('refund') ||
        lower.contains('reimbursement') ||
        lower.contains('reimbursed') ||
        lower.contains('bonus') ||
        lower.contains('dividend') ||
        lower.contains('interest') ||
        lower.contains('reward') ||
        lower.contains('credited') ||
        (lower.contains('received') && !lower.contains('received from'));

    final isTransfer =
        lower.contains('transfer') ||
        lower.contains('moved') ||
        lower.contains('move') ||
        (lower.contains('from') && lower.contains('to'));

    String type = 'expense';
    int? sourceAccountId;
    int? destAccountId;

    if (isTransfer) {
      type = 'transfer';
      // Try to extract from X to Y
      final transferMatch = RegExp(
        r'from\s+([a-zA-Z\s]+?)\s+to\s+([a-zA-Z\s]+?)(?:\s+yesterday|\s+today|\s+last|\s*$)',
        caseSensitive: false,
      ).firstMatch(lower);

      if (transferMatch != null) {
        final srcStr = transferMatch.group(1)!.trim();
        final dstStr = transferMatch.group(2)!.trim();
        sourceAccountId = matchAccount(srcStr, accounts)?.id;
        destAccountId = matchAccount(dstStr, accounts)?.id;
      }
    } else if (isIncome || (matchedCat != null && matchedCat.isIncome)) {
      type = 'income';
    }

    // 3. Match Account if not transfer
    bool hasUnassignedAccount = false;
    if (type != 'transfer') {
      final matchedAcc = matchAccount(lower, accounts);
      if (matchedAcc != null) {
        sourceAccountId = matchedAcc.id;
      } else {
        sourceAccountId = primaryAccountId;
        hasUnassignedAccount = true;
      }
    } else {
      if (sourceAccountId == null) {
        sourceAccountId = primaryAccountId;
        hasUnassignedAccount = true;
      }
    }

    // 4. Match Category (expenses and income)
    int? categoryId;
    bool hasUnassignedCategory = false;
    bool hasCategoryMismatch = false;

    if (type != 'transfer') {
      if (matchedCat != null) {
        if (type == 'income') {
          if (matchedCat.isIncome) {
            categoryId = matchedCat.id;
          } else {
            hasCategoryMismatch = true;
            categoryId = matchedCat.id;
          }
        } else {
          // type == 'expense'
          if (matchedCat.isExpense) {
            categoryId = matchedCat.id;
          } else {
            // Category matched an income category -> reconcile type to income
            type = 'income';
            categoryId = matchedCat.id;
          }
        }
      } else if (type == 'expense') {
        hasUnassignedCategory = true;
      }
    }

    // 5. Relative Date Resolution (US 6)
    String date = DateFormat('yyyy-MM-dd').format(anchorDate);
    if (lower.contains('yesterday')) {
      date = resolveRelativeDate('yesterday', anchorDate);
    } else if (lower.contains('the day before yesterday')) {
      date = resolveRelativeDate('the day before yesterday', anchorDate);
    } else {
      for (final wd in _weekdays) {
        if (lower.contains(wd)) {
          date = resolveRelativeDate(wd, anchorDate);
          break;
        }
      }
    }

    // 6. Formulate clean contextual note from transaction context
    final matchedSourceAcc = accounts
        .where((a) => a.id == sourceAccountId)
        .firstOrNull;
    final matchedDestAcc = destAccountId != null
        ? accounts.where((a) => a.id == destAccountId).firstOrNull
        : null;
    final matchedCatFinal = categoryId != null
        ? categories.where((c) => c.id == categoryId).firstOrNull
        : null;

    final String note = generateContextualNote(
      rawText: clause,
      type: type,
      sourceAccount: matchedSourceAcc,
      destinationAccount: matchedDestAcc,
      category: matchedCatFinal,
      accounts: accounts,
    );

    return DraftTransaction(
      amount: amount,
      type: type,
      accountId: sourceAccountId,
      destinationAccountId: destAccountId,
      categoryId: categoryId,
      date: date,
      note: note,
      rawSpeech: clause,
      hasUnassignedAccount: hasUnassignedAccount,
      hasUnassignedCategory: hasUnassignedCategory,
      hasCategoryMismatch: hasCategoryMismatch,
    );
  }

  /// Evaluates whether an extracted note contains raw sentence fragments,
  /// full transcription phrases, dates, amounts, account references, or conversational filler.
  static bool isContaminatedNote(
    String note, {
    Account? sourceAccount,
    Account? destinationAccount,
    List<Account>? accounts,
  }) {
    final lower = note.trim().toLowerCase();
    if (lower.isEmpty) return true;

    // Has digits or currency tokens
    if (RegExp(r'(?:\$|\b\d+(?:\.\d{1,2})?\b|dollars?|bucks?|rupees?|cents?)')
        .hasMatch(lower)) {
      return true;
    }

    // Has date or relative date words
    if (RegExp(
      r'\b(?:yesterday|today|the day before yesterday|tomorrow|last\s+[a-z]+)\b',
    ).hasMatch(lower)) {
      return true;
    }

    // Starts with conversational verbs
    if (RegExp(
      r'^(?:spent|spend|bought|buy|paid|pay|ordered|transferred|moved|received|deposited)\b',
    ).hasMatch(lower)) {
      return true;
    }

    // Contains conversational account connector phrases (e.g., "with chase", "from sbi", "on my card", "from checking to savings")
    if (RegExp(
      r'\b(?:on\s+my\s+card|using\s+(?:my\s+)?card|from\s+.+?\s+to\s+|from\s+[a-z0-9]+|with\s+[a-z0-9]+|via\s+[a-z0-9]+|using\s+[a-z0-9]+)\b',
    ).hasMatch(lower)) {
      return true;
    }

    // Contains account names or keywords
    final allAccounts = <Account>{
      ?sourceAccount,
      ?destinationAccount,
      ...?accounts,
    };
    for (final acc in allAccounts) {
      final name = acc.name.trim().toLowerCase();
      if (name.length >= 2 && lower.contains(name)) {
        return true;
      }
    }

    // Too long to be a clean note title (> 5 words)
    final words = lower
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length > 5) {
      return true;
    }

    return false;
  }

  /// Title-cases text while leaving common minor prepositions lowercase.
  static String toTitleCase(String text) {
    if (text.trim().isEmpty) return '';
    final words = text.trim().split(RegExp(r'\s+'));
    const minorWords = {
      'at',
      'for',
      'in',
      'on',
      'to',
      'with',
      'from',
      'by',
      'a',
      'an',
      'the',
      'of',
      'and',
    };
    final result = <String>[];
    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.isEmpty) continue;
      if (i > 0 && minorWords.contains(w.toLowerCase())) {
        result.add(w.toLowerCase());
      } else {
        result.add(w[0].toUpperCase() + w.substring(1));
      }
    }
    return result.join(' ');
  }

  /// Generates a concise, context-driven transaction note based on transaction type,
  /// resolved accounts, category, and extracted item/merchant keywords.
  static String generateContextualNote({
    required String rawText,
    required String type,
    Account? sourceAccount,
    Account? destinationAccount,
    Category? category,
    List<Account>? accounts,
  }) {
    // 1. Transfers: Standardize from account context
    if (type == 'transfer') {
      if (sourceAccount != null && destinationAccount != null) {
        return 'Transfer: ${sourceAccount.name} → ${destinationAccount.name}';
      } else if (destinationAccount != null) {
        return 'Transfer to ${destinationAccount.name}';
      } else if (sourceAccount != null) {
        return 'Transfer from ${sourceAccount.name}';
      }
      return 'Transfer';
    }

    // 2. Strip transaction metadata already captured in structured fields
    String cleaned = rawText;

    // Currency symbols, amounts, and amount prepositions (e.g., "for 120", "worth 50")
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(?:for|of|worth)\s+(?:\$|₹|rs\.?|inr)?\s*(?:\d+(?:\.\d{1,2})?|\.\d{1,2})\s*(?:dollars?|bucks?|rupees?|rs\.?|inr|cents?|usd|\$|₹|\b)',
        caseSensitive: false,
      ),
      ' ',
    );
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(?:\$|₹|rs\.?|inr|\b)\s*(?:\d+(?:\.\d{1,2})?|\.\d{1,2})\s*(?:dollars?|bucks?|rupees?|rs\.?|inr|cents?|usd|\$|₹|\b)',
        caseSensitive: false,
      ),
      ' ',
    );
    // Standalone numbers
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(?:\d+(?:\.\d{1,2})?|\.\d{1,2})\b'),
      ' ',
    );

    // Relative dates and weekday references
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(?:the day before yesterday|yesterday|today|tomorrow|last\s+(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // Source & destination account names & keywords
    final allAccounts = <Account>{
      ?sourceAccount,
      ?destinationAccount,
      ...?accounts,
    };

    for (final acc in allAccounts) {
      cleaned = cleaned.replaceAll(
        RegExp(
          r'\b(?:on|using|with|via|from|to|into)\s+' +
              RegExp.escape(acc.name) +
              r'\b',
          caseSensitive: false,
        ),
        ' ',
      );
      for (final word in acc.name.split(RegExp(r'\s+'))) {
        if (word.length >= 2) {
          cleaned = cleaned.replaceAll(
            RegExp(
              r'\b(?:on|using|with|via|from|to|into)\s+' +
                  RegExp.escape(word) +
                  r'\b',
              caseSensitive: false,
            ),
            ' ',
          );
        }
      }
      cleaned = cleaned.replaceAll(
        RegExp(r'\b' + RegExp.escape(acc.name) + r'\b', caseSensitive: false),
        ' ',
      );
    }

    // Generic payment phrases
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(?:on\s+my\s+card|using\s+card|on\s+card|with\s+card|on\s+credit|with\s+debit|using\s+debit|using\s+upi|on\s+upi|via\s+upi|in\s+cash|with\s+cash)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // Transaction verbs
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(?:spent|spend|spending|bought|buy|buying|paid\s+for|paid|pay|paying|cost\s+me|cost|ordered|order|purchased|purchase|charged\s+to|charged|received|deposited|deposit|earned|moved|transfer|transferred)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // Clean leading/trailing prepositions and conjunctions
    cleaned = cleaned.replaceAll(
      RegExp(
        r'^\s*(?:for|at|on|with|from|to|using|in|into|and|also|then)\s+',
        caseSensitive: false,
      ),
      ' ',
    );
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s+(?:for|at|on|with|from|to|using|in|into|and|also|then)\s*$',
        caseSensitive: false,
      ),
      ' ',
    );

    // Normalize punctuation & whitespace
    cleaned = cleaned
        .replaceAll(RegExp(r'[;,\.\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 3. Fallback synthesis if cleaned text is empty or meaningless
    if (cleaned.isEmpty || cleaned.length <= 1) {
      if (type == 'income') {
        return sourceAccount != null
            ? 'Income (${sourceAccount.name})'
            : 'Income';
      }
      if (category != null && category.name.isNotEmpty) {
        return category.name;
      }
      return 'Expense';
    }

    return toTitleCase(cleaned);
  }
}
