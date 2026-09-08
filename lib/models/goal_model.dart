class Goal {
  final int? id;
  final String name;
  final double totalTarget;
  final String targetDate;
  final double currentSaved;

  Goal({
    this.id,
    required this.name,
    required this.totalTarget,
    required this.targetDate,
    required this.currentSaved,
  });

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'],
      name: map['name'],
      totalTarget: map['total_target'],
      targetDate: map['target_date'],
      currentSaved: map['current_saved'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'total_target': totalTarget,
      'target_date': targetDate,
      'current_saved': currentSaved,
    };
  }
}
