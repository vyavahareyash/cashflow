class Account {
  final int? id;
  final String name;
  final double balance;
  final String type; // 'Bank' or 'Cash'

  Account({
    this.id,
    required this.name,
    required this.balance,
    required this.type,
  });

  // Convert a Map (from SQLite) into an Account object
  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      name: map['name'],
      balance: map['balance'],
      type: map['type'],
    );
  }

  // Convert an Account object into a Map (to save to SQLite)
  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'balance': balance, 'type': type};
  }
}
