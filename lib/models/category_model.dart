class Category {
  final int? id;
  final String name;
  final double? monthlyBudget;
  final String? _type;

  Category({
    this.id,
    required this.name,
    this.monthlyBudget,
    String? type = 'expense',
  }) : _type = type;

  String get type => (_type == null || _type!.isEmpty) ? 'expense' : _type!;

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      monthlyBudget: (map['monthly_budget'] as num?)?.toDouble(),
      type: (map['type'] as String?) ?? 'expense',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'monthly_budget': monthlyBudget,
      'type': type,
    };
  }
}
