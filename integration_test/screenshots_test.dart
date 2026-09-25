import 'package:cashflow/components/voice_recording_modal.dart';
import 'package:cashflow/components/voice_transaction_staging_sheet.dart';
import 'package:cashflow/main.dart' as app;
import 'package:cashflow/models/draft_transaction.dart';
import 'package:cashflow/screens/backup_restore_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture all app screens exhaustively in light and dark modes', (
    tester,
  ) async {
    await app.main();
    await _waitForScreen(tester, 'Cashflow');

    // 1. Seed demo finances via Settings screen
    await tester.tap(find.byTooltip('Settings & Data Backup'));
    await _waitForScreen(tester, 'Settings & Data');
    final backupScrollable = find.byType(Scrollable).first;
    final populateButton = find.widgetWithText(
      ElevatedButton,
      'Populate Sample Data',
    );
    await tester.drag(backupScrollable, const Offset(0, -500));
    await tester.pumpAndSettle();
    await _ensureVisibleAndSettled(
      tester,
      populateButton,
      scrollable: backupScrollable,
    );
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

    // Wait for the sample data feedback snackbar to dismiss before capturing dashboard
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

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
    await tester.tap(find.byKey(const Key('dashboard_log_transaction_action')));
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

    // 05: Budgets Screen (accessed via Dashboard action)
    await tester.tap(find.byKey(const Key('dashboard_add_budget_action')));
    await _waitForScreen(tester, 'Monthly Budgets');
    await _markScreen('05-budget-light');

    // 06: Add Category Dialog
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Category Name');
    await _markScreen('06-modal-add-category-light');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 07: Edit Category Dialog
    final editCatBtn = find.byTooltip('Edit Category').first;
    await _ensureVisibleAndSettled(tester, editCatBtn);
    await tester.tap(editCatBtn);
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Category Name');
    await _markScreen('07-modal-edit-category-light');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Return to Dashboard
    await tester.pageBack();
    await _waitForScreen(tester, 'Cashflow');

    // 08: Goals / Sinking Funds Screen (accessed via Dashboard action)
    await tester.tap(find.byKey(const Key('dashboard_lock_goal_action')));
    await _waitForScreen(tester, 'Sinking Funds');
    await _markScreen('08-goals-light');

    // 09: Add Goal Dialog
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Create Sinking Fund / Goal');
    await _markScreen('09-modal-add-goal-light');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 10: Locked Allocations Modal
    final breakdownBtn = find.byTooltip('Contribution Breakdown').first;
    await _ensureVisibleAndSettled(tester, breakdownBtn);
    await tester.tap(breakdownBtn);
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Goal Contributions & Activity');
    await _markScreen('10-modal-lock-funds-light');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // 11: Edit Goal Dialog
    final editGoalBtn = find.byTooltip('Edit Goal').first;
    await _ensureVisibleAndSettled(tester, editGoalBtn);
    await tester.tap(editGoalBtn);
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Edit Sinking Fund');
    await _markScreen('11-modal-edit-goal-light');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Return to Dashboard
    await tester.pageBack();
    await _waitForScreen(tester, 'Cashflow');

    // 12: Accounts Screen (accessed via bottom navigation)
    await tester.tap(find.text('Accounts'));
    await _waitForScreen(tester, 'My Accounts');
    await _markScreen('12-accounts-light');

    // 13: Accounts Dropdown Expanded
    final lockedFundsToggle = find.textContaining('Locked Funds (').first;
    await _ensureVisibleAndSettled(tester, lockedFundsToggle);
    await tester.tap(lockedFundsToggle);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await _markScreen('13-accounts-dropdown-expanded-light');
    // Collapse back
    await tester.tap(lockedFundsToggle);
    await tester.pumpAndSettle();

    // 14: Add Account Dialog
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Add New Account');
    await _markScreen('14-modal-add-account-light');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 14b: Edit Account Dialog
    final accountOptionsBtn = find.byTooltip('Account Options').first;
    await _ensureVisibleAndSettled(tester, accountOptionsBtn);
    await tester.tap(accountOptionsBtn);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Account'));
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Edit Account');
    await _markScreen('14b-modal-edit-account-light');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 15: Activity Ledger Tab (accessed via bottom navigation)
    await tester.tap(find.text('Activity'));
    await _waitForScreen(tester, 'Activity Ledger');
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _markScreen('15-activity-ledger-light');

    // 15b: Activity Ledger Advanced Filters Modal
    await tester.tap(find.byTooltip('Advanced Filters'));
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Filters');
    await _markScreen('15b-modal-ledger-filters-light');
    await tester.tap(find.byTooltip('Close filters'));
    await tester.pumpAndSettle();

    // 15c: Activity Ledger CSV Export Dialog
    await tester.tap(find.byTooltip('Export CSV'));
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Export Transactions CSV');
    await _markScreen('15c-modal-export-csv-light');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .clearSnackBars();
    await tester.pumpAndSettle();

    // 16: Spending Analytics Screen (accessed via bottom navigation)
    await tester.tap(find.text('Analytics'));
    await _waitForScreen(tester, 'Spending Analytics');
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _markScreen('16-analytics-trends-light');

    // 16b: Spending Analytics 6-Month Trends Scrolled
    final monthlyTrendsChart = find.text('Monthly Spending Trends');
    await _ensureVisibleAndSettled(tester, monthlyTrendsChart);
    await _markScreen('16b-analytics-trends-scroll-light');

    // 17: Voice AI Offline Model Prompt Modal (accessed via center voice FAB)
    await tester.tap(find.byKey(const Key('dashboard_voice_entry_fab')));
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Offline AI Models Required');
    await _markScreen('17-voice-ai-modal-light');
    await tester.tap(
      find.byKey(const Key('voice_model_download_cancel_button')),
    );
    await tester.pumpAndSettle();

    // 17b: Active Voice Listening Modal (preview bypass)
    final rootContext = tester.element(find.byType(Scaffold).first);
    await VoiceRecordingModal.show(rootContext, previewMode: true);
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Offline AI Voice Engine');
    await _markScreen('17b-voice-listening-light');
    await tester.tap(find.byKey(const Key('voice_recording_cancel_button')));
    await tester.pumpAndSettle();

    // 17c: Voice Transaction Staging Sheet (multi-draft review)
    final sampleDrafts = [
      DraftTransaction(
        amount: 250.0,
        type: 'expense',
        note: 'Lunch at Cafe',
        date: '2026-09-23',
        accountId: 1,
        categoryId: 2,
        hasUnassignedAccount: false,
        hasUnassignedCategory: false,
      ),
      DraftTransaction(
        amount: 1200.0,
        type: 'expense',
        note: 'Supermarket Groceries',
        date: '2026-09-23',
        accountId: null,
        categoryId: 1,
        hasUnassignedAccount: true,
        hasUnassignedCategory: false,
      ),
    ];
    final sheetContext = tester.element(find.byType(Scaffold).first);
    await VoiceTransactionStagingSheet.show(sheetContext, drafts: sampleDrafts);
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Staged Transactions');
    await _markScreen('17c-voice-staging-light');
    await tester.tap(find.byTooltip('Close and Discard Drafts'));
    await tester.pumpAndSettle();

    // 18: Backup & Restore Screen (accessed via top AppBar action)
    await tester.tap(find.byTooltip('Settings & Data Backup'));
    await _waitForScreen(tester, 'Settings & Data');
    await _markScreen('18-backup-restore-light');

    // 18b: Settings Screen Scrolled (Voice AI Models Management Section)
    final voiceAiHeader = find.text('Voice AI & Offline Models');
    await _ensureVisibleAndSettled(tester, voiceAiHeader);
    await _markScreen('18b-backup-restore-voice-scroll-light');

    // Return to main screen
    await tester.pageBack();
    await _waitForScreen(tester, 'Spending Analytics');

    // ==========================================
    // PASS 2: DARK MODE EXHAUSTIVE CAPTURE
    // ==========================================

    // Toggle to Dark Mode
    await tester.tap(find.byTooltip('Toggle Theme'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    // 19: Dashboard Overview (Dark)
    await tester.tap(find.text('Home'));
    await _waitForScreen(tester, 'Cashflow');
    await _markScreen('19-dashboard-dark');

    // 19b: Dashboard Overview (Privacy Mode Dark)
    await tester.tap(find.byTooltip('Hide Balance'));
    await tester.pumpAndSettle();
    await _markScreen('19b-dashboard-privacy-dark');
    await tester.tap(find.byTooltip('Show Balance'));
    await tester.pumpAndSettle();

    // 20: Log Transaction Modal (Dark)
    await tester.tap(find.byKey(const Key('dashboard_log_transaction_action')));
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Type');
    await _markScreen('20-modal-expense-dark');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // 21: Budgets Screen (Dark)
    await tester.tap(find.byKey(const Key('dashboard_add_budget_action')));
    await _waitForScreen(tester, 'Monthly Budgets');
    await _markScreen('21-budget-dark');
    await tester.pageBack();
    await _waitForScreen(tester, 'Cashflow');

    // 22: Goals / Sinking Funds Screen (Dark)
    await tester.tap(find.byKey(const Key('dashboard_lock_goal_action')));
    await _waitForScreen(tester, 'Sinking Funds');
    await _markScreen('22-goals-dark');

    // 23: Locked Allocations Modal (Dark)
    final darkBreakdownBtn = find.byTooltip('Contribution Breakdown').first;
    await _ensureVisibleAndSettled(tester, darkBreakdownBtn);
    await tester.tap(darkBreakdownBtn);
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Goal Contributions & Activity');
    await _markScreen('23-modal-lock-funds-dark');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await _waitForScreen(tester, 'Cashflow');

    // 24: Accounts Screen (Dark)
    await tester.tap(find.text('Accounts'));
    await _waitForScreen(tester, 'My Accounts');
    await _markScreen('24-accounts-dark');

    // 25: Accounts Dropdown Expanded (Dark)
    final darkLockedFundsToggle = find.textContaining('Locked Funds (').first;
    await _ensureVisibleAndSettled(tester, darkLockedFundsToggle);
    await tester.tap(darkLockedFundsToggle);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await _markScreen('25-accounts-dropdown-expanded-dark');
    await tester.tap(darkLockedFundsToggle);
    await tester.pumpAndSettle();

    // 26: Activity Ledger Tab (Dark)
    await tester.tap(find.text('Activity'));
    await _waitForScreen(tester, 'Activity Ledger');
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _markScreen('26-activity-ledger-dark');

    // 26b: Activity Ledger Advanced Filters Modal (Dark)
    await tester.tap(find.byTooltip('Advanced Filters'));
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Filters');
    await _markScreen('26b-modal-ledger-filters-dark');
    await tester.tap(find.byTooltip('Close filters'));
    await tester.pumpAndSettle();

    // 27: Spending Analytics Trends Chart (Dark)
    await tester.tap(find.text('Analytics'));
    await _waitForScreen(tester, 'Spending Analytics');
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _markScreen('27-analytics-trends-dark');

    // 27b: Spending Analytics Trends Chart Scrolled (Dark)
    final darkTrendsChart = find.text('Monthly Spending Trends');
    await _ensureVisibleAndSettled(tester, darkTrendsChart);
    await _markScreen('27b-analytics-trends-scroll-dark');

    // 28: Voice AI Offline Model Prompt Modal (Dark)
    await tester.tap(find.byKey(const Key('dashboard_voice_entry_fab')));
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Offline AI Models Required');
    await _markScreen('28-voice-ai-modal-dark');
    await tester.tap(
      find.byKey(const Key('voice_model_download_cancel_button')),
    );
    await tester.pumpAndSettle();

    // 28b: Active Voice Listening Modal (Dark preview bypass)
    final rootContextDark = tester.element(find.byType(Scaffold).first);
    await VoiceRecordingModal.show(rootContextDark, previewMode: true);
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Offline AI Voice Engine');
    await _markScreen('28b-voice-listening-dark');
    await tester.tap(find.byKey(const Key('voice_recording_cancel_button')));
    await tester.pumpAndSettle();

    // 28c: Voice Transaction Staging Sheet (Dark multi-draft review)
    final sheetContextDark = tester.element(find.byType(Scaffold).first);
    await VoiceTransactionStagingSheet.show(
      sheetContextDark,
      drafts: sampleDrafts,
    );
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Staged Transactions');
    await _markScreen('28c-voice-staging-dark');
    await tester.tap(find.byTooltip('Close and Discard Drafts'));
    await tester.pumpAndSettle();

    // 29: Backup & Restore Screen (Dark)
    await tester.tap(find.byTooltip('Settings & Data Backup'));
    await _waitForScreen(tester, 'Settings & Data');
    await _markScreen('29-backup-restore-dark');

    // 29b: Settings Screen Scrolled (Dark Voice AI Models Management Section)
    final darkVoiceAiHeader = find.text('Voice AI & Offline Models');
    await _ensureVisibleAndSettled(tester, darkVoiceAiHeader);
    await _markScreen('29b-backup-restore-voice-scroll-dark');

    // Return to main navigation screen
    await tester.pageBack();
    await _waitForScreen(tester, 'Spending Analytics');

    // Restore to Light Mode
    await tester.tap(find.byTooltip('Toggle Theme'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.byType(BackupRestoreScreen), findsNothing);
  });
}

Future<void> _ensureVisibleAndSettled(
  WidgetTester tester,
  Finder finder, {
  Finder? scrollable,
}) async {
  final scroll = scrollable ?? find.byType(Scrollable).first;
  var count = 0;
  while (findsNothing.matches(finder, {}) && count < 20) {
    await tester.drag(scroll, const Offset(0, -300));
    await tester.pumpAndSettle();
    count++;
  }
  if (finder.evaluate().isNotEmpty) {
    try {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    } catch (_) {
      await tester.drag(scroll, const Offset(0, -200));
      await tester.pumpAndSettle();
    }
  }
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitForText(WidgetTester tester, String text) async {
  final finder = find.textContaining(text);
  final deadline = DateTime.now().add(const Duration(seconds: 90));

  while (findsNothing.matches(finder, {})) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for text containing: $text');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitForScreen(WidgetTester tester, String text) async {
  final finder = find.text(text);
  final deadline = DateTime.now().add(const Duration(seconds: 90));

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
  // ignore: avoid_print
  print('SCREENSHOT_MARKER:$name');
  await Future<void>.delayed(const Duration(milliseconds: 1200));
}
