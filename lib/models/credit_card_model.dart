class CreditCard {
  final int? id;
  final int accountId;
  final double creditLimit;
  final int statementDay;
  final int dueDay;
  final int? defaultLockAccountId;
  final bool autoLock;

  CreditCard({
    this.id,
    required this.accountId,
    required this.creditLimit,
    required this.statementDay,
    required this.dueDay,
    this.defaultLockAccountId,
    this.autoLock = true,
  });

  factory CreditCard.fromMap(Map<String, dynamic> map) {
    return CreditCard(
      id: map['id'],
      accountId: map['account_id'],
      creditLimit: (map['credit_limit'] as num).toDouble(),
      statementDay: map['statement_day'] as int? ?? 1,
      dueDay: map['due_day'] as int? ?? 20,
      defaultLockAccountId: map['default_lock_account_id'] as int?,
      autoLock: (map['auto_lock'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'account_id': accountId,
      'credit_limit': creditLimit,
      'statement_day': statementDay,
      'due_day': dueDay,
      'default_lock_account_id': defaultLockAccountId,
      'auto_lock': autoLock ? 1 : 0,
    };
  }

  CreditCard copyWith({
    int? id,
    int? accountId,
    double? creditLimit,
    int? statementDay,
    int? dueDay,
    int? defaultLockAccountId,
    bool? autoLock,
  }) {
    return CreditCard(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      creditLimit: creditLimit ?? this.creditLimit,
      statementDay: statementDay ?? this.statementDay,
      dueDay: dueDay ?? this.dueDay,
      defaultLockAccountId: defaultLockAccountId ?? this.defaultLockAccountId,
      autoLock: autoLock ?? this.autoLock,
    );
  }
}
