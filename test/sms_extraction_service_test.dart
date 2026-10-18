import 'package:flutter_test/flutter_test.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/services/slm_inference_service.dart';
import 'package:cashflow/services/sms_extraction_service.dart';

void main() {
  group('SmsExtractionService Offline Parser Tests', () {
    final accounts = [
      Account(
        id: 1,
        name: 'HDFC Salary',
        balance: 50000.0,
        type: 'Bank',
        accountNumberSuffix: '1234',
      ),
      Account(
        id: 2,
        name: 'SBI Savings',
        balance: 10000.0,
        type: 'Bank',
        accountNumberSuffix: '5678',
      ),
      Account(
        id: 3,
        name: 'ICICI Credit Card',
        balance: -2000.0,
        type: 'Credit Card',
        accountNumberSuffix: '9012',
      ),
    ];

    final categories = [
      Category(id: 10, name: 'Food & Dining', type: 'expense'),
      Category(id: 11, name: 'Groceries', type: 'expense'),
      Category(id: 12, name: 'Transportation', type: 'expense'),
      Category(id: 13, name: 'Shopping', type: 'expense'),
      Category(id: 14, name: 'Entertainment', type: 'expense'),
      Category(id: 15, name: 'Salary', type: 'income'),
    ];

    test('1. Parses HDFC debit SMS with amount, merchant, and suffix correctly', () {
      const sms =
          'Alert: Rs 850.00 debited from HDFC Bank A/c XX1234 at SWIGGY on 06-10-26. Avl bal: Rs 49150.00.';

      final entity = SmsExtractionService.parseSmsText(sms);
      expect(entity.isFinancial, isTrue);
      expect(entity.amount, 850.00);
      expect(entity.type, 'expense');
      expect(entity.accountSuffix, '1234');
      expect(entity.merchant?.toUpperCase(), contains('SWIGGY'));

      final draft = SmsExtractionService.buildDraftTransaction(
        entity: entity,
        accounts: accounts,
        categories: categories,
        rawSms: sms,
      );

      expect(draft.amount, 850.00);
      expect(draft.accountId, 1); // Matched HDFC Salary
      expect(draft.hasUnassignedAccount, isFalse);
      expect(draft.categoryId, 10); // Matched Food & Dining via SWIGGY
      expect(draft.hasUnassignedCategory, isFalse);
    });

    test('2. Parses SBI credit SMS (income) correctly', () {
      const sms =
          'Your A/c 5678 is credited with INR 25,000.00 on 01-10-26 info/SALARY. Clear Bal: INR 35,000.00.';

      final entity = SmsExtractionService.parseSmsText(sms);
      expect(entity.isFinancial, isTrue);
      expect(entity.amount, 25000.00);
      expect(entity.type, 'income');
      expect(entity.accountSuffix, '5678');

      final draft = SmsExtractionService.buildDraftTransaction(
        entity: entity,
        accounts: accounts,
        categories: categories,
        rawSms: sms,
      );

      expect(draft.amount, 25000.00);
      expect(draft.type, 'income');
      expect(draft.accountId, 2); // Matched SBI Savings
      expect(draft.categoryId, 15); // Matched Salary
    });

    test('3. Parses Uber transportation expense with symbol ₹', () {
      const sms =
          'Spent ₹499.50 at UBER on card ending with 9012. Avl Lmt: ₹45,000.';

      final entity = SmsExtractionService.parseSmsText(sms);
      expect(entity.isFinancial, isTrue);
      expect(entity.amount, 499.50);
      expect(entity.type, 'expense');
      expect(entity.accountSuffix, '9012');
      expect(entity.merchant?.toUpperCase(), contains('UBER'));

      final draft = SmsExtractionService.buildDraftTransaction(
        entity: entity,
        accounts: accounts,
        categories: categories,
        rawSms: sms,
      );

      expect(draft.amount, 499.50);
      expect(draft.accountId, 3); // Matched ICICI Credit Card
      expect(draft.categoryId, 12); // Matched Transportation
      expect(draft.hasUnassignedCategory, isFalse);
    });

    test('4. Discards non-financial OTP messages and promotional discounts', () {
      const otpSms =
          'Your OTP for online transaction is 482910. Do not share this with anyone. Valid for 10 mins.';
      final entity1 = SmsExtractionService.parseSmsText(otpSms);
      expect(entity1.isFinancial, isFalse);

      const promoSms =
          'Get flat 50% off on your next purchase at Zara! Use code FLAT50. Valid today.';
      final entity2 = SmsExtractionService.parseSmsText(promoSms);
      expect(entity2.isFinancial, isFalse);
    });

    test('5. Hashing is deterministic for deduplication', () {
      const sms = 'Rs 150 debited from A/c 1234 at METRO';
      final hash1 = SmsExtractionService.computeSmsHash(
        'VM-HDFCBK',
        sms,
        '1728234500000',
      );
      final hash2 = SmsExtractionService.computeSmsHash(
        'VM-HDFCBK',
        sms,
        '1728234500000',
      );
      final hash3 = SmsExtractionService.computeSmsHash(
        'VM-HDFCBK',
        sms,
        '1728234999999',
      );

      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hash3)));
    });

    test('6. Bank sender detection verifies standard bank alphanumeric codes and DLT headers', () {
      expect(SmsExtractionService.isLikelyBankSender('AD-HDFCBK'), isTrue);
      expect(SmsExtractionService.isLikelyBankSender('VM-ICICIB'), isTrue);
      expect(SmsExtractionService.isLikelyBankSender('BZ-SBIINB'), isTrue);
      expect(SmsExtractionService.isLikelyBankSender('AXISBK'), isTrue);
      expect(SmsExtractionService.isLikelyBankSender('JD-SBICRD-S'), isTrue);
      expect(SmsExtractionService.isLikelyBankSender('AD-HDFCBK-T'), isTrue);
      expect(SmsExtractionService.isLikelyBankSender('JX-MAHABK-S'), isTrue);
      expect(SmsExtractionService.isLikelyBankSender('TX-HSBCIM-S'), isTrue);
      expect(SmsExtractionService.isLikelyBankSender('CP-CREDWL-S'), isTrue);
      expect(SmsExtractionService.isLikelyBankSender('JM-AxioPe-S'), isTrue);
      expect(SmsExtractionService.isLikelyBankSender('+919876543210'), isFalse);
      expect(SmsExtractionService.isLikelyBankSender('Mom'), isFalse);
    });

    test('7. Parses HDFC multiline UPI "Sent Rs." message', () {
      const sms =
          'Sent Rs.130.00\nFrom HDFC Bank A/C *9032\nTo SHAWARMA JUNCTION\nOn 18/10/26\nRef 665724774250\nNot You?';

      final entity = SmsExtractionService.parseSmsText(sms);
      expect(entity.isFinancial, isTrue);
      expect(entity.amount, 130.00);
      expect(entity.type, 'expense');
      expect(entity.accountSuffix, '9032');
      expect(entity.merchant, 'SHAWARMA JUNCTION');
      expect(entity.referenceNumber, '665724774250');
      expect(entity.date, '2026-10-18');
    });

    test('8. Parses ICICI Card expense with "on <date> on <MERCHANT>" format', () {
      const sms =
          'INR 3,230.00 spent using ICICI Bank Card XX8003 on 18-Oct-26 on M S UMED COLLEC. Avl Limit: INR 1,07,115.50.';

      final entity = SmsExtractionService.parseSmsText(sms);
      expect(entity.isFinancial, isTrue);
      expect(entity.amount, 3230.00);
      expect(entity.type, 'expense');
      expect(entity.accountSuffix, '8003');
      expect(entity.merchant, 'M S UMED COLLEC');
      expect(entity.date, '2026-10-18');
    });

    test('9. Parses Axis Bank UPI transaction from path structure', () {
      const sms =
          'INR 30.00 debited\nA/c no. XX1709\n14-10-26, 15:18:08\nUPI/P2M/665314039623/SmartWorks Stores\nNot you?';

      final entity = SmsExtractionService.parseSmsText(sms);
      expect(entity.isFinancial, isTrue);
      expect(entity.amount, 30.00);
      expect(entity.type, 'expense');
      expect(entity.accountSuffix, '1709');
      expect(entity.merchant, 'SmartWorks Stores');
      expect(entity.referenceNumber, '665314039623');
      expect(entity.date, '2026-10-14');
    });

    test('10. Parses Bank of Maharashtra UPI payment', () {
      const sms =
          'A/c X1717 debited by Rs. 2000.00 for UPI payment to JOHN DOE on 15-Oct-26. RRN: 665403265659 if not you';

      final entity = SmsExtractionService.parseSmsText(sms);
      expect(entity.isFinancial, isTrue);
      expect(entity.amount, 2000.00);
      expect(entity.type, 'expense');
      expect(entity.accountSuffix, '1717');
      expect(entity.merchant, 'JOHN DOE');
      expect(entity.referenceNumber, '665403265659');
      expect(entity.date, '2026-10-15');
    });

    test('11. Parses HDFC Card UPI with VPA containing @', () {
      const sms =
          'Txn Rs.89.00\nOn HDFC Bank Card 4569\nAt playstore1.bd@axisbank \nby UPI 309650712836\nOn 10-10';

      final entity = SmsExtractionService.parseSmsText(
        sms,
        fallbackDate: DateTime(2026, 10, 10),
      );
      expect(entity.isFinancial, isTrue);
      expect(entity.amount, 89.00);
      expect(entity.type, 'expense');
      expect(entity.accountSuffix, '4569');
      expect(entity.merchant, 'playstore1.bd@axisbank');
      expect(entity.referenceNumber, '309650712836');
      expect(entity.date, '2026-10-10');
    });

    test('12. Parses Loan / EMI "deducted from ... towards <NBFC>"', () {
      const sms =
          'PAYMENT ALERT! \nINR 28666.00 deducted from HDFC Bank A/C No 9032 towards ADITYA BIRLA CAPITAL LIMITED UMRN: HDFC7030109261032069';

      final entity = SmsExtractionService.parseSmsText(sms);
      expect(entity.isFinancial, isTrue);
      expect(entity.amount, 28666.00);
      expect(entity.type, 'expense');
      expect(entity.accountSuffix, '9032');
      expect(entity.merchant, 'ADITYA BIRLA CAPITAL LIMITED');
    });

    test('13. Rejects upcoming mandates and future payment alerts', () {
      const mandate1 =
          'Upcoming mandate is set for 10/10/26 12:00 AM. ? .89.00 towards Google Play Store will be debited from your HDFC Bank Credit Card 4569';
      expect(SmsExtractionService.parseSmsText(mandate1).isFinancial, isFalse);

      const mandate2 =
          'E-Mandate!\nRs.1699.00 will be deducted on 12/10/26, 00:00:00\nFor Policybazaar Insurance Brokers mandate\nMaintain Balance';
      expect(SmsExtractionService.parseSmsText(mandate2).isFinancial, isFalse);

      const reminder =
          'John Doe payment of Rs.1699 for your HDFC Life policy no. 12345678 is due on 2026-10-12. The amount will be debited from your credit card/bank account.';
      expect(SmsExtractionService.parseSmsText(reminder).isFinancial, isFalse);

      const statement =
          'Your statement for Axis Bank Credit Card no. XX1408 is generated.\nDue on: 30-10-26\nTotal amt: INR 0.00';
      expect(SmsExtractionService.parseSmsText(statement).isFinancial, isFalse);
    });

    test('14. Identifies credit card bill payments properly in buildDraftTransaction', () {
      const sms =
          'DEAR HDFCBANK CARDMEMBER, PAYMENT OF Rs. 2929.00 RECEIVED TOWARDS YOUR CREDIT CARD ENDING WITH 9012 ON 8-10-2026.YOUR AVAILABLE LIMIT IS RS. 294152.66';

      final entity = SmsExtractionService.parseSmsText(sms);
      expect(entity.isFinancial, isTrue);
      expect(entity.amount, 2929.00);
      expect(entity.accountSuffix, '9012');

      final draft = SmsExtractionService.buildDraftTransaction(
        entity: entity,
        accounts: accounts,
        categories: categories,
        rawSms: sms,
      );

      expect(draft.accountId, 3); // ICICI Credit Card with suffix 9012
      expect(draft.note, contains('Credit Card Bill Payment'));
    });

    test('15. Resolves fallbackDate correctly when SMS body contains no explicit date string', () {
      const sms =
          'Thank you for availing Pay Later credit of Rs289.45. For more info click https://example.com -axio';
      final fallback = DateTime(2026, 10, 14, 15, 30);
      final entity = SmsExtractionService.parseSmsText(
        sms,
        fallbackDate: fallback,
      );

      expect(entity.isFinancial, isTrue);
      expect(entity.amount, 289.45);
      expect(entity.date, '2026-10-14');
    });

    test('16. Resolves fallbackDate year when SMS contains day-month but no year', () {
      const sms =
          'Txn Rs.299.00\nOn HDFC Bank Card 4569\nAt *hypg@yespay\nby UPI 665692283728\nOn 17-10';
      final fallback = DateTime(2026, 10, 17, 21, 53);
      final entity = SmsExtractionService.parseSmsText(
        sms,
        fallbackDate: fallback,
      );

      expect(entity.isFinancial, isTrue);
      expect(entity.amount, 299.00);
      expect(entity.date, '2026-10-17');
    });

    test('17. buildSmsPrompt creates valid prompt containing metadata and user accounts/categories', () {
      final prompt = SmsExtractionService.buildSmsPrompt(
        sender: 'VM-HDFCBK',
        smsBody: 'Sent Rs.130.00 from HDFC Bank A/c 1234 to Shawarma Junction',
        accounts: accounts,
        categories: categories,
        anchorDate: DateTime(2026, 10, 18),
      );

      expect(prompt, contains('"name":"HDFC Salary"'));
      expect(prompt, contains('"suffix":"1234"'));
      expect(prompt, contains('"id":1'));
      expect(prompt, contains('"name":"Food & Dining"'));
      expect(prompt, contains('"id":10'));
      expect(prompt, contains('Sender: VM-HDFCBK'));
      expect(prompt, contains('2026-10-18'));
      expect(prompt, contains('Shawarma Junction'));
    });

    test('18. parseSmsWithSlm handles expense and maps account and category', () async {
      final mockEngine = MockSlmEngine(
        onGenerate: (prompt) {
          return '[{"amount": 450.0, "type": "expense", "account_id": 1, "category_id": 10, "date": "2026-10-18", "note": "Food at Dominos"}]';
        },
      );
      final slmService = SlmInferenceService(engine: mockEngine);
      await slmService.initialize(customModelPath: 'mock_path');

      final result = await SmsExtractionService.parseSmsWithSlm(
        slmService: slmService,
        sender: 'VM-HDFCBK',
        smsBody: 'INR 450.00 spent at Dominos on HDFC card 1234 on 18-10-2026',
        accounts: accounts,
        categories: categories,
        anchorDate: DateTime(2026, 10, 18),
      );

      expect(result, isNotNull);
      expect(result!.entity.isFinancial, isTrue);
      expect(result.entity.amount, 450.0);
      expect(result.entity.type, 'expense');
      expect(result.draft, isNotNull);
      expect(result.draft!.amount, 450.0);
      expect(result.draft!.type, 'expense');
      expect(result.draft!.accountId, 1);
      expect(result.draft!.categoryId, 10);
      expect(result.draft!.note, 'Food at Dominos');
    });

    test('19. parseSmsWithSlm handles transfer between two user accounts', () async {
      final mockEngine = MockSlmEngine(
        onGenerate: (prompt) {
          return '[{"amount": 5000.0, "type": "transfer", "account_id": 1, "destination_account_id": 2, "date": "2026-10-18", "note": "Transfer to SBI"}]';
        },
      );
      final slmService = SlmInferenceService(engine: mockEngine);
      await slmService.initialize(customModelPath: 'mock_path');

      final result = await SmsExtractionService.parseSmsWithSlm(
        slmService: slmService,
        sender: 'VM-HDFCBK',
        smsBody: 'Rs 5000 transferred from HDFC A/c 1234 to SBI A/c 5678 on 18-Oct-26',
        accounts: accounts,
        categories: categories,
        anchorDate: DateTime(2026, 10, 18),
      );

      expect(result, isNotNull);
      expect(result!.entity.isFinancial, isTrue);
      expect(result.entity.amount, 5000.0);
      expect(result.entity.type, 'transfer');
      expect(result.draft, isNotNull);
      expect(result.draft!.type, 'transfer');
      expect(result.draft!.accountId, 1);
      expect(result.draft!.destinationAccountId, 2);
    });

    test(
      '20. parseSmsWithSlm handles non-financial OTP/promotional message',
      () async {
        final mockEngine = MockSlmEngine(
          onGenerate: (prompt) {
            return '[]';
          },
        );
        final slmService = SlmInferenceService(engine: mockEngine);
        await slmService.initialize(customModelPath: 'mock_path');

        final result = await SmsExtractionService.parseSmsWithSlm(
          slmService: slmService,
          sender: 'VM-HDFCBK',
          smsBody: 'Your OTP for online transaction is 482910. Do not share it with anyone.',
          accounts: accounts,
          categories: categories,
          anchorDate: DateTime(2026, 10, 18),
        );

        expect(result, isNotNull);
        expect(result!.entity.isFinancial, isFalse);
        expect(result.draft, isNull);
      },
    );

    test('21. parseSmsWithSlm falls back to suffix match when SLM output misses account_id', () async {
      final mockEngine = MockSlmEngine(
        onGenerate: (prompt) {
          return '[{"amount": 120.0, "type": "expense", "category_id": 11, "date": "2026-10-18", "note": "Milk & eggs"}]';
        },
      );
      final slmService = SlmInferenceService(engine: mockEngine);
      await slmService.initialize(customModelPath: 'mock_path');

      final result = await SmsExtractionService.parseSmsWithSlm(
        slmService: slmService,
        sender: 'VM-HDFCBK',
        smsBody: 'Paid INR 120 from SBI A/c XX5678 for groceries',
        accounts: accounts,
        categories: categories,
        anchorDate: DateTime(2026, 10, 18),
      );

      expect(result, isNotNull);
      expect(result!.entity.isFinancial, isTrue);
      expect(result.draft, isNotNull);
      expect(result.draft!.accountId, 2); // Suffix 5678 matched SBI Savings
      expect(result.draft!.categoryId, 11);
    });
  });
}
