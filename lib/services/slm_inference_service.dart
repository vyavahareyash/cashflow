import 'dart:async';

import 'package:path/path.dart' as p;

import 'model_management_service.dart';
import 'slm_engine_provider.dart';
import 'voice_grammar.dart';

export 'slm_engine_provider.dart';

/// Thrown when required SmolLM2 neural model weights are missing or not installed.
class SlmModelNotInstalledException implements Exception {
  final String message;
  const SlmModelNotInstalledException([
    this.message = 'SmolLM2 model files are not installed. Download the Offline AI Model Pack in Settings.',
  ]);

  @override
  String toString() => 'SlmModelNotInstalledException: $message';
}

/// Thrown when an internal SLM isolate or inference engine failure occurs.
class SlmEngineException implements Exception {
  final String message;
  final dynamic cause;
  const SlmEngineException(this.message, [this.cause]);

  @override
  String toString() => cause != null
      ? 'SlmEngineException: $message (Cause: $cause)'
      : 'SlmEngineException: $message';
}

/// Abstract contract for Small Language Model inference engines.
abstract class SlmEngine {
  Future<void> initialize({
    required String modelPath,
    String? grammarStr,
    String? grammarRoot,
  });

  Future<String> generate({required String prompt});

  Future<void> dispose();

  bool get isInitialized;
}

/// Headless test mock for SLM inference evaluation without native C++ shared libraries.
class MockSlmEngine implements SlmEngine {
  bool _initialized = false;
  String Function(String prompt)? onGenerate;
  String defaultResponse;
  bool shouldThrowNotInstalled = false;
  bool shouldThrowError = false;

  MockSlmEngine({
    this.defaultResponse = '[]',
    this.onGenerate,
    this.shouldThrowNotInstalled = false,
    this.shouldThrowError = false,
  });

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize({
    required String modelPath,
    String? grammarStr,
    String? grammarRoot,
  }) async {
    if (shouldThrowNotInstalled) {
      throw const SlmModelNotInstalledException();
    }
    if (shouldThrowError) {
      throw const SlmEngineException('Mock SLM initialization error');
    }
    _initialized = true;
  }

  @override
  Future<String> generate({required String prompt}) async {
    if (!_initialized) {
      throw const SlmEngineException('Mock SLM is not initialized.');
    }
    if (shouldThrowError) {
      throw const SlmEngineException('Mock generation error');
    }
    if (onGenerate != null) {
      return onGenerate!(prompt);
    }
    return defaultResponse;
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
  }
}

/// Facade coordinating SLM inference lifecycle with [ModelManagementService] (US 16).
class SlmInferenceService {
  final SlmEngine _engine;
  final ModelManagementService? modelService;

  SlmInferenceService({SlmEngine? engine, this.modelService})
    : _engine = engine ?? createDefaultSlmEngine() {
    modelService?.registerLifecycleHooks(onUnload: () async => await dispose());
  }

  SlmEngine get engine => _engine;
  bool get isInitialized => _engine.isInitialized;

  /// Initializes the SLM engine using files managed by [ModelManagementService].
  Future<void> initialize({String? customModelPath}) async {
    String modelPath = customModelPath ?? '';
    if (modelPath.isEmpty && modelService != null) {
      final dir = await modelService!.getModelDirectory();
      modelPath = p.join(
        dir.path,
        'smollm2',
        'SmolLM2-360M-Instruct-Q4_K_M.gguf',
      );
    }

    if (modelPath.isEmpty) {
      throw const SlmModelNotInstalledException(
        'No model path provided and ModelManagementService not available.',
      );
    }

    await _engine.initialize(
      modelPath: modelPath,
      grammarStr: VoiceGrammar.transactionGrammar,
      grammarRoot: 'root',
    );
  }

  /// Generates GBNF-constrained JSON from the prompt.
  Future<String> generate({required String prompt}) async {
    if (!_engine.isInitialized && modelService != null) {
      await initialize();
    }
    return await _engine.generate(prompt: prompt);
  }

  /// Deallocates model RAM and isolate.
  Future<void> dispose() async {
    await _engine.dispose();
  }
}
