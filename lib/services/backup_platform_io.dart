import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> saveBackupBytes(
  String filename,
  List<int> bytes, {
  String? destinationDirectory,
  String? fullPath,
}) async {
  final safeName = basename(filename);
  String resolvedPath;
  if (fullPath != null && fullPath.isNotEmpty) {
    resolvedPath = fullPath;
  } else if (destinationDirectory != null && destinationDirectory.isNotEmpty) {
    resolvedPath = join(destinationDirectory, safeName);
  } else {
    String docsPath;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      docsPath = Directory.systemTemp.path;
    } else {
      try {
        final documentsDir = await getApplicationDocumentsDirectory();
        docsPath = documentsDir.path;
      } catch (_) {
        docsPath = Directory.systemTemp.path;
      }
    }
    resolvedPath = join(docsPath, safeName);
  }

  final file = File(resolvedPath);
  final parentDir = file.parent;
  if (!await parentDir.exists()) {
    await parentDir.create(recursive: true);
  }
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String?> pickBackupDirectory({String? initialDirectory}) async {
  return await FilePicker.getDirectoryPath(
    dialogTitle: 'Select Backup Directory',
    initialDirectory: initialDirectory,
  );
}

Future<List<int>?> pickBackupBytes() async {
  final dynamic result = await FilePicker.pickFiles(type: FileType.any);
  if (result == null) return null;

  final files = result is List<PlatformFile>
      ? result
      : (result.files as List<PlatformFile>);
  if (files.isEmpty) return null;

  final file = files.single;
  if (file.path != null) {
    return await File(file.path!).readAsBytes();
  }
  return await file.readAsBytes();
}
