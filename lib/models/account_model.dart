class Account {
  final int? id;
  final String name;
  final double balance;
  final String type; // 'Bank', 'Cash', 'Savings', 'Wallet', or 'Credit Card'
  final String? accountNumberSuffix; // Optional last 4 digits for SMS matching

  bool get isCreditCard => type == 'Credit Card';

  Account({
    this.id,
    required this.name,
    required this.balance,
    required this.type,
    this.accountNumberSuffix,
  });

  // Convert a Map (from SQLite) into an Account object
  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      name: map['name'],
      balance: map['balance'],
      type: map['type'],
      accountNumberSuffix: map['account_number_suffix'] as String?,
    );
  }

  // Convert an Account object into a Map (to save to SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'type': type,
      'account_number_suffix': accountNumberSuffix,
    };
  }

  Account copyWith({
    int? id,
    String? name,
    double? balance,
    String? type,
    String? accountNumberSuffix,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      accountNumberSuffix: accountNumberSuffix ?? this.accountNumberSuffix,
    );
  }
}
