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
/// and SLM/heuristic entity extraction pipeline (ADR-0006, US 1, 2, 4, 5, 6, 7, 13, 16, 17).
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

  final ValueNotifier<String> _liveTranscriptNotifier = ValueNotifier<String>(
    '',
  );
  final ValueNotifier<bool> _isMicActiveNotifier = ValueNotifier<bool>(false);
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  StreamSubscription<double>? _audioPipelineAmpSubscription;
  Timer? _partialTranscribeTimer;
  bool _isTranscribingPartial = false;

  VoicePipelineCoordinator({
    VoiceAudioPipeline? audioPipeline,
    SpeechToTextService? speechToTextService,
    SlmInferenceService? slmService,
    ModelManagementService? modelManager,
    DatabaseHelper? dbHelper,
  }) : speechToTextService =
           speechToTextService ?? SpeechToTextService.instance,
       modelManager = modelManager ?? ModelManagementService.instance,
       dbHelper = dbHelper ?? DatabaseHelper.instance,
       audioPipeline =
           audioPipeline ??
           VoiceAudioPipeline(
             sttService: speechToTextService ?? SpeechToTextService.instance,
           ),
       slmService =
           slmService ??
           SlmInferenceService(
             modelService: modelManager ?? ModelManagementService.instance,
           ) {
    _audioPipelineAmpSubscription = this.audioPipeline.amplitudeStream.listen((
      amp,
    ) {
      if (!_isMicPaused && !_amplitudeController.isClosed) {
        _amplitudeController.add(amp);
      }
    });
  }

  bool _isNativeRecording = false;
  bool _isMicPaused = false;

  bool get isRecording => _isNativeRecording || audioPipeline.isRecording;
  bool get isMicPaused => _isMicPaused;

  /// Observable live streaming transcript updated during active recording.
  ValueListenable<String> get liveTranscriptListenable =>
      _liveTranscriptNotifier;

  /// Observable microphone active listening state.
  ValueListenable<bool> get isMicActiveListenable => _isMicActiveNotifier;

  /// Latest captured transcript string so far.
  String get currentLiveTranscript => _liveTranscriptNotifier.value;

  /// Stream of normalized amplitude values [0.0, 1.0] for voice-driven UI animations.
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Verifies model installation and prepares RAM resources (US 16).
  Future<void> prepareSession() async {
    final installed = await modelManager.isModelPackInstalled();
    if (!installed) {
      throw const SttModelNotInstalledException();
    }
    await speechToTextService.initializeEngine();
    await modelManager.loadModelsIntoMemory();
  }

  /// Starts recording and begins live speech recognition.
  Future<String> startRecording() async {
    _isMicPaused = false;
    _isMicActiveNotifier.value = true;
    _liveTranscriptNotifier.value = '';
    final isNative = speechToTextService.isNativeEngine;
    String path = '';
    if (!isNative) {
      path = await audioPipeline.startRecording();
    } else {
      _isNativeRecording = true;
    }

    try {
      await speechToTextService.startListening(
        onResult: (words, isFinal) {
          if (words.trim().isNotEmpty) {
            _liveTranscriptNotifier.value = words.trim();
          }
        },
        onSoundLevelChange: (level) {
          if (!_isMicPaused && !_amplitudeController.isClosed) {
            _amplitudeController.add(level);
          }
        },
        onListeningStateChanged: (isListening) {
          _isMicActiveNotifier.value = isListening;
          _isMicPaused = !isListening;
          if (!isListening && !_amplitudeController.isClosed) {
            _amplitudeController.add(0.0);
          }
        },
      );
    } catch (e) {
      debugPrint('STT startListening warning (fallback to pipeline): $e');
      if (isNative) {
        _isNativeRecording = false;
        path = await audioPipeline.startRecording();
      }
    }

    if (!isNative && audioPipeline.isRecording) {
      _startPartialTranscriptionLoop();
    }
    return path;
  }

  /// Pauses active STT listening and mutes live audio amplitude.
  Future<void> pauseListening() async {
    _isMicPaused = true;
    _isMicActiveNotifier.value = false;
    if (!_amplitudeController.isClosed) {
      _amplitudeController.add(0.0);
    }
    await speechToTextService.pauseListening();
  }

  /// Resumes STT listening and unpauses live audio analysis.
  Future<void> resumeListening() async {
    _isMicPaused = false;
    _isMicActiveNotifier.value = true;
    await speechToTextService.resumeListening();
  }

  void _startPartialTranscriptionLoop() {
    _partialTranscribeTimer?.cancel();
    _partialTranscribeTimer = Timer.periodic(
      const Duration(milliseconds: 1000),
      (_) async {
        if (!isRecording || _isMicPaused || _isTranscribingPartial) return;
        try {
          final samples = await audioPipeline.readActiveRecordingSamples();
          if (samples != null && samples.length >= 8000) {
            _isTranscribingPartial = true;
            final partial = await speechToTextService.transcribeSamples(
              samples,
            );
            if (partial.trim().isNotEmpty && isRecording) {
              _liveTranscriptNotifier.value = partial.trim();
            }
          }
        } catch (_) {
          // Gracefully continue recording if partial decode fails or unsupported
        } finally {
          _isTranscribingPartial = false;
        }
      },
    );
  }

  /// Updates the live transcript manually (e.g. user corrections in UI when mic is paused).
  void updateTranscript(String newTranscript) {
    _liveTranscriptNotifier.value = newTranscript;
    speechToTextService.updateTranscript(newTranscript);
  }

  /// Stops recording, executes STT transcription, queries SQLite entities,
  /// grounds ChatML prompt, executes SLM inference (or heuristic fallback),
  /// and returns parsed [DraftTransaction] items.
  ///
  /// Guarantees that ephemeral WAV files are purged from disk (US 13).
  Future<List<DraftTransaction>> stopAndProcess({
    DateTime? anchorDate,
    String? overrideTranscript,
  }) async {
    _partialTranscribeTimer?.cancel();
    _partialTranscribeTimer = null;
    _isNativeRecording = false;
    _isMicPaused = false;
    _isMicActiveNotifier.value = false;
    final effectiveAnchor = anchorDate ?? DateTime.now();

    String transcript = overrideTranscript?.trim() ?? '';
    try {
      final sttText = await speechToTextService.stopListening();
      if (transcript.isEmpty && sttText.trim().isNotEmpty) {
        transcript = sttText.trim();
      }
    } catch (_) {}

    // 1. Transcribe audio to text string with partial fallback
    try {
      if (audioPipeline.isRecording) {
        final audioText = await audioPipeline.stopAndTranscribe();
        if (transcript.isEmpty && audioText.trim().isNotEmpty) {
          transcript = audioText.trim();
        }
      }
    } on SttSilentAudioException {
      if (transcript.isEmpty &&
          _liveTranscriptNotifier.value.trim().isNotEmpty) {
        transcript = _liveTranscriptNotifier.value.trim();
      } else if (transcript.isEmpty) {
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
      debugPrint(
        'SLM inference failed or unavailable, falling back to deterministic parser: $e',
      );
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
    _isNativeRecording = false;
    _isMicPaused = false;
    _isMicActiveNotifier.value = false;
    _liveTranscriptNotifier.value = '';
    try {
      await speechToTextService.cancelListening();
    } catch (_) {}
    if (audioPipeline.isRecording) {
      await audioPipeline.cancelRecording();
    }
  }

  /// Deallocates native model weights and isolates from RAM (US 16).
  Future<void> endSession() async {
    _partialTranscribeTimer?.cancel();
    _partialTranscribeTimer = null;
    _isNativeRecording = false;
    _isMicPaused = false;
    _isMicActiveNotifier.value = false;
    await modelManager.unloadModelsFromMemory();
    await audioPipeline.purgeLingeringCache();
  }

  /// Releases resources.
  Future<void> dispose() async {
    _partialTranscribeTimer?.cancel();
    _partialTranscribeTimer = null;
    _isNativeRecording = false;
    _isMicPaused = false;
    _isMicActiveNotifier.value = false;
    await _audioPipelineAmpSubscription?.cancel();
    if (!_amplitudeController.isClosed) {
      await _amplitudeController.close();
    }
    _liveTranscriptNotifier.dispose();
    _isMicActiveNotifier.dispose();
    await audioPipeline.dispose();
    await slmService.dispose();
  }
}
