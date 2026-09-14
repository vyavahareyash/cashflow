import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/locked_allocation_model.dart';
import 'package:cashflow/screens/accounts_screen.dart';
import 'package:cashflow/theme/theme_constants.dart';

void main() {
  group('AggregatedGoalLock unit tests', () {
    test('aggregates multiple allocations for the same goal', () {
      final locks = [
        LockedAllocation(
          id: 1,
          goalId: 101,
          accountId: 1,
          amount: 5000.0,
          goalName: 'Emergency Fund',
        ),
        LockedAllocation(
          id: 2,
          goalId: 101,
          accountId: 1,
          amount: 7500.0,
          goalName: 'Emergency Fund',
        ),
        LockedAllocation(
          id: 3,
          goalId: 202,
          accountId: 1,
          amount: 25000.0,
          goalName: 'Car Down Payment',
        ),
      ];

      final aggregated = AccountCard.aggregateLocks(locks);

      expect(aggregated.length, equals(2));

      final emergencyGoal = aggregated.firstWhere((g) => g.goalId == 101);
      expect(emergencyGoal.goalName, equals('Emergency Fund'));
      expect(emergencyGoal.amount, equals(12500.0));

      final carGoal = aggregated.firstWhere((g) => g.goalId == 202);
      expect(carGoal.goalName, equals('Car Down Payment'));
      expect(carGoal.amount, equals(25000.0));
    });

    test('handles empty locks gracefully', () {
      final aggregated = AccountCard.aggregateLocks([]);
      expect(aggregated, isEmpty);
    });
  });

  group('AccountCard widget tests', () {
    final testAccount = Account(
      id: 1,
      name: 'Main Checking',
      balance: 150000.0,
      type: 'Bank',
    );

    testWidgets('hides locked funds toggle when account has no locks',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: AccountCard(
              account: testAccount,
              locks: const [],
            ),
          ),
        ),
      );

      expect(find.text('Main Checking'), findsOneWidget);
      expect(find.text(AppFormatters.currency(150000.0)), findsOneWidget);
      expect(find.textContaining('locked'), findsNothing);
      expect(find.byKey(const Key('account_locked_funds_toggle_1')),
          findsNothing);
    });

    testWidgets(
        'shows toggle but hides breakdown by default (collapsed by default)',
        (tester) async {
      final locks = [
        LockedAllocation(
          id: 1,
          goalId: 10,
          accountId: 1,
          amount: 5000.0,
          goalName: 'Vacation',
        ),
        LockedAllocation(
          id: 2,
          goalId: 10,
          accountId: 1,
          amount: 5000.0,
          goalName: 'Vacation',
        ),
        LockedAllocation(
          id: 3,
          goalId: 20,
          accountId: 1,
          amount: 15000.0,
          goalName: 'Laptop',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: AccountCard(
              account: testAccount,
              locks: locks,
            ),
          ),
        ),
      );

      // Account name and actual balance (150,000) as primary number
      expect(find.text('Main Checking'), findsOneWidget);
      expect(find.text(AppFormatters.currency(150000.0)), findsOneWidget);

      // Balance subtitle shows usable balance when locks are active (150,000 - 25,000 = 125,000)
      expect(
          find.text('${AppFormatters.compactCurrency(125000.0)} usable'),
          findsOneWidget);

      // Toggle button is visible with aggregate summary
      final toggleFinder =
          find.byKey(const Key('account_locked_funds_toggle_1'));
      expect(toggleFinder, findsOneWidget);
      expect(find.text('Locked Funds (2 goals)'), findsOneWidget);
      expect(find.text(AppFormatters.currency(25000.0)), findsWidgets);

      // Breakdown rows should NOT be visible initially
      expect(find.text('Vacation'), findsNothing);
      expect(find.text('Laptop'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
    });

    testWidgets(
        'tapping toggle expands and collapses aggregated locked funds breakdown',
        (tester) async {
      final locks = [
        LockedAllocation(
          id: 1,
          goalId: 10,
          accountId: 1,
          amount: 5000.0,
          goalName: 'Vacation',
        ),
        LockedAllocation(
          id: 2,
          goalId: 10,
          accountId: 1,
          amount: 5000.0,
          goalName: 'Vacation',
        ),
        LockedAllocation(
          id: 3,
          goalId: 20,
          accountId: 1,
          amount: 15000.0,
          goalName: 'Laptop',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AccountCard(
                account: testAccount,
                locks: locks,
              ),
            ),
          ),
        ),
      );

      final toggleFinder =
          find.byKey(const Key('account_locked_funds_toggle_1'));

      // Initially collapsed
      expect(find.text('Vacation'), findsNothing);
      expect(find.text('Laptop'), findsNothing);

      // Tap to expand
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Now expanded: goal names and aggregated amounts with thousand separators are visible
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
      expect(find.text('Vacation'), findsOneWidget);
      // Vacation should show aggregated ₹10,000 (not two separate ₹5,000 rows)
      expect(find.text(AppFormatters.currency(10000.0)), findsOneWidget);
      expect(find.text('Laptop'), findsOneWidget);
      expect(find.text(AppFormatters.currency(15000.0)), findsOneWidget);

      // Tap again to collapse
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      expect(find.text('Vacation'), findsNothing);
      expect(find.text('Laptop'), findsNothing);
    });

    testWidgets(
        'supports external controlled expansion via isExpanded and onExpansionChanged',
        (tester) async {
      final locks = [
        LockedAllocation(
          id: 1,
          goalId: 10,
          accountId: 1,
          amount: 10000.0,
          goalName: 'Emergency',
        ),
      ];

      bool? receivedExpansion;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AccountCard(
                  account: testAccount,
                  locks: locks,
                  isExpanded: false,
                  onExpansionChanged: (val) {
                    receivedExpansion = val;
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Emergency'), findsNothing);

      final toggleFinder =
          find.byKey(const Key('account_locked_funds_toggle_1'));
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(receivedExpansion, isTrue);
    });
  });
}
