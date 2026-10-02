// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

class DatabaseIoHelper {
  static bool get isFlutterTest => false;

  static String get systemTempPath => '';

  static Future<String?> copyFileToDirectory(
    String srcFilePath,
    String targetDir,
    String fileName,
  ) async {
    return null;
  }

  static Future<bool> fileExists(String path) async {
    return await databaseFactory.databaseExists(path);
  }

  static Future<void> copyFile(String src, String dest) async {
    final exists = await databaseFactory.databaseExists(src);
    if (exists) {
      final bytes = await databaseFactory.readDatabaseBytes(src);
      await databaseFactory.writeDatabaseBytes(dest, bytes);
    }
  }

  static Future<void> deleteFile(String path) async {
    final exists = await databaseFactory.databaseExists(path);
    if (exists) {
      await databaseFactory.deleteDatabase(path);
    }
  }

  static Future<void> writeBytes(
    String path,
    List<int> bytes, {
    bool flush = false,
  }) async {
    final uint8List = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    await databaseFactory.writeDatabaseBytes(path, uint8List);
  }

  static Future<List<int>> readBytes(String path) async {
    return await databaseFactory.readDatabaseBytes(path);
  }

  static Future<void> renameFile(String oldPath, String newPath) async {
    final bytes = await databaseFactory.readDatabaseBytes(oldPath);
    await databaseFactory.writeDatabaseBytes(newPath, bytes);
    await databaseFactory.deleteDatabase(oldPath);
  }

  static const String _walkthroughSnapshotKey = 'cashflow_walkthrough_snapshot';

  static void writeWalkthroughSnapshot(String dbPath, String json) {
    try {
      html.window.localStorage[_walkthroughSnapshotKey] = json;
    } catch (_) {}
  }

  static String? readWalkthroughSnapshot(String dbPath) {
    try {
      return html.window.localStorage[_walkthroughSnapshotKey];
    } catch (_) {}
    return null;
  }

  static void deleteWalkthroughSnapshot(String dbPath) {
    try {
      html.window.localStorage.remove(_walkthroughSnapshotKey);
    } catch (_) {}
  }
}
