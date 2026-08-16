import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../models/category_model.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';
import '../components/category_badge.dart';
import '../components/custom_input.dart';
import '../components/custom_button.dart';

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

  void _showCategoryDialog({Category? category}) {
    final isEditing = category != null;
    final nameController = TextEditingController(
      text: isEditing ? category.name : '',
    );
    final budgetController = TextEditingController(
      text: isEditing ? category.monthlyBudget.toString() : '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Budget' : 'Add Budget'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomInputField(
                  controller: nameController,
                  label: 'Category Name',
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Please enter a name'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                CustomInputField(
                  controller: budgetController,
                  label: 'Monthly Budget',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter a budget';
                    if (double.tryParse(value) == null) return 'Invalid amount';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (isEditing)
            TextButton(
              onPressed: () {
                _deleteCategory(category.id!);
                Navigator.pop(context);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CustomButton(
            label: isEditing ? 'Update' : 'Add',
            onPressed: () async {
              // ...existing code...
              if (formKey.currentState!.validate()) {
                final name = nameController.text;
                final budget = double.parse(budgetController.text);

                if (isEditing) {
                  await DatabaseHelper.instance.updateCategory(
                    Category(
                      id: category.id,
                      name: name,
                      monthlyBudget: budget,
                    ),
                  );
                } else {
                  await DatabaseHelper.instance.createCategory(
                    Category(name: name, monthlyBudget: budget),
                  );
                }
                Navigator.pop(context);
                _loadBudgets();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: const Text(
          'Are you sure you want to delete this budget category?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteCategory(id);
      _loadBudgets();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Budgets',
                      style: AppTypography.headlineMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Total Reserved: \₹${_totalReserved.toStringAsFixed(2)}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.gray700,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: AppColors.green700,
                      size: 32,
                    ),
                    onPressed: () => _showCategoryDialog(),
                  ),
                  const Icon(
                    Icons.pie_chart,
                    color: AppColors.green700,
                    size: 32,
                  ),
                ],
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
                        cat,
                        spent,
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

  Widget _buildBudgetItem(Category cat, double spent, Color color) {
    double budget = cat.monthlyBudget;
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
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: CategoryBadge(label: cat.name, color: color),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '\₹${spent.toStringAsFixed(2)} / \₹${budget.toStringAsFixed(2)}',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      size: 18,
                      color: AppColors.gray700,
                    ),
                    onPressed: () => _showCategoryDialog(category: cat),
                  ),
                ],
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
