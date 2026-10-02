import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Thrown when microphone hardware permission is denied by the user or OS.
class AudioCapturePermissionException implements Exception {
  final String message;
  const AudioCapturePermissionException([
    this.message = 'Microphone permission not granted.',
  ]);

  @override
  String toString() => 'AudioCapturePermissionException: $message';
}

/// Thrown when an error occurs in the audio recording lifecycle.
class AudioCaptureException implements Exception {
  final String message;
  const AudioCaptureException(this.message);

  @override
  String toString() => 'AudioCaptureException: $message';
}

/// Abstract contract wrapping [AudioRecorder] to enable headless testing.
abstract class AudioRecorderClient {
  Future<bool> hasPermission();
  Future<bool> isRecording();
  Future<void> start(RecordConfig config, {required String path});
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
  Stream<Amplitude> onAmplitudeChanged(Duration interval);
  Future<Amplitude> getAmplitude();
}

/// Production implementation using package:record AudioRecorder.
class RecordAudioRecorderClient implements AudioRecorderClient {
  final AudioRecorder _recorder;

  RecordAudioRecorderClient([AudioRecorder? recorder])
    : _recorder = recorder ?? AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<bool> isRecording() => _recorder.isRecording();

  @override
  Future<void> start(RecordConfig config, {required String path}) =>
      _recorder.start(config, path: path);

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      _recorder.onAmplitudeChanged(interval);

  @override
  Future<Amplitude> getAmplitude() => _recorder.getAmplitude();
}

/// Web-compatible AudioCaptureService without dart:io filesystem dependencies.
class AudioCaptureService {
  static const RecordConfig standardVoiceConfig = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
  );

  final AudioRecorderClient _recorderClient;

  bool _isRecording = false;
  String? _activeRecordingPath;

  AudioCaptureService({
    AudioRecorderClient? recorderClient,
    dynamic tempDirectory,
  }) : _recorderClient = recorderClient ?? RecordAudioRecorderClient();

  bool get isRecording => _isRecording;
  String? get activeRecordingPath => _activeRecordingPath;

  Stream<double> get amplitudeStream {
    try {
      return _recorderClient
          .onAmplitudeChanged(const Duration(milliseconds: 80))
          .map((amp) => ((amp.current + 55.0) / 55.0).clamp(0.0, 1.0));
    } catch (_) {
      return const Stream.empty();
    }
  }

  Future<Float32List?> readActiveRecordingSamples() async => null;

  Future<bool> hasPermission() async {
    try {
      return await _recorderClient.hasPermission();
    } catch (_) {
      return false;
    }
  }

  Future<String> startRecording() async {
    if (_isRecording) {
      throw const AudioCaptureException(
        'A recording session is already active.',
      );
    }

    final hasPerm = await hasPermission();
    if (!hasPerm) {
      throw const AudioCapturePermissionException(
        'Microphone permission denied. Grant permission in Settings to use voice journaling.',
      );
    }

    final targetPath = 'rec_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await _recorderClient.start(standardVoiceConfig, path: targetPath);
      _isRecording = true;
      _activeRecordingPath = targetPath;
      return targetPath;
    } catch (e) {
      _isRecording = false;
      _activeRecordingPath = null;
      throw AudioCaptureException('Failed to start audio recording: $e');
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final stoppedPath = await _recorderClient.stop();
      _isRecording = false;
      final effectivePath = stoppedPath ?? _activeRecordingPath;
      _activeRecordingPath = null;
      return effectivePath;
    } catch (e) {
      _isRecording = false;
      _activeRecordingPath = null;
      throw AudioCaptureException('Failed to stop audio recording: $e');
    }
  }

  Future<void> cancelRecording() async {
    if (_isRecording) {
      try {
        await _recorderClient.cancel();
      } catch (_) {}
      _isRecording = false;
    }
    _activeRecordingPath = null;
  }

  Future<void> purgeAudioFile(String path) async {}

  Future<int> purgeTemporaryWavs() async => 0;

  Future<void> dispose() async {
    await cancelRecording();
    await _recorderClient.dispose();
  }
}
