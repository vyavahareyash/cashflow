class Category {
  final int? id;
  final String name;
  final double monthlyBudget;

  Category({this.id, required this.name, this.monthlyBudget = 0.0});

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      monthlyBudget: map['monthly_budget'] == null
          ? 0.0
          : (map['monthly_budget'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'monthly_budget': monthlyBudget};
  }
}
