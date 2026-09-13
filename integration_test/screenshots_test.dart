import 'package:cashflow/main.dart' as app;
import 'package:cashflow/screens/backup_restore_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture all app screens exhaustively in light and dark modes',
      (tester) async {
    await app.main();
    await _waitForScreen(tester, 'Cashflow');

    // 1. Seed demo finances via Settings screen
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

    // ==========================================
    // PASS 1: LIGHT MODE EXHAUSTIVE CAPTURE
    // ==========================================

    // 01: Dashboard Overview
    await _markScreen('01-dashboard-light');

    // 01b: Dashboard Overview (Privacy Mode)
    await tester.tap(find.byTooltip('Hide Balance'));
    await tester.pumpAndSettle();
    await _markScreen('01b-dashboard-privacy-light');
    await tester.tap(find.byTooltip('Show Balance'));
    await tester.pumpAndSettle();

    // 02: Log Transaction Modal - Expense Tab
    await tester.tap(find.text('Log Transaction'));
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Type');
    await _markScreen('02-modal-expense-light');

    // 03: Log Transaction Modal - Income Tab
    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Income').last);
    await tester.pumpAndSettle();
    await _markScreen('03-modal-income-light');

    // 04: Log Transaction Modal - Transfer Tab
    await tester.tap(find.text('Income').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer').last);
    await tester.pumpAndSettle();
    await _markScreen('04-modal-transfer-light');

    // Dismiss Log Transaction Modal
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // 05: Budgets Screen
    await tester.tap(find.text('Budgets'));
    await _waitForScreen(tester, 'Monthly Budgets');
    await _markScreen('05-budget-light');

    // 06: Add Category Dialog
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Category'));
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Category Name');
    await _markScreen('06-modal-add-category-light');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 07: Edit Category Dialog
    await tester.tap(find.byTooltip('Edit Category').first);
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Edit Category');
    await _markScreen('07-modal-edit-category-light');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 08: Goals / Sinking Funds Screen
    await tester.tap(find.text('Goals'));
    await _waitForScreen(tester, 'Sinking Funds');
    await _markScreen('08-goals-light');

    // 09: Add Goal Dialog
    await tester.tap(find.widgetWithText(FloatingActionButton, 'New Goal'));
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Create Sinking Fund / Goal');
    await _markScreen('09-modal-add-goal-light');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 10: Locked Allocations Modal
    await tester.tap(find.byTooltip('Contribution Breakdown').first);
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Locked Allocations for');
    await _markScreen('10-modal-lock-funds-light');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // 11: Edit Goal Dialog
    await tester.tap(find.byTooltip('Edit Goal').first);
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Edit Sinking Fund');
    await _markScreen('11-modal-edit-goal-light');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 12: Accounts Screen
    await tester.tap(find.text('Accounts'));
    await _waitForScreen(tester, 'My Accounts');
    await _markScreen('12-accounts-light');

    // 13: Accounts Dropdown Expanded
    final lockedFundsToggle = find.textContaining('Locked Funds (').first;
    await tester.ensureVisible(lockedFundsToggle);
    await tester.pumpAndSettle();
    await tester.tap(lockedFundsToggle);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await _markScreen('13-accounts-dropdown-expanded-light');
    // Collapse back
    await tester.tap(lockedFundsToggle);
    await tester.pumpAndSettle();

    // 14: Add Account Dialog
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Account'));
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Add New Account');
    await _markScreen('14-modal-add-account-light');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 15: Activity Ledger Tab (Light)
    await tester.tap(find.text('Insights'));
    await _waitForScreen(tester, 'Insights & Activity');
    await tester.tap(find.text('Activity Ledger'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await _waitForText(tester, 'Transaction Ledger');
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _markScreen('15-activity-ledger-light');

    // 16: Insights Spending Trends Chart (Light)
    await tester.tap(find.text('Analytics & Trends'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    await _waitForText(tester, 'Monthly Spending Trends');
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _markScreen('16-analytics-trends-light');

    // 17: Backup & Restore Screen (Light)
    await tester.tap(find.byTooltip('Settings & Data Backup'));
    await _waitForScreen(tester, 'Settings & Data');
    await _markScreen('17-backup-restore-light');
    await tester.pageBack();
    await _waitForScreen(tester, 'Insights & Activity');

    // ==========================================
    // PASS 2: DARK MODE EXHAUSTIVE CAPTURE
    // ==========================================

    // Toggle to Dark Mode
    await tester.tap(find.byTooltip('Toggle Theme'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    // 18: Dashboard Overview (Dark)
    await tester.tap(find.text('Home'));
    await _waitForScreen(tester, 'Cashflow');
    await _markScreen('18-dashboard-dark');

    // 18b: Dashboard Overview (Privacy Mode Dark)
    await tester.tap(find.byTooltip('Hide Balance'));
    await tester.pumpAndSettle();
    await _markScreen('18b-dashboard-privacy-dark');
    await tester.tap(find.byTooltip('Show Balance'));
    await tester.pumpAndSettle();

    // 19: Log Transaction Modal (Dark)
    await tester.tap(find.text('Log Transaction'));
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Type');
    await _markScreen('19-modal-expense-dark');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // 20: Budgets Screen (Dark)
    await tester.tap(find.text('Budgets'));
    await _waitForScreen(tester, 'Monthly Budgets');
    await _markScreen('20-budget-dark');

    // 21: Goals / Sinking Funds Screen (Dark)
    await tester.tap(find.text('Goals'));
    await _waitForScreen(tester, 'Sinking Funds');
    await _markScreen('21-goals-dark');

    // 22: Locked Allocations Modal (Dark)
    await tester.tap(find.byTooltip('Contribution Breakdown').first);
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Locked Allocations for');
    await _markScreen('22-modal-lock-funds-dark');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // 23: Accounts Screen (Dark)
    await tester.tap(find.text('Accounts'));
    await _waitForScreen(tester, 'My Accounts');
    await _markScreen('23-accounts-dark');

    // 24: Accounts Dropdown Expanded (Dark)
    final darkLockedFundsToggle = find.textContaining('Locked Funds (').first;
    await tester.ensureVisible(darkLockedFundsToggle);
    await tester.pumpAndSettle();
    await tester.tap(darkLockedFundsToggle);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await _markScreen('24-accounts-dropdown-expanded-dark');
    await tester.tap(darkLockedFundsToggle);
    await tester.pumpAndSettle();

    // 25: Activity Ledger Tab (Dark)
    await tester.tap(find.text('Insights'));
    await _waitForScreen(tester, 'Insights & Activity');
    await tester.tap(find.text('Activity Ledger'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await _waitForText(tester, 'Transaction Ledger');
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _markScreen('25-activity-ledger-dark');

    // 26: Insights Spending Trends Chart (Dark)
    await tester.tap(find.text('Analytics & Trends'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    await _waitForText(tester, 'Monthly Spending Trends');
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _markScreen('26-analytics-trends-dark');

    // 27: Backup & Restore Screen (Dark)
    await tester.tap(find.byTooltip('Settings & Data Backup'));
    await _waitForScreen(tester, 'Settings & Data');
    await _markScreen('27-backup-restore-dark');

    // Return to main navigation screen
    await tester.pageBack();
    await _waitForScreen(tester, 'Insights & Activity');

    // Restore to Light Mode
    await tester.tap(find.byTooltip('Toggle Theme'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.byType(BackupRestoreScreen), findsNothing);
  });
}

Future<void> _waitForText(WidgetTester tester, String text) async {
  final finder = find.textContaining(text);
  final deadline = DateTime.now().add(const Duration(seconds: 30));

  while (findsNothing.matches(finder, {})) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for text containing: $text');
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
  await Future<void>.delayed(const Duration(milliseconds: 1200));
}
