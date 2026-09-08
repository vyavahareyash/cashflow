class TransactionModel {
  final int? id;
  final int accountId;
  final int? destinationAccountId;
  final int? categoryId;
  final int? planId;
  final double amount;
  final String date;
  final String note;
  final String type;

  TransactionModel({
    this.id,
    required this.accountId,
    this.destinationAccountId,
    this.categoryId,
    this.planId,
    required this.amount,
    required this.date,
    required this.note,
    this.type = 'expense',
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      accountId: map['account_id'],
      destinationAccountId: map['destination_account_id'],
      categoryId: map['category_id'],
      planId: map['plan_id'],
      amount: (map['amount'] as num).toDouble(),
      date: map['date'],
      note: map['note'] ?? '',
      type: map['type'] ?? 'expense',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'account_id': accountId,
      'destination_account_id': destinationAccountId,
      'category_id': categoryId,
      'plan_id': planId,
      'amount': amount,
      'date': date,
      'note': note,
      'type': type,
    };
  }
}
