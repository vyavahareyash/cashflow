import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../models/category_model.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<Category> _categories = [];
  Map<int, double> _spending = {};
  double _totalReserved = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  void _loadBudgets() async {
    final categories = await DatabaseHelper.instance.readAllCategories();
    double totalReserved = 0;
    Map<int, double> spendingMap = {};

    for (var cat in categories) {
      totalReserved += cat.monthlyBudget;
      if (cat.id != null) {
        final spent = await DatabaseHelper.instance
            .getCategorySpendingForCurrentMonth(cat.id!);
        spendingMap[cat.id!] = spent;
      }
    }

    setState(() {
      _categories = categories;
      _spending = spendingMap;
      _totalReserved = totalReserved;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Budgets',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Total Reserved: \$${_totalReserved.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 25),

          Expanded(
            child: _categories.isEmpty
                ? const Center(child: Text('No categories found.'))
                : ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final spent = _spending[cat.id] ?? 0.0;
                      return _buildBudgetItem(
                        cat.name,
                        spent,
                        cat.monthlyBudget,
                        _getCategoryColor(cat.name),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String name) {
    switch (name) {
      case 'Groceries':
        return Colors.orange;
      case 'Transport':
        return Colors.blue;
      case 'Entertainment':
        return Colors.purple;
      case 'Dining Out':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  Widget _buildBudgetItem(
    String category,
    double spent,
    double budget,
    Color color,
  ) {
    double progress = budget > 0 ? spent / budget : 0.0;
    Color barColor = progress > 1.0 ? Colors.red : color;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${spent.toStringAsFixed(2)} / \$${budget.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress > 1.0 ? 1.0 : progress,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 8),
            if (progress > 1.0)
              const Text(
                'Over budget!',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
