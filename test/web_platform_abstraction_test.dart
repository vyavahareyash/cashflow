import 'dart:io';

import 'package:cashflow/services/database_io_helper.dart';
import 'package:cashflow/services/platform_security_service.dart';
import 'package:cashflow/services/slm_engine_provider.dart';
import 'package:cashflow/services/stt_audio_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformSecurityService Platform Behavior', () {
    test('canAuthenticate, authenticate, and setSecureFlag do not throw on current platform', () async {
      final service = PlatformSecurityService.instance;
      final canAuth = await service.canAuthenticate();
      expect(canAuth, isFalse);

      expect(() async => await service.setSecureFlag(true), returnsNormally);
      expect(() async => await service.setSecureFlag(false), returnsNormally);
    });

    test(
      'non-Android / Web target platforms safely bypass authentication',
      () async {
        final service = PlatformSecurityService.instance;
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        try {
          expect(await service.canAuthenticate(), isFalse);
          expect(await service.authenticate(), isTrue);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });

  group('DatabaseIoHelper Native IO Behavior', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('db_io_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('isFlutterTest is true in test environment', () {
      expect(DatabaseIoHelper.isFlutterTest, isTrue);
      expect(DatabaseIoHelper.systemTempPath, isNotEmpty);
    });

    test(
      'copyFileToDirectory copies files and creates target directories',
      () async {
        final srcFile = File(p.join(tempDir.path, 'source.db'));
        srcFile.writeAsStringSync('sample sqlite content');

        final targetDir = p.join(tempDir.path, 'backups', 'nested');
        final copiedPath = await DatabaseIoHelper.copyFileToDirectory(
          srcFile.path,
          targetDir,
          'dest.db',
        );

        expect(copiedPath, isNotNull);
        expect(File(copiedPath!).existsSync(), isTrue);
        expect(File(copiedPath).readAsStringSync(), 'sample sqlite content');
      },
    );

    test('file operations (copy, writeBytes, rename, delete, exists) work reliably', () async {
      final filePath = p.join(tempDir.path, 'data.bin');
      await DatabaseIoHelper.writeBytes(filePath, [1, 2, 3, 4], flush: true);
      expect(await DatabaseIoHelper.fileExists(filePath), isTrue);

      final renamedPath = p.join(tempDir.path, 'data_renamed.bin');
      await DatabaseIoHelper.renameFile(filePath, renamedPath);
      expect(await DatabaseIoHelper.fileExists(filePath), isFalse);
      expect(await DatabaseIoHelper.fileExists(renamedPath), isTrue);

      await DatabaseIoHelper.deleteFile(renamedPath);
      expect(await DatabaseIoHelper.fileExists(renamedPath), isFalse);
    });

    test(
      'walkthrough snapshot persistence writes, reads, and deletes safely',
      () {
        final dbPath = tempDir.path;
        DatabaseIoHelper.writeWalkthroughSnapshot(dbPath, '{"state": "demo"}');
        final read = DatabaseIoHelper.readWalkthroughSnapshot(dbPath);
        expect(read, '{"state": "demo"}');

        DatabaseIoHelper.deleteWalkthroughSnapshot(dbPath);
        expect(DatabaseIoHelper.readWalkthroughSnapshot(dbPath), isNull);
      },
    );
  });

  group('SttAudioReader Native IO Behavior', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('stt_reader_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('fileExists, fileLength, and readBytes read binary audio files', () {
      final audioPath = p.join(tempDir.path, 'test.wav');
      expect(SttAudioReader.fileExists(audioPath), isFalse);

      final sampleBytes = List<int>.generate(100, (i) => i % 256);
      File(audioPath).writeAsBytesSync(sampleBytes);

      expect(SttAudioReader.fileExists(audioPath), isTrue);
      expect(SttAudioReader.fileLength(audioPath), 100);
      expect(SttAudioReader.readBytes(audioPath), sampleBytes);
    });
  });

  group('SlmEngineProvider Native Factory', () {
    test('createDefaultSlmEngine returns LlamaCppSlmEngine instance on VM', () {
      final engine = createDefaultSlmEngine();
      expect(engine, isA<LlamaCppSlmEngine>());
      expect(engine.isInitialized, isFalse);
    });
  });

  group('Web Content Security Policy (index.html)', () {
    test('CSP allows Google Fonts in connect-src, font-src, and style-src for CanvasKit', () {
      final indexHtml = File('web/index.html').readAsStringSync();
      final cspMatch = RegExp(
        r'<meta\s+http-equiv="Content-Security-Policy"\s+content="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(indexHtml);
      expect(cspMatch, isNotNull);
      final csp = cspMatch!.group(1)!;

      // connect-src must allow fonts.gstatic.com for CanvasKit JS fetch()
      final connectSrcMatch = RegExp(r'connect-src\s+([^;]+);').firstMatch(csp);
      expect(connectSrcMatch, isNotNull);
      expect(connectSrcMatch!.group(1), contains('https://fonts.gstatic.com'));
      expect(
        connectSrcMatch.group(1),
        contains('https://fonts.googleapis.com'),
      );

      // font-src must allow fonts.gstatic.com
      final fontSrcMatch = RegExp(r'font-src\s+([^;]+);').firstMatch(csp);
      expect(fontSrcMatch, isNotNull);
      expect(fontSrcMatch!.group(1), contains('https://fonts.gstatic.com'));

      // style-src must allow fonts.googleapis.com
      final styleSrcMatch = RegExp(r'style-src\s+([^;]+);').firstMatch(csp);
      expect(styleSrcMatch, isNotNull);
      expect(styleSrcMatch!.group(1), contains('https://fonts.googleapis.com'));
    });
  });
}
