import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/credit_card_model.dart';
import 'package:cashflow/screens/accounts_screen.dart';
import 'package:cashflow/components/pay_cc_bill_modal.dart';

void main() {
  group('CreditCardAccountCard Widget Tests', () {
    final ccAccount = Account(
      id: 10,
      name: 'HDFC Regalia',
      balance: 15000.0,
      type: 'Credit Card',
    );

    final cardMeta = CreditCard(
      id: 1,
      accountId: 10,
      creditLimit: 100000.0,
      statementDay: 15,
      dueDay: 5,
      defaultLockAccountId: 1,
      autoLock: true,
    );

    testWidgets('renders card name, billing days, limit, outstanding, and utilization', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreditCardAccountCard(
              account: ccAccount,
              creditCard: cardMeta,
              lockedAmount: 15000.0,
            ),
          ),
        ),
      );

      expect(find.text('HDFC Regalia'), findsOneWidget);
      expect(find.text('Due on 5th • Stmt 15th'), findsOneWidget);
      expect(find.text('Outstanding'), findsOneWidget);
      expect(find.textContaining('available'), findsOneWidget);
    });

    testWidgets('displays 100% Backed badge when lockedAmount >= outstanding', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreditCardAccountCard(
              account: ccAccount,
              creditCard: cardMeta,
              lockedAmount: 15000.0,
            ),
          ),
        ),
      );

      expect(find.textContaining('100% Backed'), findsOneWidget);
    });

    testWidgets('displays Partial cash-backed badge when 0 < lockedAmount < outstanding', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreditCardAccountCard(
              account: ccAccount,
              creditCard: cardMeta,
              lockedAmount: 5000.0,
            ),
          ),
        ),
      );

      expect(find.textContaining('Backed'), findsOneWidget);
    });

    testWidgets('displays Unbacked badge when lockedAmount == 0 and outstanding > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreditCardAccountCard(
              account: ccAccount,
              creditCard: cardMeta,
              lockedAmount: 0.0,
            ),
          ),
        ),
      );

      expect(find.text('Unbacked'), findsOneWidget);
    });

    testWidgets('triggers onPayBill callback when Pay Bill button is tapped', (tester) async {
      bool payBillTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreditCardAccountCard(
              account: ccAccount,
              creditCard: cardMeta,
              lockedAmount: 15000.0,
              onPayBill: () {
                payBillTapped = true;
              },
            ),
          ),
        ),
      );

      final payBillBtn = find.text('Pay Bill');
      expect(payBillBtn, findsOneWidget);
      await tester.tap(payBillBtn);
      await tester.pumpAndSettle();

      expect(payBillTapped, isTrue);
    });
  });

  group('PayCcBillModal Widget Tests', () {
    final ccAccount = Account(
      id: 20,
      name: 'SBI Cashback',
      balance: 12000.0,
      type: 'Credit Card',
    );

    final cardMeta = CreditCard(
      id: 2,
      accountId: 20,
      creditLimit: 50000.0,
      statementDay: 10,
      dueDay: 28,
      defaultLockAccountId: 2,
      autoLock: true,
    );

    final bankAccounts = [
      Account(id: 1, name: 'HDFC Savings', balance: 50000.0, type: 'Bank'),
      Account(id: 2, name: 'ICICI Salary', balance: 75000.0, type: 'Bank'),
    ];

    testWidgets('renders modal header, current due, and payment options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => PayCcBillModal(
                      ccAccount: ccAccount,
                      creditCard: cardMeta,
                      bankAccounts: bankAccounts,
                      lockedAmount: 8000.0,
                      onPaymentCompleted: () {},
                    ),
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Pay Card Bill'), findsOneWidget);
      expect(find.text('Current Due'), findsOneWidget);
      expect(find.textContaining('Locked Amount'), findsOneWidget);
      expect(find.textContaining('Full Outstanding'), findsOneWidget);
      expect(find.text('Custom Amount'), findsOneWidget);
    });

    testWidgets('switching to custom amount displays amount input and confirms button', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => PayCcBillModal(
                      ccAccount: ccAccount,
                      creditCard: cardMeta,
                      bankAccounts: bankAccounts,
                      lockedAmount: 8000.0,
                      onPaymentCompleted: () {},
                    ),
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Custom Amount'));
      await tester.pumpAndSettle();

      expect(find.text('Enter amount to pay'), findsOneWidget);
      expect(find.text('Confirm Payment'), findsOneWidget);
    });
  });
}
