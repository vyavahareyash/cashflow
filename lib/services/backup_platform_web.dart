import 'dart:async';
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:file_picker/file_picker.dart';

Future<String?> saveBackupBytes(
  String filename,
  List<int> bytes, {
  String? destinationDirectory,
  String? fullPath,
}) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return filename;
}

Future<String?> pickBackupDirectory({String? initialDirectory}) async {
  return null;
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
