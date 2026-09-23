import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database_helper.dart';

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
enum ModelMemoryState {
  unloaded,
  loading,
  loaded,
  unloading,
}

/// Network interface connectivity type for Wi-Fi gating (US 14).
enum NetworkType {
  wifi,
  cellular,
  ethernet,
  none,
  unknown,
}

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

  String get relativeFilePath => relativeSubpath.isEmpty
      ? filename
      : p.join(relativeSubpath, filename);
}

/// Manifest of models required for full Offline Voice Transaction Journaling.
///
/// STT: Moonshine Tiny INT8 (~30 MB)
/// SLM: SmolLM2-360M-Instruct Q4_K_M (~230 MB)
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
        id: 'moonshine_preprocess',
        filename: 'preprocess.onnx',
        relativeSubpath: 'moonshine',
        downloadUrl:
            'https://huggingface.co/csukuangfj/sherpa-onnx-moonshine-tiny-en-int8/resolve/main/preprocess.onnx',
        expectedSha256:
            'f33addce61a143460fe753b5ee5b7db255e5140b5b779c065b94f6c83ff0bf4e',
        expectedSizeBytes: 6800738,
        description: 'Moonshine Audio Preprocessing ONNX',
      ),
      AiModelFile(
        id: 'moonshine_encoder',
        filename: 'encode.int8.onnx',
        relativeSubpath: 'moonshine',
        downloadUrl:
            'https://huggingface.co/csukuangfj/sherpa-onnx-moonshine-tiny-en-int8/resolve/main/encode.int8.onnx',
        expectedSha256:
            '8774dfba578de027ec6595c2c654a0836434489bc963a0db124a7f181f571acb',
        expectedSizeBytes: 18249187,
        description: 'Moonshine Tiny INT8 Speech Encoder',
      ),
      AiModelFile(
        id: 'moonshine_uncached_decoder',
        filename: 'uncached_decode.int8.onnx',
        relativeSubpath: 'moonshine',
        downloadUrl:
            'https://huggingface.co/csukuangfj/sherpa-onnx-moonshine-tiny-en-int8/resolve/main/uncached_decode.int8.onnx',
        expectedSha256:
            '216737000dd5881a17aa043f6bbd286add33e4c3b0ae257153e2ec15438bdc41',
        expectedSizeBytes: 53216096,
        description: 'Moonshine Tiny INT8 Uncached Decoder',
      ),
      AiModelFile(
        id: 'moonshine_cached_decoder',
        filename: 'cached_decode.int8.onnx',
        relativeSubpath: 'moonshine',
        downloadUrl:
            'https://huggingface.co/csukuangfj/sherpa-onnx-moonshine-tiny-en-int8/resolve/main/cached_decode.int8.onnx',
        expectedSha256:
            '2aff28bba6a03d8dcf5c9feac45462629bae37317442299f28115ad09da773f6',
        expectedSizeBytes: 45264830,
        description: 'Moonshine Tiny INT8 Cached Decoder',
      ),
      AiModelFile(
        id: 'moonshine_tokens',
        filename: 'tokens.txt',
        relativeSubpath: 'moonshine',
        downloadUrl:
            'https://huggingface.co/csukuangfj/sherpa-onnx-moonshine-tiny-en-int8/resolve/main/tokens.txt',
        expectedSha256:
            '1165c2aeb9f72f457a83be2d459a09054f27490acd9b41bd43794dfd25e296ea',
        expectedSizeBytes: 436688,
        description: 'Moonshine STT Tokenizer Dictionary',
      ),
      AiModelFile(
        id: 'smollm2_360m',
        filename: 'SmolLM2-360M-Instruct-Q4_K_M.gguf',
        relativeSubpath: 'smollm2',
        downloadUrl:
            'https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf',
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

/// Default network interface analyzer checking active network adapter types.
class PlatformNetworkConnectivityChecker implements NetworkConnectivityChecker {
  const PlatformNetworkConnectivityChecker();

  @override
  Future<NetworkType> checkConnectivity() async {
    if (kIsWeb) return NetworkType.wifi;
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      );
      if (interfaces.isEmpty) return NetworkType.none;

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.startsWith('wlan') ||
            name.startsWith('wifi') ||
            name.contains('wlan') ||
            name == 'en0') {
          return NetworkType.wifi;
        }
        if (name.startsWith('eth') || name.startsWith('en')) {
          return NetworkType.ethernet;
        }
        if (name.startsWith('rmnet') ||
            name.startsWith('pdp') ||
            name.startsWith('ccmni') ||
            name.startsWith('wwan')) {
          return NetworkType.cellular;
        }
      }
      return NetworkType.wifi; // Default fallback to unmetered if active interface found
    } catch (_) {
      return NetworkType.unknown;
    }
  }
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

