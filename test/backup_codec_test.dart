import 'package:flutter_test/flutter_test.dart';
import 'package:cashflow/services/backup_codec.dart';

void main() {
  test('round trips backup rows and metadata', () {
    final source = BackupCodec.encode(
      accounts: [
        {'id': 7, 'name': 'Primary'},
      ],
      categories: [],
      transactions: [
        {'id': 9, 'note': 'Dinner, "team"\nFriday'},
      ],
      goals: [],
      lockedAllocations: [],
    );

    final decoded = BackupCodec.decode(source);

    expect(decoded['formatVersion'], BackupCodec.formatVersion);
    expect(decoded['accounts'], [
      {'id': 7, 'name': 'Primary'},
    ]);
    expect(decoded['transactions'], [
      {'id': 9, 'note': 'Dinner, "team"\nFriday'},
    ]);
  });

  test('accepts legacy table-only backups', () {
    final decoded = BackupCodec.decode(
      '{"accounts":[{"id":1}],"categories":[]}',
    );

    expect(decoded['accounts'], [
      {'id': 1},
    ]);
    expect(decoded['goals'], isEmpty);
  });

  test('escapes CSV fields containing commas, quotes, and newlines', () {
    final csv = BackupCodec.transactionsCsv([
      {
        'amount': 12,
        'category_name': 'Food, dining',
        'account_name': 'Main "account"',
        'date': '2026-09-05',
        'note': 'Line one\nLine two',
      },
    ]);

    expect(
      csv,
      'Amount,Category,Account,Date,Note\n'
      '12,"Food, dining","Main ""account""",2026-09-05,"Line one\nLine two"\n',
    );
  });

  test('rejects malformed table payloads', () {
    expect(
      () => BackupCodec.decode('{"accounts":{"id":1}}'),
      throwsA(isA<FormatException>()),
    );
  });
}
