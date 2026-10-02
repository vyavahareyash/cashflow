import 'package:path/path.dart' as p;

/// Installation and verification lifecycle status of the Offline AI Model Pack.
enum ModelPackStatus {
  notInstalled,
  checking,
  downloading,
  verifying,
  installed,
  error,
}

/// Runtime RAM loading and deallocation state for neural model weights (US 16).
enum ModelMemoryState { unloaded, loading, loaded, unloading }

/// Network interface connectivity type for Wi-Fi gating (US 14).
enum NetworkType { wifi, cellular, ethernet, none, unknown }

/// Metadata description for an individual neural model weight binary.
class AiModelFile {
  final String id;
  final String filename;
  final String relativeSubpath;
  final String downloadUrl;
  final String expectedSha256;
  final int expectedSizeBytes;
  final String description;

  const AiModelFile({
    required this.id,
    required this.filename,
    this.relativeSubpath = '',
    required this.downloadUrl,
    required this.expectedSha256,
    required this.expectedSizeBytes,
    required this.description,
  });

  String get relativeFilePath =>
      relativeSubpath.isEmpty ? filename : p.join(relativeSubpath, filename);
}

/// Manifest of models required for full Offline Voice Transaction Journaling (ADR-0006).
///
/// STT: Platform-native on-device speech recognition (0 MB download)
/// SLM: SmolLM2-360M-Instruct Q4_K_M (~270 MB)
class AiModelPackManifest {
  final String packId;
  final String name;
  final String version;
  final List<AiModelFile> files;

  const AiModelPackManifest({
    required this.packId,
    required this.name,
    required this.version,
    required this.files,
  });

  int get totalSizeBytes =>
      files.fold(0, (sum, file) => sum + file.expectedSizeBytes);

  /// Default production manifest referencing official verified HuggingFace releases.
  static const AiModelPackManifest defaultPack = AiModelPackManifest(
    packId: 'cashflow_voice_v1',
    name: 'Offline AI Model Pack',
    version: '1.0.0',
    files: [
      AiModelFile(
        id: 'smollm2_360m',
        filename: 'SmolLM2-360M-Instruct-Q4_K_M.gguf',
        relativeSubpath: 'smollm2',
        downloadUrl: 'https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf',
        expectedSha256:
            '2fa3f013dcdd7b99f9b237717fa0b12d75bbb89984cc1274be1471a465bac9c2',
        expectedSizeBytes: 270590880,
        description: 'SmolLM2-360M-Instruct GGUF Q4_K_M',
      ),
    ],
  );
}

/// Abstract contract for checking local network interface connectivity.
abstract class NetworkConnectivityChecker {
  Future<NetworkType> checkConnectivity();
}

/// Download stream and response details from HTTP engine.
class DownloadStreamResponse {
  final Stream<List<int>> stream;
  final int statusCode;
  final int? contentLength;
  final bool isPartial;

  const DownloadStreamResponse({
    required this.stream,
    required this.statusCode,
    this.contentLength,
    this.isPartial = false,
  });
}

/// Abstract HTTP client interface allowing test mocks without network sockets.
abstract class ModelDownloadClient {
  Future<DownloadStreamResponse> openStream(
    Uri uri, {
    int startByte = 0,
    Map<String, String>? headers,
  });
  void abort();
  void close();
}
