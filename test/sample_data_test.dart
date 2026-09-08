import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/models/goal_model.dart';
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

  test('seeded demo data exercises the complete transaction history', () async {
    final db = DatabaseHelper.instance;

    await db.seedSampleData();
    final history = await db.getTransactionHistory();
    final types = history.map((row) => row['type']).toSet();

    expect(
      types,
      containsAll([
        'expense',
        'income',
        'transfer',
        'goal_lock',
        'goal_unlock',
        'goal_payment',
      ]),
    );
    final periods = history
        .map((row) => DateTime.parse(row['date'] as String))
        .map((date) => '${date.year}-${date.month}')
        .toSet();
    expect(periods, hasLength(greaterThan(1)));
    expect(history.any((row) => row['category_name'] == 'Groceries'), isTrue);
    expect(
      history.any((row) => row['destination_account_name'] != null),
      isTrue,
    );
    expect(history.any((row) => row['goal_name'] != null), isTrue);

    final database = await db.database;
    final lockedAllocations = await database.query('locked_allocations');
    final goals = await db.readAllGoals();

    expect(lockedAllocations, isNotEmpty);
    expect(
      goals,
      everyElement(
        predicate((Object? goal) => (goal as Goal).currentSaved > 0),
      ),
    );
    for (final goal in goals) {
      final lockedTotal = lockedAllocations
          .where((row) => row['goal_id'] == goal.id)
          .fold<double>(
            0.0,
            (total, row) => total + (row['amount'] as num).toDouble(),
          );
      expect(lockedTotal, goal.currentSaved);
    }
  });
}
