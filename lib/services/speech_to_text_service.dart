import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'model_management_service.dart';

/// Thrown when microphone permission has been denied.
class SttPermissionDeniedException implements Exception {
  final String message;
  const SttPermissionDeniedException([this.message = 'Microphone permission denied.']);

  @override
  String toString() => 'SttPermissionDeniedException: $message';
}

/// Thrown when required STT model weights are not downloaded or missing.
class SttModelNotInstalledException implements Exception {
  final String message;
  const SttModelNotInstalledException([
    this.message =
        'Speech recognition service is not available or required models are missing.',
  ]);

  @override
  String toString() => 'SttModelNotInstalledException: $message';
}

/// Thrown when an audio clip is silent, empty, or contains no decipherable speech.
class SttSilentAudioException implements Exception {
  final String message;
  const SttSilentAudioException([this.message = 'Audio contains only silence.']);

  @override
  String toString() => 'SttSilentAudioException: $message';
}

/// Thrown when a low-level STT engine failure occurs.
class SttEngineException implements Exception {
  final String message;
  final dynamic cause;
  const SttEngineException(this.message, [this.cause]);

  @override
  String toString() =>
      cause != null ? 'SttEngineException: $message (Cause: $cause)' : 'SttEngineException: $message';
}

/// Abstract contract for speech-to-text inference engines (ADR-0006).
abstract class SttEngine {
  Future<void> initialize({String? modelDirPath});
  bool get isInitialized;

  /// Begins streaming speech recognition from the device microphone.
  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
    void Function(double soundLevel)? onSoundLevelChange,
    void Function(String error)? onError,
    String? localeId,
  });

  /// Stops listening and returns the finalized transcription string.
  Future<String> stopListening();

  /// Cancels active listening session immediately.
  Future<void> cancelListening();

  /// Fallback / file-based transcription methods for headless test fixtures:
  Future<String> transcribeFile(String wavFilePath);
  Future<String> transcribeSamples(Float32List samples, {int sampleRate = 16000});

  Future<void> dispose();
}

/// Production STT engine running platform-native on-device speech recognition
/// (Android SpeechRecognizer / iOS SFSpeechRecognizer) via package:speech_to_text (ADR-0006).
class NativePlatformSttEngine implements SttEngine {
  final stt.SpeechToText _speech;
  bool _initialized = false;
  bool _isListening = false;
  String _lastRecognizedWords = '';
  Completer<String>? _transcriptionCompleter;

  NativePlatformSttEngine({stt.SpeechToText? speech})
      : _speech = speech ?? stt.SpeechToText();

  @override
  bool get isInitialized => _initialized && _speech.isAvailable;

  bool get isListening => _isListening;

  @override
  Future<void> initialize({String? modelDirPath}) async {
    if (_initialized && _speech.isAvailable) return;

    try {
      _initialized = await _speech.initialize(
        onError: (SpeechRecognitionError error) {
          debugPrint('Native STT error: ${error.errorMsg} (permanent: ${error.permanent})');
        },
        onStatus: (String status) {
          if (status == 'notListening' || status == 'done' || status == 'doneNoResult') {
            _isListening = false;
            if (_transcriptionCompleter != null && !_transcriptionCompleter!.isCompleted) {
              _transcriptionCompleter!.complete(_lastRecognizedWords.trim());
            }
          }
        },
        debugLogging: kDebugMode,
      );
    } catch (e) {
      _initialized = false;
      throw SttEngineException('Failed to initialize native speech recognizer: $e', e);
    }
  }

  @override
  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
    void Function(double soundLevel)? onSoundLevelChange,
    void Function(String error)? onError,
    String? localeId,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    if (!_speech.isAvailable) {
      throw const SttEngineException('Native speech recognition is not available on this device.');
    }

    _lastRecognizedWords = '';
    _transcriptionCompleter = Completer<String>();
    _isListening = true;

