import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'model_management_service.dart';

/// Thrown when microphone permission has been denied.
class SttPermissionDeniedException implements Exception {
  final String message;
  const SttPermissionDeniedException([this.message = 'Microphone permission denied.']);

  @override
  String toString() => 'SttPermissionDeniedException: $message';
}

/// Thrown when required Moonshine STT model weights are not downloaded or missing.
class SttModelNotInstalledException implements Exception {
  final String message;
  const SttModelNotInstalledException([
    this.message =
        'Moonshine STT model files are not installed. Download the Offline AI Model Pack in Settings.',
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

/// Abstract contract for speech-to-text inference engines.
abstract class SttEngine {
  Future<void> initialize({required String modelDirPath});
  Future<String> transcribeFile(String wavFilePath);
  Future<void> dispose();
  bool get isInitialized;
}

/// Production STT engine running sherpa_onnx with Moonshine Tiny INT8 models.
class SherpaOnnxSttEngine implements SttEngine {
  sherpa.OfflineRecognizer? _recognizer;
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized && _recognizer != null;

  @override
  Future<void> initialize({required String modelDirPath}) async {
    if (_initialized && _recognizer != null) return;

    try {
      sherpa.initBindings();

      final preprocessorPath = p.join(modelDirPath, 'preprocess.onnx');
      final encoderPath = p.join(modelDirPath, 'encode.int8.onnx');
      final uncachedDecoderPath = p.join(modelDirPath, 'uncached_decode.int8.onnx');
      final cachedDecoderPath = p.join(modelDirPath, 'cached_decode.int8.onnx');
      final tokensPath = p.join(modelDirPath, 'tokens.txt');

      final requiredFiles = [
        preprocessorPath,
        encoderPath,
        uncachedDecoderPath,
        cachedDecoderPath,
        tokensPath,
      ];

      for (final filePath in requiredFiles) {
        if (!await File(filePath).exists()) {
          throw SttModelNotInstalledException(
            'Missing required Moonshine model file: ${p.basename(filePath)}',
          );
        }
      }

      final config = sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          moonshine: sherpa.OfflineMoonshineModelConfig(
            preprocessor: preprocessorPath,
            encoder: encoderPath,
            uncachedDecoder: uncachedDecoderPath,
            cachedDecoder: cachedDecoderPath,
          ),
          tokens: tokensPath,
          numThreads: 1,
          debug: false,
        ),
      );

      _recognizer = sherpa.OfflineRecognizer(config);
      _initialized = true;
    } catch (e) {
      _initialized = false;
      _recognizer = null;
      if (e is SttModelNotInstalledException) rethrow;
      throw SttEngineException('Failed to initialize SherpaOnnx STT engine: $e', e);
    }
  }

  @override
  Future<String> transcribeFile(String wavFilePath) async {
    if (!isInitialized || _recognizer == null) {
      throw const SttEngineException('STT engine is not initialized.');
    }

    final file = File(wavFilePath);
    if (!await file.exists()) {
      throw SttEngineException('WAV file does not exist at $wavFilePath');
    }

    final fileLength = await file.length();
    // Standard RIFF header is 44 bytes. Anything <= 44 bytes has zero audio data.
    if (fileLength <= 44) {
      throw const SttSilentAudioException('Audio file contains no sample data.');
    }

    try {
      final waveData = sherpa.readWave(wavFilePath);
      if (waveData.samples.isEmpty) {
        throw const SttSilentAudioException('Audio waveform is empty.');
      }

      // Energy check: inspect maximum amplitude across samples to detect silence.
      double maxAmp = 0.0;
      for (int i = 0; i < waveData.samples.length; i++) {
        final a = waveData.samples[i].abs();
        if (a > maxAmp) maxAmp = a;
      }

      if (maxAmp < 0.005) {
        throw const SttSilentAudioException('Audio contains only silence.');
      }

      final stream = _recognizer!.createStream();
      try {
        stream.acceptWaveform(
          samples: waveData.samples,
          sampleRate: waveData.sampleRate,
        );
        _recognizer!.decode(stream);
        final result = _recognizer!.getResult(stream);
        final text = result.text.trim();
        if (text.isEmpty) {
          throw const SttSilentAudioException('No decipherable speech detected.');
        }
        return text;
      } finally {
        stream.free();
      }
    } on SttSilentAudioException {
      rethrow;
    } catch (e) {
      throw SttEngineException('Failed during audio decoding: $e', e);
    }
  }

  @override
  Future<void> dispose() async {
    try {
      _recognizer?.free();
    } catch (_) {}
    _recognizer = null;
    _initialized = false;
  }
}

/// Headless test mock for STT engine evaluation without native C++ libraries.
class MockSttEngine implements SttEngine {
  bool _initialized = false;
  String Function(String wavPath)? onTranscribe;
  bool shouldFailInitialization = false;
  bool shouldThrowSilent = false;
  String defaultTranscript;

  MockSttEngine({
    this.defaultTranscript = 'Lunch 12 dollars at Subway yesterday',
    this.onTranscribe,
  });

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize({required String modelDirPath}) async {
    if (shouldFailInitialization) {
      throw const SttEngineException('Simulated engine initialization failure');
    }
    _initialized = true;
  }

  @override
  Future<String> transcribeFile(String wavFilePath) async {
    if (!_initialized) {
      throw const SttEngineException('Mock STT engine is not initialized');
    }

    final file = File(wavFilePath);
    if (!await file.exists()) {
      throw SttEngineException('Audio file not found: $wavFilePath');
    }

    final len = await file.length();
    if (len <= 44 || shouldThrowSilent) {
      throw const SttSilentAudioException('Audio contains only silence.');
    }

    if (onTranscribe != null) {
      return onTranscribe!(wavFilePath);
    }

    return defaultTranscript;
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
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
  })  : _engine = engine ?? SherpaOnnxSttEngine(),
        _modelManager = modelManager ?? ModelManagementService.instance {
    // Register RAM lifecycle hooks for on-demand weight loading and deallocation (US 16)
    _modelManager.registerLifecycleHooks(
      onLoad: initializeEngine,
      onUnload: dispose,
    );
  }

  bool get isEngineInitialized => _engine.isInitialized;

  /// Validates that Moonshine model files exist locally in application documents.
  Future<bool> checkModelsInstalled() async {
    try {
      final baseDir = await _modelManager.getModelDirectory();
      final moonshineDir = Directory(p.join(baseDir.path, 'moonshine'));
      if (!await moonshineDir.exists()) return false;

      final requiredFiles = [
        'preprocess.onnx',
        'encode.int8.onnx',
        'uncached_decode.int8.onnx',
        'cached_decode.int8.onnx',
        'tokens.txt',
      ];

      for (final filename in requiredFiles) {
        if (!await File(p.join(moonshineDir.path, filename)).exists()) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Initializes the speech recognizer into RAM.
  Future<void> initializeEngine() async {
    if (_engine.isInitialized) return;

    final installed = await checkModelsInstalled();
    if (!installed) {
      throw const SttModelNotInstalledException();
    }

    final baseDir = await _modelManager.getModelDirectory();
    final moonshinePath = p.join(baseDir.path, 'moonshine');
    await _engine.initialize(modelDirPath: moonshinePath);
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
