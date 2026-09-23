import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cashflow/services/audio_capture_service.dart';
import 'package:cashflow/services/model_management_service.dart';
import 'package:cashflow/services/speech_to_text_service.dart';
import 'package:cashflow/services/voice_audio_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Helper to generate a valid RIFF WAVE PCM 16-bit audio file in memory.
Uint8List createTestWavBytes({
  int sampleRate = 16000,
  int numChannels = 1,
  int bitsPerSample = 16,
  int numSamples = 16000, // 1 second of audio
  double amplitude = 0.5, // 0.0 for silence
}) {
  final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
  final blockAlign = numChannels * (bitsPerSample ~/ 8);
  final subchunk2Size = numSamples * numChannels * (bitsPerSample ~/ 8);
  final chunkSize = 36 + subchunk2Size;

  final b = ByteData(44 + subchunk2Size);
  // 'RIFF'
  b.setUint8(0, 0x52);
  b.setUint8(1, 0x49);
  b.setUint8(2, 0x46);
  b.setUint8(3, 0x46);
  b.setUint32(4, chunkSize, Endian.little);
  // 'WAVE'
  b.setUint8(8, 0x57);
  b.setUint8(9, 0x41);
  b.setUint8(10, 0x56);
  b.setUint8(11, 0x45);
  // 'fmt '
  b.setUint8(12, 0x66);
  b.setUint8(13, 0x6D);
  b.setUint8(14, 0x74);
  b.setUint8(15, 0x20);
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM format = 1
  b.setUint16(22, numChannels, Endian.little);
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, byteRate, Endian.little);
  b.setUint16(32, blockAlign, Endian.little);
  b.setUint16(34, bitsPerSample, Endian.little);
  // 'data'
  b.setUint8(36, 0x64);
  b.setUint8(37, 0x61);
  b.setUint8(38, 0x74);
  b.setUint8(39, 0x61);
  b.setUint32(40, subchunk2Size, Endian.little);

  // Synthesize audio waveform
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

/// Fake audio recorder client simulating physical microphone hardware.
class FakeAudioRecorderClient implements AudioRecorderClient {
  bool permissionGranted;
  bool recordingActive = false;
  RecordConfig? lastConfig;
  String? lastPath;
  bool generateSilentWav;
  bool shouldThrowOnStart;

  FakeAudioRecorderClient({
    this.permissionGranted = true,
    this.generateSilentWav = false,
    this.shouldThrowOnStart = false,
  });

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> isRecording() async => recordingActive;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    if (shouldThrowOnStart) {
      throw Exception('Hardware mic initialization failed');
    }
    lastConfig = config;
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

class FakeSpeechToText extends Fake implements stt.SpeechToText {
  bool available = true;
  void Function(String status)? statusListener;
  void Function(SpeechRecognitionResult result)? resultListener;
  bool isListening = false;

  @override
  bool get isAvailable => available;

  @override
  Future<bool> initialize({
    stt.SpeechErrorListener? onError,
    stt.SpeechStatusListener? onStatus,
    dynamic debugLogging = false,
    Duration finalTimeout = stt.SpeechToText.defaultFinalTimeout,
    List<stt.SpeechConfigOption>? options,
  }) async {
    statusListener = onStatus;
    return available;
  }

  @override
  Future<dynamic> listen({
    stt.SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    stt.SpeechSoundLevelChange? onSoundLevelChange,
    dynamic cancelOnError = false,
    dynamic partialResults = true,
    dynamic onDevice = false,
    stt.ListenMode listenMode = stt.ListenMode.confirmation,
    dynamic sampleRate = 0,
    stt.SpeechListenOptions? listenOptions,
  }) async {
    resultListener = onResult;
    isListening = true;
    statusListener?.call('listening');
    return true;
  }

  @override
  Future<void> stop() async {
    isListening = false;
    statusListener?.call('notListening');
  }

  @override
  Future<void> cancel() async {
    isListening = false;
    statusListener?.call('notListening');
  }

  void emitResult(String words, bool isFinal) {
    final res = SpeechRecognitionResult(
      [SpeechRecognitionWords(words, [words], 0.95)],
      isFinal ? 1 : 0,
    );
    resultListener?.call(res);
  }

