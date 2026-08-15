class LockedAllocation {
  final int? id;
  final int planId;
  final int accountId;
  final double amount;
  final String planName; // Added for easier UI display

  LockedAllocation({
    this.id,
    required this.planId,
    required this.accountId,
    required this.amount,
    required this.planName,
  });

  factory LockedAllocation.fromMap(Map<String, dynamic> map) {
    return LockedAllocation(
      id: map['id'],
      planId: map['plan_id'],
      accountId: map['account_id'],
      amount: map['amount'],
      planName: map['plan_name'] ?? 'Unknown Plan',
    );
  }
}
