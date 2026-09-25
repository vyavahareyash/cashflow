import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/transaction_model.dart';
import 'package:cashflow/screens/backup_restore_screen.dart';
import 'package:cashflow/services/database_helper.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  FakePathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;

  @override
  Future<String?> getTemporaryPath() async => tempDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;

  const databaseFileName = 'custom_backup.db';
  DatabaseHelper.setTestDatabaseName(databaseFileName);

  late Directory tempDir;

  setUp(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
    tempDir = await Directory.systemTemp.createTemp('cashflow_backup_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
  });

  tearDown(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Custom Backup Path Configuration (Issue #59)', () {
    test(
      'persists, updates, and resets custom backup path in app_settings',
      () async {
        final db = DatabaseHelper.instance;

        // Initially null
        expect(await db.getCustomBackupPath(), isNull);

        final defaultDir = await db.getDefaultBackupDirectory();
        expect(await db.getEffectiveBackupDirectory(), defaultDir);

        // Set custom directory
        final customDir = join(tempDir.path, 'custom_backups');
        await db.setCustomBackupPath(customDir);

        expect(await db.getCustomBackupPath(), customDir);
        expect(await db.getEffectiveBackupDirectory(), customDir);

        // Reset to null
        await db.setCustomBackupPath(null);
        expect(await db.getCustomBackupPath(), isNull);
        expect(await db.getEffectiveBackupDirectory(), defaultDir);
      },
    );

    test(
      'exportDatabase copies database to custom directory with custom filename',
      () async {
        final db = DatabaseHelper.instance;
        await db.createAccount(
          Account(name: 'Checking', balance: 25000.0, type: 'Bank'),
        );

        final targetDir = join(tempDir.path, 'sqlite_custom_dir');
        const customFileName = 'my_custom_backup.db';

        final exportedPath = await db.exportDatabase(
          destinationDirectory: targetDir,
          fileName: customFileName,
        );

        expect(exportedPath, isNotNull);
        expect(exportedPath, join(targetDir, customFileName));

        final backupFile = File(exportedPath!);
        expect(await backupFile.exists(), isTrue);
        expect(await backupFile.length(), greaterThan(0));

        final lastBackup = await db.getLastBackupTimestamp();
        expect(lastBackup, isNotNull);
      },
    );

    test(
      'exportDatabaseAsJSON exports to custom directory and filename',
      () async {
        final db = DatabaseHelper.instance;
        final accId = await db.createAccount(
          Account(name: 'Wallet', balance: 500.0, type: 'Cash'),
        );
        final catId = await db.createCategory(
          Category(name: 'Snacks', monthlyBudget: 2000.0),
        );
        await db.insertTransaction(
          TransactionModel(
            accountId: accId,
            categoryId: catId,
            amount: 150.0,
            date: '2026-09-14',
            note: 'Coffee and cookie',
            type: 'expense',
          ),
        );

        final targetDir = join(tempDir.path, 'json_custom_dir');
        const customFileName = 'my_finances.json';

        final exportedPath = await db.exportDatabaseAsJSON(
          destinationDirectory: targetDir,
          fileName: customFileName,
        );

        expect(exportedPath, isNotNull);
        expect(exportedPath, join(targetDir, customFileName));

        final jsonFile = File(exportedPath!);
        expect(await jsonFile.exists(), isTrue);
        final content = await jsonFile.readAsString();
        expect(content, contains('Coffee and cookie'));
        expect(content, contains('Snacks'));
        expect(content, contains('Wallet'));
      },
    );

    test('exportTransactionsAsCSV exports transactions to custom directory and filename', () async {
      final db = DatabaseHelper.instance;
      final accId = await db.createAccount(
        Account(name: 'Card', balance: 10000.0, type: 'Card'),
      );
      final catId = await db.createCategory(
        Category(name: 'Transit', monthlyBudget: 3000.0),
      );
      await db.insertTransaction(
        TransactionModel(
          accountId: accId,
          categoryId: catId,
          amount: 75.0,
          date: '2026-09-14',
          note: 'Metro card topup',
          type: 'expense',
        ),
      );

      final targetDir = join(tempDir.path, 'csv_custom_dir');
      const customFileName = 'transit_export.csv';

      final exportedPath = await db.exportTransactionsAsCSV(
        destinationDirectory: targetDir,
        fileName: customFileName,
      );

      expect(exportedPath, isNotNull);
      expect(exportedPath, join(targetDir, customFileName));

      final csvFile = File(exportedPath!);
      expect(await csvFile.exists(), isTrue);
      final content = await csvFile.readAsString();
      expect(content, contains('Metro card topup'));
      expect(content, contains('75'));
    });
  });

  group(
    'BackupRestoreScreen Custom Location & Confirmation Flow (Issue #59)',
    () {
      testWidgets('renders high-level Export and Import tiles on main screen', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(const MaterialApp(home: BackupRestoreScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Export Data & Backups'), findsOneWidget);
        expect(find.text('Import & Restore Data'), findsOneWidget);
        expect(find.text('Backup Status'), findsOneWidget);
      });

      testWidgets(
        'shows format selection & destination confirmation dialog on export and cancels cleanly',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            const MaterialApp(home: BackupRestoreScreen()),
          );
          await tester.runAsync(() async {
            await Future.delayed(const Duration(milliseconds: 300));
          });
          await tester.pumpAndSettle();

          // Tap Export Data & Backups tile
          final exportTile = find.text('Export Data & Backups');
          await tester.ensureVisible(exportTile);
          await tester.tap(exportTile);
          await tester.runAsync(() async {
            await Future.delayed(const Duration(milliseconds: 300));
          });
          await tester.pumpAndSettle();

          // Verify export dialog is shown with format options and destination controls
          expect(find.text('Choose File Format'), findsOneWidget);
          expect(find.text('SQLite Database (.db)'), findsOneWidget);
          expect(find.text('JSON Backup (.json)'), findsOneWidget);
          expect(find.text('Transactions CSV (.csv)'), findsOneWidget);
          expect(find.text('Destination Directory'), findsOneWidget);
          expect(
            find.byKey(const Key('export_destination_directory_text')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('export_browse_directory_button')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('export_filename_input')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('export_full_path_preview')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('export_cancel_button')), findsOneWidget);
          expect(
            find.byKey(const Key('export_confirm_button')),
            findsOneWidget,
          );

          // Tap Cancel
          await tester.tap(find.byKey(const Key('export_cancel_button')));
          await tester.pumpAndSettle();

          // Verify dialog is closed and no export happened
          expect(find.byKey(const Key('export_cancel_button')), findsNothing);
          expect(find.text('Export cancelled or failed'), findsNothing);
        },
      );

      testWidgets(
        'shows export dialog, allows format selection and filename editing, and confirms export',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final db = DatabaseHelper.instance;
          await tester.runAsync(() async {
            await db.createAccount(
              Account(name: 'Primary', balance: 5000.0, type: 'Bank'),
            );
          });

          await tester.pumpWidget(
            const MaterialApp(home: BackupRestoreScreen()),
          );
          await tester.runAsync(() async {
            await Future.delayed(const Duration(milliseconds: 300));
          });
          await tester.pumpAndSettle();

          // Tap Export Data & Backups
          final exportTile = find.text('Export Data & Backups');
          await tester.ensureVisible(exportTile);
          await tester.tap(exportTile);
          await tester.runAsync(() async {
            await Future.delayed(const Duration(milliseconds: 300));
          });
          await tester.pumpAndSettle();

          // Switch format to JSON
          final jsonOption = find.text('JSON Backup (.json)');
          await tester.tap(jsonOption);
          await tester.pumpAndSettle();

          // Modify filename
          await tester.enterText(
            find.byKey(const Key('export_filename_input')),
            'custom_test_backup.json',
          );
          await tester.pumpAndSettle();

          expect(
            find.textContaining('custom_test_backup.json'),
            findsAtLeastNWidgets(1),
          );

          // Tap Confirm & Save
          await tester.tap(find.byKey(const Key('export_confirm_button')));
          await tester.pump();

          for (int i = 0; i < 30; i++) {
            await tester.runAsync(() async {
              await Future.delayed(const Duration(milliseconds: 100));
            });
            await tester.pump();
            if (find
                .textContaining('custom_test_backup.json')
                .evaluate()
                .isNotEmpty) {
              break;
            }
          }

          // Verify feedback banner confirms success with the custom file path
          expect(
            find.byKey(const Key('backup_status_message_banner')),
            findsOneWidget,
          );
          expect(
            find.textContaining('custom_test_backup.json'),
            findsAtLeastNWidgets(1),
          );

          // Advance time past any sqflite lock timers and SnackBar durations
          await tester.pump(const Duration(seconds: 11));
        },
      );

      testWidgets(
        'shows import dialog with format choices and cancels cleanly',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            const MaterialApp(home: BackupRestoreScreen()),
          );
          await tester.runAsync(() async {
            await Future.delayed(const Duration(milliseconds: 300));
          });
          await tester.pumpAndSettle();

          // Tap Import & Restore Data
          final importTile = find.text('Import & Restore Data');
          await tester.ensureVisible(importTile);
          await tester.tap(importTile);
          await tester.pumpAndSettle();

          // Verify import dialog options
          expect(
            find.text('Select the backup file format you want to restore:'),
            findsOneWidget,
          );
          expect(find.text('SQLite Database (.db)'), findsOneWidget);
          expect(find.text('JSON Backup (.json)'), findsOneWidget);

          // Tap Cancel
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();

          expect(
            find.text('Select the backup file format you want to restore:'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'renders Default Export Directory tile and allows resetting path to default',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final db = DatabaseHelper.instance;
          final customPath = join(tempDir.path, 'preconfigured_custom_dir');
          await tester.runAsync(() async {
            await db.setCustomBackupPath(customPath);
          });

          await tester.pumpWidget(
            const MaterialApp(home: BackupRestoreScreen()),
          );
          for (int i = 0; i < 30; i++) {
            await tester.runAsync(() async {
              await Future.delayed(const Duration(milliseconds: 50));
            });
            await tester.pump();
            if (find.text(customPath).evaluate().isNotEmpty) {
              break;
            }
          }
          await tester.pumpAndSettle();

          // Verify Default Export Directory tile exists
          final dirTile = find.byKey(
            const Key('settings_default_export_directory_tile'),
          );
          expect(dirTile, findsOneWidget);
          await tester.ensureVisible(dirTile);
          await tester.pumpAndSettle();

          expect(find.text(customPath), findsOneWidget);

          // Tap Default Export Directory tile
          await tester.tap(dirTile);
          await tester.pump();
          for (int i = 0; i < 30; i++) {
            await tester.runAsync(() async {
              await Future.delayed(const Duration(milliseconds: 50));
            });
            await tester.pump();
            if (find
                .byKey(const Key('settings_reset_export_directory_button'))
                .evaluate()
                .isNotEmpty) {
              break;
            }
          }
          await tester.pumpAndSettle();

          // Verify dialog appears
          expect(
            find.text('Default Export Directory'),
            findsAtLeastNWidgets(1),
          );
          expect(
            find.byKey(const Key('settings_reset_export_directory_button')),
            findsOneWidget,
          );

          // Tap Reset button
          await tester.tap(
            find.byKey(const Key('settings_reset_export_directory_button')),
          );
          await tester.pump();
          for (int i = 0; i < 30; i++) {
            await tester.runAsync(() async {
              await Future.delayed(const Duration(milliseconds: 50));
            });
            await tester.pump();
            if (find
                .byKey(const Key('settings_reset_export_directory_button'))
                .evaluate()
                .isEmpty) {
              break;
            }
          }
          await tester.pumpAndSettle();

          // Verify path was reset in db
          final effective = await tester.runAsync(
            db.getEffectiveBackupDirectory,
          );
          final defaultDir = await tester.runAsync(
            db.getDefaultBackupDirectory,
          );
          expect(effective, equals(defaultDir));
        },
      );
    },
  );
}
