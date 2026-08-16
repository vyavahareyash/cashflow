import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../models/category_model.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';
import '../components/custom_input.dart';
import '../components/custom_button.dart';
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
  double _totalSpent = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
    DatabaseHelper.dataRevision.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    DatabaseHelper.dataRevision.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      _loadBudgets();
    }
  }

  Future<void> _loadBudgets() async {
    if (_categories.isEmpty) {
      setState(() => _isLoading = true);
    }
    final categories = await DatabaseHelper.instance.readAllCategories();
    double totalReserved = 0;
    double totalSpent = 0;
    Map<int, double> spendingMap = {};

    for (var cat in categories) {
      totalReserved += cat.monthlyBudget;
      if (cat.id != null) {
        final spent = await DatabaseHelper.instance
            .getCategorySpendingForCurrentMonth(cat.id!);
        spendingMap[cat.id!] = spent;
        totalSpent += spent;
      }
    }

    if (mounted) {
      setState(() {
        _categories = categories;
        _spending = spendingMap;
        _totalReserved = totalReserved;
        _totalSpent = totalSpent;
        _isLoading = false;
      });
    }
  }

  void _showCategoryDialog({Category? category}) {
    final isEditing = category != null;
    final nameController = TextEditingController(
      text: isEditing ? category.name : '',
    );
    final budgetController = TextEditingController(
      text: isEditing ? category.monthlyBudget.toStringAsFixed(0) : '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.xlargeBorder,
          ),
          title: Text(
            isEditing ? 'Edit Category Budget' : 'Add Category Budget',
            style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomInputField(
                    controller: nameController,
                    label: 'Category Name',
                    hint: 'e.g. Groceries, Entertainment',
                    prefixIcon: Icons.category_rounded,
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Please enter a category name'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CustomInputField(
                    controller: budgetController,
                    label: 'Monthly Budget Target',
                    hint: 'e.g. 5000',
                    prefixText: '₹ ',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a budget amount';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
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
                  Navigator.pop(context);
                  _deleteCategory(category.id!);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CustomButton(
              label: isEditing ? 'Update' : 'Add',
              width: 100,
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final budget = double.parse(budgetController.text.trim());

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
        );
      },
    );
  }

  Future<void> _deleteCategory(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category Budget?'),
        content: const Text(
          'This will remove the monthly budget category allocation. Past transactions will remain intact.',
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
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalProgress = _totalReserved > 0 ? (_totalSpent / _totalReserved) : 0.0;
    final remainingTotal = (_totalReserved - _totalSpent).clamp(0.0, double.infinity);

    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.emerald700),
            )
          : RefreshIndicator(
              onRefresh: _loadBudgets,
              color: AppColors.emerald700,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // 1. TOP SUMMARY CARD
                  _buildBudgetHeaderCard(isDark, totalProgress, remainingTotal),
                  const SizedBox(height: AppSpacing.xl),

                  // 2. SECTION TITLE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Category Allocations',
                        style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_categories.length} Categories',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. CATEGORY LIST
                  if (_categories.isEmpty)
                    CustomCard(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            children: [
                              Icon(
                                Icons.pie_chart_outline_rounded,
                                size: 48,
                                color: isDark ? AppColors.gray600 : AppColors.gray400,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'No budget categories configured yet',
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Tap + below to add your monthly categories like Groceries, Rent, Transport.',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ..._categories.map((cat) {
                      final spent = _spending[cat.id] ?? 0.0;
                      return _buildBudgetItem(cat, spent, isDark);
                    }),

                  const SizedBox(height: AppSpacing.huge),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryDialog(),
        backgroundColor: AppColors.emerald700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Budget', style: AppTypography.labelLarge),
      ),
    );
  }

  Widget _buildBudgetHeaderCard(bool isDark, double totalProgress, double remainingTotal) {
    final isOver = totalProgress > 1.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: AppBorderRadius.xlargeBorder,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.gray200,
          width: 1,
        ),
        boxShadow: isDark ? [] : [AppShadows.level1],
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Monthly Budget',
                style: AppTypography.labelMedium.copyWith(
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: (isOver ? AppColors.danger : AppColors.emerald600).withOpacity(0.12),
                  borderRadius: AppBorderRadius.pillBorder,
                ),
                child: Text(
                  isOver ? 'Over Budget' : 'On Track',
                  style: AppTypography.labelSmall.copyWith(
                    color: isOver ? AppColors.danger : AppColors.emerald600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppFormatters.currency(_totalReserved),
            style: AppTypography.displayLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkText : AppColors.gray900,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // OVERFLOW-PROOF PROGRESS BAR
          ClipRRect(
            borderRadius: AppBorderRadius.pillBorder,
            child: LinearProgressIndicator(
              value: totalProgress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: isDark ? AppColors.darkBorder : AppColors.gray200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? AppColors.danger : AppColors.emerald600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spent so far',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                    Text(
                      AppFormatters.currency(_totalSpent),
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isOver ? AppColors.danger : (isDark ? AppColors.darkText : AppColors.gray900),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Remaining',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                    Text(
                      AppFormatters.currency(remainingTotal),
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.emerald600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetItem(Category cat, double spent, bool isDark) {
    final budget = cat.monthlyBudget;
    final progress = budget > 0 ? spent / budget : 0.0;
    final isOver = progress > 1.0;
    final remaining = (budget - spent).clamp(0.0, double.infinity);
    final style = CategoryStyle.getStyle(cat.name);

    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Icon, Category Name, Spent / Budget, Edit button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: style.color.withOpacity(0.12),
                  borderRadius: AppBorderRadius.mediumBorder,
                ),
                child: Icon(style.icon, color: style.color, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.name,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isOver
                          ? 'Over budget by ₹${(spent - budget).toStringAsFixed(0)}'
                          : '₹${remaining.toStringAsFixed(0)} left of ₹${budget.toStringAsFixed(0)}',
                      style: AppTypography.labelSmall.copyWith(
                        color: isOver ? AppColors.danger : (isDark ? AppColors.gray400 : AppColors.gray600),
                        fontWeight: isOver ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${spent.toStringAsFixed(0)}',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isOver ? AppColors.danger : (isDark ? AppColors.darkText : AppColors.gray900),
                    ),
                  ),
                  Text(
                    'of ₹${budget.toStringAsFixed(0)}',
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                ),
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                constraints: const BoxConstraints(),
                onPressed: () => _showCategoryDialog(category: cat),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Row 2: OVERFLOW-SAFE PROGRESS BAR WITH EXPANDED
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: AppBorderRadius.pillBorder,
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: isDark ? AppColors.darkBorder : AppColors.gray200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOver ? AppColors.danger : style.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isOver ? AppColors.danger : style.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
