import 'audio_capture_service.dart';
import 'speech_to_text_service.dart';

/// Coordinates the end-to-end voice capture and local speech-to-text pipeline.
///
/// Strictly enforces the zero-audio-persistence invariant (US 13):
/// Ephemeral WAV files are written to application cache and purged immediately
/// inside a `finally` block upon transcription success or failure.
class VoiceAudioPipeline {
  final AudioCaptureService audioCaptureService;
  final SpeechToTextService speechToTextService;

  VoiceAudioPipeline({
    AudioCaptureService? captureService,
    SpeechToTextService? sttService,
  })  : audioCaptureService = captureService ?? AudioCaptureService(),
        speechToTextService = sttService ?? SpeechToTextService.instance;

  bool get isRecording => audioCaptureService.isRecording;

  /// Starts recording a 16kHz mono WAV voice monologue.
  Future<String> startRecording() async {
    return await audioCaptureService.startRecording();
  }

  /// Stops recording and transcribes audio to text string.
  ///
  /// Guarantees that the underlying WAV file is deleted from disk in all cases
  /// (success, silent audio, engine failure, or unexpected exception).
  Future<String> stopAndTranscribe() async {
    final String? wavPath = await audioCaptureService.stopRecording();
    if (wavPath == null) {
      throw const SttSilentAudioException('No audio file was produced by recording session.');
    }

    try {
      final text = await speechToTextService.transcribe(wavPath);
      return text;
    } finally {
      // US 13: Strict Zero Audio Persistence guarantee
      await audioCaptureService.purgeAudioFile(wavPath);
    }
  }

  /// Cancels active recording and purges temporary files immediately.
  Future<void> cancelRecording() async {
    await audioCaptureService.cancelRecording();
  }

  /// Sweeps temporary cache directory to remove any orphaned `.wav` files.
  Future<int> purgeLingeringCache() async {
    return await audioCaptureService.purgeTemporaryWavs();
  }

  /// Cleans up pipeline resources.
  Future<void> dispose() async {
    await audioCaptureService.dispose();
  }
}
