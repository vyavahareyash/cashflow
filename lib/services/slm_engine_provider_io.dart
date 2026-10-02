import 'dart:async';
import 'dart:io';

import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path/path.dart' as p;

import 'slm_inference_service.dart';
import 'voice_grammar.dart';

/// Production SLM inference engine executing SmolLM2-360M-Instruct via llama_cpp_dart
/// in a background child isolate (LlamaParent / LlamaChild) with GBNF grammar constraints.
class LlamaCppSlmEngine implements SlmEngine {
  LlamaParent? _parent;
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized && _parent != null;

  @override
  Future<void> initialize({
    required String modelPath,
    String? grammarStr,
    String? grammarRoot,
  }) async {
    if (_initialized && _parent != null) return;

    final file = File(modelPath);
    if (!await file.exists()) {
      throw SlmModelNotInstalledException(
        'Missing SmolLM2 GGUF model file: ${p.basename(modelPath)}',
      );
    }

    try {
      final modelParams = ModelParams();
      final contextParams = ContextParams()
        ..nCtx = 2048
        ..nThreads = 4;

      final samplerParams = SamplerParams()
        ..grammarStr = grammarStr ?? VoiceGrammar.transactionGrammar
        ..grammarRoot = grammarRoot ?? 'root'
        ..greedy = true;

      final loadCommand = LlamaLoad(
        path: modelPath,
        modelParams: modelParams,
        contextParams: contextParams,
        samplingParams: samplerParams,
      );

      _parent = LlamaParent(loadCommand);
      await _parent!.init();
      _initialized = true;
    } catch (e) {
      _initialized = false;
      _parent = null;
      if (e is SlmModelNotInstalledException) rethrow;
      throw SlmEngineException(
        'Failed to initialize LlamaCpp SLM background isolate: $e',
        e,
      );
    }
  }

  @override
  Future<String> generate({required String prompt}) async {
    if (!isInitialized || _parent == null) {
      throw const SlmEngineException(
        'SLM inference engine is not initialized.',
      );
    }

    try {
      final response = await _parent!.sendPrompt(prompt);
      return response.trim();
    } catch (e) {
      throw SlmEngineException('SLM token generation failed: $e', e);
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _parent?.dispose();
    } catch (_) {}
    _parent = null;
    _initialized = false;
  }
}

SlmEngine createDefaultSlmEngine() => LlamaCppSlmEngine();
