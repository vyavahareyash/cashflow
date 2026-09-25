import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/screens/goals_screen.dart';
import 'package:cashflow/services/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.setTestDatabaseName(inMemoryDatabasePath);
  const databaseFileName = 'money_tracker.db';

  setUp(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
  });

  tearDown(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
  });

  group('Backup Freshness Timestamp Persistence (Issue #48)', () {
    test(
      'persists and retrieves last backup timestamp via app_settings',
      () async {
        final db = DatabaseHelper.instance;

        // Initially null
        final initialTimestamp = await db.getLastBackupTimestamp();
        expect(initialTimestamp, isNull);

        // Record a timestamp
        final testTime = DateTime(2026, 9, 14, 13, 30, 0);
        await db.setLastBackupTimestamp(testTime);

        final retrieved = await db.getLastBackupTimestamp();
        expect(retrieved, testTime.toIso8601String());
      },
    );
  });

  group('Goal Completion Celebratory Flair (Issue #48)', () {
    testWidgets(
      'GoalCard renders celebratory flair and ready-to-settle banner when 100% completed',
      (tester) async {
        final completedGoal = Goal(
          id: 10,
          name: 'Europe Vacation',
          totalTarget: 100000.0,
          currentSaved: 100000.0,
          targetDate: '2026-12-31',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: GoalCard(goal: completedGoal)),
          ),
        );
        await tester.pumpAndSettle();

        // Verified existing expectations remain intact
        expect(find.text('Goal reached! Ready to settle'), findsOneWidget);
        expect(find.text('Goal Reached'), findsOneWidget);

        // Verified celebratory flair banner is rendered
        expect(
          find.text('Ready to Settle • Sinking fund 100% funded'),
          findsOneWidget,
        );
        expect(find.text('🎉'), findsOneWidget);
      },
    );

    testWidgets(
      'GoalCard does not render celebratory flair banner when active/incomplete',
      (tester) async {
        final activeGoal = Goal(
          id: 11,
          name: 'New Car',
          totalTarget: 500000.0,
          currentSaved: 150000.0,
          targetDate: '2027-06-30',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: GoalCard(goal: activeGoal)),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Ready to Settle • Sinking fund 100% funded'),
          findsNothing,
        );
        expect(find.text('Goal reached! Ready to settle'), findsNothing);
      },
    );
  });
}
