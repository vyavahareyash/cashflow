import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/screens/history_screen.dart';
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
  const databaseFileName = 'money_tracker.db';

  late Directory tempDir;

  setUp(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
    tempDir = await Directory.systemTemp.createTemp('cashflow_history_export_test_');
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

  group('Activity Ledger CSV Export Destination Dialog (Issue #80)', () {
    testWidgets('tapping export button opens export dialog with default directory and csv filename', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final db = DatabaseHelper.instance;
      await tester.runAsync(() async {
        final accId = await db.createAccount(Account(name: 'Checking', balance: 500.0, type: 'Bank'));
        final catId = await db.createCategory(Category(name: 'Groceries', monthlyBudget: 200.0));
        await db.createExpenseTransaction(
          accountId: accId,
          categoryId: catId,
          amount: 45.0,
          date: '2026-09-20',
        );
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }
      await tester.pump();

      // Tap CSV export button on Ledger
      final exportBtn = find.byKey(const Key('activity_ledger_export_csv_btn'));
      expect(exportBtn, findsOneWidget);
      await tester.tap(exportBtn);
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      // Verify that export confirmation dialog is displayed
      expect(find.text('Export Transactions CSV'), findsOneWidget);
      expect(find.byKey(const Key('export_filename_input')), findsOneWidget);
      expect(find.byKey(const Key('export_confirm_button')), findsOneWidget);
      expect(find.byKey(const Key('export_cancel_button')), findsOneWidget);
      expect(find.text('cashflow_transactions.csv'), findsOneWidget);
    });

    testWidgets('canceling export dialog dismisses dialog and shows cancelled message', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }
      await tester.pump();

      // Tap export button
      await tester.tap(find.byKey(const Key('activity_ledger_export_csv_btn')));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.text('Export Transactions CSV'), findsOneWidget);

      // Tap Cancel button
      await tester.tap(find.byKey(const Key('export_cancel_button')));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      // Dialog dismissed
      expect(find.text('Export Transactions CSV'), findsNothing);
      expect(find.text('CSV export cancelled'), findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('editing filename and confirming exports CSV and shows success message', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final db = DatabaseHelper.instance;
      await tester.runAsync(() async {
        final accId = await db.createAccount(Account(name: 'Checking', balance: 500.0, type: 'Bank'));
        final catId = await db.createCategory(Category(name: 'Groceries', monthlyBudget: 200.0));
        await db.createExpenseTransaction(
          accountId: accId,
          categoryId: catId,
          amount: 45.0,
          date: '2026-09-20',
        );
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }
      await tester.pump();

      // Tap export button
      await tester.tap(find.byKey(const Key('activity_ledger_export_csv_btn')));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      // Edit filename
      await tester.enterText(
        find.byKey(const Key('export_filename_input')),
        'custom_ledger_export.csv',
      );
      await tester.pump();

      // Tap confirm button
      await tester.tap(find.byKey(const Key('export_confirm_button')));
      await tester.pump();

      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
        if (find.textContaining('custom_ledger_export.csv').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(find.textContaining('custom_ledger_export.csv'), findsAtLeastNWidgets(1));

      await tester.pump(const Duration(seconds: 11));
    });
  });
}
