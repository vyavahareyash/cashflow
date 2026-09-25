import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Account dropdown overflow tests', () {
    const veryLongAccountName =
        'Very Long Corporate Salary Checking Account That Far Exceeds Screen Width';
    const longGoalName =
        'Down Payment For Suburban Family Home With Garden And Garage';

    testWidgets(
      'account dropdown with isExpanded and Row ellipsis does not overflow even in narrow width',
      (tester) async {
        int? selectedId = 1;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: selectedId,
                    items: [
                      const DropdownMenuItem<int>(
                        value: 1,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                veryLongAccountName,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('₹150000'),
                          ],
                        ),
                      ),
                      const DropdownMenuItem<int>(
                        value: 2,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Secondary Savings',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('₹25000'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) => selectedId = val,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('₹150000'), findsOneWidget);

        // Open dropdown menu
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('₹25000'), findsOneWidget);

        // Select second account
        await tester.tap(find.text('₹25000'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(selectedId, 2);
      },
    );

    testWidgets(
      'goal dropdown with isExpanded and ellipsis does not overflow even in narrow width',
      (tester) async {
        const int selectedGoalId = 10;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: selectedGoalId,
                    items: const [
                      DropdownMenuItem<int>(
                        value: 10,
                        child: Text(
                          '$longGoalName (₹50000 / ₹200000)',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                    onChanged: null,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Open dropdown
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'reproduces overflow when unconstrained without isExpanded or ellipsis',
      (tester) async {
        FlutterErrorDetails? errorDetails;
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          errorDetails = details;
        };

        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<int>(
                      initialValue: 1,
                      items: const [
                        DropdownMenuItem<int>(
                          value: 1,
                          child: Text('$veryLongAccountName (₹150000)'),
                        ),
                      ],
                      onChanged: (val) {},
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(errorDetails, isNotNull);
          expect(errorDetails!.toString(), contains('overflowed'));
        } finally {
          FlutterError.onError = oldHandler;
        }
      },
    );
  });
}
