class Category {
  final int? id;
  final String name;
  final double monthlyBudget;

  Category({this.id, required this.name, required this.monthlyBudget});

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      monthlyBudget: map['monthly_budget'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'monthly_budget': monthlyBudget};
  }
}