    final options = stt.SpeechListenOptions(
      onDevice: true,
      partialResults: true,
      cancelOnError: false,
      listenMode: stt.ListenMode.dictation,
      localeId: localeId,
    );

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          _lastRecognizedWords = result.recognizedWords;
          onResult(result.recognizedWords, result.finalResult);
          if (result.finalResult &&
              _transcriptionCompleter != null &&
              !_transcriptionCompleter!.isCompleted) {
            _transcriptionCompleter!.complete(result.recognizedWords.trim());
          }
        },
        listenOptions: options,
        onSoundLevelChange: onSoundLevelChange != null
            ? (level) {
                final normalized = level <= -2.0
                    ? 0.0
                    : ((level + 2.0) / 12.0).clamp(0.0, 1.0);
                onSoundLevelChange(normalized);
              }
            : null,
      );
    } catch (e) {
      _isListening = false;
      onError?.call(e.toString());
      throw SttEngineException('Failed to start native speech listening: $e', e);
    }
  }

  @override
  Future<String> stopListening() async {
    if (!_isListening && _lastRecognizedWords.isNotEmpty) {
      return _lastRecognizedWords.trim();
    }
    _isListening = false;
    await _speech.stop();
    if (_transcriptionCompleter != null && !_transcriptionCompleter!.isCompleted) {
      _transcriptionCompleter!.complete(_lastRecognizedWords.trim());
    }
    return _lastRecognizedWords.trim();
  }

  @override
  Future<void> cancelListening() async {
    _isListening = false;
    _lastRecognizedWords = '';
    if (_transcriptionCompleter != null && !_transcriptionCompleter!.isCompleted) {
      _transcriptionCompleter!.complete('');
    }
    await _speech.cancel();
  }

  @override
  Future<String> transcribeFile(String wavFilePath) async {
    throw UnsupportedError(
      'NativePlatformSttEngine does not support file-based decoding; use streaming speech recognition or MockSttEngine.',
    );
  }

  @override
  Future<String> transcribeSamples(Float32List samples, {int sampleRate = 16000}) async {
    throw UnsupportedError(
      'NativePlatformSttEngine does not support sample-based decoding; use streaming speech recognition or MockSttEngine.',
    );
  }

  @override
  Future<void> dispose() async {
    if (_isListening) {
      await cancelListening();
    }
    _initialized = false;
  }
}

/// Headless test mock for STT engine evaluation without native C++ libraries or platform channels.
class MockSttEngine implements SttEngine {
  bool _initialized = false;
  bool _isListening = false;
  String Function(String wavPath)? onTranscribe;
  bool shouldFailInitialization = false;
  bool shouldThrowSilent = false;
  String defaultTranscript;
  final double? silenceThreshold;

  MockSttEngine({
    this.defaultTranscript = 'Chai 20 rupees on UPI yesterday',
    this.onTranscribe,
    this.silenceThreshold,
  });

  @override
  bool get isInitialized => _initialized;

  bool get isListening => _isListening;

  @override
  Future<void> initialize({String? modelDirPath}) async {
    if (shouldFailInitialization) {
      throw const SttEngineException('Simulated engine initialization failure');
    }
    _initialized = true;
  }

  @override
  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
    void Function(double soundLevel)? onSoundLevelChange,
    void Function(String error)? onError,
    String? localeId,
  }) async {
    if (!_initialized) {
      throw const SttEngineException('Mock STT engine is not initialized');
    }
    if (shouldThrowSilent) {
      _isListening = true;
      onResult('', false);
      return;
    }
    _isListening = true;
    onSoundLevelChange?.call(0.5);
    onResult(defaultTranscript, true);
  }

  @override
  Future<String> stopListening() async {
    if (!_initialized) {
      throw const SttEngineException('Mock STT engine is not initialized');
    }
    _isListening = false;
    if (shouldThrowSilent || defaultTranscript.trim().isEmpty) {
      throw const SttSilentAudioException('Audio contains only silence.');
    }
    return defaultTranscript;
  }

  @override
  Future<void> cancelListening() async {
    _isListening = false;
  }

  @override
  Future<String> transcribeSamples(
    Float32List samples, {
    int sampleRate = 16000,
  }) async {
    if (!_initialized) {
      throw const SttEngineException('Mock STT engine is not initialized');
    }
    if (samples.isEmpty || shouldThrowSilent) {
      return '';
    }
    if (silenceThreshold != null) {
      double maxAmp = 0.0;
      for (final s in samples) {
        final a = s.abs();
        if (a > maxAmp) maxAmp = a;
      }
      if (maxAmp < silenceThreshold!) {
        return '';
      }
    }
    return defaultTranscript;
  }

  @override
  Future<String> transcribeFile(String wavFilePath) async {
    if (!_initialized) {
      throw const SttEngineException('Mock STT engine is not initialized');
    }

    final file = File(wavFilePath);
    if (!file.existsSync()) {
      throw SttEngineException('Audio file not found: $wavFilePath');
    }

    final len = file.lengthSync();
    if (len <= 44 || shouldThrowSilent) {
      throw const SttSilentAudioException('Audio contains only silence.');
    }

    if (silenceThreshold != null) {
      final bytes = file.readAsBytesSync();
      int dataOffset = 44;
      for (int i = 12; i < bytes.length - 8; i++) {
        if (bytes[i] == 0x64 &&
            bytes[i + 1] == 0x61 &&
            bytes[i + 2] == 0x74 &&
            bytes[i + 3] == 0x61) {
          dataOffset = i + 8;
          break;
        }
      }
      if (bytes.length <= dataOffset) {
        throw const SttSilentAudioException('Audio contains only silence.');
      }
      final byteData = ByteData.sublistView(bytes, dataOffset);
      final numSamples = (bytes.length - dataOffset) ~/ 2;
      double maxAmp = 0.0;
      for (int i = 0; i < numSamples; i++) {
        final a = (byteData.getInt16(i * 2, Endian.little) / 32768.0).abs();
        if (a > maxAmp) maxAmp = a;
      }
      if (maxAmp < silenceThreshold!) {
        throw const SttSilentAudioException('Audio contains only silence.');
      }
    }

    if (onTranscribe != null) {
      return onTranscribe!(wavFilePath);
    }

    return defaultTranscript;
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
    _isListening = false;
  }
}

