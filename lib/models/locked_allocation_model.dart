class LockedAllocation {
  final int? id;
  final int? goalId;
  final int? creditCardId;
  final int accountId;
  final double amount;
  final String goalName;
  final String? creditCardName;

  LockedAllocation({
    this.id,
    this.goalId,
    this.creditCardId,
    required this.accountId,
    required this.amount,
    this.goalName = '',
    this.creditCardName,
  });

  bool get isCreditCardLock => creditCardId != null;
  bool get isGoalLock => goalId != null;

  String get displayName {
    if (isCreditCardLock) {
      return creditCardName != null && creditCardName!.isNotEmpty
          ? creditCardName!
          : 'Credit Card Bill';
    }
    return goalName.isNotEmpty ? goalName : 'Goal';
  }

  factory LockedAllocation.fromMap(Map<String, dynamic> map) {
    return LockedAllocation(
      id: map['id'],
      goalId: map['goal_id'],
      creditCardId: map['credit_card_id'],
      accountId: map['account_id'],
      amount: (map['amount'] as num).toDouble(),
      goalName: map['goal_name'] ?? '',
      creditCardName: map['credit_card_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'goal_id': goalId,
      'credit_card_id': creditCardId,
      'account_id': accountId,
      'amount': amount,
    };
  }
}
