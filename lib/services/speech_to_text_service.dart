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
    void Function(bool isListening)? onListeningStateChanged,
    String? localeId,
  });

  /// Updates active transcribed buffer manually (e.g. user corrections when mic paused).
  void updateTranscript(String newTranscript);

  /// Pauses listening without ending the recording session.
  Future<void> pauseListening();

  /// Resumes listening within an active recording session.
  Future<void> resumeListening();

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
  bool _sessionActive = false;
  bool _isPaused = false;

  String _committedText = '';
  String _currentTurnWords = '';
  String _lastRecognizedWords = '';
  Completer<String>? _transcriptionCompleter;

  void Function(String words, bool isFinal)? _onResultCallback;
  void Function(double soundLevel)? _onSoundLevelChangeCallback;
  void Function(String error)? _onErrorCallback;
  void Function(bool isListening)? _onListeningStateChangedCallback;
  String? _currentLocaleId;

  NativePlatformSttEngine({stt.SpeechToText? speech})
      : _speech = speech ?? stt.SpeechToText();

  @override
  bool get isInitialized => _initialized && _speech.isAvailable;

  bool get isListening => _isListening;
  bool get isPaused => _isPaused;

  static String _combineTranscripts(String base, String addition) {
    final b = base.trim();
    final a = addition.trim();
    if (b.isEmpty) return a;
    if (a.isEmpty) return b;

    final bLower = b.toLowerCase();
    final aLower = a.toLowerCase();

    // Already identical, or base already ends with addition, or addition is already contained
    if (bLower == aLower ||
        bLower.endsWith(aLower) ||
        bLower.endsWith(', $aLower') ||
        bLower.split(', ').any((part) => part.trim() == aLower)) {
      return b;
    }
    // Base is a prefix of addition: addition is an extended refinement of base
    if (aLower.startsWith(bLower)) {
      return a;
    }

    return '$b, $a';
  }

  @visibleForTesting
  static String combineTranscripts(String base, String addition) =>
      _combineTranscripts(base, addition);

  @override
  Future<void> initialize({String? modelDirPath}) async {
    if (_initialized && _speech.isAvailable) return;

    try {
      _initialized = await _speech.initialize(
        onError: (SpeechRecognitionError error) {
          debugPrint('Native STT error: ${error.errorMsg} (permanent: ${error.permanent})');
          _isListening = false;
          _onListeningStateChangedCallback?.call(false);
          _onErrorCallback?.call(error.errorMsg);
        },
        onStatus: (String status) {
          if (status == 'notListening' || status == 'done' || status == 'doneNoResult') {
            _isListening = false;

            // Commit any active turn words that haven't been committed yet
            if (_currentTurnWords.isNotEmpty) {
              _committedText = _combineTranscripts(_committedText, _currentTurnWords);
              _currentTurnWords = '';
              _lastRecognizedWords = _committedText;
            }

            // Immediately notify listener that native recognition has stopped
            _onListeningStateChangedCallback?.call(false);

            if (!_sessionActive) {
              final finalTranscript = (_committedText.isNotEmpty ? _committedText : _lastRecognizedWords).trim();
              if (_transcriptionCompleter != null && !_transcriptionCompleter!.isCompleted) {
                _transcriptionCompleter!.complete(finalTranscript);
              }
            }
          } else if (status == 'listening') {
            _isListening = true;
            _onListeningStateChangedCallback?.call(true);
          }
        },
        debugLogging: false,
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
    void Function(bool isListening)? onListeningStateChanged,
    String? localeId,
  }) async {
    _sessionActive = true;
    _isPaused = false;
    _committedText = '';
    _currentTurnWords = '';
    _lastRecognizedWords = '';
    _transcriptionCompleter = Completer<String>();
    _onResultCallback = onResult;
    _onSoundLevelChangeCallback = onSoundLevelChange;
    _onErrorCallback = onError;
    _onListeningStateChangedCallback = onListeningStateChanged;
    _currentLocaleId = localeId;

    await _startListeningSession();
  }

  Future<void> _startListeningSession() async {
    if (!_sessionActive || _isPaused) return;

    if (!_initialized) {
      await initialize();
    }

    if (!_speech.isAvailable) {
      throw const SttEngineException('Native speech recognition is not available on this device.');
    }

    _isListening = true;
    _onListeningStateChangedCallback?.call(true);

    final options = stt.SpeechListenOptions(
      onDevice: true,
      partialResults: true,
      cancelOnError: false,
      listenMode: stt.ListenMode.dictation,
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 4),
      localeId: _currentLocaleId,
    );

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (!_sessionActive || _isPaused) return;

          final incoming = result.recognizedWords.trim();
          if (incoming.isEmpty) return;

          // Replace active turn words with latest hypothesis from recognizer.
          // This allows native STT to correct earlier words ("50" -> "250") naturally
          // without heuristic string matching or duplication.
          _currentTurnWords = incoming;
          final combined = _combineTranscripts(_committedText, _currentTurnWords);

          _lastRecognizedWords = combined;
          _onResultCallback?.call(combined, result.finalResult);

          if (result.finalResult && _currentTurnWords.isNotEmpty) {
            _committedText = combined;
            _currentTurnWords = '';
          }
        },
        listenOptions: options,
        onSoundLevelChange: (level) {
          if (_onSoundLevelChangeCallback != null && !_isPaused) {
            final normalized = level <= -2.0
                ? 0.0
                : ((level + 2.0) / 12.0).clamp(0.0, 1.0);
            _onSoundLevelChangeCallback!(normalized);
          }
        },
      );
    } catch (e) {
      _isListening = false;
      _onListeningStateChangedCallback?.call(false);
      _onErrorCallback?.call(e.toString());
    }
  }

  @override
  void updateTranscript(String newTranscript) {
    _committedText = newTranscript.trim();
    _currentTurnWords = '';
    _lastRecognizedWords = _committedText;
  }

  @override
  Future<void> pauseListening() async {
    _isPaused = true;
    _isListening = false;
    if (_currentTurnWords.isNotEmpty) {
      _committedText = _combineTranscripts(_committedText, _currentTurnWords);
      _currentTurnWords = '';
    }
    _lastRecognizedWords = _committedText;
    await _speech.stop();
    _onListeningStateChangedCallback?.call(false);
  }

  @override
  Future<void> resumeListening() async {
    if (!_sessionActive) return;
    _isPaused = false;
    _currentTurnWords = '';
    await _startListeningSession();
  }

  @override
  Future<String> stopListening() async {
    _sessionActive = false;
    _isPaused = false;
    _isListening = false;
    if (_currentTurnWords.isNotEmpty) {
      _committedText = _combineTranscripts(_committedText, _currentTurnWords);
      _currentTurnWords = '';
    }
    await _speech.stop();
    _onListeningStateChangedCallback?.call(false);

    final finalTranscript = (_committedText.isNotEmpty ? _committedText : _lastRecognizedWords).trim();
    if (_transcriptionCompleter != null && !_transcriptionCompleter!.isCompleted) {
      _transcriptionCompleter!.complete(finalTranscript);
    }
    return finalTranscript;
  }

  @override
  Future<void> cancelListening() async {
    _sessionActive = false;
    _isPaused = false;
    _isListening = false;
    _committedText = '';
    _currentTurnWords = '';
    _lastRecognizedWords = '';
    if (_transcriptionCompleter != null && !_transcriptionCompleter!.isCompleted) {
      _transcriptionCompleter!.complete('');
    }
    await _speech.cancel();
    _onListeningStateChangedCallback?.call(false);
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
    _sessionActive = false;
    _isPaused = false;
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

  bool _isPaused = false;
  bool get isPaused => _isPaused;
  void Function(bool isListening)? _onListeningStateChanged;

  @override
  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
    void Function(double soundLevel)? onSoundLevelChange,
    void Function(String error)? onError,
    void Function(bool isListening)? onListeningStateChanged,
    String? localeId,
  }) async {
    _onListeningStateChanged = onListeningStateChanged;
    if (!_initialized) {
      throw const SttEngineException('Mock STT engine is not initialized');
    }
    if (shouldThrowSilent) {
      _isListening = true;
      _onListeningStateChanged?.call(true);
      onResult('', false);
      return;
    }
    _isListening = true;
    _onListeningStateChanged?.call(true);
    onSoundLevelChange?.call(0.5);
    onResult(defaultTranscript, true);
  }

  @override
  Future<String> stopListening() async {
    if (!_initialized) {
      throw const SttEngineException('Mock STT engine is not initialized');
    }
    _isListening = false;
    _isPaused = false;
    _onListeningStateChanged?.call(false);
    if (shouldThrowSilent || defaultTranscript.trim().isEmpty) {
      throw const SttSilentAudioException('Audio contains only silence.');
    }
    return defaultTranscript;
  }

  @override
  void updateTranscript(String newTranscript) {
    defaultTranscript = newTranscript;
  }

  @override
  Future<void> pauseListening() async {
    _isPaused = true;
    _isListening = false;
    _onListeningStateChanged?.call(false);
  }

  @override
  Future<void> resumeListening() async {
    _isPaused = false;
    _isListening = true;
    _onListeningStateChanged?.call(true);
  }

  @override
  Future<void> cancelListening() async {
    _isListening = false;
    _isPaused = false;
    _onListeningStateChanged?.call(false);
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
    void Function(bool isListening)? onListeningStateChanged,
    String? localeId,
  }) async {
    if (!_engine.isInitialized) {
      await initializeEngine();
    }
    await _engine.startListening(
      onResult: onResult,
      onSoundLevelChange: onSoundLevelChange,
      onError: onError,
      onListeningStateChanged: onListeningStateChanged,
      localeId: localeId,
    );
  }

  /// Manually updates the active transcription buffer (e.g. user manual correction).
  void updateTranscript(String newTranscript) {
    _engine.updateTranscript(newTranscript);
  }

  /// Pauses active speech listening without closing the recording session.
  Future<void> pauseListening() async {
    await _engine.pauseListening();
  }

  /// Resumes speech listening within an active recording session.
  Future<void> resumeListening() async {
    await _engine.resumeListening();
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
