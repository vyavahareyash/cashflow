import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../models/category_model.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';
import '../components/category_badge.dart';

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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Budgets',
                    style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total Reserved: \$${_totalReserved.toStringAsFixed(2)}',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.gray700),
                  ),
                ],
              ),
              Icon(
                Icons.pie_chart,
                color: AppColors.green700,
                size: 32,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

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
    Color barColor = progress > 1.0 ? AppColors.danger : color;

    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CategoryBadge(
                label: category,
                color: color,
              ),
              Text(
                '\$${spent.toStringAsFixed(2)} / \$${budget.toStringAsFixed(2)}',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppBorderRadius.smallBorder,
            child: LinearProgressIndicator(
              value: progress > 1.0 ? 1.0 : progress,
              minHeight: 10,
              backgroundColor: AppColors.gray200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (progress > 1.0)
            Text(
              'Over budget!',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
