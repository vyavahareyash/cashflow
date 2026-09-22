import 'transaction_model.dart';

/// Ephemeral in-memory representation of an uncommitted transaction parsed
/// from voice audio or text monologue (US 1, ADR-0005, CONTEXT.md).
///
/// Holds parsed parameters along with audit flags ([hasUnassignedAccount],
/// [hasUnassignedCategory]) indicating inferred or missing fields requiring
/// user review in the staging sheet before atomic database commit.
class DraftTransaction {
  final String id;
  final double amount;
  final String type; // 'expense', 'income', or 'transfer'
  final int? accountId;
  final int? destinationAccountId;
  final int? categoryId;
  final String date; // 'YYYY-MM-DD'
  final String note;
  final String? rawSpeech;
  final bool hasUnassignedAccount;
  final bool hasUnassignedCategory;

  DraftTransaction({
    String? id,
    required this.amount,
    this.type = 'expense',
    this.accountId,
    this.destinationAccountId,
    this.categoryId,
    required this.date,
    required this.note,
    this.rawSpeech,
    this.hasUnassignedAccount = false,
    this.hasUnassignedCategory = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
  bool get isTransfer => type == 'transfer';

  /// Evaluates whether the draft has all necessary fields to commit cleanly.
  bool get isValid {
    if (amount <= 0) return false;
    if (accountId == null) return false;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) return false;

    if (isTransfer) {
      if (destinationAccountId == null) return false;
      if (destinationAccountId == accountId) return false;
    }

    return true;
  }

  /// Converts this validated draft into a persistent [TransactionModel] for SQLite insertion.
  TransactionModel toTransactionModel() {
    if (!isValid) {
      throw StateError(
        'Cannot convert invalid DraftTransaction (amount: $amount, accountId: $accountId, type: $type) to TransactionModel.',
      );
    }
    return TransactionModel(
      accountId: accountId!,
      destinationAccountId: isTransfer ? destinationAccountId : null,
      categoryId: isExpense ? categoryId : null,
      amount: amount,
      date: date,
      note: note,
      type: type,
    );
  }

  DraftTransaction copyWith({
    String? id,
    double? amount,
    String? type,
    int? accountId,
    int? destinationAccountId,
    int? categoryId,
    String? date,
    String? note,
    String? rawSpeech,
    bool? hasUnassignedAccount,
    bool? hasUnassignedCategory,
  }) {
    return DraftTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      accountId: accountId ?? this.accountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      note: note ?? this.note,
      rawSpeech: rawSpeech ?? this.rawSpeech,
      hasUnassignedAccount: hasUnassignedAccount ?? this.hasUnassignedAccount,
      hasUnassignedCategory:
          hasUnassignedCategory ?? this.hasUnassignedCategory,
    );
  }

  factory DraftTransaction.fromMap(Map<String, dynamic> map) {
    return DraftTransaction(
      id: map['id']?.toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] as String? ?? 'expense',
      accountId: map['account_id'] as int?,
      destinationAccountId: map['destination_account_id'] as int?,
      categoryId: map['category_id'] as int?,
      date: map['date'] as String? ?? '',
      note: map['note'] as String? ?? '',
      rawSpeech: map['raw_speech'] as String?,
      hasUnassignedAccount: map['has_unassigned_account'] as bool? ?? false,
      hasUnassignedCategory: map['has_unassigned_category'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'account_id': accountId,
      'destination_account_id': destinationAccountId,
      'category_id': categoryId,
      'date': date,
      'note': note,
      'raw_speech': rawSpeech,
      'has_unassigned_account': hasUnassignedAccount,
      'has_unassigned_category': hasUnassignedCategory,
    };
  }

  @override
  String toString() =>
      'DraftTransaction(id: $id, amount: $amount, type: $type, accountId: $accountId, destAccountId: $destinationAccountId, categoryId: $categoryId, date: $date, note: "$note", valid: $isValid)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DraftTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          amount == other.amount &&
          type == other.type &&
          accountId == other.accountId &&
          destinationAccountId == other.destinationAccountId &&
          categoryId == other.categoryId &&
          date == other.date &&
          note == other.note &&
          hasUnassignedAccount == other.hasUnassignedAccount &&
          hasUnassignedCategory == other.hasUnassignedCategory;

  @override
  int get hashCode =>
      id.hashCode ^
      amount.hashCode ^
      type.hashCode ^
      accountId.hashCode ^
      destinationAccountId.hashCode ^
      categoryId.hashCode ^
      date.hashCode ^
      note.hashCode ^
      hasUnassignedAccount.hashCode ^
      hasUnassignedCategory.hashCode;
}
