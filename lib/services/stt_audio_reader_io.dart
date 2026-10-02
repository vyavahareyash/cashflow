import 'dart:io';
import 'dart:typed_data';

class SttAudioReader {
  static bool fileExists(String path) => File(path).existsSync();
  static int fileLength(String path) => File(path).lengthSync();
  static Uint8List readBytes(String path) => File(path).readAsBytesSync();
}
