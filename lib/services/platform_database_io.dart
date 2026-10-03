import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> configurePlatformDatabase() async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    if (databaseFactory != databaseFactoryFfi) {
      databaseFactory = databaseFactoryFfi;
    }
  }
}
