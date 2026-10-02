import 'dart:async';

import 'package:flutter/widgets.dart';

import 'database_helper.dart';
import 'model_management_types.dart';

export 'model_management_types.dart';

class PlatformNetworkConnectivityChecker implements NetworkConnectivityChecker {
  const PlatformNetworkConnectivityChecker();

  @override
  Future<NetworkType> checkConnectivity() async => NetworkType.wifi;
}

class DefaultModelDownloadClient implements ModelDownloadClient {
  @override
  Future<DownloadStreamResponse> openStream(
    Uri uri, {
    int startByte = 0,
    Map<String, String>? headers,
  }) async {
    throw UnsupportedError('Model downloads are unsupported on web.');
  }

  @override
  void abort() {}

  @override
  void close() {}
}

class ModelManagementService extends ChangeNotifier
    with WidgetsBindingObserver {
  static ModelManagementService? _instance;
  static ModelManagementService get instance =>
      _instance ??= ModelManagementService();

  static void setMockInstance(ModelManagementService service) {
    _instance = service;
  }

  static void resetInstance() {
    _instance = null;
  }

  final NetworkConnectivityChecker connectivityChecker;
  final ModelDownloadClient downloadClient;

  ModelManagementService({
    dynamic baseDirectory,
    this.connectivityChecker = const PlatformNetworkConnectivityChecker(),
    ModelDownloadClient? downloadClient,
    DatabaseHelper? databaseHelper,
  }) : downloadClient = downloadClient ?? DefaultModelDownloadClient();

  ModelPackStatus get status => ModelPackStatus.installed;
  ModelMemoryState get memoryState => ModelMemoryState.loaded;
  bool get isModelLoadedInMemory => true;
  String? get errorMessage => null;
  String get statusDetail => 'Web speech engine ready (zero download)';
  int get bytesDownloaded => 0;
  int get totalBytes => 0;
  double get progress => 1.0;
  bool get isDownloading => false;
  bool get isInstalled => true;

  AiModelPackManifest get effectiveManifest => AiModelPackManifest.defaultPack;

  Future<NetworkType> checkNetworkType() =>
      connectivityChecker.checkConnectivity();

  Future<dynamic> getModelDirectory() async => null;

  Future<int> getModelsDiskUsage() async => 0;

  Future<ModelPackStatus> checkInstalledStatus({
    bool verifyChecksums = false,
  }) async => ModelPackStatus.installed;

  Future<bool> isModelPackInstalled({bool verifyChecksums = false}) async =>
      true;

  Future<bool> downloadModelPack({
    bool allowCellular = false,
    DatabaseHelper? dbHelper,
  }) async => true;

  void cancelDownload() {}

  Future<void> deleteModels() async {}

  void registerLifecycleHooks({
    Future<void> Function()? onLoad,
    Future<void> Function()? onUnload,
  }) {}

  Future<void> loadModelsIntoMemory() async {}

  Future<void> unloadModelsFromMemory() async {}
}