  void emitStatus(String status) {
    statusListener?.call(status);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testTempDir;
  late Directory testModelDir;

  setUp(() async {
    testTempDir = await Directory.systemTemp.createTemp('cashflow_audio_test_');
    testModelDir = await Directory.systemTemp.createTemp('cashflow_models_test_');
  });

  tearDown(() async {
    if (await testTempDir.exists()) {
      await testTempDir.delete(recursive: true);
    }
    if (await testModelDir.exists()) {
      await testModelDir.delete(recursive: true);
    }
  });

  group('AudioCaptureService', () {
    test('configures strictly 16kHz mono 16-bit PCM WAV', () async {
      final fakeClient = FakeAudioRecorderClient();
      final service = AudioCaptureService(
        recorderClient: fakeClient,
        tempDirectory: testTempDir,
      );

      final path = await service.startRecording();
      expect(fakeClient.recordingActive, isTrue);
      expect(fakeClient.lastConfig?.encoder, equals(AudioEncoder.wav));
      expect(fakeClient.lastConfig?.sampleRate, equals(16000));
      expect(fakeClient.lastConfig?.numChannels, equals(1));
      expect(path.endsWith('.wav'), isTrue);

      final stoppedPath = await service.stopRecording();
      expect(stoppedPath, equals(path));
      expect(fakeClient.recordingActive, isFalse);

      await service.purgeAudioFile(path);
      expect(await File(path).exists(), isFalse);
    });

    test('throws AudioCapturePermissionException when mic permission denied', () async {
      final fakeClient = FakeAudioRecorderClient(permissionGranted: false);
      final service = AudioCaptureService(
        recorderClient: fakeClient,
        tempDirectory: testTempDir,
      );

      expect(
        () => service.startRecording(),
        throwsA(isA<AudioCapturePermissionException>()),
      );
      expect(service.isRecording, isFalse);
    });

    test('cancelRecording immediately purges active recording file', () async {
      final fakeClient = FakeAudioRecorderClient();
      final service = AudioCaptureService(
        recorderClient: fakeClient,
        tempDirectory: testTempDir,
      );

      final path = await service.startRecording();
      expect(await File(path).exists(), isTrue);

      await service.cancelRecording();
      expect(service.isRecording, isFalse);
      expect(await File(path).exists(), isFalse);
    });

    test('purgeTemporaryWavs removes all lingering wav files in audio directory', () async {
      final fakeClient = FakeAudioRecorderClient();
      final service = AudioCaptureService(
        recorderClient: fakeClient,
        tempDirectory: testTempDir,
      );

      final audioDir = await service.getAudioDirectory();
      final file1 = File(p.join(audioDir.path, 'lingering_1.wav'));
      final file2 = File(p.join(audioDir.path, 'lingering_2.wav'));
      final otherFile = File(p.join(audioDir.path, 'notes.txt'));

      await file1.writeAsString('dummy');
      await file2.writeAsString('dummy');
      await otherFile.writeAsString('keep');

      final deleted = await service.purgeTemporaryWavs();
      expect(deleted, equals(2));
      expect(await file1.exists(), isFalse);
      expect(await file2.exists(), isFalse);
      expect(await otherFile.exists(), isTrue);
    });
  });

  group('SpeechToTextService (ADR-0006)', () {
    test('validates platform-native STT readiness with zero weight download', () async {
      final mockManager = ModelManagementService(baseDirectory: testModelDir);
      final mockEngine = MockSttEngine();
      final service = SpeechToTextService(
        engine: mockEngine,
        modelManager: mockManager,
      );

      // Platform STT requires zero downloaded weights
      expect(await service.checkModelsInstalled(), isTrue);
      await service.initializeEngine();
      expect(service.isEngineInitialized, isTrue);
    });

    test('streaming startListening and stopListening delivers live transcripts', () async {
      final mockEngine = MockSttEngine(defaultTranscript: 'Chai 20 rupees on UPI');
      final service = SpeechToTextService(
        engine: mockEngine,
        modelManager: ModelManagementService(baseDirectory: testModelDir),
      );

      String liveWords = '';
      bool wasFinal = false;
      double lastSound = 0.0;

      await service.startListening(
        onResult: (words, isFinal) {
          liveWords = words;
          wasFinal = isFinal;
        },
        onSoundLevelChange: (sound) {
          lastSound = sound;
        },
      );

      expect(liveWords, equals('Chai 20 rupees on UPI'));
      expect(wasFinal, isTrue);
      expect(lastSound, equals(0.5));

      final finalResult = await service.stopListening();
      expect(finalResult, equals('Chai 20 rupees on UPI'));
    });

    test('detects silent audio and throws SttSilentAudioException', () async {
      final mockEngine = MockSttEngine();
      final service = SpeechToTextService(
        engine: mockEngine,
        modelManager: ModelManagementService(baseDirectory: testModelDir),
      );

      // Create empty wav file (44 bytes header only)
      final emptyWav = File(p.join(testTempDir.path, 'empty.wav'));
      final emptyBytes = createTestWavBytes(numSamples: 0);
      await emptyWav.writeAsBytes(emptyBytes);

      expect(
        () => service.transcribe(emptyWav.path),
        throwsA(isA<SttSilentAudioException>()),
      );
    });

    test('propagates engine failures as SttEngineException', () async {
      final mockEngine = MockSttEngine(onTranscribe: (_) {
        throw const SttEngineException('Decoding stream timeout');
      });
      await mockEngine.initialize(modelDirPath: testModelDir.path);

      final validWav = File(p.join(testTempDir.path, 'valid.wav'));
      await validWav.writeAsBytes(createTestWavBytes());

      expect(
        () => mockEngine.transcribeFile(validWav.path),
        throwsA(isA<SttEngineException>()),
      );
    });

    test('NativePlatformSttEngine handles progressive corrections without duplication', () async {
      final fakeSpeech = FakeSpeechToText();
      final engine = NativePlatformSttEngine(speech: fakeSpeech);
      await engine.initialize();

      final emittedResults = <String>[];
      await engine.startListening(
        onResult: (words, isFinal) {
          emittedResults.add(words);
        },
      );

      // 1. Partial: initial misheard acoustic guess
      fakeSpeech.emitResult('spend 50', false);
      expect(emittedResults.last, equals('spend 50'));

      // 2. Progressive correction from recognizer: 'spend 50' -> 'spent 250'
      fakeSpeech.emitResult('spent 250', false);
      expect(emittedResults.last, equals('spent 250'));
      // Verify no duplication like 'spend 50, spent 250'
      expect(emittedResults.last.contains('spend 50'), isFalse);

      // 3. Extension of phrase
      fakeSpeech.emitResult('spent 250 on lunch', true);
      expect(emittedResults.last, equals('spent 250 on lunch'));

      final finalTranscript = await engine.stopListening();
      expect(finalTranscript, equals('spent 250 on lunch'));
    });

    test('NativePlatformSttEngine emits listening state change and commits on status notListening', () async {
      final fakeSpeech = FakeSpeechToText();
      final engine = NativePlatformSttEngine(speech: fakeSpeech);
      await engine.initialize();

      bool? listeningState;
      await engine.startListening(
        onResult: (_, __) {},
        onListeningStateChanged: (active) {
          listeningState = active;
        },
      );
      expect(listeningState, isTrue);

      // Partial words spoken in turn 1
      fakeSpeech.emitResult('Chai 20 rupees', false);

      // Android silence timeout triggers status 'notListening'
      fakeSpeech.emitStatus('notListening');
      expect(listeningState, isFalse);

      // User resumes listening for turn 2
      await engine.resumeListening();
      expect(listeningState, isTrue);

      fakeSpeech.emitResult('and 30 on snack', true);
      final finalTranscript = await engine.stopListening();
      expect(finalTranscript, equals('Chai 20 rupees, and 30 on snack'));
    });

    test('does not duplicate transcript when Android auto-stops on silence timeout', () async {
      final fakeSpeech = FakeSpeechToText();
      final engine = NativePlatformSttEngine(speech: fakeSpeech);
      await engine.initialize();

      String lastResult = '';
      await engine.startListening(
        onResult: (words, isFinal) {
          lastResult = words;
        },
      );

      // 1. User speaks words
      fakeSpeech.emitResult('lunch 250 rupees', false);
      expect(lastResult, equals('lunch 250 rupees'));

      // 2. Recognizer emits final result for utterance
      fakeSpeech.emitResult('lunch 250 rupees', true);
      expect(lastResult, equals('lunch 250 rupees'));

      // 3. Android silence timeout fires notListening
      fakeSpeech.emitStatus('notListening');

      // 4. Stop listening to retrieve final result for model prompt
      final finalTranscript = await engine.stopListening();
      expect(finalTranscript, equals('lunch 250 rupees'));
      expect(lastResult, equals('lunch 250 rupees'));
    });

    test('updateTranscript updates committed buffer and appends subsequent speech', () async {
      final fakeSpeech = FakeSpeechToText();
      final engine = NativePlatformSttEngine(speech: fakeSpeech);
      await engine.initialize();

      String lastResult = '';
      await engine.startListening(
        onResult: (words, isFinal) {
          lastResult = words;
        },
      );

      // 1. Spoken words
      fakeSpeech.emitResult('lunch 25 rupees', false);
      expect(lastResult, equals('lunch 25 rupees'));

      // 2. Pause
      await engine.pauseListening();

      // 3. User corrects typo manually
      engine.updateTranscript('lunch 250 rupees');

      // 4. User resumes and speaks additional items
      await engine.resumeListening();
      fakeSpeech.emitResult('and 30 tea', true);

      final finalTranscript = await engine.stopListening();
      expect(finalTranscript, equals('lunch 250 rupees, and 30 tea'));
    });
  });

  group('VoiceAudioPipeline - Zero Audio Persistence Invariant (US 13)', () {
    test('transcribes speech accurately and purges WAV file on success', () async {
      final fakeClient = FakeAudioRecorderClient();
      final captureService = AudioCaptureService(
        recorderClient: fakeClient,
        tempDirectory: testTempDir,
      );

      final mockEngine = MockSttEngine(
        defaultTranscript: 'Lunch 12 dollars at Subway yesterday',
      );
      await mockEngine.initialize(modelDirPath: testModelDir.path);

      final sttService = SpeechToTextService(
        engine: mockEngine,
        modelManager: ModelManagementService(baseDirectory: testModelDir),
      );

      final pipeline = VoiceAudioPipeline(
        captureService: captureService,
        sttService: sttService,
      );

      // 1. Start recording
      final wavPath = await pipeline.startRecording();
      expect(pipeline.isRecording, isTrue);
      expect(await File(wavPath).exists(), isTrue);

      // 2. Stop and transcribe
      final transcript = await pipeline.stopAndTranscribe();
      expect(transcript, equals('Lunch 12 dollars at Subway yesterday'));

      // 3. Verify US 13: Zero audio persistence - file deleted immediately
      expect(await File(wavPath).exists(), isFalse);

      // 4. Verify 0 lingering files in audio directory
      final lingering = await pipeline.purgeLingeringCache();
      expect(lingering, equals(0));
    });

    test('guarantees WAV deletion even when transcription fails with error', () async {
      final fakeClient = FakeAudioRecorderClient();
      final captureService = AudioCaptureService(
        recorderClient: fakeClient,
        tempDirectory: testTempDir,
      );

      final mockEngine = MockSttEngine(
        onTranscribe: (_) => throw const SttEngineException('ONNX runtime crash'),
      );
      await mockEngine.initialize(modelDirPath: testModelDir.path);

      final sttService = SpeechToTextService(
        engine: mockEngine,
        modelManager: ModelManagementService(baseDirectory: testModelDir),
      );

      final pipeline = VoiceAudioPipeline(
        captureService: captureService,
        sttService: sttService,
      );

      final wavPath = await pipeline.startRecording();
      expect(await File(wavPath).exists(), isTrue);

      // Stop and transcribe fails
      await expectLater(
        () => pipeline.stopAndTranscribe(),
        throwsA(isA<SttEngineException>()),
      );

      // Invariant US 13: WAV must STILL be purged in finally block!
      expect(await File(wavPath).exists(), isFalse);
    });

    test('guarantees WAV deletion when audio is silent', () async {
      final fakeClient = FakeAudioRecorderClient(generateSilentWav: true);
      final captureService = AudioCaptureService(
        recorderClient: fakeClient,
        tempDirectory: testTempDir,
      );

      final mockEngine = MockSttEngine();
      mockEngine.shouldThrowSilent = true;
      await mockEngine.initialize(modelDirPath: testModelDir.path);

      final sttService = SpeechToTextService(
        engine: mockEngine,
        modelManager: ModelManagementService(baseDirectory: testModelDir),
      );

      final pipeline = VoiceAudioPipeline(
        captureService: captureService,
        sttService: sttService,
      );

      final wavPath = await pipeline.startRecording();
      expect(await File(wavPath).exists(), isTrue);

      await expectLater(
        () => pipeline.stopAndTranscribe(),
        throwsA(isA<SttSilentAudioException>()),
      );

      // Purged even on silent audio exception
      expect(await File(wavPath).exists(), isFalse);
    });

    test('cancelRecording aborts and deletes active audio file', () async {
      final fakeClient = FakeAudioRecorderClient();
      final captureService = AudioCaptureService(
        recorderClient: fakeClient,
        tempDirectory: testTempDir,
      );
      final mockEngine = MockSttEngine();
      final sttService = SpeechToTextService(
        engine: mockEngine,
        modelManager: ModelManagementService(baseDirectory: testModelDir),
      );

      final pipeline = VoiceAudioPipeline(
        captureService: captureService,
        sttService: sttService,
      );

      final wavPath = await pipeline.startRecording();
      expect(await File(wavPath).exists(), isTrue);

      await pipeline.cancelRecording();
      expect(pipeline.isRecording, isFalse);
      expect(await File(wavPath).exists(), isFalse);
    });
  });
}
