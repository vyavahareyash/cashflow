import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cashflow/screens/backup_restore_screen.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/services/model_management_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  FakePathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;

  @override
  Future<String?> getTemporaryPath() async => tempDir.path;
}

class FakeNetworkConnectivityChecker implements NetworkConnectivityChecker {
  NetworkType currentNetwork;
  FakeNetworkConnectivityChecker(this.currentNetwork);

  @override
  Future<NetworkType> checkConnectivity() async => currentNetwork;
}

class FakeModelDownloadClient implements ModelDownloadClient {
  final Map<String, List<int>> fileData;
  final bool failChecksum;
  final bool simulateSlowDownload;
  final int failTimes;
  int callCount = 0;
  final Map<String, int> startBytesRequested = {};
  bool isAborted = false;
  bool isClosed = false;
  StreamController<List<int>>? _activeController;

  FakeModelDownloadClient({
    required this.fileData,
    this.failChecksum = false,
    this.simulateSlowDownload = false,
    this.failTimes = 0,
  });

  @override
  Future<DownloadStreamResponse> openStream(
    Uri uri, {
    int startByte = 0,
    Map<String, String>? headers,
  }) async {
    callCount++;
    if (callCount <= failTimes) {
      throw const SocketException('Connection reset by peer');
    }

    final filename = p.basename(uri.path);
    startBytesRequested[filename] = startByte;
    final rawData = fileData[filename] ?? [1, 2, 3, 4, 5];

    final effectiveData = failChecksum
        ? [9, 9, 9, 9, 9] // corrupted bytes
        : rawData;

    final slice = startByte < effectiveData.length
        ? effectiveData.sublist(startByte)
        : <int>[];

    final mid = slice.length ~/ 2;
    final chunk1 = slice.sublist(0, mid);
    final chunk2 = slice.sublist(mid);

    final controller = StreamController<List<int>>();
    _activeController = controller;

    if (simulateSlowDownload) {
      if (chunk1.isNotEmpty) controller.add(chunk1);
    } else {
      if (chunk1.isNotEmpty) controller.add(chunk1);
      if (chunk2.isNotEmpty) controller.add(chunk2);
      unawaited(controller.close());
    }

    return DownloadStreamResponse(
      stream: controller.stream,
      statusCode: startByte > 0 ? HttpStatus.partialContent : HttpStatus.ok,
      contentLength: slice.length,
      isPartial: startByte > 0,
    );
  }

  @override
  Future<void> abort() async {
    isAborted = true;
    unawaited(_activeController?.close());
  }

  @override
  Future<void> close() async {
    isClosed = true;
    unawaited(_activeController?.close());
  }
}

class MockModelManagementService extends ModelManagementService {
  bool downloadCalled = false;
  bool lastAllowCellular = false;
  bool deleteCalled = false;
  ModelPackStatus _mockStatus;
  int _mockDiskUsage;

  MockModelManagementService({
    super.manifest,
    super.connectivityChecker,
    ModelPackStatus initialStatus = ModelPackStatus.notInstalled,
    int initialDiskUsage = 0,
  }) : _mockStatus = initialStatus,
       _mockDiskUsage = initialDiskUsage;

  @override
  ModelPackStatus get status => _mockStatus;

  @override
  bool get isInstalled => _mockStatus == ModelPackStatus.installed;

  @override
  Future<ModelPackStatus> checkInstalledStatus({
    bool verifyChecksums = false,
  }) async {
    return _mockStatus;
  }

  @override
  Future<int> getModelsDiskUsage() async => _mockDiskUsage;

  @override
  Future<bool> downloadModelPack({
    bool allowCellular = false,
    DatabaseHelper? dbHelper,
  }) async {
    downloadCalled = true;
    lastAllowCellular = allowCellular;
    _mockStatus = ModelPackStatus.installed;
    _mockDiskUsage = 260 * 1024 * 1024;
    notifyListeners();
    return true;
  }

