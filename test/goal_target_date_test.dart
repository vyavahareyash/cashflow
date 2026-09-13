import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/screens/goals_screen.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
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

  group('Goal target date domain logic', () {
    final fixedToday = DateTime(2026, 9, 13);

    test('parses valid and invalid target dates', () {
      final goalValid = Goal(
        name: 'Valid Date',
        totalTarget: 1000.0,
        targetDate: '2026-12-25',
        currentSaved: 0.0,
      );
      expect(goalValid.parsedTargetDate, DateTime(2026, 12, 25));
      expect(goalValid.formattedTargetDate, 'Dec 25, 2026');
      expect(goalValid.shortTargetDate, 'Dec 2026');

      final goalInvalid = Goal(
        name: 'Invalid Date',
        totalTarget: 1000.0,
        targetDate: 'not-a-date',
        currentSaved: 0.0,
      );
      expect(goalInvalid.parsedTargetDate, isNull);
      expect(goalInvalid.formattedTargetDate, 'not-a-date');
      expect(goalInvalid.shortTargetDate, 'not-a-date');
      expect(goalInvalid.daysRemaining(today: fixedToday), isNull);
      expect(
        goalInvalid.deadlineStatusText(today: fixedToday),
        'No target date',
      );
    });

    test('calculates days remaining accurately', () {
      final futureGoal = Goal(
        name: 'Vacation',
        totalTarget: 50000.0,
        targetDate: '2026-09-23',
        currentSaved: 10000.0,
      );
      expect(futureGoal.daysRemaining(today: fixedToday), 10);

      final todayGoal = Goal(
        name: 'Due Today',
        totalTarget: 5000.0,
        targetDate: '2026-09-13',
        currentSaved: 0.0,
      );
      expect(todayGoal.daysRemaining(today: fixedToday), 0);

      final pastGoal = Goal(
        name: 'Overdue Goal',
        totalTarget: 10000.0,
        targetDate: '2026-09-10',
        currentSaved: 2000.0,
      );
      expect(pastGoal.daysRemaining(today: fixedToday), -3);
    });

    test('evaluates isOverdue and isCompleted correctly', () {
      final pastUnmet = Goal(
        name: 'Unmet Goal',
        totalTarget: 10000.0,
        targetDate: '2026-09-01',
        currentSaved: 5000.0,
      );
      expect(pastUnmet.isOverdue(today: fixedToday), isTrue);
      expect(pastUnmet.isCompleted, isFalse);

      final pastCompleted = Goal(
        name: 'Completed Past Goal',
        totalTarget: 10000.0,
        targetDate: '2026-09-01',
        currentSaved: 10000.0,
      );
      expect(pastCompleted.isOverdue(today: fixedToday), isFalse);
      expect(pastCompleted.isCompleted, isTrue);

      final futureUnmet = Goal(
        name: 'Future Goal',
        totalTarget: 10000.0,
        targetDate: '2026-12-31',
        currentSaved: 0.0,
      );
      expect(futureUnmet.isOverdue(today: fixedToday), isFalse);
      expect(futureUnmet.isCompleted, isFalse);
    });

    test('calculates recommended monthly savings pace', () {
      final goal = Goal(
        name: 'Emergency Fund',
        totalTarget: 30000.0,
        targetDate: '2026-11-13', // 61 days away
        currentSaved: 0.0,
      );
      final pace = goal.recommendedMonthlyPace(today: fixedToday);
      expect(pace, isNotNull);
      // 61 days / 30.4375 ~= 2.004 months -> ~30000 / 2.004 ~= 14970
      expect(pace!, closeTo(14970, 100));

      final completedGoal = Goal(
        name: 'Completed',
        totalTarget: 1000.0,
        targetDate: '2026-11-13',
        currentSaved: 1000.0,
      );
      expect(completedGoal.recommendedMonthlyPace(today: fixedToday), 0.0);

      final pastGoal = Goal(
        name: 'Past Goal',
        totalTarget: 1000.0,
        targetDate: '2026-09-01',
        currentSaved: 200.0,
      );
      expect(pastGoal.recommendedMonthlyPace(today: fixedToday), isNull);

      final urgentGoal = Goal(
        name: 'Urgent',
        totalTarget: 5000.0,
        targetDate: '2026-09-20', // 7 days away (< 30 days)
        currentSaved: 1000.0,
      );
      // Under 30 days, returns remaining amount needed
      expect(urgentGoal.recommendedMonthlyPace(today: fixedToday), 4000.0);
    });

    test('returns correct deadlineStatusText', () {
      expect(
        Goal(
          name: 'Completed',
          totalTarget: 1000.0,
          targetDate: '2026-09-01',
          currentSaved: 1000.0,
        ).deadlineStatusText(today: fixedToday),
        'Goal Reached',
      );

      expect(
        Goal(
          name: 'Overdue 1',
          totalTarget: 1000.0,
          targetDate: '2026-09-12',
          currentSaved: 0.0,
        ).deadlineStatusText(today: fixedToday),
        'Overdue by 1 day',
      );

      expect(
        Goal(
          name: 'Overdue Multi',
          totalTarget: 1000.0,
          targetDate: '2026-09-08',
          currentSaved: 0.0,
        ).deadlineStatusText(today: fixedToday),
        'Overdue by 5 days',
      );

      expect(
        Goal(
          name: 'Due Today',
          totalTarget: 1000.0,
          targetDate: '2026-09-13',
          currentSaved: 0.0,
        ).deadlineStatusText(today: fixedToday),
        'Due today',
      );

      expect(
        Goal(
          name: 'Due Tomorrow',
          totalTarget: 1000.0,
          targetDate: '2026-09-14',
          currentSaved: 0.0,
        ).deadlineStatusText(today: fixedToday),
        '1 day left',
      );

      expect(
        Goal(
          name: 'Due 15 Days',
          totalTarget: 1000.0,
          targetDate: '2026-09-28',
          currentSaved: 0.0,
        ).deadlineStatusText(today: fixedToday),
        '15 days left',
      );

      expect(
        Goal(
          name: 'Due 3 Months',
          totalTarget: 1000.0,
          targetDate: '2026-12-13',
          currentSaved: 0.0,
        ).deadlineStatusText(today: fixedToday),
        '3 months left',
      );
    });
  });

  group('Goal edit and database persistence', () {
    test('updates target_date in database via updateGoal', () async {
      final db = DatabaseHelper.instance;
      final goalId = await db.createGoal(
        Goal(
          name: 'MacBook Pro',
          totalTarget: 150000.0,
          targetDate: '2026-10-01',
          currentSaved: 20000.0,
        ),
      );

      final initialGoals = await db.readAllGoals();
      expect(initialGoals.first.targetDate, '2026-10-01');

      // Update name, totalTarget, and targetDate
      await db.updateGoal(
        Goal(
          id: goalId,
          name: 'MacBook Pro M4',
          totalTarget: 180000.0,
          targetDate: '2027-03-31',
          currentSaved: 20000.0,
        ),
      );

      final updatedGoals = await db.readAllGoals();
      expect(updatedGoals, hasLength(1));
      final updated = updatedGoals.first;
      expect(updated.id, goalId);
      expect(updated.name, 'MacBook Pro M4');
      expect(updated.totalTarget, 180000.0);
      expect(updated.targetDate, '2027-03-31');
      expect(updated.currentSaved, 20000.0);
    });
  });

  group('Goal UI Component Widget tests', () {
    testWidgets(
      'GoalCard displays due date, deadline status badge, and pacing advice',
      (tester) async {
        final activeGoal = Goal(
          id: 1,
          name: 'Tokyo Trip',
          totalTarget: 100000.0,
          targetDate: '2027-05-15',
          currentSaved: 25000.0,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: GoalCard(goal: activeGoal)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tokyo Trip'), findsOneWidget);
        expect(find.text('Due May 15, 2027'), findsOneWidget);
        expect(find.text(activeGoal.deadlineStatusText()), findsOneWidget);
        expect(find.textContaining('to hit target on time'), findsOneWidget);
      },
    );

    testWidgets('GoalCard displays overdue warning when deadline has passed', (
      tester,
    ) async {
      final overdueGoal = Goal(
        id: 2,
        name: 'Urgent Car Fix',
        totalTarget: 40000.0,
        targetDate: '2025-01-01',
        currentSaved: 10000.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GoalCard(goal: overdueGoal)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Urgent Car Fix'), findsOneWidget);
      expect(find.text('Due Jan 01, 2025'), findsOneWidget);
      expect(find.text(overdueGoal.deadlineStatusText()), findsOneWidget);
      expect(
        find.textContaining('Target date passed — ₹30000 still needed'),
        findsOneWidget,
      );
    });

    testWidgets(
      'GoalCard displays completed state when total target is reached',
      (tester) async {
        final completedGoal = Goal(
          id: 3,
          name: 'MacBook Pro',
          totalTarget: 50000.0,
          targetDate: '2026-12-31',
          currentSaved: 50000.0,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: GoalCard(goal: completedGoal)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Goal reached! Ready to settle'), findsOneWidget);
        expect(find.text('Goal Reached'), findsOneWidget);
        expect(find.textContaining('still needed'), findsNothing);
        expect(find.textContaining('to hit target on time'), findsNothing);
      },
    );

    testWidgets(
      'EditGoalDialog shows current target date and triggers onUpdate with updated date',
      (tester) async {
        final initialGoal = Goal(
          id: 42,
          name: 'Vacation Fund',
          totalTarget: 75000.0,
          targetDate: '2027-08-20',
          currentSaved: 15000.0,
        );

        Goal? updatedResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EditGoalDialog(
                goal: initialGoal,
                onUpdate: (updatedGoal) async {
                  updatedResult = updatedGoal;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify initial fields
        expect(find.text('Edit Sinking Fund'), findsOneWidget);
        expect(find.text('Vacation Fund'), findsOneWidget);
        expect(find.text('75000'), findsOneWidget);
        expect(find.text('Target Date'), findsOneWidget);
        expect(find.text('Aug 20, 2027'), findsOneWidget);

        // Tap Update button
        expect(find.text('Update'), findsOneWidget);
        await tester.tap(find.text('Update'));
        await tester.pumpAndSettle();

        expect(updatedResult, isNotNull);
        expect(updatedResult!.id, 42);
        expect(updatedResult!.name, 'Vacation Fund');
        expect(updatedResult!.totalTarget, 75000.0);
        expect(updatedResult!.targetDate, '2027-08-20');
        expect(updatedResult!.currentSaved, 15000.0);
      },
    );
  });
}
