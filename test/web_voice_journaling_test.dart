import 'dart:async';
import 'dart:io';

import 'package:cashflow/components/voice_model_download_sheet.dart';
import 'package:cashflow/components/voice_recording_modal.dart';
import 'package:cashflow/components/voice_transaction_staging_sheet.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/draft_transaction.dart';
import 'package:cashflow/screens/backup_restore_screen.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/services/model_management_service_web.dart'
    as web_model;
import 'package:cashflow/services/slm_inference_service.dart';
import 'package:cashflow/services/speech_to_text_service.dart';
import 'package:cashflow/services/voice_audio_pipeline.dart';
import 'package:cashflow/services/voice_entity_parser.dart';
import 'package:cashflow/services/voice_pipeline_coordinator.dart';
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

class FakeAudioPipeline extends Fake implements VoiceAudioPipeline {
  @override
  bool get isRecording => false;

  @override
  Stream<double> get amplitudeStream => const Stream.empty();

  @override
  Future<String> startRecording() async => '';

  @override
  Future<void> cancelRecording() async {}

  @override
  Future<int> purgeLingeringCache() async => 0;

  @override
  Future<void> dispose() async {}
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
    tempDir = await Directory.systemTemp.createTemp('cashflow_web_voice_test_');
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

  Widget buildTestApp(VoicePipelineCoordinator testCoord, {bool isWeb = true}) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.emerald700,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.emerald700),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              key: const Key('open_modal_button'),
              onPressed: () => VoiceRecordingModal.show(
                context,
                coordinator: testCoord,
                isWeb: isWeb,
              ),
              child: const Text('Open Modal'),
            ),
          ),
        ),
      ),
    );
  }

  group('1. Web Model Management Service Stubs (Zero-Download Guarantee)', () {
    test('reports installed status and zero storage footprint', () async {
      final service = web_model.ModelManagementService();

      expect(service.status, equals(web_model.ModelPackStatus.installed));
      expect(await service.isModelPackInstalled(), isTrue);
      expect(
        await service.checkInstalledStatus(),
        equals(web_model.ModelPackStatus.installed),
      );
      expect(service.statusDetail, contains('Web speech engine ready'));
      expect(service.errorMessage, isNull);
      expect(service.bytesDownloaded, equals(0));
      expect(service.totalBytes, equals(0));
      expect(service.progress, equals(1.0));
      expect(service.isDownloading, isFalse);
      expect(service.isInstalled, isTrue);
      expect(await service.getModelsDiskUsage(), equals(0));
      expect(
        await service.checkNetworkType(),
        equals(web_model.NetworkType.wifi),
      );
    });

    test('download and lifecycle calls complete safely on web', () async {
      final service = web_model.ModelManagementService();

      final downloadResult = await service.downloadModelPack();
      expect(downloadResult, isTrue);

      service.cancelDownload();
      await service.deleteModels();
      await service.loadModelsIntoMemory();
      await service.unloadModelsFromMemory();

      expect(
        () =>
            service.downloadClient.openStream(Uri.parse('https://example.com')),
        throwsUnsupportedError,
      );
    });
  });

  group('2. Browser STT Error Formatting & Permission Handling', () {
    test(
      'translates not-allowed error to graceful browser microphone message',
      () {
        final msg = SpeechToTextService.formatSttErrorMessage(
          'error_not-allowed',
          isWeb: true,
        );
        expect(
          msg,
          equals(
            'Microphone permission denied. Grant permission in your browser to use voice journaling.',
          ),
        );
      },
    );

    test('translates generic permission error to permission guidance', () {
      final msg = SpeechToTextService.formatSttErrorMessage(
        'permission-denied',
        isWeb: true,
      );
      expect(msg, contains('Microphone permission denied'));
    });

    test(
      'translates not-supported error to browser compatibility guidance',
      () {
        final msg = SpeechToTextService.formatSttErrorMessage(
          'not-supported-in-browser',
          isWeb: true,
        );
        expect(
          msg,
          equals(
            'Web Speech API is not supported in this browser. Please use Chrome, Edge, or Safari.',
          ),
        );
      },
    );

    test('maps not-allowed error string to SttPermissionDeniedException', () {
      final ex = SpeechToTextService.mapSttErrorToException(
        'not-allowed',
        isWeb: true,
      );
      expect(ex, isA<SttPermissionDeniedException>());
      expect(
        (ex as SttPermissionDeniedException).message,
        contains('Grant permission in your browser'),
      );
    });

    test('maps not-supported error string to SttNotSupportedException', () {
      final ex = SpeechToTextService.mapSttErrorToException(
        'speech recognition not-supported',
        isWeb: true,
      );
      expect(ex, isA<SttNotSupportedException>());
    });
  });

  group('3. Web Voice UI Presentation (Zero Download & Permission UI)', () {
    testWidgets(
      'VoiceModelDownloadSheet displays Web Speech Ready with zero download highlights',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(const VoiceModelDownloadSheet(isWeb: true)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Web Speech Engine Ready'), findsOneWidget);
        expect(find.text('100% Client-Side & Private'), findsOneWidget);
        expect(find.text('Zero Download Required'), findsOneWidget);
        expect(find.text('Deterministic Heuristic Parser'), findsOneWidget);
        expect(find.text('Start Voice Journaling'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);

        // Verify mobile-only download components are absent
        expect(find.byKey(const Key('voice_model_progress_bar')), findsNothing);
        expect(find.text('Offline AI Models Required'), findsNothing);
      },
    );

    testWidgets(
      'BackupRestoreScreen displays Web AI model card with 0.0 MB footprint',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(const BackupRestoreScreen(isWeb: true)),
        );
        await tester.pumpAndSettle();

        final cardFinder = find.byKey(const Key('voice_model_card'));
        await tester.ensureVisible(cardFinder);

        expect(cardFinder, findsOneWidget);
        expect(find.text('Ready (Zero Download)'), findsOneWidget);
        expect(find.text('0.0 MB Footprint'), findsOneWidget);
        expect(
          find.byKey(const Key('web_speech_active_banner')),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Browser-native Web Speech recognition is active',
          ),
          findsOneWidget,
        );

        // Mobile controls must be hidden
        expect(
          find.byKey(const Key('voice_models_wifi_only_switch')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('voice_model_download_button')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('voice_model_delete_button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'VoiceRecordingModal renders web engine badge and initial status',
      (tester) async {
        final mockStt = MockSttEngine();
        final coordinator = VoicePipelineCoordinator(
          audioPipeline: FakeAudioPipeline(),
          speechToTextService: SpeechToTextService(engine: mockStt),
          slmService: SlmInferenceService(engine: MockSlmEngine()),
          isWeb: true,
        );

        await tester.pumpWidget(buildTestApp(coordinator, isWeb: true));
        await tester.tap(find.byKey(const Key('open_modal_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Web Speech Voice Engine (Zero Download)'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('voice_recording_engine_badge')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'VoiceRecordingModal displays browser permission error when STT error occurs',
      (tester) async {
        final mockStt = MockSttEngine();
        final coordinator = VoicePipelineCoordinator(
          audioPipeline: FakeAudioPipeline(),
          speechToTextService: SpeechToTextService(engine: mockStt),
          slmService: SlmInferenceService(engine: MockSlmEngine()),
          isWeb: true,
        );

        await tester.pumpWidget(buildTestApp(coordinator, isWeb: true));
        await tester.tap(find.byKey(const Key('open_modal_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Emit browser microphone permission error into coordinator
        coordinator.emitError(
          'Microphone permission denied. Grant permission in your browser to use voice journaling.',
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.textContaining('Microphone permission denied'),
          findsOneWidget,
        );
        expect(find.text('Close'), findsOneWidget);
      },
    );
  });

  group('4. Client-Side Heuristic Parsing for Web Transcripts', () {
    final anchor = DateTime(2026, 9, 23);
    final testAccounts = [
      Account(id: 1, name: 'Chase Checking', balance: 1500.0, type: 'Bank'),
      Account(id: 2, name: 'Cash Wallet', balance: 200.0, type: 'Cash'),
    ];
    final testCategories = [
      Category(id: 1, name: 'Groceries', monthlyBudget: 400.0, type: 'expense'),
      Category(
        id: 2,
        name: 'Dining Out',
        monthlyBudget: 300.0,
        type: 'expense',
      ),
      Category(id: 3, name: 'Salary', type: 'income'),
    ];

    test('parses single expense with merchant and category accurately', () {
      const transcript = 'Spent 45 dollars at Trader Joes for groceries';
      final drafts = VoiceEntityParser.parseTranscriptionSample(
        transcript,
        anchorDate: anchor,
        accounts: testAccounts,
        categories: testCategories,
      );

      expect(drafts, hasLength(1));
      final draft = drafts.first;
      expect(draft.amount, equals(45.0));
      expect(draft.isExpense, isTrue);
      expect(draft.categoryId, equals(1)); // Groceries
      expect(draft.accountId, equals(1)); // Primary account
      expect(draft.date, equals('2026-09-23'));
    });

    test('parses income transaction accurately', () {
      const transcript = 'Received salary 3500 from Acme Corp';
      final drafts = VoiceEntityParser.parseTranscriptionSample(
        transcript,
        anchorDate: anchor,
        accounts: testAccounts,
        categories: testCategories,
      );

      expect(drafts, hasLength(1));
      final draft = drafts.first;
      expect(draft.amount, equals(3500.0));
      expect(draft.isIncome, isTrue);
      expect(draft.categoryId, equals(3)); // Salary
    });

    test('parses multiple transactions in single monologue', () {
      const transcript = 'Spent 15 on lunch and 35 on groceries';
      final drafts = VoiceEntityParser.parseTranscriptionSample(
        transcript,
        anchorDate: anchor,
        accounts: testAccounts,
        categories: testCategories,
      );

      expect(drafts, hasLength(2));
      expect(drafts[0].amount, equals(15.0));
      expect(drafts[1].amount, equals(35.0));
    });

    test('resolves relative dates deterministically', () {
      const transcript = 'Spent 20 on coffee yesterday';
      final drafts = VoiceEntityParser.parseTranscriptionSample(
        transcript,
        anchorDate: anchor,
        accounts: testAccounts,
        categories: testCategories,
      );

      expect(drafts, hasLength(1));
      expect(drafts.first.date, equals('2026-09-22')); // Yesterday
    });
  });

  group('5. Staging Sheet Review & Atomic SQLite Commit', () {
    setUp(() async {
      final db = DatabaseHelper.instance;
      await db.createAccount(
        Account(id: 1, name: 'Primary Checking', balance: 2000.0, type: 'Bank'),
      );
      await db.createCategory(
        Category(
          id: 1,
          name: 'Groceries',
          monthlyBudget: 500.0,
          type: 'expense',
        ),
      );
      await db.createCategory(
        Category(id: 2, name: 'Consulting', type: 'income'),
      );
    });

    testWidgets('renders parsed drafts in VoiceTransactionStagingSheet', (
      tester,
    ) async {
      final drafts = [
        DraftTransaction(
          id: 'web-draft-1',
          amount: 45.0,
          type: 'expense',
          accountId: 1,
          categoryId: 1,
          date: '2026-09-23',
          note: 'Trader Joes',
        ),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          VoiceTransactionStagingSheet(
            drafts: drafts,
            accounts: [
              Account(
                id: 1,
                name: 'Primary Checking',
                balance: 2000.0,
                type: 'Bank',
              ),
            ],
            categories: [
              Category(
                id: 1,
                name: 'Groceries',
                monthlyBudget: 500.0,
                type: 'expense',
              ),
            ],
            isPrivate: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Staged Transactions'), findsOneWidget);
      expect(find.text('Trader Joes'), findsOneWidget);
      expect(find.text('₹45'), findsOneWidget);
      expect(find.text('Primary Checking'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Approve All (1)'), findsOneWidget);
    });

    test('commits batch transactions atomically to SQLite database', () async {
      final db = DatabaseHelper.instance;
      final initialRevision = DatabaseHelper.dataRevision.value;

      final drafts = [
        DraftTransaction(
          id: 'draft-1',
          amount: 50.0,
          type: 'expense',
          accountId: 1,
          categoryId: 1,
          date: '2026-09-23',
          note: 'Whole Foods Market',
        ),
        DraftTransaction(
          id: 'draft-2',
          amount: 300.0,
          type: 'income',
          accountId: 1,
          categoryId: 2,
          date: '2026-09-23',
          note: 'Freelance Design',
        ),
      ];

      final insertedIds = await db.commitDraftTransactions(drafts);
      expect(insertedIds, hasLength(2));

      // Revision increments
      expect(DatabaseHelper.dataRevision.value, equals(initialRevision + 1));

      // Verify account balance updated atomically: 2000 - 50 + 300 = 2250
      final account = await db.readAccount(1);
      expect(account?.balance, equals(2250.0));

      // Verify transactions exist in table
      final sqliteDb = await db.database;
      final allTxns = await sqliteDb.query('transactions');
      expect(allTxns, hasLength(2));
      expect(
        allTxns.any(
          (t) => t['note'] == 'Whole Foods Market' && t['amount'] == 50.0,
        ),
        isTrue,
      );
      expect(
        allTxns.any(
          (t) => t['note'] == 'Freelance Design' && t['amount'] == 300.0,
        ),
        isTrue,
      );
    });

    test('rolls back entire transaction if any draft is invalid', () async {
      final db = DatabaseHelper.instance;
      final initialRevision = DatabaseHelper.dataRevision.value;

      final drafts = [
        DraftTransaction(
          id: 'draft-valid',
          amount: 50.0,
          type: 'expense',
          accountId: 1,
          categoryId: 1,
          date: '2026-09-23',
          note: 'Valid Coffee',
        ),
        DraftTransaction(
          id: 'draft-invalid',
          amount: -10.0, // Invalid negative amount
          type: 'expense',
          accountId: 1,
          categoryId: 1,
          date: '2026-09-23',
          note: 'Invalid Item',
        ),
      ];

      expect(() => db.commitDraftTransactions(drafts), throwsArgumentError);

      // Verify rollback: no transactions inserted, account balance unchanged
      final sqliteDb = await db.database;
      final allTxns = await sqliteDb.query('transactions');
      expect(allTxns, isEmpty);

      final account = await db.readAccount(1);
      expect(account?.balance, equals(2000.0));
      expect(DatabaseHelper.dataRevision.value, equals(initialRevision));
    });
  });
}
