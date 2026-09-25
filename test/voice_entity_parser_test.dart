import 'package:flutter_test/flutter_test.dart';

import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/draft_transaction.dart';
import 'package:cashflow/services/model_management_service.dart';
import 'package:cashflow/services/slm_inference_service.dart';
import 'package:cashflow/services/voice_entity_parser.dart';
import 'package:cashflow/services/voice_grammar.dart';
import 'package:cashflow/services/voice_prompt_builder.dart';

void main() {
  group('VoiceEntityParser Headless Test Harness (US 1, 4, 5, 6, 7, 17)', () {
    // Anchor date: Tuesday, September 22, 2026
    final anchorDate = DateTime(2026, 9, 22);

    final mockAccounts = [
      Account(id: 1, name: 'Checking', balance: 5000.0, type: 'Bank'),
      Account(id: 2, name: 'Savings', balance: 12000.0, type: 'Savings'),
      Account(
        id: 3,
        name: 'Chase Sapphire',
        balance: -450.0,
        type: 'Credit Card',
      ),
      Account(id: 4, name: 'Cash Wallet', balance: 120.0, type: 'Cash'),
    ];

    final mockCategories = [
      Category(
        id: 10,
        name: 'Food & Dining',
        monthlyBudget: 600.0,
        type: 'expense',
      ),
      Category(
        id: 11,
        name: 'Groceries',
        monthlyBudget: 800.0,
        type: 'expense',
      ),
      Category(
        id: 12,
        name: 'Transportation',
        monthlyBudget: 300.0,
        type: 'expense',
      ),
      Category(
        id: 13,
        name: 'Utilities',
        monthlyBudget: 250.0,
        type: 'expense',
      ),
    ];

    test('1. Headless test harness verifies deterministic parsing for Coffee on Chase', () {
      const sample = 'Coffee 5 dollars yesterday on Chase';

      final results = VoiceEntityParser.parseTranscriptionSample(
        sample,
        anchorDate: anchorDate,
        accounts: mockAccounts,
        categories: mockCategories,
      );

      expect(results.length, 1);
      final draft = results.first;
      expect(draft.amount, 5.0);
      expect(draft.type, 'expense');
      expect(draft.accountId, 3); // Chase Sapphire ID
      expect(draft.categoryId, 10); // Food & Dining ID
      expect(draft.date, '2026-09-21'); // Yesterday relative to 2026-09-22
      expect(draft.hasUnassignedAccount, isFalse);
      expect(draft.hasUnassignedCategory, isFalse);
      expect(draft.isValid, isTrue);

      final txn = draft.toTransactionModel();
      expect(txn.accountId, 3);
      expect(txn.categoryId, 10);
      expect(txn.amount, 5.0);
      expect(txn.date, '2026-09-21');
      expect(txn.type, 'expense');
    });

    test('2. Headless test harness verifies deterministic parsing for Salary income', () {
      const sample = 'Salary 3000 deposited to Checking';

      final results = VoiceEntityParser.parseTranscriptionSample(
        sample,
        anchorDate: anchorDate,
        accounts: mockAccounts,
        categories: mockCategories,
      );

      expect(results.length, 1);
      final draft = results.first;
      expect(draft.amount, 3000.0);
      expect(draft.type, 'income');
      expect(draft.accountId, 1); // Checking ID
      expect(draft.destinationAccountId, isNull);
      expect(draft.categoryId, isNull);
      expect(draft.date, '2026-09-22');
      expect(draft.isValid, isTrue);

      final txn = draft.toTransactionModel();
      expect(txn.type, 'income');
      expect(txn.amount, 3000.0);
      expect(txn.accountId, 1);
    });

    test('3. Headless test harness verifies deterministic parsing for transfer between accounts', () {
      const sample = 'Moved 100 from Checking to Savings';

      final results = VoiceEntityParser.parseTranscriptionSample(
        sample,
        anchorDate: anchorDate,
        accounts: mockAccounts,
        categories: mockCategories,
      );

      expect(results.length, 1);
      final draft = results.first;
      expect(draft.amount, 100.0);
      expect(draft.type, 'transfer');
      expect(draft.accountId, 1); // Source: Checking
      expect(draft.destinationAccountId, 2); // Destination: Savings
      expect(draft.categoryId, isNull);
      expect(draft.isValid, isTrue);

      final txn = draft.toTransactionModel();
      expect(txn.type, 'transfer');
      expect(txn.amount, 100.0);
      expect(txn.accountId, 1);
      expect(txn.destinationAccountId, 2);
    });

    test('4. Defaults unassigned accounts to primary account with audit flag (US 7)', () {
      const sample = 'Lunch 15 dollars today';

      final results = VoiceEntityParser.parseTranscriptionSample(
        sample,
        anchorDate: anchorDate,
        accounts: mockAccounts,
        categories: mockCategories,
      );

      expect(results.length, 1);
      final draft = results.first;
      expect(draft.amount, 15.0);
      expect(draft.type, 'expense');
      // Should default to first bank account (Checking, id: 1)
      expect(draft.accountId, 1);
      expect(draft.hasUnassignedAccount, isTrue);
      expect(draft.categoryId, 10); // Food & Dining
      expect(draft.date, '2026-09-22');
      expect(draft.isValid, isTrue);
    });

    test(
      '5. Resolves relative dates deterministically across weekdays (US 6)',
      () {
        // Anchor date: Tuesday, Sep 22, 2026
        expect(
          VoiceEntityParser.resolveRelativeDate('today', anchorDate),
          '2026-09-22',
        );
        expect(
          VoiceEntityParser.resolveRelativeDate('yesterday', anchorDate),
          '2026-09-21',
        );
        expect(
          VoiceEntityParser.resolveRelativeDate(
            'the day before yesterday',
            anchorDate,
          ),
          '2026-09-20',
        );
        // Last Friday relative to Tuesday 2026-09-22 is 2026-09-18 (4 days ago)
        expect(
          VoiceEntityParser.resolveRelativeDate('last Friday', anchorDate),
          '2026-09-18',
        );
        // Last Sunday is 2026-09-20 (2 days ago)
        expect(
          VoiceEntityParser.resolveRelativeDate('last Sunday', anchorDate),
          '2026-09-20',
        );
        // Last Monday is 2026-09-21 (1 day ago)
        expect(
          VoiceEntityParser.resolveRelativeDate('last Monday', anchorDate),
          '2026-09-21',
        );
        // Last Tuesday strictly resolves to 7 days prior: 2026-09-15
        expect(
          VoiceEntityParser.resolveRelativeDate('last Tuesday', anchorDate),
          '2026-09-15',
        );
      },
    );

    test('6. Dictates multiple transactions in a single continuous monologue (US 1)', () {
      const monologue =
          'Coffee 5 dollars yesterday on Chase and 45 for groceries at Walmart on Checking';

      final results = VoiceEntityParser.parseTranscriptionSample(
        monologue,
        anchorDate: anchorDate,
        accounts: mockAccounts,
        categories: mockCategories,
      );

      expect(results.length, 2);

      final draft1 = results[0];
      expect(draft1.amount, 5.0);
      expect(draft1.type, 'expense');
      expect(draft1.accountId, 3); // Chase
      expect(draft1.categoryId, 10); // Food & Dining
      expect(draft1.date, '2026-09-21');

      final draft2 = results[1];
      expect(draft2.amount, 45.0);
      expect(draft2.type, 'expense');
      expect(draft2.accountId, 1); // Checking
      expect(draft2.categoryId, 11); // Groceries
      expect(draft2.date, '2026-09-22');
    });

    test(
      '7. Flags unassigned category for unrecognized expense items (US 8)',
      () {
        const sample = 'Random gadget 89 dollars on Checking';

        final results = VoiceEntityParser.parseTranscriptionSample(
          sample,
          anchorDate: anchorDate,
          accounts: mockAccounts,
          categories: mockCategories,
        );

        expect(results.length, 1);
        final draft = results.first;
        expect(draft.amount, 89.0);
        expect(draft.categoryId, isNull);
        expect(draft.hasUnassignedCategory, isTrue);
      },
    );
  });

  group('DraftTransaction Model Validation & Transformations', () {
    test('Validates complete expense draft', () {
      final draft = DraftTransaction(
        amount: 25.50,
        type: 'expense',
        accountId: 1,
        categoryId: 10,
        date: '2026-09-22',
        note: 'Dinner',
      );

      expect(draft.isValid, isTrue);
      expect(draft.isExpense, isTrue);
      expect(draft.isIncome, isFalse);
      expect(draft.isTransfer, isFalse);

      final model = draft.toTransactionModel();
      expect(model.amount, 25.50);
      expect(model.accountId, 1);
      expect(model.categoryId, 10);
      expect(model.destinationAccountId, isNull);
      expect(model.date, '2026-09-22');
      expect(model.note, 'Dinner');
    });

    test('Validates transfer requires distinct destinationAccountId', () {
      final invalidTransferSameAccount = DraftTransaction(
        amount: 50.0,
        type: 'transfer',
        accountId: 1,
        destinationAccountId: 1,
        date: '2026-09-22',
        note: 'Self loop',
      );
      expect(invalidTransferSameAccount.isValid, isFalse);

      final invalidTransferMissingDest = DraftTransaction(
        amount: 50.0,
        type: 'transfer',
        accountId: 1,
        destinationAccountId: null,
        date: '2026-09-22',
        note: 'No destination',
      );
      expect(invalidTransferMissingDest.isValid, isFalse);

      final validTransfer = DraftTransaction(
        amount: 50.0,
        type: 'transfer',
        accountId: 1,
        destinationAccountId: 2,
        date: '2026-09-22',
        note: 'To savings',
      );
      expect(validTransfer.isValid, isTrue);
      final model = validTransfer.toTransactionModel();
      expect(model.type, 'transfer');
      expect(model.destinationAccountId, 2);
    });

    test('Rejects zero or negative amounts', () {
      final zeroDraft = DraftTransaction(
        amount: 0.0,
        accountId: 1,
        date: '2026-09-22',
        note: 'Zero',
      );
      expect(zeroDraft.isValid, isFalse);

      final negativeDraft = DraftTransaction(
        amount: -10.0,
        accountId: 1,
        date: '2026-09-22',
        note: 'Negative',
      );
      expect(negativeDraft.isValid, isFalse);
    });

    test('Supports copyWith, toMap, and fromMap serialization', () {
      final draft = DraftTransaction(
        id: 'draft-101',
        amount: 14.25,
        type: 'expense',
        accountId: 1,
        categoryId: 10,
        date: '2026-09-22',
        note: 'Chipotle',
        hasUnassignedAccount: false,
        hasUnassignedCategory: false,
      );

      final copy = draft.copyWith(amount: 19.99, note: 'Chipotle Burrito Bowl');
      expect(copy.id, 'draft-101');
      expect(copy.amount, 19.99);
      expect(copy.note, 'Chipotle Burrito Bowl');

      final map = draft.toMap();
      final fromMap = DraftTransaction.fromMap(map);
      expect(fromMap, equals(draft));
    });
  });

  group('VoiceGrammar and Schema Parsing', () {
    test('transactionGrammar specification contains required GBNF rules', () {
      expect(VoiceGrammar.transactionGrammar, contains('root ::='));
      expect(VoiceGrammar.transactionGrammar, contains('transaction ::='));
      expect(VoiceGrammar.transactionGrammar, contains('amount'));
      expect(VoiceGrammar.transactionGrammar, contains('type'));
      expect(VoiceGrammar.transactionGrammar, contains('account_id'));
      expect(
        VoiceGrammar.transactionGrammar,
        contains('destination_account_id'),
      );
      expect(VoiceGrammar.transactionGrammar, contains('category_id'));
      expect(VoiceGrammar.transactionGrammar, contains('date'));
      expect(VoiceGrammar.transactionGrammar, contains('note'));
    });

    test('tryParseGrammarJson parses valid GBNF JSON output', () {
      const jsonStr = '''
[
  {
    "amount": 12.5,
    "type": "expense",
    "account_id": 1,
    "destination_account_id": null,
    "category_id": 10,
    "date": "2026-09-22",
    "note": "Lunch sandwich"
  }
]
''';
      final parsed = VoiceGrammar.tryParseGrammarJson(jsonStr);
      expect(parsed, isNotNull);
      expect(parsed!.length, 1);
      expect(parsed[0]['amount'], 12.5);
      expect(parsed[0]['type'], 'expense');
      expect(parsed[0]['account_id'], 1);
      expect(parsed[0]['note'], 'Lunch sandwich');
    });

    test('tryParseGrammarJson returns null on invalid schema', () {
      expect(VoiceGrammar.tryParseGrammarJson('invalid json string'), isNull);
      expect(VoiceGrammar.tryParseGrammarJson('{"not": "array"}'), isNull);
      // Missing amount
      expect(
        VoiceGrammar.tryParseGrammarJson(
          '[{"type": "expense", "date": "2026-09-22", "note": "Hi"}]',
        ),
        isNull,
      );
      // Invalid date format
      expect(
        VoiceGrammar.tryParseGrammarJson(
          '[{"amount": 10, "type": "expense", "date": "invalid", "note": "Hi"}]',
        ),
        isNull,
      );
    });
  });

  group('VoicePromptBuilder ChatML Generation', () {
    test('Builds properly formatted ChatML prompt with calendar anchor and SQLite entities', () {
      final anchor = DateTime(2026, 9, 22);
      final accounts = [
        Account(id: 1, name: 'Checking', balance: 500.0, type: 'Bank'),
      ];
      final categories = [
        Category(id: 10, name: 'Food', monthlyBudget: 100.0, type: 'expense'),
      ];

      final prompt = VoicePromptBuilder.buildPrompt(
        transcript: 'Spent 10 on Food yesterday',
        anchorDate: anchor,
        accounts: accounts,
        categories: categories,
      );

      expect(prompt, contains('<|im_start|>system'));
      expect(prompt, contains('today: 2026-09-22 (Tuesday)'));
      expect(prompt, contains('"name":"Checking"'));
      expect(prompt, contains('"name":"Food"'));
      expect(prompt, contains('<|im_end|>'));
      expect(
        prompt,
        contains('<|im_start|>user\nSpent 10 on Food yesterday\n<|im_end|>'),
      );
      expect(prompt, contains('<|im_start|>assistant'));
    });
  });

  group('SLM Output JSON Parser Integration', () {
    final anchor = DateTime(2026, 9, 22);
    final accounts = [
      Account(id: 1, name: 'Checking', balance: 2000.0, type: 'Bank'),
      Account(id: 2, name: 'Savings', balance: 5000.0, type: 'Savings'),
    ];
    final categories = [
      Category(
        id: 10,
        name: 'Groceries',
        monthlyBudget: 400.0,
        type: 'expense',
      ),
    ];

    test('parseJsonOutput handles valid SLM array and applies primary account fallback', () {
      const slmOutput = '''
[
  {
    "amount": 34.50,
    "type": "expense",
    "account_id": null,
    "destination_account_id": null,
    "category_id": 10,
    "date": "2026-09-21",
    "note": "Supermarket"
  },
  {
    "amount": 500.0,
    "type": "transfer",
    "account_id": 1,
    "destination_account_id": 2,
    "category_id": null,
    "date": "2026-09-22",
    "note": "Savings deposit"
  }
]
''';

      final drafts = VoiceEntityParser.parseJsonOutput(
        slmOutput,
        anchorDate: anchor,
        accounts: accounts,
        categories: categories,
      );

      expect(drafts.length, 2);

      // Draft 1: unassigned account defaulted to primary account (Checking, id: 1)
      expect(drafts[0].amount, 34.50);
      expect(drafts[0].type, 'expense');
      expect(drafts[0].accountId, 1);
      expect(drafts[0].hasUnassignedAccount, isTrue);
      expect(drafts[0].categoryId, 10);
      expect(drafts[0].hasUnassignedCategory, isFalse);
      expect(drafts[0].date, '2026-09-21');

      // Draft 2: valid transfer
      expect(drafts[1].amount, 500.0);
      expect(drafts[1].type, 'transfer');
      expect(drafts[1].accountId, 1);
      expect(drafts[1].destinationAccountId, 2);
      expect(drafts[1].categoryId, isNull);
      expect(drafts[1].isValid, isTrue);
    });

    test('parseJsonOutput extracts JSON array embedded with extraneous whitespace', () {
      const messyOutput =
          '   \n\n [ {"amount": 20, "type": "expense", "account_id": 1, "destination_account_id": null, "category_id": 10, "date": "2026-09-22", "note": "Gas"} ] \n ';

      final drafts = VoiceEntityParser.parseJsonOutput(
        messyOutput,
        anchorDate: anchor,
        accounts: accounts,
        categories: categories,
      );

      expect(drafts.length, 1);
      expect(drafts.first.amount, 20.0);
      expect(drafts.first.note, 'Gas');
    });
  });

  group('SlmInferenceService and MockSlmEngine Lifecycle', () {
    test(
      'MockSlmEngine initializes, generates responses, and disposes cleanly',
      () async {
        final mock = MockSlmEngine(
          onGenerate: (prompt) => '[{"amount": 15.0, "type": "expense", "account_id": 1, "destination_account_id": null, "category_id": 10, "date": "2026-09-22", "note": "Coffee"}]',
        );

        expect(mock.isInitialized, isFalse);
        await mock.initialize(modelPath: '/dummy/path');
        expect(mock.isInitialized, isTrue);

        final res = await mock.generate(prompt: 'Test');
        expect(res, contains('"amount": 15.0'));

        await mock.dispose();
        expect(mock.isInitialized, isFalse);
      },
    );

    test('SlmInferenceService integrates with ModelManagementService deallocation hook', () async {
      final mockEngine = MockSlmEngine();

      final modelService = ModelManagementService();
      final service = SlmInferenceService(
        engine: mockEngine,
        modelService: modelService,
      );

      await mockEngine.initialize(modelPath: '/mock/path');
      expect(service.isInitialized, isTrue);

      // Load models to enter loaded state, then trigger deallocation
      await modelService.loadModelsIntoMemory();
      await modelService.unloadModelsFromMemory();
      expect(service.isInitialized, isFalse);
    });

    test(
      'Throws SlmModelNotInstalledException when model is missing',
      () async {
        final mockEngine = MockSlmEngine(shouldThrowNotInstalled: true);
        final service = SlmInferenceService(engine: mockEngine);

        expect(
          () => service.initialize(customModelPath: '/nonexistent/path.gguf'),
          throwsA(isA<SlmModelNotInstalledException>()),
        );
      },
    );
  });

  group('Context-Aware Transaction Note Generation', () {
    final anchorDate = DateTime(2026, 9, 22);
    final mockAccounts = [
      Account(id: 1, name: 'Checking', balance: 5000.0, type: 'Bank'),
      Account(id: 2, name: 'Savings', balance: 12000.0, type: 'Savings'),
      Account(
        id: 3,
        name: 'Chase Sapphire',
        balance: -450.0,
        type: 'Credit Card',
      ),
    ];
    final mockCategories = [
      Category(
        id: 10,
        name: 'Food & Dining',
        monthlyBudget: 600.0,
        type: 'expense',
      ),
      Category(
        id: 11,
        name: 'Groceries',
        monthlyBudget: 800.0,
        type: 'expense',
      ),
      Category(
        id: 12,
        name: 'Transportation',
        monthlyBudget: 300.0,
        type: 'expense',
      ),
    ];

    test('Generates contextual note isolating merchant/item and stripping amounts, dates, accounts', () {
      final drafts = VoiceEntityParser.parseTranscriptionSample(
        'Spent 5 on coffee at Starbucks with Chase yesterday',
        anchorDate: anchorDate,
        accounts: mockAccounts,
        categories: mockCategories,
      );

      expect(drafts.length, 1);
      expect(drafts.first.note, 'Coffee at Starbucks');
      expect(
        drafts.first.rawSpeech,
        'Spent 5 on coffee at Starbucks with Chase yesterday',
      );
    });

    test('Generates distinct contextual notes in multi-transaction monologue without bleeding', () {
      const monologue =
          'Spent 5 on coffee at Starbucks with Chase and 45 for groceries at Walmart on Checking yesterday';

      final drafts = VoiceEntityParser.parseTranscriptionSample(
        monologue,
        anchorDate: anchorDate,
        accounts: mockAccounts,
        categories: mockCategories,
      );

      expect(drafts.length, 2);
      expect(drafts[0].note, 'Coffee at Starbucks');
      expect(drafts[0].amount, 5.0);
      expect(drafts[0].accountId, 3);

      expect(drafts[1].note, 'Groceries at Walmart');
      expect(drafts[1].amount, 45.0);
      expect(drafts[1].accountId, 1);
    });

    test('Standardizes transfer notes using source and destination account context', () {
      final drafts = VoiceEntityParser.parseTranscriptionSample(
        'Moved 250 dollars from Checking to Savings yesterday',
        anchorDate: anchorDate,
        accounts: mockAccounts,
        categories: mockCategories,
      );

      expect(drafts.length, 1);
      expect(drafts.first.type, 'transfer');
      expect(drafts.first.note, 'Transfer: Checking → Savings');
    });

    test('Falls back to category name when speech contains no merchant or item name', () {
      final note = VoiceEntityParser.generateContextualNote(
        rawText: '25 dollars yesterday on Checking',
        type: 'expense',
        sourceAccount: mockAccounts.first,
        category: mockCategories.first, // Food & Dining
      );

      expect(note, 'Food & Dining');
    });

    test(
      'SLM parser automatically sanitizes contaminated transcript-echo notes',
      () {
        const contaminatedSlmJson = '''
[
  {
    "amount": 7.50,
    "type": "expense",
    "account_id": 3,
    "destination_account_id": null,
    "category_id": 10,
    "date": "2026-09-21",
    "note": "Spent 7.50 dollars on latte at Starbucks yesterday with Chase"
  }
]
''';

        final drafts = VoiceEntityParser.parseJsonOutput(
          contaminatedSlmJson,
          anchorDate: anchorDate,
          accounts: mockAccounts,
          categories: mockCategories,
        );

        expect(drafts.length, 1);
        expect(drafts.first.note, 'Latte at Starbucks');
        expect(drafts.first.amount, 7.50);
        expect(drafts.first.accountId, 3);
      },
    );

    test('SLM parser standardizes transfer notes even if SLM returns colloquial phrase', () {
      const transferSlmJson = '''
[
  {
    "amount": 100.0,
    "type": "transfer",
    "account_id": 1,
    "destination_account_id": 2,
    "category_id": null,
    "date": "2026-09-22",
    "note": "Moved 100 from checking to savings"
  }
]
''';

      final drafts = VoiceEntityParser.parseJsonOutput(
        transferSlmJson,
        anchorDate: anchorDate,
        accounts: mockAccounts,
        categories: mockCategories,
      );

      expect(drafts.length, 1);
      expect(drafts.first.note, 'Transfer: Checking → Savings');
    });
  });
}
