import 'dart:io';
import 'dart:typed_data';

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
import 'package:path/path.dart' as p hide equals;
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

/// Fake recorder client that feeds real WAV sample fixtures into the recording path.
class SampleAudioRecorderClient implements AudioRecorderClient {
  final File sampleAudioFile;
  bool permissionGranted;
  bool recordingActive = false;
  String? lastPath;

  SampleAudioRecorderClient({
    required this.sampleAudioFile,
    this.permissionGranted = true,
  });

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> isRecording() async => recordingActive;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    recordingActive = true;
    lastPath = path;
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    // Copy real sample audio bytes directly to the recording path
    final sampleBytes = sampleAudioFile.readAsBytesSync();
    file.writeAsBytesSync(sampleBytes);
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
  Stream<Amplitude> onAmplitudeChanged(Duration interval) {
    if (sampleAudioFile.existsSync()) {
      final bytes = sampleAudioFile.readAsBytesSync();
      if (bytes.length > 44) {
        int maxAmpInt = 0;
        final byteData = ByteData.sublistView(bytes, 44);
        final count = (bytes.length - 44) ~/ 2;
        for (int i = 0; i < count; i++) {
          final val = byteData.getInt16(i * 2, Endian.little).abs();
          if (val > maxAmpInt) maxAmpInt = val;
        }
        final double normalized = maxAmpInt / 32768.0;
        final double dbfs = normalized > 0.0001
            ? 20 * (normalized.clamp(0.0001, 1.0)) - 60
            : -80.0;
        return Stream.value(Amplitude(current: dbfs, max: dbfs));
      }
    }
    return Stream.value(Amplitude(current: -20.0, max: -10.0));
  }

