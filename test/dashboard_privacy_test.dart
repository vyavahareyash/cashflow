import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
  const databaseFileName = 'money_tracker.db';

  setUp(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
  });

  tearDown(() async {
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
  });

  group('DatabaseHelper App Settings & Privacy Persistence', () {
    test('getSetting returns default when key does not exist', () async {
      final db = DatabaseHelper.instance;
      final val = await db.getSetting('non_existent_key', defaultValue: 'default_val');
      expect(val, 'default_val');
    });

    test('setSetting persists and overrides setting value', () async {
      final db = DatabaseHelper.instance;
      await db.setSetting('theme_preference', 'dark');
      expect(await db.getSetting('theme_preference'), 'dark');

      await db.setSetting('theme_preference', 'light');
      expect(await db.getSetting('theme_preference'), 'light');
    });

    test('getPrivacyMode defaults to false and setPrivacyMode toggles it', () async {
      final db = DatabaseHelper.instance;
      expect(await db.getPrivacyMode(), isFalse);

      await db.setPrivacyMode(true);
      expect(await db.getPrivacyMode(), isTrue);

      await db.setPrivacyMode(false);
      expect(await db.getPrivacyMode(), isFalse);
    });
  });

  group('Dashboard Privacy Masking & UI Formatting Tests', () {
    test('AppFormatters masks all currency types when private', () {
      // Main balance
      expect(AppFormatters.currency(50000, isPrivate: false), '₹50,000');
      expect(AppFormatters.currency(50000, isPrivate: true), '••••••');

      // Compact currency (formula pills, goal amounts, budget caps)
      expect(AppFormatters.compactCurrency(15000, isPrivate: false), '₹15.0k');
      expect(AppFormatters.compactCurrency(15000, isPrivate: true), '••••');

      expect(AppFormatters.compactCurrency(250000, isPrivate: false), '₹2.5L');
      expect(AppFormatters.compactCurrency(250000, isPrivate: true), '••••');

      expect(AppFormatters.compactCurrency(15000000, isPrivate: false), '₹1.5Cr');
      expect(AppFormatters.compactCurrency(15000000, isPrivate: true), '••••');
    });

    testWidgets('renders masked budget snapshot and goal targets when isPrivate is true',
        (tester) async {
      const isPrivate = true;
      const daysLeft = 17;
      const perDayLeft = 450.0;
      const remainingBudget = 7650.0;
      const totalBudgetLimit = 25000.0;
      const goalSaved = 15000.0;
      const goalTarget = 50000.0;

      final budgetSubtitle =
          '$daysLeft days left (${AppFormatters.compactCurrency(perDayLeft, isPrivate: isPrivate)}/day)';
      final budgetRemaining =
          '${AppFormatters.compactCurrency(remainingBudget, isPrivate: isPrivate)} left of ${AppFormatters.compactCurrency(totalBudgetLimit, isPrivate: isPrivate)}';
      final goalAmount =
          '${AppFormatters.compactCurrency(goalSaved, isPrivate: isPrivate)} / ${AppFormatters.compactCurrency(goalTarget, isPrivate: isPrivate)}';

      expect(budgetSubtitle, '17 days left (••••/day)');
      expect(budgetRemaining, '•••• left of ••••');
      expect(goalAmount, '•••• / ••••');

      // Widget test verifying rendering of masked text elements
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text(budgetSubtitle),
                Text(budgetRemaining),
                Text(goalAmount),
              ],
            ),
          ),
        ),
      );

      expect(find.text('17 days left (••••/day)'), findsOneWidget);
      expect(find.text('•••• left of ••••'), findsOneWidget);
      expect(find.text('•••• / ••••'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing);
    });

    testWidgets('renders unmasked budget snapshot and goal targets when isPrivate is false',
        (tester) async {
      const isPrivate = false;
      const daysLeft = 17;
      const perDayLeft = 450.0;
      const remainingBudget = 7650.0;
      const totalBudgetLimit = 25000.0;
      const goalSaved = 15000.0;
      const goalTarget = 50000.0;

      final budgetSubtitle =
          '$daysLeft days left (${AppFormatters.compactCurrency(perDayLeft, isPrivate: isPrivate)}/day)';
      final budgetRemaining =
          '${AppFormatters.compactCurrency(remainingBudget, isPrivate: isPrivate)} left of ${AppFormatters.compactCurrency(totalBudgetLimit, isPrivate: isPrivate)}';
      final goalAmount =
          '${AppFormatters.compactCurrency(goalSaved, isPrivate: isPrivate)} / ${AppFormatters.compactCurrency(goalTarget, isPrivate: isPrivate)}';

      expect(budgetSubtitle, '17 days left (₹450/day)');
      expect(budgetRemaining, '₹7.7k left of ₹25.0k');
      expect(goalAmount, '₹15.0k / ₹50.0k');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text(budgetSubtitle),
                Text(budgetRemaining),
                Text(goalAmount),
              ],
            ),
          ),
        ),
      );

      expect(find.text('17 days left (₹450/day)'), findsOneWidget);
      expect(find.text('₹7.7k left of ₹25.0k'), findsOneWidget);
      expect(find.text('₹15.0k / ₹50.0k'), findsOneWidget);
      expect(find.textContaining('••••'), findsNothing);
    });
  });
}
