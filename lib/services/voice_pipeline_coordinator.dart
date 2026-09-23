import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;

import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/draft_transaction.dart';
import 'database_helper.dart';
import 'model_management_service.dart';
import 'slm_inference_service.dart';
import 'speech_to_text_service.dart';
import 'voice_audio_pipeline.dart';
import 'voice_entity_parser.dart';
import 'voice_prompt_builder.dart';

/// Coordinates the end-to-end voice capture, transcription, prompt grounding,
/// and SLM/heuristic entity extraction pipeline (US 1, 2, 4, 5, 6, 7, 13, 16, 17).
///
/// Decouples voice journaling orchestration from UI components, ensuring
/// headless testability and strict adherence to zero-audio-persistence (US 13)
/// and memory lifecycle (US 16) guarantees.
class VoicePipelineCoordinator {
  final VoiceAudioPipeline audioPipeline;
  final SpeechToTextService speechToTextService;
  final SlmInferenceService slmService;
  final ModelManagementService modelManager;
  final DatabaseHelper dbHelper;

  final ValueNotifier<String> _liveTranscriptNotifier = ValueNotifier<String>('');
  Timer? _partialTranscribeTimer;
  bool _isTranscribingPartial = false;

  VoicePipelineCoordinator({
    VoiceAudioPipeline? audioPipeline,
    SpeechToTextService? speechToTextService,
    SlmInferenceService? slmService,
    ModelManagementService? modelManager,
    DatabaseHelper? dbHelper,
  })  : speechToTextService =
            speechToTextService ?? SpeechToTextService.instance,
        modelManager = modelManager ?? ModelManagementService.instance,
        dbHelper = dbHelper ?? DatabaseHelper.instance,
        audioPipeline = audioPipeline ??
            VoiceAudioPipeline(
              sttService: speechToTextService ?? SpeechToTextService.instance,
            ),
        slmService = slmService ??
            SlmInferenceService(
              modelService: modelManager ?? ModelManagementService.instance,
            );

  bool get isRecording => audioPipeline.isRecording;

  /// Observable live streaming transcript updated during active recording.
  ValueListenable<String> get liveTranscriptListenable => _liveTranscriptNotifier;

  /// Latest captured transcript string so far.
  String get currentLiveTranscript => _liveTranscriptNotifier.value;

  /// Stream of normalized amplitude values [0.0, 1.0] for voice-driven UI animations.
  Stream<double> get amplitudeStream => audioPipeline.amplitudeStream;

  /// Verifies model installation and prepares RAM resources (US 16).
  Future<void> prepareSession() async {
    final installed = await modelManager.isModelPackInstalled();
    if (!installed) {
      throw const SttModelNotInstalledException();
    }
    await modelManager.loadModelsIntoMemory();
  }

  /// Starts recording 16kHz mono WAV audio and begins live partial transcription.
  Future<String> startRecording() async {
    _liveTranscriptNotifier.value = '';
    final path = await audioPipeline.startRecording();
    _startPartialTranscriptionLoop();
    return path;
  }

  void _startPartialTranscriptionLoop() {
    _partialTranscribeTimer?.cancel();
    _partialTranscribeTimer = Timer.periodic(
      const Duration(milliseconds: 1000),
      (_) async {
        if (!isRecording || _isTranscribingPartial) return;
        try {
          final samples = await audioPipeline.readActiveRecordingSamples();
          if (samples != null && samples.length >= 8000) {
            _isTranscribingPartial = true;
            final partial = await speechToTextService.transcribeSamples(samples);
            if (partial.trim().isNotEmpty && isRecording) {
              _liveTranscriptNotifier.value = partial.trim();
            }
          }
        } catch (_) {
          // Gracefully continue recording if partial decode fails
        } finally {
          _isTranscribingPartial = false;
        }
      },
    );
  }

  /// Stops recording, executes STT transcription, queries SQLite entities,
  /// grounds ChatML prompt, executes SLM inference (or heuristic fallback),
  /// and returns parsed [DraftTransaction] items.
  ///
  /// Guarantees that ephemeral WAV files are purged from disk (US 13).
  Future<List<DraftTransaction>> stopAndProcess({
    DateTime? anchorDate,
  }) async {
    _partialTranscribeTimer?.cancel();
    _partialTranscribeTimer = null;
    final effectiveAnchor = anchorDate ?? DateTime.now();

    // 1. Transcribe audio to text string with partial fallback
    String transcript = '';
    try {
      transcript = await audioPipeline.stopAndTranscribe();
    } on SttSilentAudioException {
      if (_liveTranscriptNotifier.value.trim().isNotEmpty) {
        transcript = _liveTranscriptNotifier.value.trim();
      } else {
        rethrow;
      }
    }

    final trimmedTranscript = transcript.trim().isNotEmpty
        ? transcript.trim()
        : _liveTranscriptNotifier.value.trim();

    if (trimmedTranscript.isEmpty) {
      throw const SttSilentAudioException(
        'No decipherable speech detected in audio capture.',
      );
    }

    // 2. Query active SQLite accounts and categories
    final List<Account> accounts = await dbHelper.readAllAccounts();
    final List<Category> categories = await dbHelper.readAllCategories();

    // 3. Format grounded ChatML prompt with calendar anchor
    final prompt = VoicePromptBuilder.buildPrompt(
      transcript: trimmedTranscript,
      anchorDate: effectiveAnchor,
      accounts: accounts,
      categories: categories,
    );

    // 4. Execute token-level GBNF grammar inference with fallback
    List<DraftTransaction> drafts = [];
    try {
      final slmOutput = await slmService.generate(prompt: prompt);
      drafts = VoiceEntityParser.parseJsonOutput(
        slmOutput,
        anchorDate: effectiveAnchor,
        accounts: accounts,
        categories: categories,
      );
    } catch (e) {
      debugPrint('SLM inference failed or unavailable, falling back to deterministic parser: $e');
      drafts = [];
    }

    // 5. Fallback to deterministic heuristic parser if SLM yielded no drafts
    if (drafts.isEmpty) {
      drafts = VoiceEntityParser.parseTranscriptionSample(
        trimmedTranscript,
        anchorDate: effectiveAnchor,
        accounts: accounts,
        categories: categories,
      );
    }

    return drafts;
  }

  /// Cancels active recording and purges temporary files (US 13).
  Future<void> cancelRecording() async {
    _partialTranscribeTimer?.cancel();
    _partialTranscribeTimer = null;
    _liveTranscriptNotifier.value = '';
    await audioPipeline.cancelRecording();
  }

  /// Deallocates native model weights and isolates from RAM (US 16).
  Future<void> endSession() async {
    _partialTranscribeTimer?.cancel();
    _partialTranscribeTimer = null;
    await modelManager.unloadModelsFromMemory();
    await audioPipeline.purgeLingeringCache();
  }

  /// Releases resources.
  Future<void> dispose() async {
    _partialTranscribeTimer?.cancel();
    _partialTranscribeTimer = null;
    _liveTranscriptNotifier.dispose();
    await audioPipeline.dispose();
    await slmService.dispose();
  }
}
