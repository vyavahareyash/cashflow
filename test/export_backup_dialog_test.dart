import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashflow/components/export_backup_dialog.dart';
import 'package:cashflow/services/backup_platform_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cashflow_export_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ExportBackupDialog Timestamp & Overwrite Tests', () {
    testWidgets('default filename contains timestamp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportBackupDialog(
              isDark: false,
              defaultDirectory: tempDir.path,
              initialDirectory: tempDir.path,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inputFinder = find.byKey(const Key('export_filename_input'));
      expect(inputFinder, findsOneWidget);

      final textField = tester.widget<TextField>(inputFinder);
      final text = textField.controller!.text;

      // Matches cashflow_backup_YYYYMMDD_HHMMSS.db
      expect(
        RegExp(r'^cashflow_backup_\d{8}_\d{6}\.db$').hasMatch(text),
        isTrue,
      );
    });

    test(
      'backupFileExists returns true for existing file and false otherwise',
      () async {
        final existingFile = File('${tempDir.path}/existing_backup.db');
        await existingFile.writeAsString('test');

        expect(
          backupFileExists(
            'existing_backup.db',
            destinationDirectory: tempDir.path,
          ),
          isTrue,
        );
        expect(
          backupFileExists(
            'non_existing_backup.db',
            destinationDirectory: tempDir.path,
          ),
          isFalse,
        );
      },
    );
  });
}
