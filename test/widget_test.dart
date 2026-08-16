import 'package:flutter_test/flutter_test.dart';
import 'package:cashflow/theme/theme_constants.dart';

void main() {
  group('AppFormatters unit tests', () {
    test('currency formats numbers correctly', () {
      expect(AppFormatters.currency(5000), '₹5,000');
      expect(AppFormatters.currency(1234.56), '₹1,234.56');
      expect(AppFormatters.currency(5000, isPrivate: true), '••••••');
    });

    test('compactCurrency formats large values cleanly', () {
      expect(AppFormatters.compactCurrency(1500), '₹1.5k');
      expect(AppFormatters.compactCurrency(250000), '₹2.5L');
      expect(AppFormatters.compactCurrency(15000000), '₹1.5Cr');
      expect(AppFormatters.compactCurrency(500, isPrivate: true), '••••');
    });

    test('CategoryStyle maps category names to distinct icons and colors', () {
      final groceryStyle = CategoryStyle.getStyle('Groceries');
      final diningStyle = CategoryStyle.getStyle('Dining Out');
      final transportStyle = CategoryStyle.getStyle('Transport');

      expect(groceryStyle.color, AppColors.emerald600);
      expect(diningStyle.color, AppColors.orange);
      expect(transportStyle.color, AppColors.info);
    });
  });
}
