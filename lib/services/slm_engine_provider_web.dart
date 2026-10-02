import 'dart:async';

import 'slm_inference_service.dart';

/// Web stub for SLM engine where native C++ neural inference is unavailable.
class WebSlmEngine implements SlmEngine {
  @override
  bool get isInitialized => false;

  @override
  Future<void> initialize({
    required String modelPath,
    String? grammarStr,
    String? grammarRoot,
  }) async {
    throw const SlmModelNotInstalledException(
      'On-device neural inference is not supported in web browser.',
    );
  }

  @override
  Future<String> generate({required String prompt}) async {
    throw const SlmEngineException(
      'Neural inference is not supported on web target.',
    );
  }

  @override
  Future<void> dispose() async {}
}

class LlamaCppSlmEngine extends WebSlmEngine {}

SlmEngine createDefaultSlmEngine() => WebSlmEngine();
