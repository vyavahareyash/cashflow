import 'package:cashflow/components/choice_picker_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppChoicePickerField Tests', () {
    final testItems = [
      const AppChoiceItem<int>(
        value: 1,
        label: 'Groceries',
        subtitle: 'Food & drinks',
        icon: Icons.shopping_basket_rounded,
      ),
      const AppChoiceItem<int>(
        value: 2,
        label: 'Dining Out',
        subtitle: 'Restaurants & cafes',
        icon: Icons.restaurant_rounded,
      ),
      const AppChoiceItem<int>(
        value: 3,
        label: 'Shopping',
        subtitle: 'Apparel & electronics',
        icon: Icons.shopping_bag_rounded,
      ),
      const AppChoiceItem<int>(
        value: 4,
        label: 'Utilities & Bills',
        subtitle: 'Electricity, water, gas',
        icon: Icons.bolt_rounded,
      ),
      const AppChoiceItem<int>(
        value: 5,
        label: 'Transport & Fuel',
        subtitle: 'Cabs, metro, petrol',
        icon: Icons.directions_car_rounded,
      ),
      const AppChoiceItem<int>(
        value: 6,
        label: 'Entertainment',
        subtitle: 'Movies & events',
        icon: Icons.movie_rounded,
      ),
    ];

    testWidgets('renders initial value and label correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppChoicePickerField<int>(
              label: 'Category',
              initialValue: 1,
              items: testItems,
            ),
          ),
        ),
      );

      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
    });

    testWidgets('renders hint text when initialValue is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppChoicePickerField<int>(
              label: 'Category',
              hintText: 'Choose a category',
              items: testItems,
            ),
          ),
        ),
      );

      expect(find.text('Choose a category'), findsOneWidget);
    });

    testWidgets('opens bottom sheet and selects an item', (tester) async {
      int? selectedValue = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AppChoicePickerField<int>(
                  label: 'Category',
                  initialValue: selectedValue,
                  items: testItems,
                  onChanged: (val) {
                    setState(() => selectedValue = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Groceries'), findsOneWidget);

      // Tap trigger to open sheet
      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();

      // Sheet is visible with header and choices
      expect(find.text('Select Category'), findsOneWidget);
      expect(find.text('Dining Out'), findsOneWidget);
      expect(find.text('Restaurants & cafes'), findsOneWidget);

      // Select 'Dining Out'
      await tester.tap(find.text('Dining Out'));
      await tester.pumpAndSettle();

      // Sheet should close and field should show selected item
      expect(find.text('Select Category'), findsNothing);
      expect(find.text('Dining Out'), findsOneWidget);
      expect(selectedValue, equals(2));
    });

    testWidgets('filters items when typing in search input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppChoicePickerField<int>(
              label: 'Category',
              initialValue: 1,
              items: testItems,
              enableSearch: true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Fuel');
      await tester.pumpAndSettle();

      expect(find.text('Transport & Fuel'), findsOneWidget);
      expect(find.text('Dining Out'), findsNothing);
      expect(find.text('Shopping'), findsNothing);

      // Select filtered item
      await tester.tap(find.text('Transport & Fuel'));
      await tester.pumpAndSettle();

      expect(find.text('Transport & Fuel'), findsOneWidget);
    });

    testWidgets('displays validation error when invalid', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: AppChoicePickerField<int>(
                label: 'Category',
                items: testItems,
                validator: (val) => val == null ? 'Category is required' : null,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Category is required'), findsNothing);

      // Trigger validation
      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(find.text('Category is required'), findsOneWidget);
    });

    testWidgets('supports selectedWidgetBuilder for custom display', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppChoicePickerField<int>(
              label: 'Category',
              initialValue: 1,
              items: testItems,
              selectedWidgetBuilder: (context, item) =>
                  Text('Custom: ${item?.label}'),
            ),
          ),
        ),
      );

      expect(find.text('Custom: Groceries'), findsOneWidget);
    });

    testWidgets('supports itemTileBuilder for custom modal rows', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppChoicePickerField<int>(
              label: 'Category',
              initialValue: 1,
              items: testItems,
              itemTileBuilder: (context, item, isSelected, onSelect) {
                return ListTile(
                  key: ValueKey('custom_tile_${item.value}'),
                  title: Text('Tile: ${item.label}'),
                  onTap: onSelect,
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('custom_tile_1')), findsOneWidget);
      expect(find.text('Tile: Groceries'), findsOneWidget);
    });

    testWidgets('supports nullable types with null value option', (
      tester,
    ) async {
      int? selectedId = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AppChoicePickerField<int?>(
                  label: 'Category',
                  initialValue: selectedId,
                  items: const [
                    AppChoiceItem<int?>(value: null, label: 'No Category'),
                    AppChoiceItem<int?>(value: 1, label: 'Groceries'),
                  ],
                  onChanged: (val) => setState(() => selectedId = val),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Groceries'), findsOneWidget);

      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('No Category'));
      await tester.pumpAndSettle();

      expect(selectedId, isNull);
      expect(find.text('No Category'), findsOneWidget);
    });

    testWidgets('disabled field does not open bottom sheet on tap', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppChoicePickerField<int>(
              label: 'Category',
              enabled: false,
              items: testItems,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Select an option'));
      await tester.pumpAndSettle();

      // Modal sheet should not be open
      expect(find.text('Search Category'), findsNothing);
    });
  });
}
