import 'dart:io';

import 'package:cashflow/components/voice_model_download_sheet.dart';
import 'package:cashflow/components/voice_recording_modal.dart';
import 'package:cashflow/components/voice_transaction_staging_sheet.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/draft_transaction.dart';
import 'package:cashflow/screens/dashboard_screen.dart';
import 'package:cashflow/main.dart';
import 'package:cashflow/services/audio_capture_service.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/services/model_management_service.dart';
import 'package:cashflow/services/slm_inference_service.dart';
import 'package:cashflow/services/speech_to_text_service.dart';
import 'package:cashflow/services/voice_audio_pipeline.dart';
import 'package:cashflow/services/voice_pipeline_coordinator.dart';
import 'package:cashflow/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeAudioRecorderClient implements AudioRecorderClient {
  bool permissionGranted;
  bool recordingActive = false;
  String? lastPath;

  FakeAudioRecorderClient({this.permissionGranted = true});

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> isRecording() async => recordingActive;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    lastPath = path;
    recordingActive = true;
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    file.writeAsBytesSync(List.filled(200, 1));
  }

  @override
  Future<String?> stop() async {
    recordingActive = false;
    return lastPath;
  }

  @override
  Future<void> cancel() async {
    recordingActive = false;
    if (lastPath != null) {
      final f = File(lastPath!);
      if (f.existsSync()) f.deleteSync();
    }
  }

  @override
  Future<void> dispose() async {
    recordingActive = false;
  }

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream.empty();

  @override
  Future<Amplitude> getAmplitude() async =>
      Amplitude(current: -30.0, max: -10.0);
}

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

  final testAccounts = [
    Account(id: 1, name: 'Chase Checking', balance: 2500.0, type: 'Bank'),
    Account(id: 2, name: 'Cash Wallet', balance: 350.0, type: 'Cash'),
    Account(
      id: 3,
      name: 'Sapphire Preferred',
      balance: 120.0,
      type: 'Credit Card',
    ),
  ];

  final testCategories = [
    Category(
      id: 1,
      name: 'Food & Dining',
      monthlyBudget: 500.0,
      type: 'expense',
    ),
    Category(id: 2, name: 'Groceries', monthlyBudget: 400.0, type: 'expense'),
    Category(
      id: 3,
      name: 'Transportation',
      monthlyBudget: 200.0,
      type: 'expense',
    ),
    Category(id: 4, name: 'Salary', type: 'income'),
  ];

  setUp(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
    tempDir = await Directory.systemTemp.createTemp(
      'cashflow_voice_staging_test_',
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

  group(
    'VoiceTransactionStagingSheet Widget Tests (US 3, 8, 9, 10, 18, 20)',
    () {
      testWidgets(
        '1. Renders mock draft transactions with chips and notes (US 3, 9)',
        (tester) async {
          final drafts = [
            DraftTransaction(
              id: 'draft-1',
              amount: 45.0,
              type: 'expense',
              accountId: 1,
              categoryId: 1,
              date: '2026-09-22',
              note: 'Dinner at Subway',
            ),
          ];

          await tester.pumpWidget(
            buildTestableWidget(
              VoiceTransactionStagingSheet(
                drafts: drafts,
                accounts: testAccounts,
                categories: testCategories,
                isPrivate: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Staged Transactions'), findsOneWidget);
          expect(find.text('Dinner at Subway'), findsOneWidget);
          expect(find.text('₹45'), findsOneWidget);
          expect(find.text('Chase Checking'), findsOneWidget);
          expect(find.text('Food & Dining'), findsOneWidget);
          expect(find.text('2026-09-22'), findsOneWidget);
          expect(find.text('Approve All (1)'), findsOneWidget);
        },
      );

      testWidgets(
        '2. Displays warning badges on unassigned or inferred fields (US 8)',
        (tester) async {
          final drafts = [
            DraftTransaction(
              id: 'draft-inferred-acc',
              amount: 15.0,
              type: 'expense',
              accountId: 1,
              categoryId: null,
              date: '2026-09-22',
              note: 'Corner store purchase',
              hasUnassignedAccount: true,
              hasUnassignedCategory: true,
            ),
          ];

          await tester.pumpWidget(
            buildTestableWidget(
              VoiceTransactionStagingSheet(
                drafts: drafts,
                accounts: testAccounts,
                categories: testCategories,
                isPrivate: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('Default Account Inferred: Review Account'),
            findsOneWidget,
          );
          expect(find.text('Unassigned Category: Tap to Pick'), findsOneWidget);
          expect(
            find.text(
              'Some entries have missing or inferred fields. Tap tiles to adjust.',
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        '3. Interactive inline Amount chip tap allows in-place amount update (US 9)',
        (tester) async {
          final drafts = [
            DraftTransaction(
              id: 'draft-amt',
              amount: 30.0,
              type: 'expense',
              accountId: 1,
              categoryId: 1,
              date: '2026-09-22',
              note: 'Coffee meeting',
            ),
          ];

          await tester.pumpWidget(
            buildTestableWidget(
              VoiceTransactionStagingSheet(
                drafts: drafts,
                accounts: testAccounts,
                categories: testCategories,
                isPrivate: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Tap Amount chip
          await tester.tap(find.text('₹30'));
          await tester.pumpAndSettle();

          // Dialog opens
          expect(find.text('Edit Amount'), findsOneWidget);
          final textField = find.byType(TextField);
          expect(textField, findsOneWidget);

          await tester.enterText(textField, '75.50');
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();

          // Value updated in chip
          expect(find.text('₹75.50'), findsOneWidget);
        },
      );

      testWidgets(
        '4. Interactive inline Account chip tap selects new account and clears warning (US 9, 8)',
        (tester) async {
          final drafts = [
            DraftTransaction(
              id: 'draft-acc',
              amount: 50.0,
              type: 'expense',
              accountId: 1,
              categoryId: 1,
              date: '2026-09-22',
              note: 'Gas station',
              hasUnassignedAccount: true,
            ),
          ];

          await tester.pumpWidget(
            buildTestableWidget(
              VoiceTransactionStagingSheet(
                drafts: drafts,
                accounts: testAccounts,
                categories: testCategories,
                isPrivate: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('Default Account Inferred: Review Account'),
            findsOneWidget,
          );

          // Tap Account chip
          await tester.tap(find.text('Chase Checking'));
          await tester.pumpAndSettle();

          // Modal bottom sheet with accounts appears
          expect(find.text('Select Account'), findsOneWidget);
          expect(find.text('Cash Wallet'), findsOneWidget);

          // Pick Cash Wallet
          await tester.tap(find.text('Cash Wallet'));
          await tester.pumpAndSettle();

          // Chip updated, warning cleared
          expect(find.text('Cash Wallet'), findsOneWidget);
          expect(
            find.text('Default Account Inferred: Review Account'),
            findsNothing,
          );
        },
      );

      testWidgets(
        '5. Interactive inline Category chip tap selects category and clears warning (US 9, 8)',
        (tester) async {
          final drafts = [
            DraftTransaction(
              id: 'draft-cat',
              amount: 80.0,
              type: 'expense',
              accountId: 1,
              categoryId: null,
              date: '2026-09-22',
              note: 'Supermarket weekly trip',
              hasUnassignedCategory: true,
            ),
          ];

          await tester.pumpWidget(
            buildTestableWidget(
              VoiceTransactionStagingSheet(
                drafts: drafts,
                accounts: testAccounts,
                categories: testCategories,
                isPrivate: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Select Category'), findsOneWidget);
          expect(find.text('Unassigned Category: Tap to Pick'), findsOneWidget);

          // Tap Category chip
          await tester.tap(find.text('Select Category'));
          await tester.pumpAndSettle();

          expect(find.text('Groceries'), findsOneWidget);

          // Select Groceries
          await tester.tap(find.text('Groceries'));
          await tester.pumpAndSettle();

          expect(find.text('Groceries'), findsOneWidget);
          expect(find.text('Unassigned Category: Tap to Pick'), findsNothing);
        },
      );

      testWidgets('6. Swipe-away dismisses draft card cleanly (US 10)', (
        tester,
      ) async {
        final drafts = [
          DraftTransaction(
            id: 'draft-swipe-1',
            amount: 25.0,
            type: 'expense',
            accountId: 1,
            categoryId: 1,
            date: '2026-09-22',
            note: 'Duplicate sandwich order',
          ),
          DraftTransaction(
            id: 'draft-keep-2',
            amount: 60.0,
            type: 'expense',
            accountId: 1,
            categoryId: 2,
            date: '2026-09-22',
            note: 'Legitimate grocery receipt',
          ),
        ];

        await tester.pumpWidget(
          buildTestableWidget(
            VoiceTransactionStagingSheet(
              drafts: drafts,
              accounts: testAccounts,
              categories: testCategories,
              isPrivate: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Duplicate sandwich order'), findsOneWidget);
        expect(find.text('Legitimate grocery receipt'), findsOneWidget);

        // Swipe left on first card
        await tester.drag(
          find.text('Duplicate sandwich order'),
          const Offset(-500, 0),
        );
        await tester.pumpAndSettle();

        // First card dismissed, second card remains
        expect(find.text('Duplicate sandwich order'), findsNothing);
        expect(find.text('Legitimate grocery receipt'), findsOneWidget);
        expect(find.text('(1)'), findsOneWidget);
      });

      testWidgets(
        '7. Delete button dismisses draft card and shows empty state when all dismissed (US 10)',
        (tester) async {
          final drafts = [
            DraftTransaction(
              id: 'draft-delete-1',
              amount: 10.0,
              type: 'expense',
              accountId: 1,
              date: '2026-09-22',
              note: 'Erroneous charge',
            ),
          ];

          await tester.pumpWidget(
            buildTestableWidget(
              VoiceTransactionStagingSheet(
                drafts: drafts,
                accounts: testAccounts,
                categories: testCategories,
                isPrivate: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Erroneous charge'), findsOneWidget);

          // Tap delete icon button
          await tester.tap(find.byIcon(Icons.delete_outline_rounded));
          await tester.pumpAndSettle();

          // Empty state shown
          expect(find.text('No draft transactions remaining'), findsOneWidget);
          expect(
            find.text('All drafts have been committed or dismissed cleanly.'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        '8. Respects Privacy Mode bullet masks (\$••••••) and header toggle (US 18)',
        (tester) async {
          final drafts = [
            DraftTransaction(
              id: 'draft-priv',
              amount: 450.0,
              type: 'expense',
              accountId: 1,
              categoryId: 1,
              date: '2026-09-22',
              note: 'Electronic appliance',
            ),
          ];

          await tester.pumpWidget(
            buildTestableWidget(
              VoiceTransactionStagingSheet(
                drafts: drafts,
                accounts: testAccounts,
                categories: testCategories,
                isPrivate: true,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Verify masked amount
          expect(find.text('••••••'), findsOneWidget);
          expect(find.text('₹450'), findsNothing);

          // Toggle privacy off via staging header icon
          await tester.tap(find.byTooltip('Show Amounts'));
          await tester.pumpAndSettle();

          // Unmasked amount
          expect(find.text('₹450'), findsOneWidget);
          expect(find.text('••••••'), findsNothing);
        },
      );

      testWidgets(
        '9. Clean exit leaves 0 orphaned records in SQLite database (US 20)',
        (tester) async {
          final db = DatabaseHelper.instance;
          int initialTxCount = 0;
          await tester.runAsync(() async {
            await db.seedDatabase();
            initialTxCount = (await db.getTransactionHistory()).length;
          });

          final drafts = [
            DraftTransaction(
              id: 'draft-clean-exit',
              amount: 99.0,
              type: 'expense',
              accountId: 1,
              categoryId: 1,
              date: '2026-09-22',
              note: 'Uncommitted draft during cancellation',
            ),
          ];

          await tester.pumpWidget(
            buildTestableWidget(
              Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () async {
                    await VoiceTransactionStagingSheet.show(
                      ctx,
                      drafts: drafts,
                      accounts: testAccounts,
                      categories: testCategories,
                      isPrivate: false,
                    );
                  },
                  child: const Text('Open Staging'),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Open staging sheet
          await tester.tap(find.text('Open Staging'));
          await tester.pumpAndSettle();

          expect(
            find.text('Uncommitted draft during cancellation'),
            findsOneWidget,
          );

          // Discard all drafts
          await tester.tap(find.text('Discard All'));
          await tester.pumpAndSettle();

          // Modal closed
          expect(
            find.text('Uncommitted draft during cancellation'),
            findsNothing,
          );

          // Verify SQLite transaction table has zero new records
          int finalTxCount = 0;
          await tester.runAsync(() async {
            finalTxCount = (await db.getTransactionHistory()).length;
          });
          expect(finalTxCount, equals(initialTxCount));
        },
      );

      testWidgets(
        '10. Dashboard hero balance card excludes mic icon; standard quick actions preserved',
        (tester) async {
          DashboardScreen.resetStartupPrivacyFlag();
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.runAsync(() async {
            final db = DatabaseHelper.instance;
            await db.seedDatabase();
          });

          await tester.pumpWidget(buildTestableWidget(const DashboardScreen()));
          await tester.pump();
          for (int i = 0; i < 20; i++) {
            await tester.runAsync(
              () => Future.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump(const Duration(milliseconds: 50));
            if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
              break;
            }
          }

          // Verify hero card does not have the mic button (clean card as requested)
          expect(
            find.byKey(const Key('dashboard_hero_mic_button')),
            findsNothing,
          );

          // Verify standard Quick Actions are present
          expect(find.text('Log Transaction'), findsOneWidget);
          expect(find.text('Goals'), findsOneWidget);
          expect(find.text('Budgets'), findsOneWidget);
        },
      );

      testWidgets(
        '11. Batch approval: Approve Valid commits valid entries while retaining invalid ones (US 11, 12)',
        (tester) async {
          final validDraft = DraftTransaction(
            id: 'valid-1',
            amount: 25.0,
            type: 'expense',
            accountId: 1,
            categoryId: 1,
            date: '2026-09-22',
            note: 'Valid coffee',
          );

          final invalidDraft = DraftTransaction(
            id: 'invalid-2',
            amount: -5.0, // invalid amount
            type: 'expense',
            accountId: 1,
            categoryId: 1,
            date: '2026-09-22',
            note: 'Negative amount expense',
          );

          List<DraftTransaction> committedBatch = [];

          await tester.pumpWidget(
            buildTestableWidget(
              VoiceTransactionStagingSheet(
                drafts: [validDraft, invalidDraft],
                accounts: testAccounts,
                categories: testCategories,
                isPrivate: false,
                onCommit: (approved) async {
                  committedBatch = approved;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Approve Valid (1)'), findsOneWidget);
          expect(find.text('Approve All (2)'), findsOneWidget);

          // Tap Approve Valid
          await tester.tap(find.text('Approve Valid (1)'));
          await tester.pumpAndSettle();

          // Valid entry was committed
          expect(committedBatch.length, equals(1));
          expect(committedBatch.first.id, equals('valid-1'));

          // Invalid entry remains on screen for correction
          expect(find.text('Negative amount expense'), findsOneWidget);
          expect(find.text('Missing or invalid amount'), findsOneWidget);
        },
      );

      testWidgets(
        '12. MainNavigationScreen prominent microphone FAB guards on model install (US 3, 14, 19)',
        (tester) async {
          DashboardScreen.resetStartupPrivacyFlag();
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.runAsync(() async {
            final db = DatabaseHelper.instance;
            await db.seedDatabase();
          });

          await tester.pumpWidget(
            MaterialApp(home: MainNavigationScreen(onThemeToggle: () {})),
          );
          await tester.pump();
          for (int i = 0; i < 20; i++) {
            await tester.runAsync(
              () => Future.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump(const Duration(milliseconds: 50));
            if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
              break;
            }
          }

          // Verify mic FAB is visible
          final fabFinder = find.byKey(const Key('dashboard_voice_entry_fab'));
          expect(fabFinder, findsOneWidget);

          // Tap FAB when models not installed -> opens VoiceModelDownloadSheet
          tester.widget<InkWell>(fabFinder).onTap!();
          await tester.pump();
          for (int i = 0; i < 10; i++) {
            await tester.runAsync(
              () => Future.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump(const Duration(milliseconds: 50));
          }

          // Model download guard sheet is displayed
          expect(find.byType(VoiceModelDownloadSheet), findsOneWidget);
          expect(find.text('Offline AI Models Required'), findsOneWidget);
        },
      );

      testWidgets(
        '13. MainNavigationScreen prominent microphone FAB launches VoiceRecordingModal when models installed (US 3, 14)',
        (tester) async {
          DashboardScreen.resetStartupPrivacyFlag();
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final mockModelDir = Directory(
            join(tempDir.path, 'installed_models'),
          );
          await tester.runAsync(() async {
            for (final file in AiModelPackManifest.defaultPack.files) {
              final f = File(join(mockModelDir.path, file.relativeFilePath));
              await f.parent.create(recursive: true);
              await f.writeAsString('dummy');
            }
          });
          final mockManager = ModelManagementService(
            baseDirectory: mockModelDir,
          );
          ModelManagementService.setMockInstance(mockManager);
          addTearDown(ModelManagementService.resetInstance);

          final mockCoordinator = VoicePipelineCoordinator(
            audioPipeline: VoiceAudioPipeline(
              captureService: AudioCaptureService(
                recorderClient: FakeAudioRecorderClient(
                  permissionGranted: true,
                ),
                tempDirectory: Directory(join(tempDir.path, 'audio')),
              ),
              sttService: SpeechToTextService(
                engine: MockSttEngine(),
                modelManager: mockManager,
              ),
            ),
            speechToTextService: SpeechToTextService(
              engine: MockSttEngine(),
              modelManager: mockManager,
            ),
            slmService: SlmInferenceService(
              engine: MockSlmEngine(),
              modelService: mockManager,
            ),
            modelManager: mockManager,
          );
          addTearDown(() async => await mockCoordinator.dispose());

          await tester.runAsync(() async {
            final db = DatabaseHelper.instance;
            await db.seedDatabase();
          });

          await tester.pumpWidget(
            MaterialApp(
              home: MainNavigationScreen(
                onThemeToggle: () {},
                voiceCoordinator: mockCoordinator,
              ),
            ),
          );
          await tester.pump();
          for (int i = 0; i < 20; i++) {
            await tester.runAsync(
              () => Future.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump(const Duration(milliseconds: 50));
            if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
              break;
            }
          }

          final fabFinder = find.byKey(const Key('dashboard_voice_entry_fab'));
          expect(fabFinder, findsOneWidget);

          tester.widget<InkWell>(fabFinder).onTap!();
          await tester.pump();
          for (int i = 0; i < 40; i++) {
            await tester.runAsync(
              () => Future.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump(const Duration(milliseconds: 50));
            if (find
                    .byKey(const Key('voice_recording_cancel_button'))
                    .evaluate()
                    .isNotEmpty ||
                find
                    .byKey(const Key('voice_recording_error_close_button'))
                    .evaluate()
                    .isNotEmpty) {
              break;
            }
          }
          expect(find.byType(VoiceRecordingModal), findsOneWidget);
          expect(find.text('Voice Transaction Journaling'), findsOneWidget);
          expect(
            find.byKey(const Key('voice_recording_cancel_button')),
            findsOneWidget,
          );

          await tester.tap(
            find.byKey(const Key('voice_recording_cancel_button')),
          );
          await tester.pump();
          for (int i = 0; i < 40; i++) {
            await tester.runAsync(
              () => Future.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump(const Duration(milliseconds: 50));
            if (find.byType(VoiceRecordingModal).evaluate().isEmpty) break;
          }
        },
      );

      testWidgets(
        '14. MainNavigationScreen shows global download banner during active download',
        (tester) async {
          DashboardScreen.resetStartupPrivacyFlag();
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final mockService = _MockDownloadingModelService();
          ModelManagementService.setMockInstance(mockService);
          addTearDown(ModelManagementService.resetInstance);

          await tester.runAsync(() async {
            final db = DatabaseHelper.instance;
            await db.seedDatabase();
          });

          await tester.pumpWidget(
            MaterialApp(home: MainNavigationScreen(onThemeToggle: () {})),
          );
          await tester.pump();
          for (int i = 0; i < 20; i++) {
            await tester.runAsync(
              () => Future.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump(const Duration(milliseconds: 50));
            if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
              break;
            }
          }

          expect(
            find.byKey(const Key('global_model_download_banner')),
            findsOneWidget,
          );
          expect(
            find.textContaining('Downloading AI Model Pack (45%)'),
            findsOneWidget,
          );
        },
      );
    },
  );
}

class _MockDownloadingModelService extends ModelManagementService {
  @override
  ModelPackStatus get status => ModelPackStatus.downloading;

  @override
  bool get isDownloading => true;

  @override
  double get progress => 0.45;

  @override
  int get bytesDownloaded => 120 * 1024 * 1024;

  @override
  int get totalBytes => 270 * 1024 * 1024;

  @override
  String get statusDetail => 'Downloading SmolLM2...';
}
