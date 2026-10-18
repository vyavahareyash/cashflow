import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/draft_transaction.dart';
import 'slm_inference_service.dart';
import 'voice_entity_parser.dart';
import 'voice_prompt_builder.dart';

/// Structured result returned by SLM SMS entity extraction.
class SlmSmsParseResult {
  final DraftTransaction? draft;
  final ParsedSmsEntity entity;
  final bool isFinancial;

  SlmSmsParseResult({
    this.draft,
    required this.entity,
    required this.isFinancial,
  });
}

/// Extracted financial entities from an SMS text.
class ParsedSmsEntity {
  final double amount;
  final String type; // 'expense' or 'income'
  final String? merchant;
  final String? accountSuffix;
  final String? referenceNumber;
  final String? date; // 'YYYY-MM-DD'
  final String note;
  final bool isFinancial;

  ParsedSmsEntity({
    required this.amount,
    required this.type,
    this.merchant,
    this.accountSuffix,
    this.referenceNumber,
    this.date,
    required this.note,
    this.isFinancial = true,
  });

  factory ParsedSmsEntity.nonFinancial() {
    return ParsedSmsEntity(
      amount: 0.0,
      type: 'expense',
      note: '',
      isFinancial: false,
    );
  }
}

/// Offline engine for identifying, parsing, and extracting financial transactions
/// from bank and UPI SMS text messages.
class SmsExtractionService {
  // Common bank header regex pattern supporting DLT suffix (e.g. AX-HDFCBK-T, JD-SBICRD-S, JX-MAHABK-S)
  static final RegExp bankSenderPattern = RegExp(
    r'^[a-zA-Z]{2}[-_]?[a-zA-Z0-9]{3,8}(?:[-_][a-zA-Z0-9])?$',
    caseSensitive: false,
  );

  // Strict OTP keywords that immediately reject a message
  static final RegExp _otpPattern = RegExp(
    r'\b(otp|one[- ]time password|verification code|is your code|secret code|do not share(?: this)?)\b',
    caseSensitive: false,
  );

  // Common promotional / marketing keywords
  static final RegExp _promoPattern = RegExp(
    r'\b(flat \d+% off|discount coupon|cashback coupon|pre-approved loan|apply now|win free)\b',
    caseSensitive: false,
  );

  // Future reminders, mandates, statement summaries, or non-transaction alerts
  static final RegExp _futureOrNonTxnAlertPattern = RegExp(
    r'\b('
    r'will be (?:debited|deducted|auto-debited)|'
    r'is due on|'
    r'upcoming mandate|'
    r'e-mandate|'
    r'mandate is set|'
    r'mandate created for|'
    r'maintain (?:sufficient )?balance|'
    r'maintain a limit|'
    r'auto debit on|'
    r'statement (?:is )?generated|'
    r'e-statement|'
    r'total amt due|'
    r'minimum due|'
    r'is below the required min|'
    r'reminder to complete|'
    r'data usage alert|'
    r'unmet spends criteria|'
    r'e-aadhaar|'
    r'kyc renewal is due|'
    r'national cyber security|'
    r'login alert'
    r')\b',
    caseSensitive: false,
  );

  // Financial action indicators (debit/spent vs credited/deposited)
  static final RegExp _debitPattern = RegExp(
    r'\b(debited(?: by)?|spent|paid|sent|withdrawn|deducted(?: from)?|transferred to|charged|purchase of|txn of|txn rs\.?)\b',
    caseSensitive: false,
  );

  static final RegExp _creditPattern = RegExp(
    r'\b(credited(?: with| to)?|credit of|deposited|received|refunded|reversed|cashback received)\b',
    caseSensitive: false,
  );

