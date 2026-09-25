import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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

/// Captures user speech strictly configured for 16kHz mono 16-bit PCM WAV.
///
/// Enforces the zero-audio-persistence invariant (US 13) via [purgeAudioFile]
/// and [purgeTemporaryWavs].
class AudioCaptureService {
  /// Standard 16kHz mono WAV configuration for audio recording.
  static const RecordConfig standardVoiceConfig = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
  );

  final AudioRecorderClient _recorderClient;
  final Directory? _overrideTempDirectory;

  bool _isRecording = false;
  String? _activeRecordingPath;

  AudioCaptureService({
    AudioRecorderClient? recorderClient,
    Directory? tempDirectory,
  }) : _recorderClient = recorderClient ?? RecordAudioRecorderClient(),
       _overrideTempDirectory = tempDirectory;

  bool get isRecording => _isRecording;
  String? get activeRecordingPath => _activeRecordingPath;

  /// Stream of normalized amplitude values [0.0, 1.0] from microphone input.
  Stream<double> get amplitudeStream {
    try {
      return _recorderClient
          .onAmplitudeChanged(const Duration(milliseconds: 80))
          .map((amp) => ((amp.current + 55.0) / 55.0).clamp(0.0, 1.0));
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Reads raw 16kHz mono Float32 audio samples accumulated so far in the active recording.
  Future<Float32List?> readActiveRecordingSamples() async {
    if (!_isRecording || _activeRecordingPath == null) return null;
    try {
      final file = File(_activeRecordingPath!);
      if (!file.existsSync()) return null;
      final bytes = file.readAsBytesSync();
      // WAV header is at least 44 bytes. Anything <= 44 bytes has zero PCM sample data.
      if (bytes.length <= 44) return null;

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
      if (bytes.length <= dataOffset) return null;

      final numSamples = (bytes.length - dataOffset) ~/ 2;
      if (numSamples <= 0) return null;

      final byteData = ByteData.sublistView(bytes, dataOffset);
      final samples = Float32List(numSamples);
      for (int i = 0; i < numSamples; i++) {
        final int sampleInt = byteData.getInt16(i * 2, Endian.little);
        samples[i] = sampleInt / 32768.0;
      }
      return samples;
    } catch (_) {
      return null;
    }
  }

  /// Checks and requests microphone hardware permission.
  Future<bool> hasPermission() async {
    try {
      return await _recorderClient.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Returns the temporary directory used for ephemeral voice recordings.
  Future<Directory> getAudioDirectory() async {
    final Directory baseDir =
        _overrideTempDirectory ?? await getTemporaryDirectory();
    final Directory audioDir = Directory(
      p.join(baseDir.path, 'voice_recordings'),
    );
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir;
  }

  /// Begins recording 16kHz mono WAV audio to an ephemeral cache path.
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

    final dir = await getAudioDirectory();
    final filename = 'rec_${DateTime.now().millisecondsSinceEpoch}.wav';
    final targetPath = p.join(dir.path, filename);

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

  /// Stops the current recording and returns the path to the recorded WAV file.
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

  /// Aborts active recording and purges any temporary file immediately.
  Future<void> cancelRecording() async {
    if (_isRecording) {
      try {
        await _recorderClient.cancel();
      } catch (_) {}
      _isRecording = false;
    }

    if (_activeRecordingPath != null) {
      await purgeAudioFile(_activeRecordingPath!);
      _activeRecordingPath = null;
    }
  }

  /// Deletes a specific audio file immediately from disk (US 13).
  Future<void> purgeAudioFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Sweeps temporary storage to guarantee zero lingering WAV files (US 13).
  Future<int> purgeTemporaryWavs() async {
    int deletedCount = 0;
    try {
      final audioDir = await getAudioDirectory();
      if (await audioDir.exists()) {
        await for (final entity in audioDir.list(
          recursive: false,
          followLinks: false,
        )) {
          if (entity is File && entity.path.toLowerCase().endsWith('.wav')) {
            try {
              await entity.delete();
              deletedCount++;
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    return deletedCount;
  }

  /// Releases recorder native resources.
  Future<void> dispose() async {
    await cancelRecording();
    await _recorderClient.dispose();
  }
}
