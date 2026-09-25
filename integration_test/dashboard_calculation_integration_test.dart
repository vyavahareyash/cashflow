import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cashflow/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'dashboard calculation, balance display, and refresh integration test',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle();

      // 1. Verify Cashflow App Bar & Dashboard Title
      expect(find.text('Cashflow'), findsOneWidget);

      // 2. Verify Hero Balance Card & Formula Structure
      expect(find.text('Safe-to-Spend Balance'), findsOneWidget);
      expect(find.text('Physical'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);
      expect(find.text('Budget cap'), findsOneWidget);

      // 3. Verify Budget Pace & Section Headers
      expect(find.text('Spent so far'), findsOneWidget);
      expect(find.text('Sinking Funds & Goals'), findsOneWidget);

      final dashboardScrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Recent Activity'), 200.0);
      expect(find.text('Recent Activity'), findsOneWidget);

      // Scroll back to top for pull-to-refresh
      await tester.scrollUntilVisible(
        find.text('Safe-to-Spend Balance'),
        -200.0,
      );
      expect(find.text('Safe-to-Spend Balance'), findsOneWidget);

      // 4. Test Dashboard Pull-To-Refresh Trigger
      await tester.drag(dashboardScrollable, const Offset(0, 300));
      await tester.pumpAndSettle();

      // Verify still intact after pull-to-refresh
      expect(find.text('Safe-to-Spend Balance'), findsOneWidget);

      // 5. Navigate to Settings & Data screen
      final settingsButton = find.byTooltip('Settings & Data Backup');
      expect(settingsButton, findsOneWidget);
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      // Verify Settings & Data components
      expect(find.text('Settings & Data'), findsOneWidget);
      expect(find.text('Backup Status'), findsOneWidget);
      expect(find.text('Export as JSON'), findsOneWidget);
      expect(find.text('Import from JSON'), findsOneWidget);

      // Return to Dashboard
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Cashflow'), findsOneWidget);
      expect(find.text('Safe-to-Spend Balance'), findsOneWidget);
    },
  );
}
