import 'package:cashflow/main.dart' as app;
import 'package:cashflow/screens/backup_restore_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture all app screens', (tester) async {
    await app.main();
    await _waitForScreen(tester, 'Cashflow');

    await tester.tap(find.byTooltip('Settings & Data Backup'));
    await _waitForScreen(tester, 'Settings & Data');
    final populateButton = find.widgetWithText(
      ElevatedButton,
      'Populate Sample Data',
    );
    final backupScrollable = find.ancestor(
      of: populateButton,
      matching: find.byType(Scrollable),
    );
    await tester.drag(backupScrollable, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(populateButton);
    await _waitForText(tester, 'Populate Sample Demo Finances?');
    final loadDemoButton = find.widgetWithText(
      ElevatedButton,
      'Load Demo Data',
    );
    await tester.tap(loadDemoButton);
    await _waitForText(tester, 'Sample finances populated successfully!');
    await _waitForScreen(tester, 'Settings & Data');
    await tester.pageBack();
    await _waitForScreen(tester, 'Cashflow');

    await _markScreen('01-dashboard');

    const destinations = <({String label, String title, String screenshot})>[
      (label: 'Budgets', title: 'Monthly Budgets', screenshot: '02-budget'),
      (label: 'Goals', title: 'Sinking Funds', screenshot: '03-goals'),
      (label: 'Accounts', title: 'My Accounts', screenshot: '04-accounts'),
      (
        label: 'Insights',
        title: 'Insights & Activity',
        screenshot: '05-analytics',
      ),
    ];

    for (final destination in destinations) {
      await tester.tap(find.text(destination.label));
      await _waitForScreen(tester, destination.title);
      await _markScreen(destination.screenshot);
    }

    await tester.tap(find.text('Analytics & Trends'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    await _waitForText(tester, 'Monthly Spending Trends');
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _markScreen('06-analytics-trends');

    await tester.tap(find.byTooltip('Settings & Data Backup'));
    await _waitForScreen(tester, 'Settings & Data');
    await _markScreen('07-backup-restore');

    expect(find.byType(BackupRestoreScreen), findsOneWidget);
  });
}

Future<void> _waitForText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  final deadline = DateTime.now().add(const Duration(seconds: 30));

  while (findsNothing.matches(finder, {})) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for text: $text');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitForScreen(WidgetTester tester, String text) async {
  final finder = find.text(text);
  final deadline = DateTime.now().add(const Duration(seconds: 30));

  while (findsNothing.matches(finder, {})) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for screen title: $text');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  final loadingFinder = find.byType(CircularProgressIndicator);
  while (loadingFinder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for screen data: $text');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _markScreen(String name) async {
  // The host capture script watches these markers and uses adb screencap.
  print('SCREENSHOT_MARKER:$name');
  await Future<void>.delayed(const Duration(milliseconds: 1000));
}
