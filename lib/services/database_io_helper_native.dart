import 'dart:io';

import 'package:path/path.dart' as p;

class DatabaseIoHelper {
  static bool get isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  static String get systemTempPath => Directory.systemTemp.path;

  static Future<String?> copyFileToDirectory(
    String srcFilePath,
    String targetDir,
    String fileName,
  ) async {
    final file = File(srcFilePath);
    if (!await file.exists()) {
      throw Exception('Database file not found');
    }
    final dir = Directory(targetDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final backupPath = p.join(targetDir, fileName);
    final backupFile = await file.copy(backupPath);
    return backupFile.path;
  }

  static Future<bool> fileExists(String path) async {
    return await File(path).exists();
  }

  static Future<void> copyFile(String src, String dest) async {
    final file = File(src);
    if (await file.exists()) {
      await file.copy(dest);
    }
  }

  static Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> writeBytes(
    String path,
    List<int> bytes, {
    bool flush = false,
  }) async {
    await File(path).writeAsBytes(bytes, flush: flush);
  }

  static Future<void> renameFile(String oldPath, String newPath) async {
    await File(oldPath).rename(newPath);
  }

  static Future<List<int>> readBytes(String path) async {
    return await File(path).readAsBytes();
  }

  static void writeWalkthroughSnapshot(String dbPath, String json) {
    try {
      final file = File(p.join(dbPath, 'walkthrough_snapshot.json'));
      file.writeAsStringSync(json, flush: true);
    } catch (_) {}
  }

  static String? readWalkthroughSnapshot(String dbPath) {
    try {
      final file = File(p.join(dbPath, 'walkthrough_snapshot.json'));
      if (file.existsSync()) {
        return file.readAsStringSync();
      }
    } catch (_) {}
    return null;
  }

  static void deleteWalkthroughSnapshot(String dbPath) {
    try {
      final file = File(p.join(dbPath, 'walkthrough_snapshot.json'));
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }
}
