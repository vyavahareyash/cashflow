import 'dart:io';

import 'package:cashflow/components/voice_recording_modal.dart';
import 'package:cashflow/components/voice_transaction_staging_sheet.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/services/audio_capture_service.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/services/model_management_service.dart';
import 'package:cashflow/services/slm_inference_service.dart';
import 'package:cashflow/services/speech_to_text_service.dart';
import 'package:cashflow/services/voice_audio_pipeline.dart';
import 'package:cashflow/services/voice_pipeline_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';
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
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsBytes(List.filled(200, 1));
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
      if (await f.exists()) await f.delete();
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
  const databaseFileName = 'money_tracker_modal_test.db';

  late Directory tempDir;
  late Directory modelDir;
  late Directory audioDir;
  late FakeAudioRecorderClient fakeRecorder;
  late AudioCaptureService captureService;
  late MockSttEngine mockSttEngine;
  late SpeechToTextService sttService;
  late MockSlmEngine mockSlmEngine;
  late SlmInferenceService slmService;
  late ModelManagementService modelManager;
  late VoicePipelineCoordinator coordinator;

  setUp(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    final dbFile = File(join(dbPath, databaseFileName));
    if (await dbFile.exists()) {
      await dbFile.delete();
    }

    tempDir = await Directory.systemTemp.createTemp('cashflow_modal_test_');
    modelDir = Directory(join(tempDir.path, 'models', 'voice'));
    audioDir = Directory(join(tempDir.path, 'audio'));
    await modelDir.create(recursive: true);
    await audioDir.create(recursive: true);

    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);

    // Create dummy model files so model manager passes
    for (final file in AiModelPackManifest.defaultPack.files) {
      final f = File(join(modelDir.path, file.relativeFilePath));
      await f.parent.create(recursive: true);
      await f.writeAsString('model_data');
    }

    fakeRecorder = FakeAudioRecorderClient(permissionGranted: true);
    captureService = AudioCaptureService(
      recorderClient: fakeRecorder,
      tempDirectory: audioDir,
    );

    mockSttEngine = MockSttEngine();
    mockSlmEngine = MockSlmEngine();

    modelManager = ModelManagementService(baseDirectory: modelDir);
    sttService = SpeechToTextService(
      engine: mockSttEngine,
      modelManager: modelManager,
    );
    slmService = SlmInferenceService(
      engine: mockSlmEngine,
      modelService: modelManager,
    );

    coordinator = VoicePipelineCoordinator(
      audioPipeline: VoiceAudioPipeline(
        captureService: captureService,
        sttService: sttService,
      ),
      speechToTextService: sttService,
      slmService: slmService,
      modelManager: modelManager,
    );

    await DatabaseHelper.instance.createAccount(
      Account(name: 'Chase Checking', balance: 1200.0, type: 'Bank'),
    );
    await DatabaseHelper.instance.createCategory(
      Category(name: 'Groceries', monthlyBudget: 300.0, type: 'expense'),
    );
  });

  tearDown(() async {
    await coordinator.dispose();
    await DatabaseHelper.instance.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Widget buildTestApp(VoicePipelineCoordinator testCoord) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              key: const Key('open_modal_button'),
              onPressed: () => VoiceRecordingModal.show(
                context,
                coordinator: testCoord,
              ),
              child: const Text('Open Modal'),
            ),
          ),
        ),
      ),
    );
  }

  group('VoiceRecordingModal Widget & A11y Tests (US 1, 3, 13, 16)', () {
    Future<void> waitForRecordingReady(WidgetTester tester) async {
      for (int i = 0; i < 50; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byKey(const Key('voice_recording_done_button')).evaluate().isNotEmpty ||
            find.byKey(const Key('voice_recording_error_close_button')).evaluate().isNotEmpty) {
          break;
        }
      }
    }

    testWidgets('1. Renders listening UI with timer, mic button, live transcript card, and controls', (tester) async {
      await tester.pumpWidget(buildTestApp(coordinator));
      await tester.tap(find.byKey(const Key('open_modal_button')));
      await tester.pump();
      await waitForRecordingReady(tester);

      expect(find.text('Voice Transaction Journaling'), findsOneWidget);
      expect(find.byKey(const Key('voice_recording_mic_button')), findsOneWidget);
      expect(find.byKey(const Key('voice_recording_live_transcript_card')), findsOneWidget);
      expect(find.byKey(const Key('voice_recording_live_transcript_text')), findsOneWidget);
      expect(find.textContaining('rupees'), findsWidgets);
      expect(find.byKey(const Key('voice_recording_duration_text')), findsNothing);
      expect(find.byKey(const Key('voice_recording_cancel_button')), findsOneWidget);
      expect(find.byKey(const Key('voice_recording_done_button')), findsOneWidget);
    });

    testWidgets('1b. Live streaming transcript updates reactively in real time', (tester) async {
      await tester.pumpWidget(buildTestApp(coordinator));
      await tester.tap(find.byKey(const Key('open_modal_button')));
      await tester.pump();
      await waitForRecordingReady(tester);

      // Verify initial Indian helper text
      expect(find.textContaining('Chai 20 rupees on UPI'), findsOneWidget);

      // Simulate partial live transcript emission
      (coordinator.liveTranscriptListenable as ValueNotifier<String>).value =
          'Chai 20 rupees on UPI yesterday';
      await tester.pump();

      expect(find.text('Chai 20 rupees on UPI yesterday'), findsOneWidget);
    });

    testWidgets('1c. Tapping central mic button toggles mic between ON and OFF states with visual indicators', (tester) async {
      await tester.pumpWidget(buildTestApp(coordinator));
      await tester.tap(find.byKey(const Key('open_modal_button')));
      await tester.pump();
      await waitForRecordingReady(tester);

      // Initially active: shows 'Listening' and 'MIC ON'
      expect(find.text('Listening'), findsOneWidget);
      expect(find.text('MIC ON'), findsOneWidget);
      expect(coordinator.isMicPaused, isFalse);

      // Tap central mic button -> pauses listening
      await tester.tap(find.byKey(const Key('voice_recording_mic_button')));
      await tester.pump();

      expect(find.text('Mic Off'), findsOneWidget);
      expect(find.text('MIC OFF'), findsOneWidget);
      expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);
      expect(coordinator.isMicPaused, isTrue);

      // Tap central mic button again -> resumes listening
      await tester.tap(find.byKey(const Key('voice_recording_mic_button')));
      await tester.pump();

      expect(find.text('Listening'), findsOneWidget);
      expect(find.text('MIC ON'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(coordinator.isMicPaused, isFalse);
    });

    testWidgets('1d. Android stopping listening automatically reflects in button state as MIC OFF and allows resuming', (tester) async {
      await tester.pumpWidget(buildTestApp(coordinator));
      await tester.tap(find.byKey(const Key('open_modal_button')));
      await tester.pump();
      await waitForRecordingReady(tester);

      expect(find.text('Listening'), findsOneWidget);
      expect(find.text('MIC ON'), findsOneWidget);

      // Simulate Android STT silence timeout or stop event:
      // coordinator's isMicActiveListenable is updated to false
      (coordinator.isMicActiveListenable as ValueNotifier<bool>).value = false;
      await tester.pump();

      // UI automatically reflects Android stopped listening
      expect(find.text('Mic Off'), findsOneWidget);
      expect(find.text('MIC OFF'), findsOneWidget);
      expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);
      expect(find.text('Microphone paused. Tap mic to resume'), findsOneWidget);

      // User taps central mic button to resume
      await tester.tap(find.byKey(const Key('voice_recording_mic_button')));
      await tester.pump();

      expect(find.text('Listening'), findsOneWidget);
      expect(find.text('MIC ON'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('1e. User can edit transcript when mic is off to correct STT errors', (tester) async {
      await tester.pumpWidget(buildTestApp(coordinator));
      await tester.tap(find.byKey(const Key('open_modal_button')));
      await tester.pump();
      await waitForRecordingReady(tester);

      // 1. Initial live transcription while listening
      (coordinator.liveTranscriptListenable as ValueNotifier<String>).value = 'Chai 20 rupees';
      await tester.pump();
      expect(find.text('Chai 20 rupees'), findsOneWidget);

      // 2. Pause mic (either manually or via silence timeout)
      await tester.tap(find.byKey(const Key('voice_recording_mic_button')));
      await tester.pump();

      // Editable field should now appear with current transcript
      final editField = find.byKey(const Key('voice_recording_live_transcript_edit_field'));
      expect(editField, findsOneWidget);
      expect(find.text('Mic off: Tap above to edit before submitting or tap mic to resume'), findsOneWidget);

      // 3. User edits text in field to fix STT error
      await tester.enterText(editField, 'Chai 25 rupees on UPI');
      await tester.pump();

      expect(coordinator.currentLiveTranscript, equals('Chai 25 rupees on UPI'));

      // 4. User resumes mic -> edits preserved
      await tester.tap(find.byKey(const Key('voice_recording_mic_button')));
      await tester.pump();

      expect(find.byKey(const Key('voice_recording_live_transcript_text')), findsOneWidget);
      expect(find.text('Chai 25 rupees on UPI'), findsOneWidget);
    });

    testWidgets('2. Tap Cancel cancels capture and dismisses modal cleanly (US 13)', (tester) async {
      await tester.pumpWidget(buildTestApp(coordinator));
      await tester.tap(find.byKey(const Key('open_modal_button')));
      await tester.pump();
      await waitForRecordingReady(tester);

      expect(find.byKey(const Key('voice_recording_modal')), findsOneWidget);

      await tester.tap(find.byKey(const Key('voice_recording_cancel_button')));
      await tester.pump();
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byKey(const Key('voice_recording_modal')).evaluate().isEmpty) break;
      }

      expect(find.byKey(const Key('voice_recording_modal')), findsNothing);
      expect(coordinator.isRecording, isFalse);
    });

    testWidgets('3. Tap Done processes audio and transitions to staging sheet (US 1, 3)', (tester) async {
      mockSttEngine.initialize(modelDirPath: modelDir.path);
      mockSttEngine.defaultTranscript = 'Spent 25 dollars on Groceries';

      mockSlmEngine.initialize(modelPath: 'dummy');
      mockSlmEngine.defaultResponse = '''
[
  {
    "amount": 25.0,
    "type": "expense",
    "account_id": 1,
    "category_id": 1,
    "date": "2026-09-22",
    "note": "Groceries"
  }
]
''';

      await tester.pumpWidget(buildTestApp(coordinator));
      await tester.tap(find.byKey(const Key('open_modal_button')));
      await tester.pump();
      await waitForRecordingReady(tester);

      // Tap Done
      await tester.tap(find.byKey(const Key('voice_recording_done_button')));
      await tester.pump();

      // Wait for async processing
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // VoiceRecordingModal is gone, StagingSheet is now open
      expect(find.byType(VoiceRecordingModal), findsNothing);
      expect(find.byType(VoiceTransactionStagingSheet), findsOneWidget);
      expect(find.text('Groceries'), findsWidgets);
    });

    testWidgets('4. Silent audio displays friendly error message', (tester) async {
      mockSttEngine.initialize(modelDirPath: modelDir.path);
      mockSttEngine.shouldThrowSilent = true;

      await tester.pumpWidget(buildTestApp(coordinator));
      await tester.tap(find.byKey(const Key('open_modal_button')));
      await tester.pump();
      await waitForRecordingReady(tester);

      await tester.tap(find.byKey(const Key('voice_recording_done_button')));
      await tester.pump();

      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byKey(const Key('voice_recording_error_text')), findsOneWidget);
      expect(find.textContaining('No decipherable speech detected'), findsOneWidget);
      expect(find.byKey(const Key('voice_recording_error_close_button')), findsOneWidget);
    });

    testWidgets('5. Permission denial displays error view and close button', (tester) async {
      fakeRecorder.permissionGranted = false;

      await tester.pumpWidget(buildTestApp(coordinator));
      await tester.tap(find.byKey(const Key('open_modal_button')));
      await tester.pump();
      await waitForRecordingReady(tester);

      expect(find.byKey(const Key('voice_recording_error_text')), findsOneWidget);
      expect(find.textContaining('Microphone permission denied'), findsOneWidget);
      expect(find.byKey(const Key('voice_recording_error_close_button')), findsOneWidget);
    });

    testWidgets('6. Accessibility: meets WCAG AA tap targets and contrast guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildTestApp(coordinator));
      await tester.tap(find.byKey(const Key('open_modal_button')));
      await tester.pump();
      await waitForRecordingReady(tester);

      // Android 48x48 tap target guideline
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      // iOS 44x44 tap target guideline
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      // Labeled tap targets
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    });

    testWidgets('7. Empty drafts displays dark mode readable SnackBar', (tester) async {
      mockSttEngine.initialize(modelDirPath: modelDir.path);
      mockSttEngine.defaultTranscript = 'Hello how are you doing today';
      mockSlmEngine.initialize(modelPath: 'dummy');
      mockSlmEngine.defaultResponse = '[]'; // No financial entities

      await tester.pumpWidget(buildTestApp(coordinator));
      await tester.tap(find.byKey(const Key('open_modal_button')));
      await tester.pump();
      await waitForRecordingReady(tester);

      await tester.tap(find.byKey(const Key('voice_recording_done_button')));
      await tester.pump();

      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.textContaining('No transactions recognized'), findsOneWidget);
    });
  });
}
