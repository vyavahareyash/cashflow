import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/screens/backup_restore_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;

  const databaseFileName = 'settings_hub_test.db';
  DatabaseHelper.setTestDatabaseName(databaseFileName);

  setUp(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
    await DatabaseHelper.instance.database;
  });

  tearDown(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
  });

  group('BackupRestoreScreen Settings Hub Redesign Tests', () {
    testWidgets(
      'renders 4 category cards and hero banner with support & about on main screen',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(const MaterialApp(home: BackupRestoreScreen()));
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 300));
        });
        await tester.pumpAndSettle();

        // Verify Header & Hero
        expect(find.text('Settings & Data'), findsOneWidget);
        expect(find.text('100% Local & Offline'), findsOneWidget);

        // Verify Section Headers
        expect(find.text('Preferences'), findsOneWidget);
        expect(find.text('Data & Automation'), findsOneWidget);

        // Verify 4 Category Cards
        expect(
          find.byKey(const Key('settings_category_privacy')),
          findsOneWidget,
        );
        expect(find.text('Privacy & Security'), findsOneWidget);

        expect(
          find.byKey(const Key('settings_category_cycle')),
          findsOneWidget,
        );
        expect(find.text('Financial Cycle & Storage'), findsOneWidget);

        expect(
          find.byKey(const Key('settings_category_data_backup')),
          findsOneWidget,
        );
        expect(find.text('Data, Sync & Backups'), findsOneWidget);

        expect(
          find.byKey(const Key('settings_category_voice_ai')),
          findsOneWidget,
        );
        expect(find.text('Voice AI & Offline Models'), findsOneWidget);

        // Verify Walkthrough and About/System directly on main settings screen
        expect(find.text('App Walkthrough & Concepts'), findsOneWidget);
        expect(find.text('System & About'), findsOneWidget);
        expect(find.text('Created by Yash Vyavahare'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Privacy & Security card navigates into sub-screen and back',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(const MaterialApp(home: BackupRestoreScreen()));
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 300));
        });
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('settings_category_privacy')));
        await tester.pumpAndSettle();

        // Now inside Privacy & Security sub-screen
        expect(
          find.byKey(const Key('start_in_privacy_mode_switch')),
          findsOneWidget,
        );
        expect(find.text('Start in Privacy Mode'), findsOneWidget);

        // Pop back
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('settings_category_privacy')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping Data, Sync & Backups card navigates into sub-screen and back',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(const MaterialApp(home: BackupRestoreScreen()));
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 300));
        });
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('settings_category_data_backup')),
        );
        await tester.pumpAndSettle();

        // Now inside Data, Sync & Backups sub-screen
        expect(find.text('Export Data & Backups'), findsOneWidget);
        expect(find.text('Import & Restore Data'), findsOneWidget);
        expect(find.text('Danger Zone'), findsOneWidget);

        // Pop back
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('settings_category_data_backup')),
          findsOneWidget,
        );
      },
    );
  });
}
