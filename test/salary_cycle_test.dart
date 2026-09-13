import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/models/salary_cycle.dart';
import 'package:cashflow/models/goal_model.dart';
import 'package:cashflow/screens/goals_screen.dart';
import 'package:cashflow/theme/theme_constants.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper Salary Day Persistence', () {
    late DatabaseHelper db;

    setUp(() async {
      db = DatabaseHelper.instance;
      final dbPath = await getDatabasesPath();
      await db.close();
      await deleteDatabase(join(dbPath, 'cashflow.db'));
    });

    tearDown(() async {
      final dbPath = await getDatabasesPath();
      await db.close();
      await deleteDatabase(join(dbPath, 'cashflow.db'));
    });

    test('getSalaryDay defaults to 1 and setSalaryDay persists value', () async {
      expect(await db.getSalaryDay(), 1);

      await db.setSalaryDay(25);
      expect(await db.getSalaryDay(), 25);

      // Clamp upper bounds
      await db.setSalaryDay(50);
      expect(await db.getSalaryDay(), 31);

      // Clamp lower bounds
      await db.setSalaryDay(-5);
      expect(await db.getSalaryDay(), 1);
    });
  });

  group('SalaryCycle Domain Logic', () {
    final fixedToday = DateTime(2026, 9, 14);

    test('clamps month end dates correctly across short months and leap years', () {
      // February non-leap year (2025: 28 days)
      expect(SalaryCycle.paydayForMonth(2025, 2, 31), DateTime(2025, 2, 28));
      expect(SalaryCycle.paydayForMonth(2025, 2, 15), DateTime(2025, 2, 15));

      // February leap year (2024: 29 days)
      expect(SalaryCycle.paydayForMonth(2024, 2, 31), DateTime(2024, 2, 29));

      // 30-day month (April 2026)
      expect(SalaryCycle.paydayForMonth(2026, 4, 31), DateTime(2026, 4, 30));

      // 31-day month (May 2026)
      expect(SalaryCycle.paydayForMonth(2026, 5, 31), DateTime(2026, 5, 31));
    });

    test('resolves cycle boundaries and countdown with salaryDay = 1', () {
      final cycle = SalaryCycle.resolve(salaryDay: 1, today: fixedToday);

      expect(cycle.salaryDay, 1);
      expect(cycle.cycleStart, DateTime(2026, 9, 1));
      expect(cycle.nextCycleStart, DateTime(2026, 10, 1));
      expect(cycle.cycleEnd, DateTime(2026, 9, 30));
      expect(cycle.daysLeftInCycle, 17);
      expect(cycle.cycleLabel, 'Sep 1 – Sep 30');
      expect(cycle.resetCountdownText, 'Resets in 17 days (Oct 1)');
    });

    test('resolves cycle boundaries and countdown with mid-month salaryDay = 25', () {
      final cycle = SalaryCycle.resolve(salaryDay: 25, today: fixedToday);

      expect(cycle.salaryDay, 25);
      expect(cycle.cycleStart, DateTime(2026, 8, 25));
      expect(cycle.nextCycleStart, DateTime(2026, 9, 25));
      expect(cycle.cycleEnd, DateTime(2026, 9, 24));
      expect(cycle.daysLeftInCycle, 11);
      expect(cycle.cycleLabel, 'Aug 25 – Sep 24');
      expect(cycle.resetCountdownText, 'Resets in 11 days (Sep 25)');
    });

    test('resolves cycle boundaries when today is exactly payday', () {
      final paydayDate = DateTime(2026, 9, 25);
      final cycle = SalaryCycle.resolve(salaryDay: 25, today: paydayDate);

      expect(cycle.cycleStart, DateTime(2026, 9, 25));
      expect(cycle.nextCycleStart, DateTime(2026, 10, 25));
      expect(cycle.daysLeftInCycle, 30);
      expect(cycle.cycleLabel, 'Sep 25 – Oct 24');
    });

    test('counts paydays strictly between two dates', () {
      // From Sep 14 to Nov 15 with salaryDay = 1: Oct 1 and Nov 1 (2 paydays)
      final count1 = SalaryCycle.countPaydaysBetween(
        from: fixedToday,
        to: DateTime(2026, 11, 15),
        salaryDay: 1,
      );
      expect(count1, 2);

      // From Sep 14 to Sep 28 with salaryDay = 1: 0 paydays left
      final count2 = SalaryCycle.countPaydaysBetween(
        from: fixedToday,
        to: DateTime(2026, 9, 28),
        salaryDay: 1,
      );
      expect(count2, 0);

      // From Sep 14 to Oct 10 with salaryDay = 25: Sep 25 (1 payday)
      final count3 = SalaryCycle.countPaydaysBetween(
        from: fixedToday,
        to: DateTime(2026, 10, 10),
        salaryDay: 25,
      );
      expect(count3, 1);
    });
  });

  group('Goal Payday-Aware Pacing', () {
    final fixedToday = DateTime(2026, 9, 14);

    test('calculates pace across multiple paydays', () {
      final goal = Goal(
        name: 'Vacation',
        totalTarget: 10000.0,
        targetDate: '2026-11-15',
        currentSaved: 0.0,
      );

      // 2 paydays (Oct 1 and Nov 1)
      expect(goal.paydaysRemaining(today: fixedToday, salaryDay: 1), 2);
      expect(goal.recommendedMonthlyPace(today: fixedToday, salaryDay: 1), 5000.0);
      expect(
        goal.pacingAdviceText(today: fixedToday, salaryDay: 1),
        'Save ~₹5000 / paycheck (2 paydays left)',
      );
    });

    test('calculates pace with single payday remaining', () {
      final goal = Goal(
        name: 'Festive Shopping',
        totalTarget: 5000.0,
        targetDate: '2026-10-10',
        currentSaved: 1000.0,
      );

      // 1 payday on Sep 25
      expect(goal.paydaysRemaining(today: fixedToday, salaryDay: 25), 1);
      expect(goal.recommendedMonthlyPace(today: fixedToday, salaryDay: 25), 4000.0);
      expect(
        goal.pacingAdviceText(today: fixedToday, salaryDay: 25),
        'Save ~₹4000 from next paycheck (1 payday left)',
      );
    });

    test('warns and advises immediate allocation when 0 paydays remain before deadline', () {
      final goal = Goal(
        name: 'Short Term Bill',
        totalTarget: 3000.0,
        targetDate: '2026-09-28',
        currentSaved: 500.0,
      );

      // Next payday is Oct 1, which is after Sep 28
      expect(goal.paydaysRemaining(today: fixedToday, salaryDay: 1), 0);
      expect(goal.recommendedMonthlyPace(today: fixedToday, salaryDay: 1), 2500.0);
      expect(
        goal.pacingAdviceText(today: fixedToday, salaryDay: 1),
        'Due in 14 days (0 paydays left) • Fund from existing balance',
      );
    });

    test('returns 0 pace and null advice for completed goal', () {
      final goal = Goal(
        name: 'Done Goal',
        totalTarget: 2000.0,
        targetDate: '2026-11-01',
        currentSaved: 2000.0,
      );

      expect(goal.paydaysRemaining(today: fixedToday, salaryDay: 1), 0);
      expect(goal.recommendedMonthlyPace(today: fixedToday, salaryDay: 1), 0.0);
      expect(goal.pacingAdviceText(today: fixedToday, salaryDay: 1), isNull);
    });
  });

  group('UI Component Tests', () {
    testWidgets('GoalCard renders paycheck-aware advice banner with salaryDay', (tester) async {
      final goal = Goal(
        id: 1,
        name: 'Health Insurance',
        totalTarget: 12000.0,
        targetDate: DateTime.now().add(const Duration(days: 65)).toIso8601String().split('T').first,
        currentSaved: 2000.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: GoalCard(
                  goal: goal,
                  salaryDay: 1,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Health Insurance'), findsOneWidget);
      expect(find.textContaining('paycheck'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    });



    testWidgets('Payday 31-day picker grid renders all 31 days and selects tapped day', (tester) async {
      int selected = 1;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) {
                return Column(
                  children: [
                    Text('Current: $selected'),
                    ElevatedButton(
                      key: const Key('open_picker'),
                      onPressed: () {
                        showModalBottomSheet(
                          context: ctx,
                          isScrollControlled: true,
                          builder: (sheetCtx) => SizedBox(
                            height: 400,
                            child: GridView.builder(
                              itemCount: 31,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                              ),
                              itemBuilder: (c, idx) {
                                final day = idx + 1;
                                return InkWell(
                                  key: Key('payday_grid_day_$day'),
                                  onTap: () {
                                    setState(() => selected = day);
                                    Navigator.pop(sheetCtx);
                                  },
                                  child: Text('Day $day'),
                                );
                              },
                            ),
                          ),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.byKey(const Key('open_picker')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payday_grid_day_1')), findsOneWidget);
      expect(find.byKey(const Key('payday_grid_day_15')), findsOneWidget);
      expect(find.byKey(const Key('payday_grid_day_31')), findsOneWidget);

      await tester.tap(find.byKey(const Key('payday_grid_day_20')));
      await tester.pumpAndSettle();

      expect(find.text('Current: 20'), findsOneWidget);
    });
  });
}
