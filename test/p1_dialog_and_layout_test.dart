import 'package:cashflow/components/app_dialogs.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/credit_card_model.dart';
import 'package:cashflow/screens/accounts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Issue #67: AppDialogs.showWarning validation dialogs', () {
    testWidgets('AppDialogs.showWarning renders warning dialog with title, message, icon and OK button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AppDialogs.showWarning(
                  context,
                  title: 'Custom Error Title',
                  message: 'Please enter an amount > 0',
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog contents
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Custom Error Title'), findsOneWidget);
      expect(find.text('Please enter an amount > 0'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      // Tap OK and verify dialog closes
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('AppDialogs.showWarning defaults to Validation Error title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AppDialogs.showWarning(
                  context,
                  message: 'Destination account is required',
                ),
                child: const Text('Show Default'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Default'));
      await tester.pumpAndSettle();

      expect(find.text('Validation Error'), findsOneWidget);
      expect(find.text('Destination account is required'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('Issue #71: EditAccountDialog action buttons horizontal layout', () {
    testWidgets('Edit Account dialog has header delete icon and single horizontal actions row', (tester) async {
      final account = Account(id: 1, name: 'HDFC Savings', balance: 50000.0, type: 'Bank');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => EditAccountDialog(
                      account: account,
                      bankAccounts: [account],
                    ),
                  );
                },
                child: const Text('Open Edit Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Edit Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.text('Edit Account'), findsOneWidget);

      // Verify title row has Delete icon button
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      // Verify actions contains Cancel and Update buttons, and no Delete button
      expect(find.widgetWithText(TextButton, 'Delete'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.actions, isNotNull);
      expect(dialog.actions!.length, 2);

      // Tap Cancel to dismiss
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Edit Credit Card dialog has header delete icon and actions with Cancel and Update', (tester) async {
      final bankAccount = Account(id: 1, name: 'HDFC Bank', balance: 75000.0, type: 'Bank');
      final ccAccount = Account(id: 2, name: 'Axis Atlas', balance: 12000.0, type: 'Credit Card');
      final cardMeta = CreditCard(
        id: 1,
        accountId: 2,
        creditLimit: 150000.0,
        statementDay: 12,
        dueDay: 2,
        defaultLockAccountId: 1,
        autoLock: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => EditAccountDialog(
                      account: ccAccount,
                      creditCard: cardMeta,
                      bankAccounts: [bankAccount],
                    ),
                  );
                },
                child: const Text('Open CC Edit Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open CC Edit Dialog'));
      await tester.pumpAndSettle();

      // Verify Edit Credit Card title
      expect(find.text('Edit Credit Card'), findsOneWidget);

      // Verify header delete icon
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      // Verify actions contains Cancel and Update buttons, and no Delete button
      expect(find.widgetWithText(TextButton, 'Delete'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.actions, isNotNull);
      expect(dialog.actions!.length, 2);
    });
  });

  group('Issue #67: TransferFundsModal validation triggers AppDialogs.showWarning', () {
    testWidgets('Transfer validation shows dialog pop-up instead of SnackBar', (tester) async {
      final source = Account(id: 1, name: 'Account A', balance: 10000.0, type: 'Bank');
      final dest = Account(id: 2, name: 'Account B', balance: 5000.0, type: 'Bank');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => TransferFundsModal(
                      sourceAccount: source,
                      destinationAccounts: [dest],
                    ),
                  );
                },
                child: const Text('Open Transfer Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Transfer Modal'));
      await tester.pumpAndSettle();

      // Modal is now open
      expect(find.textContaining('Transfer from "Account A"'), findsOneWidget);

      final completeBtn = find.widgetWithText(ElevatedButton, 'Complete Transfer');

      // 1. Empty amount validation
      await tester.tap(completeBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Please enter an amount'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      // 2. Amount <= 0 validation
      final amountField = find.byType(TextField).first;
      await tester.enterText(amountField, '0');
      await tester.pumpAndSettle();

      await tester.tap(completeBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Please enter an amount > 0'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      // 3. Amount > balance validation
      await tester.enterText(amountField, '999999');
      await tester.pumpAndSettle();

      await tester.tap(completeBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Cannot transfer more than account balance'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
