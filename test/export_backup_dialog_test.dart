import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashflow/components/export_backup_dialog.dart';

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

    testWidgets('prompts confirmation when exporting to an existing file', (
      tester,
    ) async {
      // Create existing file in tempDir
      final existingFile = File('${tempDir.path}/existing_backup.db');
      await existingFile.writeAsString('test');

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

      // Enter the existing filename
      final inputFinder = find.byKey(const Key('export_filename_input'));
      await tester.enterText(inputFinder, 'existing_backup.db');
      await tester.pumpAndSettle();

      // Tap Confirm
      final confirmBtn = find.byKey(const Key('export_confirm_button'));
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Overwrite confirmation dialog should be shown
      expect(find.text('Replace Existing File?'), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel -> stays on dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Replace Existing File?'), findsNothing);
      expect(find.byType(ExportBackupDialog), findsOneWidget);
    });
  });
}