  @override
  Future<Amplitude> getAmplitude() async =>
      Amplitude(current: -20.0, max: -10.0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.setTestDatabaseName(inMemoryDatabasePath);
  const databaseFileName = 'money_tracker_sample_audio_test.db';

  late Directory tempDir;
  late Directory modelDir;
  late Directory audioDir;
  late File normalSpeechFile;
  late File softSpeechFile;
  late File silentAudioFile;

  setUpAll(() {
    normalSpeechFile = File('test/fixtures/chai_groceries_16k.wav');
    softSpeechFile = File('test/fixtures/soft_speech_16k.wav');
    silentAudioFile = File('test/fixtures/silent_16k.wav');

    expect(
      normalSpeechFile.existsSync(),
      isTrue,
      reason: 'Sample speech audio fixture must exist at test/fixtures/chai_groceries_16k.wav',
    );
    expect(
      softSpeechFile.existsSync(),
      isTrue,
      reason: 'Soft speech audio fixture must exist at test/fixtures/soft_speech_16k.wav',
    );
    expect(
      silentAudioFile.existsSync(),
      isTrue,
      reason: 'Silent audio fixture must exist at test/fixtures/silent_16k.wav',
    );
  });

  setUp(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    final dbFile = File(p.join(dbPath, databaseFileName));
    if (await dbFile.exists()) {
      await dbFile.delete();
    }

    tempDir = await Directory.systemTemp.createTemp('cashflow_e2e_audio_test_');
    modelDir = Directory(p.join(tempDir.path, 'models', 'voice'));
    audioDir = Directory(p.join(tempDir.path, 'audio'));
    await modelDir.create(recursive: true);
    await audioDir.create(recursive: true);

    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);

    for (final file in AiModelPackManifest.defaultPack.files) {
      final f = File(p.join(modelDir.path, file.relativeFilePath));
      f.parent.createSync(recursive: true);
      f.writeAsStringSync('model_data');
    }

    await DatabaseHelper.instance.createAccount(
      Account(name: 'UPI / HDFC', balance: 5000.0, type: 'Bank'),
    );
    await DatabaseHelper.instance.createCategory(
      Category(name: 'Food & Dining', monthlyBudget: 500.0, type: 'expense'),
    );
    await DatabaseHelper.instance.createCategory(
      Category(name: 'Groceries', monthlyBudget: 1000.0, type: 'expense'),
    );
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('Sample Audio Silence Threshold Comparison (Previous 0.005 vs Calibrated 0.0005)', () {
    test('1. Soft speech sample (peak ~0.003) FAILS with previous silence threshold 0.005', () async {
      final sttEnginePrevious = MockSttEngine(
        silenceThreshold: 0.005, // Previous threshold (~ -46 dBFS)
        defaultTranscript: 'Paid 20 rupees for chai on UPI and 450 rupees for groceries yesterday',
      );
      await sttEnginePrevious.initialize(modelDirPath: modelDir.path);

      // Verify soft speech file fails due to silence threshold
      expect(
        () => sttEnginePrevious.transcribeFile(softSpeechFile.path),
        throwsA(isA<SttSilentAudioException>()),
        reason: 'Previous threshold 0.005 rejected quiet/whispered speech as silent audio',
      );
    });

    test('2. Soft speech sample (peak ~0.003) PASSES with calibrated silence threshold 0.0005', () async {
      final sttEngineCalibrated = MockSttEngine(
        silenceThreshold: 0.0005, // Calibrated threshold (~ -66 dBFS)
        defaultTranscript: 'Paid 20 rupees for chai on UPI and 450 rupees for groceries yesterday',
      );
      await sttEngineCalibrated.initialize(modelDirPath: modelDir.path);

      final transcript = await sttEngineCalibrated.transcribeFile(
        softSpeechFile.path,
      );
      expect(
        transcript,
        equals(
          'Paid 20 rupees for chai on UPI and 450 rupees for groceries yesterday',
        ),
      );
    });

    test('3. Silent audio sample (peak ~0.0001) is correctly rejected by both thresholds', () async {
      final sttEngineCalibrated = MockSttEngine(silenceThreshold: 0.0005);
      await sttEngineCalibrated.initialize(modelDirPath: modelDir.path);

      expect(
        () => sttEngineCalibrated.transcribeFile(silentAudioFile.path),
        throwsA(isA<SttSilentAudioException>()),
      );
    });

    test(
      '4. Amplitude stream computes non-zero RMS from sample audio file',
      () async {
        final recorderClient = SampleAudioRecorderClient(
          sampleAudioFile: normalSpeechFile,
        );
        final captureService = AudioCaptureService(
          recorderClient: recorderClient,
          tempDirectory: audioDir,
        );
        final amp = await captureService.amplitudeStream.first;
        expect(amp, greaterThan(0.0));
      },
    );
  });

  group('Full End-to-End Test with Real Speech Sample Audio (Issue #94, US 1, 3, 11, 13)', () {
    test('Record sample audio -> Live PCM streaming -> Coordinator processing -> SQLite Commit -> Purge Audio', () async {
      final recorderClient = SampleAudioRecorderClient(
        sampleAudioFile: normalSpeechFile,
      );
      final captureService = AudioCaptureService(
        recorderClient: recorderClient,
        tempDirectory: audioDir,
      );

      final mockSttEngine = MockSttEngine(
        silenceThreshold: 0.0005,
        defaultTranscript: 'Paid 20 rupees for chai on UPI and 450 rupees for groceries yesterday',
      );
      await mockSttEngine.initialize(modelDirPath: modelDir.path);

      final modelManager = ModelManagementService(baseDirectory: modelDir);
      final sttService = SpeechToTextService(
        engine: mockSttEngine,
        modelManager: modelManager,
      );

      final mockSlmEngine = MockSlmEngine();
      await mockSlmEngine.initialize(modelPath: 'dummy');
      mockSlmEngine.defaultResponse = '''
[
  {
    "amount": 20.0,
    "type": "expense",
    "account_id": 1,
    "category_id": 1,
    "date": "2026-09-22",
    "note": "Chai on UPI"
  },
  {
    "amount": 450.0,
    "type": "expense",
    "account_id": 1,
    "category_id": 2,
    "date": "2026-09-22",
    "note": "Groceries"
  }
]
''';
      final slmService = SlmInferenceService(
        engine: mockSlmEngine,
        modelService: modelManager,
      );

      final coordinator = VoicePipelineCoordinator(
        audioPipeline: VoiceAudioPipeline(
          captureService: captureService,
          sttService: sttService,
        ),
        speechToTextService: sttService,
        slmService: slmService,
        modelManager: modelManager,
      );

      // 1. Prepare session and start recording with real sample audio
      await coordinator.prepareSession();
      final path = await coordinator.startRecording();
      expect(coordinator.isRecording, isTrue);
      expect(File(path).existsSync(), isTrue);

      // 2. Verify PCM samples read directly from active recording file
      final activeSamples = await coordinator.audioPipeline
          .readActiveRecordingSamples();
      expect(activeSamples, isNotNull);
      expect(activeSamples!.length, greaterThan(1000));

      // 3. Stop recording and execute full pipeline
      final drafts = await coordinator.stopAndProcess(
        anchorDate: DateTime(2026, 9, 23),
      );
      expect(drafts.length, equals(2));
      expect(drafts[0].amount, equals(20.0));
      expect(drafts[0].note, equals('Chai on UPI'));
      expect(drafts[1].amount, equals(450.0));
      expect(drafts[1].note, equals('Groceries'));

      final db = await DatabaseHelper.instance.database;
      final beforeCount =
          (await db.rawQuery('SELECT COUNT(*) as cnt FROM transactions'))
                  .first['cnt']
              as int;

      // 4. Commit to SQLite Database
      await DatabaseHelper.instance.commitDraftTransactions(drafts);

      // 5. Query SQLite to verify committed records
      final afterCount =
          (await db.rawQuery('SELECT COUNT(*) as cnt FROM transactions'))
                  .first['cnt']
              as int;
      expect(afterCount - beforeCount, equals(2));

      final rows = await db.query('transactions', orderBy: 'id DESC', limit: 2);
      expect(rows.length, equals(2));
      // In DESC order, rows[0] is the second draft and rows[1] is the first draft
      final notes = rows.map((r) => r['note']).toSet();
      expect(notes, contains('Chai on UPI'));
      expect(notes, contains('Groceries'));
      final amounts = rows.map((r) => r['amount']).toSet();
      expect(amounts, contains(20.0));
      expect(amounts, contains(450.0));

      // 6. Verify US 13 Zero Audio Persistence: temporary recording file purged
      expect(File(path).existsSync(), isFalse);
      final lingeringWavs = await captureService.purgeTemporaryWavs();
      expect(lingeringWavs, equals(0));

      await coordinator.dispose();
    });
  });
}