/// High-level SpeechToTextService coordinating on-device speech transcription.
class SpeechToTextService {
  static SpeechToTextService? _instance;
  static SpeechToTextService get instance =>
      _instance ??= SpeechToTextService();

  @visibleForTesting
  static void setMockInstance(SpeechToTextService service) {
    _instance = service;
  }

  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  final SttEngine _engine;
  final ModelManagementService _modelManager;

  SpeechToTextService({
    SttEngine? engine,
    ModelManagementService? modelManager,
  })  : _engine = engine ?? NativePlatformSttEngine(),
        _modelManager = modelManager ?? ModelManagementService.instance {
    // Register RAM lifecycle hooks for on-demand weight loading and deallocation (US 16)
    _modelManager.registerLifecycleHooks(
      onLoad: initializeEngine,
      onUnload: dispose,
    );
  }

  bool get isEngineInitialized => _engine.isInitialized;
  bool get isNativeEngine => _engine is NativePlatformSttEngine;
  SttEngine get engine => _engine;

  /// Validates engine availability. Platform-native STT requires 0 downloaded weights.
  Future<bool> checkModelsInstalled() async {
    return true;
  }

  /// Initializes the speech recognizer into RAM.
  Future<void> initializeEngine() async {
    if (_engine.isInitialized) return;
    await _engine.initialize();
  }

  /// Starts streaming speech recognition from device microphone.
  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
    void Function(double soundLevel)? onSoundLevelChange,
    void Function(String error)? onError,
    String? localeId,
  }) async {
    if (!_engine.isInitialized) {
      await initializeEngine();
    }
    await _engine.startListening(
      onResult: onResult,
      onSoundLevelChange: onSoundLevelChange,
      onError: onError,
      localeId: localeId,
    );
  }

  /// Stops streaming speech recognition and returns final transcript.
  Future<String> stopListening() async {
    return await _engine.stopListening();
  }

  /// Cancels streaming speech recognition.
  Future<void> cancelListening() async {
    await _engine.cancelListening();
  }

  /// Transcribes raw 16kHz mono Float32 audio samples into text string.
  Future<String> transcribeSamples(
    Float32List samples, {
    int sampleRate = 16000,
  }) async {
    if (!_engine.isInitialized) {
      await initializeEngine();
    }

    return await _engine.transcribeSamples(samples, sampleRate: sampleRate);
  }

  /// Transcribes a 16kHz mono WAV file into text string.
  ///
  /// Guarantees error handling for uninstalled models, silent clips, and engine failures.
  Future<String> transcribe(String wavFilePath) async {
    if (!_engine.isInitialized) {
      await initializeEngine();
    }

    return await _engine.transcribeFile(wavFilePath);
  }

  /// Unloads the recognizer and deallocates native model memory (US 16).
  Future<void> dispose() async {
    await _engine.dispose();
  }
}
