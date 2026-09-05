import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> saveBackupBytes(String filename, List<int> bytes) async {
  final documentsDir = await getApplicationDocumentsDirectory();
  final file = File(join(documentsDir.path, filename));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<List<int>?> pickBackupBytes() async {
  final dynamic result = await FilePicker.pickFiles(
    type: FileType.any,
    withData: true,
  );
  if (result == null) return null;

  final files = result is List<PlatformFile>
      ? result
      : (result.files as List<PlatformFile>);
  if (files.isEmpty) return null;
  return files.single.readAsBytes();
}
