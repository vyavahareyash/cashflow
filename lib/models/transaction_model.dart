class TransactionModel {
  final int? id;
  final int accountId;
  final int categoryId;
  final double amount;
  final String date;
  final String note;

  TransactionModel({
    this.id,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    required this.date,
    required this.note,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      accountId: map['account_id'],
      categoryId: map['category_id'],
      amount: map['amount'],
      date: map['date'],
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'account_id': accountId,
      'category_id': categoryId,
      'amount': amount,
      'date': date,
      'note': note,
    };
  }
}