/// Standard production HTTP client implementing Range requests and stream aborts.
class DefaultModelDownloadClient implements ModelDownloadClient {
  HttpClient? _client;
  HttpClientRequest? _activeRequest;

  @override
  Future<DownloadStreamResponse> openStream(
    Uri uri, {
    int startByte = 0,
    Map<String, String>? headers,
  }) async {
    _client = HttpClient();
    _activeRequest = await _client!.getUrl(uri);

    if (startByte > 0) {
      _activeRequest!.headers.set(HttpHeaders.rangeHeader, 'bytes=$startByte-');
    }

    if (headers != null) {
      headers.forEach((k, v) => _activeRequest!.headers.set(k, v));
    }

    final response = await _activeRequest!.close();
    final isPartial = response.statusCode == HttpStatus.partialContent;

    return DownloadStreamResponse(
      stream: response,
      statusCode: response.statusCode,
      contentLength: response.contentLength,
      isPartial: isPartial,
    );
  }

  @override
  void abort() {
    _activeRequest?.abort();
    _activeRequest = null;
    _client?.close(force: true);
    _client = null;
  }

  @override
  void close() {
    _client?.close(force: false);
    _client = null;
  }
}

/// Manages the download, cryptographic verification, disk storage, and RAM lifecycle
/// of on-device AI model weights for offline voice journaling.
class ModelManagementService extends ChangeNotifier {
  static ModelManagementService? _instance;
  static ModelManagementService get instance =>
      _instance ??= ModelManagementService();

  @visibleForTesting
  static void setMockInstance(ModelManagementService service) {
    _instance = service;
  }

  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  final AiModelPackManifest manifest;
  final Directory? _overrideBaseDirectory;
  NetworkConnectivityChecker connectivityChecker;
  ModelDownloadClient? downloadClient;

  ModelPackStatus _status = ModelPackStatus.notInstalled;
  ModelMemoryState _memoryState = ModelMemoryState.unloaded;
  String? _errorMessage;
  String _statusDetail = '';

  int _bytesDownloaded = 0;
  int _totalBytes = 0;
  double _progress = 0.0;
  bool _isCancelled = false;
  ModelDownloadClient? _activeClient;

  final List<Future<void> Function()> _onLoadHooks = [];
  final List<Future<void> Function()> _onUnloadHooks = [];

  final DatabaseHelper? _dbHelper;

  ModelManagementService({
    this.manifest = AiModelPackManifest.defaultPack,
    Directory? baseDirectory,
    this.connectivityChecker = const PlatformNetworkConnectivityChecker(),
    this.downloadClient,
    DatabaseHelper? databaseHelper,
  })  : _overrideBaseDirectory = baseDirectory,
        _dbHelper = databaseHelper;

  // --- GETTERS ---

  ModelPackStatus get status => _status;
  ModelMemoryState get memoryState => _memoryState;
  bool get isModelLoadedInMemory => _memoryState == ModelMemoryState.loaded;
  String? get errorMessage => _errorMessage;
  String get statusDetail => _statusDetail;
  int get bytesDownloaded => _bytesDownloaded;
  int get totalBytes => _totalBytes;
  double get progress => _progress;
  bool get isDownloading => _status == ModelPackStatus.downloading;
  bool get isInstalled => _status == ModelPackStatus.installed;

  AiModelPackManifest get effectiveManifest =>
      manifest.packId == AiModelPackManifest.defaultPack.packId
          ? AiModelPackManifest.defaultPack
          : manifest;

  /// Checks current network connectivity type.
  Future<NetworkType> checkNetworkType() =>
      connectivityChecker.checkConnectivity();

