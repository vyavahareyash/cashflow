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

  static Future<bool> fileExists(String path) async => false;

  static Future<void> copyFile(String src, String dest) async {}

  static Future<void> deleteFile(String path) async {}

  static Future<void> writeBytes(
    String path,
    List<int> bytes, {
    bool flush = false,
  }) async {}

  static Future<void> renameFile(String oldPath, String newPath) async {}

  static void writeWalkthroughSnapshot(String dbPath, String json) {}

  static String? readWalkthroughSnapshot(String dbPath) => null;

  static void deleteWalkthroughSnapshot(String dbPath) {}
}
