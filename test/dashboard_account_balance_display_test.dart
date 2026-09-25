import 'dart:io';

import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/screens/dashboard_screen.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
  DatabaseHelper.setTestDatabaseName(inMemoryDatabasePath);
  const databaseFileName = 'money_tracker.db';

  late Directory tempDir;

  setUp(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
    tempDir = await Directory.systemTemp.createTemp('cashflow_dash_acc_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
  });

  tearDown(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('DashboardScreen Account Balance Display', () {
    testWidgets(
      'displays total balance on top and usable balance below when locked, and Balance when unlocked',
      (tester) async {
        DashboardScreen.resetStartupPrivacyFlag();
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final db = DatabaseHelper.instance;

        await tester.runAsync(() async {
          // Account 1: Bank with locked funds
          final acc1Id = await db.createAccount(
            Account(name: 'Main Checking', balance: 50000.0, type: 'Bank'),
          );
          // Account 2: Cash without locked funds
          await db.createAccount(
            Account(name: 'Wallet Cash', balance: 5000.0, type: 'Cash'),
          );

          // Create goal and lock 15,000 on acc1
          final goalId = await db.createGoal(
            Goal(
              name: 'Emergency Fund',
              totalTarget: 50000.0,
              targetDate: '2027-01-01',
              currentSaved: 0.0,
            ),
          );
          await db.createGoalLockTransaction(
            goalId: goalId,
            accountId: acc1Id,
            amount: 15000.0,
            date: '2026-09-23',
            note: 'Emergency savings allocation',
          );
        });

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: DashboardScreen())),
        );
        await tester.pump();
        for (int i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
        }

        // Total balance 50,000 is displayed at top for Main Checking
        expect(find.text('₹50,000'), findsOneWidget);
        // Usable balance (50,000 - 15,000 = 35,000) is displayed below
        expect(find.text('₹35.0k usable'), findsOneWidget);

        // Total balance 5,000 is displayed at top for Wallet Cash
        expect(find.text('₹5,000'), findsOneWidget);
        // 'Balance' is displayed below for account without locks
        expect(find.text('Balance'), findsOneWidget);
      },
    );
  });
}