  /// Returns the base directory where voice models are cached.
  Future<Directory> getModelDirectory() async {
    if (_overrideBaseDirectory != null) {
      if (!await _overrideBaseDirectory.exists()) {
        await _overrideBaseDirectory.create(recursive: true);
      }
      return _overrideBaseDirectory;
    }

    final docDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory(p.join(docDir.path, 'models', 'voice'));
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  /// Calculates total disk space in bytes occupied by installed models in the pack directory.
  Future<int> getModelsDiskUsage() async {
    try {
      final dir = await getModelDirectory();
      if (!await dir.exists()) return 0;

      int total = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Checks if all model files in the manifest are present and valid on disk.
  Future<ModelPackStatus> checkInstalledStatus({bool verifyChecksums = false}) async {
    try {
      final dir = await getModelDirectory();
      if (!await dir.exists()) {
        _status = ModelPackStatus.notInstalled;
        _statusDetail = '';
        notifyListeners();
        return _status;
      }

      for (final fileDef in effectiveManifest.files) {
        final targetPath = p.join(dir.path, fileDef.relativeFilePath);
        final file = File(targetPath);
        if (!await file.exists()) {
          _status = ModelPackStatus.notInstalled;
          _statusDetail = '';
          notifyListeners();
          return _status;
        }

        if (verifyChecksums) {
          final computedHash = await calculateFileSha256(file);
          if (computedHash.toLowerCase() != fileDef.expectedSha256.toLowerCase()) {
            _status = ModelPackStatus.notInstalled;
            _errorMessage = 'Checksum verification failed for ${fileDef.filename}';
            notifyListeners();
            return _status;
          }
        }
      }

      _status = ModelPackStatus.installed;
      _progress = 1.0;
      _statusDetail = 'All models installed and ready';
      _errorMessage = null;
      notifyListeners();
      return _status;
    } catch (e) {
      _status = ModelPackStatus.error;
      _errorMessage = 'Failed to check installed models: $e';
      notifyListeners();
      return _status;
    }
  }

  /// Checks whether the model pack is fully installed on disk.
  Future<bool> isModelPackInstalled({bool verifyChecksums = false}) async {
    final status = await checkInstalledStatus(verifyChecksums: verifyChecksums);
    return status == ModelPackStatus.installed;
  }

  /// Calculates the SHA-256 digest of a local file via streaming to avoid memory overhead.
  Future<String> calculateFileSha256(File file) async {
    final stream = file.openRead();
    final digest = await sha256.bind(stream).first;
    return digest.toString();
  }

  /// Downloads the AI Model Pack with resume capability, Wi-Fi checks, and SHA-256 verification.
  ///
  /// Returns `true` on successful download & verification.
  /// Returns `false` if blocked by cellular gate or cancelled.
  Future<bool> downloadModelPack({
    bool allowCellular = false,
    DatabaseHelper? dbHelper,
  }) async {
    if (_status == ModelPackStatus.downloading) {
      return false;
    }

    _isCancelled = false;
    _errorMessage = null;

    // 1. Connectivity & Wi-Fi Check (US 14)
    final currentNetwork = await connectivityChecker.checkConnectivity();

    if (currentNetwork == NetworkType.none) {
      _errorMessage = 'No network connection available.';
      _statusDetail = 'Offline';
      notifyListeners();
      return false;
    }

    if (!allowCellular && currentNetwork == NetworkType.cellular) {
      final db = dbHelper ?? _dbHelper ?? DatabaseHelper.instance;
      final wifiOnly = await db.getVoiceModelsWifiOnly();
      if (wifiOnly) {
        _errorMessage = 'Cellular connection detected. Download requires Wi-Fi.';
        _statusDetail = 'Blocked by Wi-Fi only policy';
        notifyListeners();
        return false;
      }
    }

    _status = ModelPackStatus.downloading;
    _totalBytes = effectiveManifest.totalSizeBytes;
    _bytesDownloaded = 0;
    _progress = 0.0;
    _statusDetail = 'Starting download...';
    notifyListeners();

    final dir = await getModelDirectory();

    try {
      for (int i = 0; i < effectiveManifest.files.length; i++) {
        if (_isCancelled) {
          _cleanCancelState();
          return false;
        }

        final fileDef = effectiveManifest.files[i];
        final targetPath = p.join(dir.path, fileDef.relativeFilePath);
        final partPath = '$targetPath.part';
        final targetFile = File(targetPath);
        final partFile = File(partPath);

        // Ensure parent subdirectory exists
        final parentDir = targetFile.parent;
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }

        // Check if already completed and verified
        if (await targetFile.exists()) {
          final len = await targetFile.length();
          if (len == fileDef.expectedSizeBytes) {
            _bytesDownloaded += len;
            _progress = (_bytesDownloaded / _totalBytes).clamp(0.0, 1.0);
            notifyListeners();
            continue;
          }
        }

        // Check existing .part file length for HTTP resume
        int existingBytes = 0;
        if (await partFile.exists()) {
          existingBytes = await partFile.length();
          if (existingBytes > fileDef.expectedSizeBytes) {
            await partFile.delete();
            existingBytes = 0;
          }
        }

        _statusDetail = 'Downloading ${fileDef.filename} (${i + 1}/${effectiveManifest.files.length})...';
        notifyListeners();

        final client = downloadClient ?? DefaultModelDownloadClient();
        _activeClient = client;

        final response = await client.openStream(
          Uri.parse(fileDef.downloadUrl),
          startByte: existingBytes,
        );

        if (response.statusCode != HttpStatus.ok &&
            response.statusCode != HttpStatus.partialContent) {
          throw HttpException(
            'Failed to download ${fileDef.filename}: HTTP ${response.statusCode}',
          );
        }

        final sink = partFile.openWrite(
          mode: response.isPartial ? FileMode.append : FileMode.write,
        );

        try {
          await for (final chunk in response.stream) {
            if (_isCancelled) {
              await sink.flush();
              await sink.close();
              _cleanCancelState();
              return false;
            }

            sink.add(chunk);
            _bytesDownloaded += chunk.length;
            _progress = (_bytesDownloaded / _totalBytes).clamp(0.0, 1.0);
            notifyListeners();
          }
          await sink.flush();
        } finally {
          await sink.close();
        }

        if (_isCancelled) {
          _cleanCancelState();
          return false;
        }

        // 2. Cryptographic SHA-256 Checksum Verification (US 15)
        _status = ModelPackStatus.verifying;
        _statusDetail = 'Verifying integrity of ${fileDef.filename}...';
        notifyListeners();

        final actualSha256 = await calculateFileSha256(partFile);
        if (actualSha256.toLowerCase() != fileDef.expectedSha256.toLowerCase()) {
          if (await partFile.exists()) {
            await partFile.delete();
          }
          throw StateError(
            'Cryptographic SHA-256 integrity check failed for ${fileDef.filename}. '
            'Expected: ${fileDef.expectedSha256}, Actual: $actualSha256',
          );
        }

        // Commit verified .part file to final model target
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await partFile.rename(targetPath);

        _status = ModelPackStatus.downloading;
      }

      _status = ModelPackStatus.installed;
      _progress = 1.0;
      _statusDetail = 'Installed and verified';
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      if (_isCancelled) {
        _cleanCancelState();
        return false;
      }
      _status = ModelPackStatus.error;
      _errorMessage = e.toString();
      _statusDetail = 'Download error';
      notifyListeners();
      return false;
    } finally {
      _activeClient?.close();
      _activeClient = null;
    }
  }

  /// Cancels an in-flight download operation.
  void cancelDownload() {
    if (_status == ModelPackStatus.downloading ||
        _status == ModelPackStatus.verifying) {
      _isCancelled = true;
      _activeClient?.abort();
      _activeClient = null;
      _cleanCancelState();
    }
  }

  void _cleanCancelState() {
    _status = ModelPackStatus.notInstalled;
    _statusDetail = 'Download cancelled';
    _progress = 0.0;
    _bytesDownloaded = 0;
    notifyListeners();
  }

  /// Purges all downloaded model files and temporary .part files from local storage.
  Future<void> deleteModels() async {
    if (isModelLoadedInMemory) {
      await unloadModelsFromMemory();
    }

    try {
      final dir = await getModelDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _status = ModelPackStatus.notInstalled;
      _statusDetail = '';
      _errorMessage = null;
      _progress = 0.0;
      _bytesDownloaded = 0;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete models: $e';
      notifyListeners();
    }
  }

  // --- MODEL MEMORY LIFECYCLE MANAGEMENT (US 16) ---

  /// Registers lifecycle hooks called when models are loaded or unloaded from RAM.
  void registerLifecycleHooks({
    Future<void> Function()? onLoad,
    Future<void> Function()? onUnload,
  }) {
    if (onLoad != null) _onLoadHooks.add(onLoad);
    if (onUnload != null) _onUnloadHooks.add(onUnload);
  }

  /// Loads AI model weights into RAM on-demand when opening voice modal.
  Future<void> loadModelsIntoMemory() async {
    if (_memoryState == ModelMemoryState.loaded) return;

    _memoryState = ModelMemoryState.loading;
    notifyListeners();

    try {
      // Execute any registered native isolate initialization hooks
      for (final hook in _onLoadHooks) {
        await hook();
      }
      _memoryState = ModelMemoryState.loaded;
    } catch (e) {
      _memoryState = ModelMemoryState.unloaded;
      _errorMessage = 'Failed to load models into memory: $e';
    } finally {
      notifyListeners();
    }
  }

  /// Immediately deallocates AI model weights and isolates on modal exit (US 16).
  Future<void> unloadModelsFromMemory() async {
    if (_memoryState == ModelMemoryState.unloaded) return;

    _memoryState = ModelMemoryState.unloading;
    notifyListeners();

    try {
      // Execute registered deallocation hooks (e.g. sherpa_onnx / llama_cpp shutdown)
      for (final hook in _onUnloadHooks) {
        await hook();
      }
    } catch (e) {
      _errorMessage = 'Failed to deallocate models from memory: $e';
    } finally {
      _memoryState = ModelMemoryState.unloaded;
      notifyListeners();
    }
  }
}
