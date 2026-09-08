import 'package:cashflow/models/category_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Category monthly budget', () {
    test('accepts a null budget', () {
      final category = Category(name: 'Unbudgeted', monthlyBudget: null);

      expect(category.monthlyBudget, isNull);
    });

    test('preserves a null budget when mapping from the database', () {
      final category = Category.fromMap({
        'id': 1,
        'name': 'Unbudgeted',
        'monthly_budget': null,
      });

      expect(category.monthlyBudget, isNull);
      expect(category.toMap()['monthly_budget'], isNull);
    });

    test('converts numeric database budgets to double', () {
      final category = Category.fromMap({
        'id': 1,
        'name': 'Groceries',
        'monthly_budget': 1800,
      });

      expect(category.monthlyBudget, 1800.0);
      expect(category.toMap()['monthly_budget'], 1800.0);
    });
  });
}
