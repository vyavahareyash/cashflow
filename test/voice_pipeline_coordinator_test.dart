import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' hide Category;
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/services/audio_capture_service.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/services/model_management_service.dart';
import 'package:cashflow/services/slm_inference_service.dart';
import 'package:cashflow/services/speech_to_text_service.dart';
import 'package:cashflow/services/voice_audio_pipeline.dart';
import 'package:cashflow/services/voice_pipeline_coordinator.dart';
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

Uint8List createTestWavBytes({
  int sampleRate = 16000,
  int numChannels = 1,
  int bitsPerSample = 16,
  int numSamples = 16000,
  double amplitude = 0.5,
}) {
  final subchunk2Size = numSamples * numChannels * (bitsPerSample ~/ 8);
  final chunkSize = 36 + subchunk2Size;
  final b = ByteData(44 + subchunk2Size);

  b.setUint8(0, 0x52);
  b.setUint8(1, 0x49);
  b.setUint8(2, 0x46);
  b.setUint8(3, 0x46);
  b.setUint32(4, chunkSize, Endian.little);
  b.setUint8(8, 0x57);
  b.setUint8(9, 0x41);
  b.setUint8(10, 0x56);
  b.setUint8(11, 0x45);
  b.setUint8(12, 0x66);
  b.setUint8(13, 0x6D);
  b.setUint8(14, 0x74);
  b.setUint8(15, 0x20);
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, numChannels, Endian.little);
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(
    28,
    sampleRate * numChannels * (bitsPerSample ~/ 8),
    Endian.little,
  );
  b.setUint16(32, numChannels * (bitsPerSample ~/ 8), Endian.little);
  b.setUint16(34, bitsPerSample, Endian.little);
  b.setUint8(36, 0x64);
  b.setUint8(37, 0x61);
  b.setUint8(38, 0x74);
  b.setUint8(39, 0x61);
  b.setUint32(40, subchunk2Size, Endian.little);

  const offset = 44;
  for (int i = 0; i < numSamples; i++) {
    final double sampleVal = amplitude == 0.0
        ? 0.0
        : amplitude * math.sin(2 * math.pi * 440 * i / sampleRate);
    final int sampleInt = (sampleVal * 32767).toInt().clamp(-32768, 32767);
    b.setInt16(offset + (i * 2), sampleInt, Endian.little);
  }

  return b.buffer.asUint8List();
}

class FakeAudioRecorderClient implements AudioRecorderClient {
  bool permissionGranted = true;
  bool recordingActive = false;
  String? lastPath;
  bool generateSilentWav = false;

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
    final bytes = createTestWavBytes(
      sampleRate: config.sampleRate,
      numChannels: config.numChannels,
      amplitude: generateSilentWav ? 0.0 : 0.8,
    );
    await file.writeAsBytes(bytes);
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
  DatabaseHelper.setTestDatabaseName(inMemoryDatabasePath);
  const databaseFileName = 'money_tracker_coordinator_test.db';

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