  // Amount extraction: Rs. 1,234.50, INR 500, ₹499.00, Rs289.45
  static final RegExp _amountPattern = RegExp(
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // Account suffix extraction: A/c XX1234, Acct ending with 5678, Card ending 9012, Bank XX9032
  static final RegExp _accountSuffixPattern = RegExp(
    r'(?:a\/c|acct|account|card|bank)\s*(?:no\.?)?\s*(?:ending\s*(?:with|in)?)?\s*(?:[*xX]+)?(\d{3,5})\b',
    caseSensitive: false,
  );

  // Standalone masked suffix fallback (e.g. *9032, XX8003, X1717)
  static final RegExp _maskedSuffixPattern = RegExp(
    r'\b[*xX]{1,6}(\d{3,5})\b',
    caseSensitive: false,
  );

  // Reference / RRN extraction pattern:
  static final RegExp _refNumberPattern = RegExp(
    r'\b(?:ref(?:\s*no\.?|#)?|rrn:?|upi\/(?:p2m|p2a|p2p)\/|upi\s+)\s*([a-zA-Z0-9]{8,16})\b',
    caseSensitive: false,
  );

  // Date extraction: DD-MM-YY, DD/MM/YYYY, DD-MMM-YY, or DD-MM
  static final RegExp _datePattern = RegExp(
    r'\b(\d{1,2})[-/](\d{1,2}|[a-zA-Z]{3})(?:[-/](\d{2,4}))?\b',
    caseSensitive: false,
  );

  /// Generates a deterministic hash for deduplication.
  static String computeSmsHash(String sender, String body, String timestamp) {
    // Clean body whitespace and digits that might be dynamic OTPs or reference numbers
    final normalized =
        '${sender.trim().toUpperCase()}|${body.replaceAll(RegExp(r'\s+'), ' ').trim()}|$timestamp';
    return md5.convert(utf8.encode(normalized)).toString();
  }

  /// Determines if a sender string matches transactional bank headers.
  static bool isLikelyBankSender(String sender) {
    final trimmed = sender.trim();
    if (trimmed.isEmpty) return false;
    // Reject personal phone numbers
    if (RegExp(r'^\+?\d{10,13}$').hasMatch(trimmed)) return false;

    final upper = trimmed.toUpperCase();
    if (upper.contains('BANK') ||
        upper.contains('BK') ||
        upper.contains('CRD') ||
        upper.contains('HDFC') ||
        upper.contains('ICICI') ||
        upper.contains('SBI') ||
        upper.contains('AXIS') ||
        upper.contains('KOTAK') ||
        upper.contains('PAYTM') ||
        upper.contains('AMEX') ||
        upper.contains('MAHA') ||
        upper.contains('HSBC') ||
        upper.contains('CRED') ||
        upper.contains('AXIO') ||
        upper.contains('RBL') ||
        upper.contains('IDFC') ||
        upper.contains('INDUS') ||
        upper.contains('PNB') ||
        upper.contains('CANBNK') ||
        upper.contains('BOI') ||
        upper.contains('UNION')) {
      return true;
    }

    return bankSenderPattern.hasMatch(trimmed);
  }

  /// Categorization dictionary for Indian merchants without any network calls.
  static final Map<String, List<String>> _merchantCategoryKeywords = {
    'Food & Dining': [
      'swiggy',
      'zomato',
      'eats',
      'restaurant',
      'cafe',
      'mcdonald',
      'domino',
      'kfc',
      'starbucks',
      'burger king',
      'pizza',
      'biryani',
      'food',
      'dine',
      'shawarma',
      'bake n cake',
      'eatclub',
      'kitchen',
      'soda point',
      'dairy',
      'dhaba',
      'barbeque',
      'sweet',
    ],
    'Groceries': [
      'blinkit',
      'zepto',
      'instamart',
      'bigbasket',
      'dmart',
      'supermarket',
      'nature basket',
      'fresh',
      'grocery',
      'spencer',
      'greenthing',
      'dudh dairy',
      'milk',
    ],
    'Transportation': [
      'uber',
      'ola',
      'rapido',
      'irctc',
      'metro',
      'petrol',
      'fuel',
      'hpcl',
      'bpcl',
      'iocl',
      'indian oil',
      'shell',
      'toll',
      'fastag',
      'parking',
      'washing center',
      'automobile',
    ],
    'Shopping': [
      'amazon',
      'flipkart',
      'myntra',
      'ajio',
      'nykaa',
      'tata cliq',
      'meesho',
      'zara',
      'h&m',
      'croma',
      'reliance retail',
      'retail',
      'smartworks',
      'shopee',
      'vending',
      'keymaker',
      'enterprises',
    ],
    'Entertainment': [
      'netflix',
      'spotify',
      'hotstar',
      'prime video',
      'bookmyshow',
      'pvr',
      'inox',
      'cinema',
      'gaming',
      'steam',
      'youtube',
      'cinepolis',
      'google play',
      'playstore',
    ],
    'Utilities': [
      'electricity',
      'bescom',
      'tata power',
      'airtel',
      'jio',
      'vi recharge',
      'broadband',
      'gas bill',
      'water bill',
      'billdesk',
      'tataplay',
      'tata play',
      'tatasky',
    ],
    'Investments': [
      'zerodha',
      'groww',
      'kuvera',
      'indmoney',
      'upstox',
      'mutual fund',
      'sip',
      'camsonline',
      'stable money',
      'suryoday',
    ],
    'Health & Medical': [
      'pharmacy',
      'chemist',
      'apollo',
      'wellness forever',
      'pharma sphere',
      'hospital',
      'clinic',
      '1mg',
      'netmeds',
      'medplus',
      'healthcare',
    ],
    'Bills & Loans': [
      'cred',
      'aditya birla',
      'propelld',
      'axio',
      'loan emi',
      'loan',
      'personal loan',
      'nach',
      'insurance',
      'policybazaar',
      'hdfc life',
      'lic',
      'max life',
      'ergo',
    ],
  };

  /// Multi-pattern extractor for merchants, beneficiaries, VPAs, and counterparties.
  static String? _extractMerchant(String text, String type) {
    // 1. Axis UPI pattern: UPI/(P2M|P2A|P2P)/<RRN>/<Merchant>
    final axisUpiMatch = RegExp(
      r'UPI\/(?:P2M|P2A|P2P)\/\d+\/([^\/\n\r]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (axisUpiMatch != null) {
      final m = axisUpiMatch.group(1)?.trim();
      if (m != null && m.isNotEmpty) return _cleanMerchant(m);
    }

    // 2. ICICI Card pattern: on <date> on <MERCHANT>
    final iciciCardMatch = RegExp(
      r'on\s+\d{1,2}-[a-zA-Z]{3}-\d{2,4}\s+on\s+([a-zA-Z0-9_\-\.\s&]{2,35}?)(?:\.|\s+Avl|\s+If not|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (iciciCardMatch != null) {
      final m = iciciCardMatch.group(1)?.trim();
      if (m != null && m.isNotEmpty) return _cleanMerchant(m);
    }

    // 3. Towards <MERCHANT> (EMIs, NACH, loans, credit cards)
    final towardsMatch = RegExp(
      r'\btowards\s+([a-zA-Z0-9_\-\.\s&]{2,35}?)(?:\s+(?:UMRN|Ref|using|policy|Credit Card)|\.|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (towardsMatch != null) {
      final m = towardsMatch.group(1)?.trim();
      if (m != null && m.isNotEmpty) return _cleanMerchant(m);
    }

    // 4. For credits / deposits: from <SENDER/VPA>
    if (type == 'income') {
      final fromMatch = RegExp(
        r'\bfrom\s+(?:VPA\s+)?([a-zA-Z0-9_\-\.@\s]{2,35}?)(?:\s*\(UPI|\s+RRN|\s+on|\.|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (fromMatch != null) {
        final m = fromMatch.group(1)?.trim();
        if (m != null && m.isNotEmpty) return _cleanMerchant(m);
      }

      // Salary / NEFT deposit company: for <Company> - Salary
      final salaryMatch = RegExp(
        r'for\s+(?:[A-Z0-9]+\s*-\s*)?([A-Za-z0-9_\-\.\s\(\)&]{3,45}?)(?:\s*-\s*Salary|\.Avl|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (salaryMatch != null) {
        final m = salaryMatch.group(1)?.trim();
        if (m != null && m.isNotEmpty) return _cleanMerchant(m);
      }
    }

    // 5. Standard at/to/vpa/info pattern (including @ and * for handles)
    final standardMatch = RegExp(
      r'\b(?:at|to|info\/|vpa)\s+([a-zA-Z0-9_\-\.\@\*\s&]{2,35}?)(?:\s+(?:on|using|via|ref|bal|avl|avail|dt|date|through|by UPI|\n)|\s*\.(?:\s+|$)|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (standardMatch != null) {
      final m = standardMatch.group(1)?.trim();
      if (m != null && m.isNotEmpty) return _cleanMerchant(m);
    }

    return null;
  }

  static String _cleanMerchant(String raw) {
    var cleaned = raw
        .replaceAll(RegExp(r'[\.,;\-]+$'), '')
        .replaceAll(RegExp(r'^\*+'), '')
        .trim();
    cleaned = cleaned
        .replaceAll(
          RegExp(
            r'\s+on\s+\d{1,2}[-/]\d{1,2}(?:[-/]\d{2,4})?.*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    return cleaned;
  }

  /// Parses a bank SMS text into a [ParsedSmsEntity].
  static ParsedSmsEntity parseSmsText(String body, {DateTime? fallbackDate}) {
    final trimmed = body.trim();

    // 1. Check for strict OTP
    if (_otpPattern.hasMatch(trimmed)) {
      return ParsedSmsEntity.nonFinancial();
    }

    // 2. Reject pure promotional text
    if (_promoPattern.hasMatch(trimmed) &&
        !_debitPattern.hasMatch(trimmed) &&
        !_creditPattern.hasMatch(trimmed)) {
      return ParsedSmsEntity.nonFinancial();
    }

    // 3. Reject future reminders, mandates, statement summaries, or non-transaction alerts
    if (_futureOrNonTxnAlertPattern.hasMatch(trimmed)) {
      return ParsedSmsEntity.nonFinancial();
    }

    // 4. Extract Amount
    final amountMatch = _amountPattern.firstMatch(trimmed);
    if (amountMatch == null) {
      return ParsedSmsEntity.nonFinancial();
    }

    final rawAmountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(rawAmountStr) ?? 0.0;
    if (amount <= 0) {
      return ParsedSmsEntity.nonFinancial();
    }

    // 5. Determine transaction type (expense vs income)
    String type = 'expense';
    if (_creditPattern.hasMatch(trimmed)) {
      type = 'income';
    } else if (_debitPattern.hasMatch(trimmed)) {
      type = 'expense';
    } else {
      // If neither keyword explicitly found, verify if it mentions A/c and Rs
      if (!trimmed.toLowerCase().contains('a/c') &&
          !trimmed.toLowerCase().contains('acct') &&
          !trimmed.toLowerCase().contains('card')) {
        return ParsedSmsEntity.nonFinancial();
      }
    }

    // 6. Extract Account Suffix (e.g. XX1234, *9032)
    String? accountSuffix;
    final suffixMatch = _accountSuffixPattern.firstMatch(trimmed);
    if (suffixMatch != null) {
      accountSuffix = suffixMatch.group(1);
    } else {
      final maskedMatch = _maskedSuffixPattern.firstMatch(trimmed);
      if (maskedMatch != null) {
        accountSuffix = maskedMatch.group(1);
      }
    }

    // 7. Extract Merchant / Beneficiary / Counterparty
    final merchant = _extractMerchant(trimmed, type);

    // 8. Extract Reference Number / RRN
    String? referenceNumber;
    final refMatch = _refNumberPattern.firstMatch(trimmed);
    if (refMatch != null) {
      referenceNumber = refMatch.group(1);
    }

    // 9. Extract Date
    String resolvedDate;
    final dateMatch = _datePattern.firstMatch(trimmed);
    if (dateMatch != null) {
      resolvedDate = _normalizeSmsDate(
        dateMatch.group(1)!,
        dateMatch.group(2)!,
        dateMatch.group(3),
        fallbackDate ?? DateTime.now(),
      );
    } else {
      resolvedDate = DateFormat('yyyy-MM-dd')
          .format(fallbackDate ?? DateTime.now());
    }

    final note = merchant != null && merchant.isNotEmpty
        ? (type == 'expense' ? 'Paid to $merchant' : 'Received from $merchant')
        : (type == 'expense' ? 'SMS Expense' : 'SMS Deposit');

    return ParsedSmsEntity(
      amount: amount,
      type: type,
      merchant: merchant,
      accountSuffix: accountSuffix,
      referenceNumber: referenceNumber,
      date: resolvedDate,
      note: note,
      isFinancial: true,
    );
  }

  /// Normalizes date components into YYYY-MM-DD.
  static String _normalizeSmsDate(
    String dayStr,
    String monthStr,
    String? yearStr,
    DateTime fallback,
  ) {
    try {
      final day = int.parse(dayStr);
      int year = yearStr != null ? int.parse(yearStr) : fallback.year;
      if (year < 100) {
        year += 2000;
      }

      int month;
      final monthInt = int.tryParse(monthStr);
      if (monthInt != null) {
        month = monthInt;
      } else {
        const months = {
          'jan': 1,
          'feb': 2,
          'mar': 3,
          'apr': 4,
          'may': 5,
          'jun': 6,
          'jul': 7,
          'aug': 8,
          'sep': 9,
          'oct': 10,
          'nov': 11,
          'dec': 12,
        };
        month =
            months[monthStr.toLowerCase().substring(0, 3)] ?? fallback.month;
      }

      final date = DateTime(year, month, day);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return DateFormat('yyyy-MM-dd').format(fallback);
    }
  }

  /// Converts a [ParsedSmsEntity] into an interactive [DraftTransaction]
  /// reconciling against existing accounts and categories.
  static DraftTransaction buildDraftTransaction({
    required ParsedSmsEntity entity,
    required List<Account> accounts,
    required List<Category> categories,
    String? rawSms,
  }) {
    int? matchedAccountId;
    bool hasUnassignedAccount = true;
    Account? matchedAccount;

    // Match by account number suffix
    if (entity.accountSuffix != null && entity.accountSuffix!.isNotEmpty) {
      matchedAccount = accounts.where((a) {
        if (a.accountNumberSuffix != null &&
            a.accountNumberSuffix!.isNotEmpty &&
            a.accountNumberSuffix == entity.accountSuffix) {
          return true;
        }
        // Fallback: check if account name contains suffix
        return a.name.contains(entity.accountSuffix!);
      }).firstOrNull;

      if (matchedAccount != null) {
        matchedAccountId = matchedAccount.id;
        hasUnassignedAccount = false;
      }
    }

    // If still unmatched, default to the primary bank account
    if (matchedAccountId == null && accounts.isNotEmpty) {
      final defaultAcc = accounts.firstWhere(
        (a) => !a.isCreditCard,
        orElse: () => accounts.first,
      );
      matchedAccountId = defaultAcc.id;
      hasUnassignedAccount = true; // Still marked unassigned so user reviews
    }

    // Check if this is a credit card bill payment
    final isCreditCardPayment =
        (matchedAccount != null &&
            matchedAccount.isCreditCard &&
            entity.type == 'income') ||
        (rawSms != null &&
            RegExp(
              r'\b(?:towards (?:your )?credit card|credited to your (?:credit )?card|payment of .* received towards)\b',
              caseSensitive: false,
            ).hasMatch(rawSms));

    // Match category by merchant keywords
    int? matchedCategoryId;
    bool hasUnassignedCategory = true;

    if (isCreditCardPayment) {
      final billCat = categories.where((c) {
        final lower = c.name.toLowerCase();
        return lower.contains('bill') ||
            lower.contains('loan') ||
            lower.contains('utilit');
      }).firstOrNull;
      if (billCat != null) {
        matchedCategoryId = billCat.id;
        hasUnassignedCategory = false;
      }
    } else if (entity.merchant != null && entity.merchant!.isNotEmpty) {
      final merchantLower = entity.merchant!.toLowerCase();
      String? matchedCategoryName;

      for (final entry in _merchantCategoryKeywords.entries) {
        if (entry.value.any(merchantLower.contains)) {
          matchedCategoryName = entry.key;
          break;
        }
      }

      if (matchedCategoryName != null) {
        final cat = categories.where((c) {
          final isSameType = entity.type == 'income' ? c.isIncome : c.isExpense;
          return isSameType &&
              c.name.toLowerCase().contains(matchedCategoryName!.toLowerCase());
        }).firstOrNull;

        if (cat != null) {
          matchedCategoryId = cat.id;
          hasUnassignedCategory = false;
        }
      }
    }

    // If not matched, try generic fallback
    if (matchedCategoryId == null) {
      final typeCats = categories
          .where((c) => entity.type == 'income' ? c.isIncome : c.isExpense)
          .toList();
      if (typeCats.isNotEmpty) {
        matchedCategoryId = typeCats.first.id;
        hasUnassignedCategory = true; // Prompt user to confirm
      }
    }

    final resolvedNote = isCreditCardPayment && entity.type == 'income'
        ? (entity.accountSuffix != null
              ? 'Credit Card Bill Payment (A/c ${entity.accountSuffix})'
              : 'Credit Card Bill Payment')
        : entity.note;

    return DraftTransaction(
      amount: entity.amount,
      type: entity.type,
      accountId: matchedAccountId,
      categoryId: matchedCategoryId,
      date: entity.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      note: resolvedNote,
      rawSpeech: rawSms,
      hasUnassignedAccount: hasUnassignedAccount,
      hasUnassignedCategory: hasUnassignedCategory,
      hasCategoryMismatch: false,
    );
  }

  /// Formats grounded ChatML prompt for bank SMS entity extraction conforming to [VoiceGrammar.transactionGrammar].
  static String buildSmsPrompt({
    required String smsBody,
    required String sender,
    required DateTime anchorDate,
    required List<Account> accounts,
    required List<Category> categories,
  }) {
    final cleanBody = smsBody
        .replaceAll('<|im_start|>', '')
        .replaceAll('<|im_end|>', '')
        .replaceAll('<|endoftext|>', '');
    final cleanSender = sender
        .replaceAll('<|im_start|>', '')
        .replaceAll('<|im_end|>', '')
        .replaceAll('<|endoftext|>', '');

    final anchorStr = VoicePromptBuilder.formatAnchorDate(anchorDate);

    final accountsPayload = accounts.map((a) {
      return {
        'id': a.id,
        'name': a.name,
        'type': a.type,
        if (a.accountNumberSuffix != null && a.accountNumberSuffix!.isNotEmpty)
          'suffix': a.accountNumberSuffix,
      };
    }).toList();

    final categoriesPayload = categories.map((c) {
      return {'id': c.id, 'name': c.name, 'type': c.type};
    }).toList();

    final accountsJson = jsonEncode(accountsPayload);
    final categoriesJson = jsonEncode(categoriesPayload);

    return '''<|im_start|>system
You are an intelligent offline bank SMS transaction extraction engine.
Analyze the SMS text and extract the financial transaction into a JSON array of objects conforming to the schema.
If the SMS is non-transactional (e.g. OTP verification code, promotional deal/discount, service alert, statement reminder, or login notification), emit an empty JSON array: [].

Calendar Anchor:
today: $anchorStr

Sender: $cleanSender

Active User Accounts:
$accountsJson

Active User Categories:
$categoriesJson

Extraction Instructions:
1. "type": Classify the message into one of these types:
   - "expense": Money debited, spent, paid, charged, withdrawn, or purchased.
   - "income": Money credited, deposited, received, salary, interest, cashback, or refund.
   - "transfer": Moving funds between user's accounts, or credit card bill payment from a bank account to a credit card.
2. "amount": Positive decimal number of the transaction.
3. "account_id": Integer ID of the active user account that matches this transaction based on:
   - Account number suffix in SMS (e.g. "XX1234", "ending 1234", "*1234").
   - Bank name in sender or SMS text (e.g. "HDFC", "SBI", "ICICI", "Axis").
   If no account matches, emit null.
4. "destination_account_id": Integer ID of destination account if type is "transfer" or credit card bill payment, otherwise null.
5. "category_id": Integer ID of the matching user category:
   - Map merchant/payee (e.g. Swiggy/Zomato -> Food & Dining, Blinkit/Zepto -> Groceries, Uber/Ola/Petrol -> Transportation, Amazon/Flipkart -> Shopping, Netflix -> Entertainment, Bescom/Airtel -> Utilities, Zerodha/Groww -> Investments).
   - If salary or wage -> Salary/Income category.
   - If no category fits, emit null.
6. "date": ISO date "YYYY-MM-DD" extracted from the SMS text or relative to calendar anchor.
7. "note": Clean concise 1-4 word label specifying merchant, payee, or purpose (e.g. "Swiggy", "Uber", "Amazon", "Salary", "Electricity Bill", "Credit Card Payment"). Never include raw SMS text, OTPs, or card numbers.
<|im_end|>
<|im_start|>user
$cleanBody
<|im_end|>
<|im_start|>assistant
''';
  }

  /// Executes on-device SLM inference to extract transaction details, classify message types,
  /// and ground against user accounts and categories.
  static Future<SlmSmsParseResult?> parseSmsWithSlm({
    required String smsBody,
    required String sender,
    required DateTime anchorDate,
    required List<Account> accounts,
    required List<Category> categories,
    required SlmInferenceService slmService,
  }) async {
    // Check if obvious OTP or non-financial alert
    if (_otpPattern.hasMatch(smsBody) ||
        _futureOrNonTxnAlertPattern.hasMatch(smsBody)) {
      return SlmSmsParseResult(
        entity: ParsedSmsEntity.nonFinancial(),
        isFinancial: false,
      );
    }

    final prompt = buildSmsPrompt(
      smsBody: smsBody,
      sender: sender,
      anchorDate: anchorDate,
      accounts: accounts,
      categories: categories,
    );

    final slmOutput = await slmService.generate(prompt: prompt);
    final drafts = VoiceEntityParser.parseJsonOutput(
      slmOutput,
      anchorDate: anchorDate,
      accounts: accounts,
      categories: categories,
    );

    if (drafts.isEmpty) {
      return SlmSmsParseResult(
        entity: ParsedSmsEntity.nonFinancial(),
        isFinancial: false,
      );
    }

    var draft = drafts.first;

    // Extract reference number & account suffix from body for pairing and deduplication
    final refMatch = _refNumberPattern.firstMatch(smsBody);
    final referenceNumber = refMatch?.group(1);

    String? accountSuffix;
    final suffixMatch =
        _accountSuffixPattern.firstMatch(smsBody) ??
        _maskedSuffixPattern.firstMatch(smsBody);
    if (suffixMatch != null) {
      accountSuffix = suffixMatch.group(1);
    }

    // Reconcile account if SLM did not assign or marked unassigned
    if ((draft.accountId == null || draft.hasUnassignedAccount) &&
        accountSuffix != null) {
      final matchedAcc = accounts.where((a) {
        if (a.accountNumberSuffix != null &&
            a.accountNumberSuffix!.isNotEmpty &&
            a.accountNumberSuffix == accountSuffix) {
          return true;
        }
        return a.name.contains(accountSuffix!);
      }).firstOrNull;

      if (matchedAcc != null) {
        draft = draft.copyWith(
          accountId: matchedAcc.id,
          hasUnassignedAccount: false,
        );
      }
    }

    // Reconcile category fallback if unassigned
    if ((draft.categoryId == null || draft.hasUnassignedCategory) &&
        draft.type != 'transfer') {
      final merchantLower = (draft.note.isNotEmpty ? draft.note : smsBody)
          .toLowerCase();
      String? matchedCategoryName;
      for (final entry in _merchantCategoryKeywords.entries) {
        if (entry.value.any(merchantLower.contains)) {
          matchedCategoryName = entry.key;
          break;
        }
      }
      if (matchedCategoryName != null) {
        final cat = categories.where((c) {
          final isSameType = draft.type == 'income' ? c.isIncome : c.isExpense;
          return isSameType &&
              c.name.toLowerCase().contains(matchedCategoryName!.toLowerCase());
        }).firstOrNull;
        if (cat != null) {
          draft = draft.copyWith(
            categoryId: cat.id,
            hasUnassignedCategory: false,
          );
        }
      }
    }

    final entity = ParsedSmsEntity(
      amount: draft.amount,
      type: draft.type,
      merchant: draft.note.isNotEmpty ? draft.note : null,
      accountSuffix: accountSuffix,
      referenceNumber: referenceNumber,
      date: draft.date,
      note: draft.note,
      isFinancial: true,
    );

    return SlmSmsParseResult(
      draft: draft.copyWith(rawSpeech: smsBody),
      entity: entity,
      isFinancial: true,
    );
  }
}