  @override
  Future<void> deleteModels() async {
    deleteCalled = true;
    _mockStatus = ModelPackStatus.notInstalled;
    _mockDiskUsage = 0;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.setTestDatabaseName(inMemoryDatabasePath);
  const databaseFileName = 'money_tracker.db';

  late Directory tempDir;
  late AiModelPackManifest testManifest;
  late Map<String, List<int>> sampleBytes;
  late String encoderSha;
  late String decoderSha;

  setUp(() async {
    ModelManagementService.resetInstance();
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(p.join(dbPath, databaseFileName));

    tempDir = await Directory.systemTemp.createTemp('cashflow_model_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);

    final encBytes = utf8.encode('moonshine_encoder_mock_weights');
    final decBytes = utf8.encode('moonshine_decoder_mock_weights');
    encoderSha = sha256.convert(encBytes).toString();
    decoderSha = sha256.convert(decBytes).toString();

    sampleBytes = {
      'encoder.int8.onnx': encBytes,
      'decoder.int8.onnx': decBytes,
    };

    testManifest = AiModelPackManifest(
      packId: 'test_pack',
      name: 'Test Voice Model Pack',
      version: '1.0.0',
      files: [
        AiModelFile(
          id: 'test_encoder',
          filename: 'encoder.int8.onnx',
          relativeSubpath: 'moonshine',
          downloadUrl: 'https://example.com/models/encoder.int8.onnx',
          expectedSha256: encoderSha,
          expectedSizeBytes: encBytes.length,
          description: 'Encoder',
        ),
        AiModelFile(
          id: 'test_decoder',
          filename: 'decoder.int8.onnx',
          relativeSubpath: 'moonshine',
          downloadUrl: 'https://example.com/models/decoder.int8.onnx',
          expectedSha256: decoderSha,
          expectedSizeBytes: decBytes.length,
          description: 'Decoder',
        ),
      ],
    );
  });

  tearDown(() async {
    ModelManagementService.resetInstance();
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(p.join(dbPath, databaseFileName));
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('DatabaseHelper Voice Wi-Fi Preference', () {
    test('defaults to true and persists changes', () async {
      final db = DatabaseHelper.instance;
      expect(await db.getVoiceModelsWifiOnly(), isTrue);

      await db.setVoiceModelsWifiOnly(false);
      expect(await db.getVoiceModelsWifiOnly(), isFalse);

      await db.setVoiceModelsWifiOnly(true);
      expect(await db.getVoiceModelsWifiOnly(), isTrue);
    });
  });

  group('ModelManagementService Core & Download Lifecycle', () {
    test('initial state is not installed with 0 disk usage', () async {
      final service = ModelManagementService(
        manifest: testManifest,
        baseDirectory: Directory(p.join(tempDir.path, 'models', 'voice')),
      );

      expect(service.status, ModelPackStatus.notInstalled);
      expect(service.isInstalled, isFalse);
      expect(service.isDownloading, isFalse);
      expect(await service.getModelsDiskUsage(), 0);
    });

    test(
      'successful download verifies SHA-256 and installs model pack',
      () async {
        final fakeClient = FakeModelDownloadClient(fileData: sampleBytes);
        final fakeChecker = FakeNetworkConnectivityChecker(NetworkType.wifi);

        final service = ModelManagementService(
          manifest: testManifest,
          baseDirectory: Directory(p.join(tempDir.path, 'models', 'voice')),
          connectivityChecker: fakeChecker,
          downloadClient: fakeClient,
        );

        final statusHistory = <ModelPackStatus>[];
        service.addListener(() => statusHistory.add(service.status));

        final success = await service.downloadModelPack();
        expect(success, isTrue);
        expect(service.isInstalled, isTrue);
        expect(service.progress, 1.0);
        expect(service.errorMessage, isNull);

        // Verify files exist in directory
        final modelDir = await service.getModelDirectory();
        final encFile = File(
          p.join(modelDir.path, 'moonshine', 'encoder.int8.onnx'),
        );
        final decFile = File(
          p.join(modelDir.path, 'moonshine', 'decoder.int8.onnx'),
        );
        expect(await encFile.exists(), isTrue);
        expect(await decFile.exists(), isTrue);

        // Verify disk usage
        final usage = await service.getModelsDiskUsage();
        expect(usage, testManifest.totalSizeBytes);

        // Status check should report installed
        final check = await service.checkInstalledStatus(verifyChecksums: true);
        expect(check, ModelPackStatus.installed);
      },
    );

    test(
      'corrupted download triggers SHA-256 error and purges file (US 15)',
      () async {
        final fakeClient = FakeModelDownloadClient(
          fileData: sampleBytes,
          failChecksum: true,
        );
        final fakeChecker = FakeNetworkConnectivityChecker(NetworkType.wifi);

        final service = ModelManagementService(
          manifest: testManifest,
          baseDirectory: Directory(p.join(tempDir.path, 'models', 'voice')),
          connectivityChecker: fakeChecker,
          downloadClient: fakeClient,
        );

        final success = await service.downloadModelPack();
        expect(success, isFalse);
        expect(service.status, ModelPackStatus.error);
        expect(
          service.errorMessage,
          contains('SHA-256 integrity check failed'),
        );

        // Ensure partial/corrupted file was removed
        final modelDir = await service.getModelDirectory();
        final partFile = File(
          p.join(modelDir.path, 'moonshine', 'encoder.int8.onnx.part'),
        );
        final targetFile = File(
          p.join(modelDir.path, 'moonshine', 'encoder.int8.onnx'),
        );
        expect(await partFile.exists(), isFalse);
        expect(await targetFile.exists(), isFalse);
      },
    );

    test(
      'resumes download using HTTP range header when partial file exists',
      () async {
        final modelDir = Directory(p.join(tempDir.path, 'models', 'voice'));
        await modelDir.create(recursive: true);

        final encPart = File(
          p.join(modelDir.path, 'moonshine', 'encoder.int8.onnx.part'),
        );
        await encPart.parent.create(recursive: true);
        // Pre-write half the bytes for encoder
        final fullBytes = sampleBytes['encoder.int8.onnx']!;
        final halfLength = fullBytes.length ~/ 2;
        await encPart.writeAsBytes(fullBytes.sublist(0, halfLength));

        final fakeClient = FakeModelDownloadClient(fileData: sampleBytes);
        final service = ModelManagementService(
          manifest: testManifest,
          baseDirectory: modelDir,
          connectivityChecker: FakeNetworkConnectivityChecker(NetworkType.wifi),
          downloadClient: fakeClient,
        );

        final success = await service.downloadModelPack();
        expect(success, isTrue);
        expect(fakeClient.startBytesRequested['encoder.int8.onnx'], halfLength);
        expect(fakeClient.startBytesRequested['decoder.int8.onnx'], 0);
      },
    );

    test('cancelling download aborts stream and resets status', () async {
      final fakeClient = FakeModelDownloadClient(
        fileData: sampleBytes,
        simulateSlowDownload: true,
      );
      final service = ModelManagementService(
        manifest: testManifest,
        baseDirectory: Directory(p.join(tempDir.path, 'models', 'voice')),
        connectivityChecker: FakeNetworkConnectivityChecker(NetworkType.wifi),
        downloadClient: fakeClient,
      );

      // Start download
      final future = service.downloadModelPack();
      // Wait for download to start and transition to downloading status
      await Future<void>.delayed(const Duration(milliseconds: 10));
      service.cancelDownload();
      final success = await future;

      expect(success, isFalse);
      expect(service.status, ModelPackStatus.notInstalled);
    });

    test('checkInstalledStatus and isModelPackInstalled do not reset status while downloading', () async {
      final fakeClient = FakeModelDownloadClient(
        fileData: sampleBytes,
        simulateSlowDownload: true,
      );
      final service = ModelManagementService(
        manifest: testManifest,
        baseDirectory: Directory(p.join(tempDir.path, 'models', 'voice')),
        connectivityChecker: FakeNetworkConnectivityChecker(NetworkType.wifi),
        downloadClient: fakeClient,
      );

      final future = service.downloadModelPack();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.status, ModelPackStatus.downloading);

      // Calling checkInstalledStatus while downloading must retain downloading status
      final status = await service.checkInstalledStatus();
      expect(status, ModelPackStatus.downloading);
      expect(service.status, ModelPackStatus.downloading);

      // Calling isModelPackInstalled while downloading returns false without clobbering
      final installed = await service.isModelPackInstalled();
      expect(installed, isFalse);
      expect(service.status, ModelPackStatus.downloading);

      service.cancelDownload();
      await future;
    });

    test(
      'concurrent downloadModelPack calls share the active download future',
      () async {
        final fakeClient = FakeModelDownloadClient(
          fileData: sampleBytes,
          simulateSlowDownload: true,
        );
        final service = ModelManagementService(
          manifest: testManifest,
          baseDirectory: Directory(p.join(tempDir.path, 'models', 'voice')),
          connectivityChecker: FakeNetworkConnectivityChecker(NetworkType.wifi),
          downloadClient: fakeClient,
        );

        final f1 = service.downloadModelPack();
        final f2 = service.downloadModelPack();

        expect(identical(f1, f2), isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 10));
        service.cancelDownload();
        await f1;
      },
    );

    test(
      'transient network drop triggers retry and successfully completes',
      () async {
        final fakeClient = FakeModelDownloadClient(
          fileData: sampleBytes,
          failTimes: 1, // fails once with SocketException then succeeds
        );
        final service = ModelManagementService(
          manifest: testManifest,
          baseDirectory: Directory(p.join(tempDir.path, 'models', 'voice')),
          connectivityChecker: FakeNetworkConnectivityChecker(NetworkType.wifi),
          downloadClient: fakeClient,
        );

        final success = await service.downloadModelPack();
        expect(success, isTrue);
        expect(service.isInstalled, isTrue);
        expect(fakeClient.callCount, greaterThan(1));
      },
    );

    test(
      'app lifecycle transitions track background state and resume cleanly',
      () async {
        final service = ModelManagementService(
          manifest: testManifest,
          baseDirectory: Directory(p.join(tempDir.path, 'models', 'voice')),
        );

        service.didChangeAppLifecycleState(AppLifecycleState.paused);
        service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      },
    );
  });

  group('Wi-Fi and Cellular Gating (US 14)', () {
    test('blocks download on cellular when wifiOnly is true', () async {
      final db = DatabaseHelper.instance;
      await db.setVoiceModelsWifiOnly(true);

      final fakeChecker = FakeNetworkConnectivityChecker(NetworkType.cellular);
      final service = ModelManagementService(
        manifest: testManifest,
        baseDirectory: Directory(p.join(tempDir.path, 'models', 'voice')),
        connectivityChecker: fakeChecker,
      );

      final success = await service.downloadModelPack(allowCellular: false);
      expect(success, isFalse);
      expect(service.errorMessage, contains('Cellular connection detected'));
    });

    test(
      'proceeds on cellular when allowCellular is explicitly true',
      () async {
        final db = DatabaseHelper.instance;
        await db.setVoiceModelsWifiOnly(true);

        final fakeClient = FakeModelDownloadClient(fileData: sampleBytes);
        final fakeChecker = FakeNetworkConnectivityChecker(
          NetworkType.cellular,
        );
        final service = ModelManagementService(
          manifest: testManifest,
          baseDirectory: Directory(p.join(tempDir.path, 'models', 'voice')),
          connectivityChecker: fakeChecker,
          downloadClient: fakeClient,
        );

        final success = await service.downloadModelPack(allowCellular: true);
        expect(success, isTrue);
        expect(service.isInstalled, isTrue);
      },
    );

    test('fails immediately when device is offline', () async {
      final fakeChecker = FakeNetworkConnectivityChecker(NetworkType.none);
      final service = ModelManagementService(
        manifest: testManifest,
        baseDirectory: Directory(p.join(tempDir.path, 'models', 'voice')),
        connectivityChecker: fakeChecker,
      );

      final success = await service.downloadModelPack();
      expect(success, isFalse);
      expect(service.errorMessage, contains('No network connection available'));
    });
  });

  group('Storage Deletion & Reclamation', () {
    test('deleteModels purges all files and resets disk usage to 0', () async {
      final fakeClient = FakeModelDownloadClient(fileData: sampleBytes);
      final service = ModelManagementService(
        manifest: testManifest,
        baseDirectory: Directory(p.join(tempDir.path, 'models', 'voice')),
        connectivityChecker: FakeNetworkConnectivityChecker(NetworkType.wifi),
        downloadClient: fakeClient,
      );

      await service.downloadModelPack();
      expect(await service.getModelsDiskUsage(), greaterThan(0));
      expect(service.isInstalled, isTrue);

      await service.deleteModels();
      expect(await service.getModelsDiskUsage(), 0);
      expect(service.status, ModelPackStatus.notInstalled);
      expect(service.isInstalled, isFalse);
    });
  });

  group('Model Memory Lifecycle Management (US 16)', () {
    test('load and unload trigger registered hooks and manage state', () async {
      final service = ModelManagementService(
        manifest: testManifest,
        baseDirectory: Directory(p.join(tempDir.path, 'models', 'voice')),
      );

      bool loadHookCalled = false;
      bool unloadHookCalled = false;

      service.registerLifecycleHooks(
        onLoad: () async => loadHookCalled = true,
        onUnload: () async => unloadHookCalled = true,
      );

      expect(service.isModelLoadedInMemory, isFalse);
      expect(service.memoryState, ModelMemoryState.unloaded);

      await service.loadModelsIntoMemory();
      expect(service.isModelLoadedInMemory, isTrue);
      expect(service.memoryState, ModelMemoryState.loaded);
      expect(loadHookCalled, isTrue);

      await service.unloadModelsFromMemory();
      expect(service.isModelLoadedInMemory, isFalse);
      expect(service.memoryState, ModelMemoryState.unloaded);
      expect(unloadHookCalled, isTrue);
    });
  });

  group('BackupRestoreScreen Voice AI Model Pack UI', () {
    testWidgets('renders Voice AI Model Pack card with Not Installed status', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockModelManagementService(
        manifest: testManifest,
        connectivityChecker: FakeNetworkConnectivityChecker(NetworkType.wifi),
        initialStatus: ModelPackStatus.notInstalled,
      );
      ModelManagementService.setMockInstance(service);

      await tester.pumpWidget(const MaterialApp(home: BackupRestoreScreen()));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const Key('voice_model_card'));
      await tester.ensureVisible(cardFinder);

      expect(cardFinder, findsOneWidget);
      expect(find.byKey(const Key('voice_model_status_badge')), findsOneWidget);
      expect(find.text('Not Installed'), findsOneWidget);
      expect(
        find.byKey(const Key('voice_model_download_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('voice_models_wifi_only_switch')),
        findsOneWidget,
      );
    });

    testWidgets('triggers cellular warning gate dialog when on cellular', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockModelManagementService(
        manifest: testManifest,
        connectivityChecker: FakeNetworkConnectivityChecker(
          NetworkType.cellular,
        ),
      );
      ModelManagementService.setMockInstance(service);

      await tester.pumpWidget(const MaterialApp(home: BackupRestoreScreen()));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      final downloadBtn = find.byKey(const Key('voice_model_download_button'));
      await tester.ensureVisible(downloadBtn);
      await tester.tap(downloadBtn);
      await tester.pumpAndSettle();

      // Verify Cellular Warning Dialog shows
      expect(find.byKey(const Key('cellular_warning_dialog')), findsOneWidget);
      expect(find.text('Cellular Data Warning'), findsOneWidget);

      // Cancel button dismisses
      await tester.tap(find.byKey(const Key('cellular_warning_cancel_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cellular_warning_dialog')), findsNothing);
      expect(service.downloadCalled, isFalse);

      // Tap again and proceed
      await tester.tap(downloadBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cellular_warning_dialog')), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('cellular_warning_proceed_button')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cellular_warning_dialog')), findsNothing);
      expect(service.downloadCalled, isTrue);
      expect(service.lastAllowCellular, isTrue);
      expect(service.isInstalled, isTrue);
      expect(find.text('Installed & Ready'), findsOneWidget);
      expect(
        find.byKey(const Key('voice_model_delete_button')),
        findsOneWidget,
      );
    });

    testWidgets(
      'delete models button triggers confirmation and deletes files',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final service = MockModelManagementService(
          manifest: testManifest,
          connectivityChecker: FakeNetworkConnectivityChecker(NetworkType.wifi),
          initialStatus: ModelPackStatus.installed,
          initialDiskUsage: 260 * 1024 * 1024,
        );
        ModelManagementService.setMockInstance(service);

        await tester.pumpWidget(const MaterialApp(home: BackupRestoreScreen()));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pumpAndSettle();

        final cardFinder = find.byKey(const Key('voice_model_card'));
        await tester.ensureVisible(cardFinder);

        expect(find.text('Installed & Ready'), findsOneWidget);
        final deleteBtn = find.byKey(const Key('voice_model_delete_button'));
        expect(deleteBtn, findsOneWidget);

        await tester.ensureVisible(deleteBtn);
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // Verify dialog
        expect(find.byKey(const Key('delete_models_dialog')), findsOneWidget);

        await tester.tap(find.byKey(const Key('delete_models_confirm_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('delete_models_dialog')), findsNothing);
        expect(service.deleteCalled, isTrue);
        expect(service.isInstalled, isFalse);
        expect(find.text('Not Installed'), findsOneWidget);
      },
    );
  });
}
