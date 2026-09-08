import 'dart:convert';

class BackupCodec {
  static const formatVersion = 1;
  static const schemaVersion = 1;
  static const _tableNames = [
    'accounts',
    'categories',
    'transactions',
    'goals',
    'locked_allocations',
  ];

  static String encode({
    required List<Map<String, dynamic>> accounts,
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> goals,
    required List<Map<String, dynamic>> lockedAllocations,
  }) {
    return jsonEncode({
      'formatVersion': formatVersion,
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'accounts': accounts,
      'categories': categories,
      'transactions': transactions,
      'goals': goals,
      'locked_allocations': lockedAllocations,
    });
  }

  static Map<String, dynamic> decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Backup must contain a JSON object');
    }

    final data = Map<String, dynamic>.from(decoded);
    final formatVersion = data['formatVersion'];
    if (formatVersion != null && formatVersion != formatVersionValue) {
      throw FormatException('Unsupported backup format: $formatVersion');
    }

    for (final tableName in _tableNames) {
      final rows = data[tableName];
      if (rows == null) {
        data[tableName] = <Map<String, dynamic>>[];
      } else if (rows is List && rows.every((row) => row is Map)) {
        data[tableName] = rows
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      } else {
        throw FormatException('Backup table is invalid: $tableName');
      }
    }

    return data;
  }

  static const formatVersionValue = formatVersion;

  static String transactionsCsv(List<Map<String, dynamic>> transactions) {
    final lines = <String>['Amount,Category,Account,Date,Note'];
    for (final transaction in transactions) {
      lines.add(
        [
          transaction['amount'],
          transaction['category_name'],
          transaction['account_name'],
          transaction['date'],
          transaction['note'],
        ].map(_escapeCsv).join(','),
      );
    }
    return '${lines.join('\n')}\n';
  }

  static String _escapeCsv(Object? value) {
    final text = value?.toString() ?? '';
    if (!text.contains(RegExp(r'[",\n\r]'))) return text;
    return '"${text.replaceAll('"', '""')}"';
  }
}
