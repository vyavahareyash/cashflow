import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cashflow/config/app_config.dart';
import 'package:cashflow/screens/backup_restore_screen.dart';
import 'package:cashflow/services/database_helper.dart';

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
    AppConfig.setOverrideEnableExternalDonations(null);
    final dbPath = await getDatabasesPath();
    await DatabaseHelper.instance.close();
    await deleteDatabase(join(dbPath, databaseFileName));
  });

  group('AppConfig compile-time and runtime flag tests', () {
    test('Default donations flag enables in debug mode for previewing', () {
      AppConfig.setOverrideEnableExternalDonations(null);
      // In flutter test / debug mode without --dart-define, defaults to kDebugMode (true)
      expect(AppConfig.enableExternalDonations, isTrue);
      expect(AppConfig.buyMeACoffeeUrl, contains('buymeacoffee.com'));
    });

    test('Override flag toggles donations properly', () {
      AppConfig.setOverrideEnableExternalDonations(true);
      expect(AppConfig.enableExternalDonations, isTrue);

      AppConfig.setOverrideEnableExternalDonations(false);
      expect(AppConfig.enableExternalDonations, isFalse);
    });
  });

  group('BackupRestoreScreen Support Development Card', () {
    testWidgets('Support card is hidden when enableExternalDonations is false', (tester) async {
      AppConfig.setOverrideEnableExternalDonations(false);

      await tester.pumpWidget(
        const MaterialApp(
          home: BackupRestoreScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Support & Open Source'), findsNothing);
      expect(find.byKey(const Key('buy_me_a_coffee_button')), findsNothing);
    });

    testWidgets('Support card is displayed when enableExternalDonations is true', (tester) async {
      AppConfig.setOverrideEnableExternalDonations(true);

      await tester.pumpWidget(
        const MaterialApp(
          home: BackupRestoreScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Support & Open Source'), findsOneWidget);
      expect(find.text('Support Development'), findsOneWidget);
      expect(find.byKey(const Key('buy_me_a_coffee_button')), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
    });
  });
}
