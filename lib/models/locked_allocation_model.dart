class LockedAllocation {
  final int? id;
  final int goalId;
  final int accountId;
  final double amount;
  final String goalName; // Added for easier UI display

  LockedAllocation({
    this.id,
    required this.goalId,
    required this.accountId,
    required this.amount,
    required this.goalName,
  });

  factory LockedAllocation.fromMap(Map<String, dynamic> map) {
    return LockedAllocation(
      id: map['id'],
      goalId: map['goal_id'],
      accountId: map['account_id'],
      amount: map['amount'],
      goalName: map['goal_name'] ?? 'Unknown Goal',
    );
  }
}
