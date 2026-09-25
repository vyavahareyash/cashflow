import 'dart:io';

import 'package:cashflow/components/voice_transaction_staging_sheet.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/draft_transaction.dart';
import 'package:cashflow/screens/dashboard_screen.dart';
import 'package:cashflow/screens/history_screen.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  FakePathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;

  @override
  Future<String?> getTemporaryPath() async => tempDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.setTestDatabaseName(inMemoryDatabasePath);
  const databaseFileName = 'money_tracker.db';

  late Directory tempDir;

  setUp(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
    tempDir = await Directory.systemTemp.createTemp(
      'cashflow_voice_batch_test_',
    );
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
  });

  tearDown(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.emerald700,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.emerald700),
      ),
      home: Scaffold(body: child),
    );
  }

  group('Atomic Batch Commit and Reactive State Synchronization (Issue #88, #78)', () {
    test('1. commitDraftTransactions commits mixed valid batch atomically with single dataRevision bump', () async {
      final db = DatabaseHelper.instance;
      final bankId = await db.createAccount(
        Account(name: 'Main Checking', balance: 2000.0, type: 'Bank'),
      );
      final cashId = await db.createAccount(
        Account(name: 'Cash Pocket', balance: 500.0, type: 'Cash'),
      );
      final catFoodId = await db.createCategory(
        Category(name: 'Dining', monthlyBudget: 400.0, type: 'expense'),
      );
      final catIncomeId = await db.createCategory(
        Category(name: 'Side Gig', type: 'income'),
      );

      final initialRevision = DatabaseHelper.dataRevision.value;

      final drafts = [
        DraftTransaction(
          id: 'draft-expense',
          amount: 50.0,
          type: 'expense',
          accountId: bankId,
          categoryId: catFoodId,
          date: '2026-09-22',
          note: 'Sushi Lunch',
        ),
        DraftTransaction(
          id: 'draft-income',
          amount: 300.0,
          type: 'income',
          accountId: bankId,
          categoryId: catIncomeId,
          date: '2026-09-22',
          note: 'Consulting Payout',
        ),
        DraftTransaction(
          id: 'draft-transfer',
          amount: 100.0,
          type: 'transfer',
          accountId: bankId,
          destinationAccountId: cashId,
          date: '2026-09-22',
          note: 'ATM Cash Withdrawal',
        ),
      ];

      final insertedIds = await db.commitDraftTransactions(drafts);

      expect(insertedIds.length, equals(3));
      // Exactly 1 revision bump for the entire batch
      expect(DatabaseHelper.dataRevision.value, equals(initialRevision + 1));

      // Balances verified:
      // Bank: 2000 - 50 + 300 - 100 = 2150.0
      // Cash: 500 + 100 = 600.0
      final updatedBank = await db.readAccount(bankId);
      final updatedCash = await db.readAccount(cashId);
      expect(updatedBank?.balance, equals(2150.0));
      expect(updatedCash?.balance, equals(600.0));

      final history = await db.getTransactionHistory();
      expect(history.length, equals(3));
      expect(history.any((t) => t['note'] == 'Sushi Lunch'), isTrue);
      expect(history.any((t) => t['note'] == 'Consulting Payout'), isTrue);
      expect(history.any((t) => t['note'] == 'ATM Cash Withdrawal'), isTrue);
    });

    test('2. Atomic rollback integrity: entire batch rolls back if any write in the batch fails', () async {
      final db = DatabaseHelper.instance;
      final bankId = await db.createAccount(
        Account(name: 'Main Checking', balance: 1000.0, type: 'Bank'),
      );
      final catId = await db.createCategory(
        Category(name: 'Supplies', monthlyBudget: 200.0, type: 'expense'),
      );

      final initialRevision = DatabaseHelper.dataRevision.value;

      final drafts = [
        DraftTransaction(
          id: 'valid-first',
          amount: 120.0,
          type: 'expense',
          accountId: bankId,
          categoryId: catId,
          date: '2026-09-22',
          note: 'Office Chair',
        ),
        DraftTransaction(
          id: 'invalid-second',
          amount: 50.0,
          type: 'expense',
          accountId: 99999, // Non-existent account ID -> throws StateError
          categoryId: catId,
          date: '2026-09-22',
          note: 'Invalid Account Expense',
        ),
      ];

      expect(
        () async => await db.commitDraftTransactions(drafts),
        throwsA(isA<StateError>()),
      );

      // Verify complete rollback: zero transactions written
      final history = await db.getTransactionHistory();
      expect(history.isEmpty, isTrue);

      // Verify balance untouched
      final bank = await db.readAccount(bankId);
      expect(bank?.balance, equals(1000.0));

      // Revision was not incremented
      expect(DatabaseHelper.dataRevision.value, equals(initialRevision));
    });

    test('3. commitDraftTransactions with empty list is a no-op', () async {
      final initialRevision = DatabaseHelper.dataRevision.value;
      final ids = await DatabaseHelper.instance.commitDraftTransactions([]);
      expect(ids, isEmpty);
      expect(DatabaseHelper.dataRevision.value, equals(initialRevision));
    });

    testWidgets(
      '4. Staging sheet UI: 3 valid transactions -> tap "Approve All" (US 11)',
      (tester) async {
        final db = DatabaseHelper.instance;
        int bankId = 0;
        int catId = 0;
        await tester.runAsync(() async {
          bankId = await db.createAccount(
            Account(name: 'Primary Checking', balance: 1500.0, type: 'Bank'),
          );
          catId = await db.createCategory(
            Category(name: 'Groceries', monthlyBudget: 600.0, type: 'expense'),
          );
        });

        final testAccs = [
          Account(
            id: bankId,
            name: 'Primary Checking',
            balance: 1500.0,
            type: 'Bank',
          ),
        ];
        final testCats = [
          Category(
            id: catId,
            name: 'Groceries',
            monthlyBudget: 600.0,
            type: 'expense',
          ),
        ];

        final drafts = [
          DraftTransaction(
            id: 'draft-1',
            amount: 40.0,
            type: 'expense',
            accountId: bankId,
            categoryId: catId,
            date: '2026-09-22',
            note: 'Milk & Bread',
          ),
          DraftTransaction(
            id: 'draft-2',
            amount: 25.0,
            type: 'expense',
            accountId: bankId,
            categoryId: catId,
            date: '2026-09-22',
            note: 'Coffee Beans',
          ),
          DraftTransaction(
            id: 'draft-3',
            amount: 85.0,
            type: 'expense',
            accountId: bankId,
            categoryId: catId,
            date: '2026-09-22',
            note: 'Supermarket Run',
          ),
        ];

        List<DraftTransaction> committedBatch = [];

        await tester.pumpWidget(
          buildTestableWidget(
            VoiceTransactionStagingSheet(
              drafts: drafts,
              accounts: testAccs,
              categories: testCats,
              isPrivate: false,
              onCommit: (approved) async {
                committedBatch = approved;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Staged Transactions'), findsOneWidget);
        expect(find.text('Approve All (3)'), findsOneWidget);

        // Tap Approve All
        await tester.tap(find.text('Approve All (3)'));
        await tester.pumpAndSettle();

        // Verify all 3 transactions committed to batch callback
        expect(committedBatch.length, equals(3));

        // Commit to DB and verify atomic updates
        await tester.runAsync(() async {
          await db.commitDraftTransactions(committedBatch);
          final history = await db.getTransactionHistory();
          expect(history.length, equals(3));
          final bank = await db.readAccount(bankId);
          expect(bank?.balance, equals(1350.0));
        });
      },
    );

    testWidgets(
      '5. Staging sheet UI: 2 valid + 1 draft with missing account -> tap "Approve Valid" then fix and commit (US 12)',
      (tester) async {
        final db = DatabaseHelper.instance;
        int bankId = 0;
        int catId = 0;
        await tester.runAsync(() async {
          bankId = await db.createAccount(
            Account(name: 'Checking', balance: 1000.0, type: 'Bank'),
          );
          catId = await db.createCategory(
            Category(name: 'Fast Food', monthlyBudget: 200.0, type: 'expense'),
          );
        });

        final testAccs = [
          Account(id: bankId, name: 'Checking', balance: 1000.0, type: 'Bank'),
        ];
        final testCats = [
          Category(
            id: catId,
            name: 'Fast Food',
            monthlyBudget: 200.0,
            type: 'expense',
          ),
        ];

        final validDraft1 = DraftTransaction(
          id: 'valid-1',
          amount: 20.0,
          type: 'expense',
          accountId: bankId,
          categoryId: catId,
          date: '2026-09-22',
          note: 'Burger King',
        );
        final validDraft2 = DraftTransaction(
          id: 'valid-2',
          amount: 30.0,
          type: 'expense',
          accountId: bankId,
          categoryId: catId,
          date: '2026-09-22',
          note: 'Pizza Slice',
        );
        final missingAccountDraft = DraftTransaction(
          id: 'incomplete-3',
          amount: 15.0,
          type: 'expense',
          accountId: null, // missing account!
          categoryId: catId,
          date: '2026-09-22',
          note: 'Chai Stall',
          hasUnassignedAccount: true,
        );

        List<DraftTransaction> committedBatch1 = [];
        List<DraftTransaction> committedBatch2 = [];

        await tester.pumpWidget(
          buildTestableWidget(
            VoiceTransactionStagingSheet(
              drafts: [validDraft1, validDraft2, missingAccountDraft],
              accounts: testAccs,
              categories: testCats,
              isPrivate: false,
              onCommit: (approved) async {
                if (committedBatch1.isEmpty) {
                  committedBatch1 = approved;
                } else {
                  committedBatch2 = approved;
                }
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Approve Valid (2) is visible, Approve All is disabled
        expect(find.text('Approve Valid (2)'), findsOneWidget);
        expect(find.text('Approve All (3)'), findsOneWidget);

        // Tap Approve Valid (2)
        await tester.tap(find.text('Approve Valid (2)'));
        await tester.pumpAndSettle();

        expect(committedBatch1.length, equals(2));
        expect(committedBatch1.any((t) => t.note == 'Burger King'), isTrue);
        expect(committedBatch1.any((t) => t.note == 'Pizza Slice'), isTrue);

        await tester.runAsync(() async {
          await db.commitDraftTransactions(committedBatch1);
          final intermediateHistory = await db.getTransactionHistory();
          expect(intermediateHistory.length, equals(2));
          final intermediateBank = await db.readAccount(bankId);
          expect(intermediateBank?.balance, equals(950.0));
        });

        // Sheet is still open and incomplete draft remains on screen
        expect(find.text('Chai Stall'), findsOneWidget);
        expect(find.text('Select Account'), findsWidgets);

        // Tap account chip on the remaining draft to select account
        await tester.tap(find.text('Select Account').first);
        await tester.pumpAndSettle();

        // Choose Checking
        await tester.tap(find.text('Checking'));
        await tester.pumpAndSettle();

        // Now draft is valid, Approve All (1) is available
        expect(find.text('Approve All (1)'), findsOneWidget);

        // Tap Approve All (1)
        await tester.tap(find.text('Approve All (1)'));
        await tester.pumpAndSettle();

        expect(committedBatch2.length, equals(1));
        expect(committedBatch2.first.note, equals('Chai Stall'));

        // Commit final batch to DB
        await tester.runAsync(() async {
          await db.commitDraftTransactions(committedBatch2);
          final finalHistory = await db.getTransactionHistory();
          expect(finalHistory.length, equals(3));
          expect(finalHistory.any((t) => t['note'] == 'Chai Stall'), isTrue);

          final finalBank = await db.readAccount(bankId);
          expect(finalBank?.balance, equals(935.0));
        });
      },
    );

    testWidgets(
      '6. Reactive state synchronization: Dashboard updates immediately upon commitDraftTransactions',
      (tester) async {
        DashboardScreen.resetStartupPrivacyFlag();
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final db = DatabaseHelper.instance;
        int bankId = 0;
        int catId = 0;
        await tester.runAsync(() async {
          bankId = await db.createAccount(
            Account(name: 'Checking', balance: 5000.0, type: 'Bank'),
          );
          catId = await db.createCategory(
            Category(name: 'Tech', monthlyBudget: 1000.0, type: 'expense'),
          );
        });

        await tester.pumpWidget(buildTestableWidget(const DashboardScreen()));
        await tester.pump();
        for (int i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
        }

        // Initial state: no transactions in recent list
        expect(find.text('Keyboard Purchase'), findsNothing);

        // Commit draft transaction via database helper
        await tester.runAsync(() async {
          await db.commitDraftTransactions([
            DraftTransaction(
              amount: 150.0,
              type: 'expense',
              accountId: bankId,
              categoryId: catId,
              date: '2026-09-22',
              note: 'Keyboard Purchase',
            ),
          ]);
        });

        // Pump frames to process ValueNotifier update
        await tester.pump();
        for (int i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (find.text('Keyboard Purchase').evaluate().isNotEmpty) break;
        }

        // Dashboard reacted immediately and displays the committed transaction
        expect(find.text('Keyboard Purchase'), findsOneWidget);
      },
    );

    testWidgets(
      '7. Reactive state synchronization: Activity Ledger in HistoryScreen updates immediately upon commitDraftTransactions',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final db = DatabaseHelper.instance;
        int bankId = 0;
        int catId = 0;
        await tester.runAsync(() async {
          bankId = await db.createAccount(
            Account(name: 'Main Bank', balance: 3000.0, type: 'Bank'),
          );
          catId = await db.createCategory(
            Category(name: 'Utilities', monthlyBudget: 500.0, type: 'expense'),
          );
        });

        await tester.pumpWidget(buildTestableWidget(const HistoryScreen()));
        await tester.pump();
        for (int i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
        }

        expect(find.byType(HistoryScreen), findsOneWidget);
        expect(find.text('Electric Bill'), findsNothing);

        // Commit draft batch
        await tester.runAsync(() async {
          await db.commitDraftTransactions([
            DraftTransaction(
              amount: 80.0,
              type: 'expense',
              accountId: bankId,
              categoryId: catId,
              date: '2026-09-22',
              note: 'Electric Bill',
            ),
          ]);
        });

        // Pump frames
        await tester.pump();
        for (int i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (find.text('Electric Bill').evaluate().isNotEmpty) break;
        }

        // Activity Ledger updated reactively and shows the transaction
        expect(find.text('Electric Bill'), findsOneWidget);
      },
    );

    test('7. commitDraftTransactions commits income draft with income category and preserves categoryId', () async {
      final db = DatabaseHelper.instance;
      final accId = await db.createAccount(
        Account(name: 'Checking Acc', balance: 1000.0, type: 'Bank'),
      );
      final incCatId = await db.createCategory(
        Category(name: 'Cashback', type: 'income'),
      );

      final ids = await db.commitDraftTransactions([
        DraftTransaction(
          amount: 50.0,
          type: 'income',
          accountId: accId,
          categoryId: incCatId,
          date: '2026-09-22',
          note: 'Cashback Reward',
        ),
      ]);

      expect(ids.length, 1);
      final txns = await db.getTransactionHistory();
      expect(txns.length, 1);
      expect(txns.first['type'], 'income');
      expect(txns.first['amount'], 50.0);
      expect(txns.first['category_id'], incCatId);
      expect(txns.first['category_name'], 'Cashback');

      final updatedAcc = await db.readAccount(accId);
      expect(updatedAcc?.balance, 1050.0);
    });

    test(
      '8. commitDraftTransactions rejects draft with mismatched category type',
      () async {
        final db = DatabaseHelper.instance;
        final accId = await db.createAccount(
          Account(name: 'Checking Acc 2', balance: 1000.0, type: 'Bank'),
        );
        final expenseCatId = await db.createCategory(
          Category(name: 'Dining', monthlyBudget: 200.0, type: 'expense'),
        );
        final incomeCatId = await db.createCategory(
          Category(name: 'Refund', type: 'income'),
        );

        // Income draft with expense category -> throws ArgumentError
        expect(
          () => db.commitDraftTransactions([
            DraftTransaction(
              amount: 30.0,
              type: 'income',
              accountId: accId,
              categoryId: expenseCatId,
              date: '2026-09-22',
              note: 'Invalid Income',
            ),
          ]),
          throwsArgumentError,
        );

        // Expense draft with income category -> throws ArgumentError
        expect(
          () => db.commitDraftTransactions([
            DraftTransaction(
              amount: 30.0,
              type: 'expense',
              accountId: accId,
              categoryId: incomeCatId,
              date: '2026-09-22',
              note: 'Invalid Expense',
            ),
          ]),
          throwsArgumentError,
        );
      },
    );
  });
}