    tempDir = await Directory.systemTemp.createTemp('cashflow_coord_test_');
    modelDir = Directory(join(tempDir.path, 'models', 'voice'));
    audioDir = Directory(join(tempDir.path, 'audio'));
    await modelDir.create(recursive: true);
    await audioDir.create(recursive: true);

    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);

    fakeRecorder = FakeAudioRecorderClient();
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

    // Initialize mock database records
    await DatabaseHelper.instance.createAccount(
      Account(name: 'Chase Checking', balance: 2000.0, type: 'Bank'),
    );
    await DatabaseHelper.instance.createAccount(
      Account(name: 'Cash Wallet', balance: 150.0, type: 'Cash'),
    );
    await DatabaseHelper.instance.createCategory(
      Category(name: 'Food & Dining', monthlyBudget: 400.0, type: 'expense'),
    );
    await DatabaseHelper.instance.createCategory(
      Category(name: 'Salary', type: 'income'),
    );
  });

  tearDown(() async {
    await coordinator.dispose();
    await DatabaseHelper.instance.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('VoicePipelineCoordinator Orchestration Tests (Issue #94, ADR-0005)', () {
    test('1. prepareSession throws SttModelNotInstalledException when models missing', () async {
      expect(
        () => coordinator.prepareSession(),
        throwsA(isA<SttModelNotInstalledException>()),
      );
    });

    test(
      '2. prepareSession loads models into memory when installed (US 16)',
      () async {
        // Create mock model files
        for (final file in AiModelPackManifest.defaultPack.files) {
          final f = File(join(modelDir.path, file.relativeFilePath));
          await f.parent.create(recursive: true);
          await f.writeAsString('mock_content');
        }

        await coordinator.prepareSession();
        expect(modelManager.isModelLoadedInMemory, isTrue);
      },
    );

    test(
      '3. startRecording and isRecording reflect active capture state',
      () async {
        expect(coordinator.isRecording, isFalse);
        final wavPath = await coordinator.startRecording();
        expect(coordinator.isRecording, isTrue);
        expect(File(wavPath).existsSync(), isTrue);

        await coordinator.cancelRecording();
        expect(coordinator.isRecording, isFalse);
        expect(
          File(wavPath).existsSync(),
          isFalse,
        ); // US 13: Zero audio persistence
      },
    );

    test('4. stopAndProcess end-to-end happy path with SLM GBNF output (US 1, 4, 5, 6, 17)', () async {
      await mockSttEngine.initialize(modelDirPath: modelDir.path);
      mockSttEngine.defaultTranscript =
          'Spent 14 dollars on lunch from Chase yesterday';

      await mockSlmEngine.initialize(modelPath: 'dummy');
      mockSlmEngine.onGenerate = (prompt) {
        // Assert prompt includes grounded accounts and categories
        expect(prompt, contains('Chase Checking'));
        expect(prompt, contains('Food & Dining'));
        return '''
[
  {
    "amount": 14.0,
    "type": "expense",
    "account_id": 1,
    "category_id": 1,
    "date": "2026-09-21",
    "note": "lunch"
  }
]
''';
      };

      await coordinator.startRecording();
      final drafts = await coordinator.stopAndProcess(
        anchorDate: DateTime(2026, 9, 22),
      );

      expect(drafts.length, 1);
      final draft = drafts.first;
      expect(draft.amount, 14.0);
      expect(draft.type, 'expense');
      expect(draft.accountId, 1);
      expect(draft.categoryId, 1);
      expect(draft.date, '2026-09-21');
      expect(draft.note, 'lunch');
      expect(draft.hasUnassignedAccount, isFalse);
      expect(draft.hasUnassignedCategory, isFalse);

      // Verify zero audio persistence (US 13)
      final remainingWavs = await captureService.purgeTemporaryWavs();
      expect(remainingWavs, 0);
    });

    test('5. stopAndProcess falls back gracefully to deterministic heuristic parser if SLM fails (US 1)', () async {
      await mockSttEngine.initialize(modelDirPath: modelDir.path);
      mockSttEngine.defaultTranscript = 'Coffee 5 dollars at Starbucks';

      await mockSlmEngine.initialize(modelPath: 'dummy');
      mockSlmEngine.shouldThrowError = true; // Simulate SLM engine failure

      await coordinator.startRecording();
      final drafts = await coordinator.stopAndProcess(
        anchorDate: DateTime(2026, 9, 22),
      );

      // Heuristic parser should rescue the transcription
      expect(drafts.isNotEmpty, isTrue);
      expect(drafts.first.amount, 5.0);
      expect(drafts.first.type, 'expense');
      expect(drafts.first.note.toLowerCase(), contains('coffee'));
    });

    test(
      '6. stopAndProcess throws SttSilentAudioException on empty transcription',
      () async {
        await mockSttEngine.initialize(modelDirPath: modelDir.path);
        mockSttEngine.defaultTranscript = '   '; // Whitespace only

        await coordinator.startRecording();
        expect(
          () => coordinator.stopAndProcess(),
          throwsA(isA<SttSilentAudioException>()),
        );

        // US 13: WAV file purged even on silence error
        final lingering = await captureService.purgeTemporaryWavs();
        expect(lingering, 0);
      },
    );

    test(
      '7. endSession unloads models and clears lingering cache (US 13, US 16)',
      () async {
        for (final file in AiModelPackManifest.defaultPack.files) {
          final f = File(join(modelDir.path, file.relativeFilePath));
          await f.parent.create(recursive: true);
          await f.writeAsString('dummy');
        }
        await coordinator.prepareSession();
        expect(modelManager.isModelLoadedInMemory, isTrue);

        await coordinator.endSession();
        expect(modelManager.isModelLoadedInMemory, isFalse);
      },
    );

    test('8. readActiveRecordingSamples reads float32 PCM samples during recording', () async {
      await coordinator.startRecording();
      final samples = await coordinator.audioPipeline
          .readActiveRecordingSamples();
      expect(samples, isNotNull);
      expect(samples!.isNotEmpty, isTrue);
      await coordinator.cancelRecording();
    });

    test('9. stopAndProcess falls back to currentLiveTranscript when file transcribe throws SttSilentAudioException', () async {
      await mockSttEngine.initialize(modelDirPath: modelDir.path);
      await mockSlmEngine.initialize(modelPath: 'dummy');

      await coordinator.startRecording();
      // Simulate live transcript having captured words
      (coordinator.liveTranscriptListenable as ValueNotifier<String>).value =
          'Chai 20 rupees on UPI yesterday';

      // Simulate full WAV file throwing silent audio exception (e.g. silence cutoff at the end)
      mockSttEngine.shouldThrowSilent = true;

      final drafts = await coordinator.stopAndProcess(
        anchorDate: DateTime(2026, 9, 22),
      );

      // Should have rescued the transaction using the accumulated live transcript!
      expect(drafts.isNotEmpty, isTrue);
      expect(drafts.first.amount, 20.0);
    });

    test('10. pauseListening and resumeListening toggle isMicPaused state and STT engine', () async {
      await coordinator.startRecording();
      expect(coordinator.isMicPaused, isFalse);

      await coordinator.pauseListening();
      expect(coordinator.isMicPaused, isTrue);

      await coordinator.resumeListening();
      expect(coordinator.isMicPaused, isFalse);

      await coordinator.cancelRecording();
    });

    test('11. NativePlatformSttEngine.combineTranscripts prevents duplicate appended transcripts', () {
      // 1. Identical repeated transcript (e.g. from trailing stop callback)
      expect(
        NativePlatformSttEngine.combineTranscripts(
          'Chai 20 rupees',
          'Chai 20 rupees',
        ),
        'Chai 20 rupees',
      );

      // 2. Case-insensitive duplicate
      expect(
        NativePlatformSttEngine.combineTranscripts(
          'chai 20 rupees',
          'Chai 20 rupees',
        ),
        'chai 20 rupees',
      );

      // 3. Progressive refinement/extension (new text starts with prior text)
      expect(
        NativePlatformSttEngine.combineTranscripts(
          'Chai 20',
          'Chai 20 rupees on UPI',
        ),
        'Chai 20 rupees on UPI',
      );

      // 4. Base already ends with the addition
      expect(
        NativePlatformSttEngine.combineTranscripts(
          'Dinner 200, Chai 20 rupees',
          'Chai 20 rupees',
        ),
        'Dinner 200, Chai 20 rupees',
      );

      // 5. Genuinely distinct utterances separated cleanly by comma
      expect(
        NativePlatformSttEngine.combineTranscripts(
          'Chai 20 rupees',
          'Dosa 50 rupees',
        ),
        'Chai 20 rupees, Dosa 50 rupees',
      );

      // 6. Empty base or empty addition
      expect(
        NativePlatformSttEngine.combineTranscripts('', 'Chai 20 rupees'),
        'Chai 20 rupees',
      );
      expect(
        NativePlatformSttEngine.combineTranscripts('Chai 20 rupees', ''),
        'Chai 20 rupees',
      );
    });

    test('12. isMicActiveListenable stays in sync with startRecording, pauseListening, resumeListening, and cancelRecording', () async {
      expect(coordinator.isMicActiveListenable.value, isFalse);

      await coordinator.startRecording();
      expect(coordinator.isMicActiveListenable.value, isTrue);

      await coordinator.pauseListening();
      expect(coordinator.isMicActiveListenable.value, isFalse);

      await coordinator.resumeListening();
      expect(coordinator.isMicActiveListenable.value, isTrue);

      await coordinator.cancelRecording();
      expect(coordinator.isMicActiveListenable.value, isFalse);
    });
  });
}
