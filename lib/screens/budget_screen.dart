import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../models/category_model.dart';
import '../models/salary_cycle.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';
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
  Map<int, double> _incomeMap = {};
  double _totalBudgetLimit = 0.0;
  double _totalSpent = 0.0;
  double _totalIncomeThisCycle = 0.0;
  int _salaryDay = 1;
  bool _isLoading = true;
  String _selectedTab = 'expense'; // 'expense' or 'income'

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
    final salaryDay = await DatabaseHelper.instance.getSalaryDay();
    final cycle = SalaryCycle.resolve(salaryDay: salaryDay);
    final monthlySpending =
        await DatabaseHelper.instance.getMonthlySpendingByCategoryId(cycle: cycle);
    final monthlyIncome =
        await DatabaseHelper.instance.getMonthlyIncomeByCategoryId(cycle: cycle);
    double totalBudgetLimit = 0;
    double totalSpent = 0;
    Map<int, double> spendingMap = {};

    for (var cat in categories.where((c) => c.isExpense)) {
      final budget = cat.monthlyBudget;
      final hasBudget = budget != null && budget > 0;
      if (hasBudget) {
        totalBudgetLimit += budget;
      }
      if (cat.id != null) {
        final spent = monthlySpending[cat.id!] ?? 0.0;
        spendingMap[cat.id!] = spent;
        if (hasBudget) {
          totalSpent += spent;
        }
      }
    }

    double totalIncome = 0;
    for (var cat in categories.where((c) => c.isIncome)) {
      if (cat.id != null) {
        totalIncome += monthlyIncome[cat.id!] ?? 0.0;
      }
    }

    if (mounted) {
      setState(() {
        _categories = categories;
        _spending = spendingMap;
        _incomeMap = monthlyIncome;
        _totalBudgetLimit = totalBudgetLimit;
        _totalSpent = totalSpent;
        _totalIncomeThisCycle = totalIncome;
        _salaryDay = salaryDay;
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
      text: isEditing && category.monthlyBudget != null
          ? category.monthlyBudget!.toStringAsFixed(0)
          : '',
    );
    String type = isEditing ? category.type : _selectedTab;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final isExpense = type == 'expense';

            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: AppBorderRadius.xlargeBorder,
              ),
              title: Text(
                isEditing
                    ? (isExpense ? 'Edit Expense Budget' : 'Edit Income Category')
                    : (isExpense ? 'Add Expense Budget' : 'Add Income Category'),
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isEditing) ...[
                        Text(
                          'Category Type',
                          style: AppTypography.labelMedium.copyWith(
                            color: isDark ? AppColors.gray300 : AppColors.gray700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        DropdownButtonFormField<String>(
                          initialValue: type,
                          isExpanded: true,
                          dropdownColor: isDark
                              ? AppColors.darkSurfaceElevated
                              : AppColors.white,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark
                                ? AppColors.darkSurface
                                : AppColors.gray50,
                            border: OutlineInputBorder(
                              borderRadius: AppBorderRadius.mediumBorder,
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.gray300,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'expense',
                              child: Text('Expense Budget'),
                            ),
                            DropdownMenuItem(
                              value: 'income',
                              child: Text('Income Category'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => type = val);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      CustomInputField(
                        controller: nameController,
                        label: 'Category Name',
                        hint: isExpense
                            ? 'e.g. Groceries, Entertainment'
                            : 'e.g. Salary, Freelance, Rental',
                        prefixIcon: Icons.category_rounded,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Please enter a category name'
                            : null,
                      ),
                      if (isExpense) ...[
                        const SizedBox(height: AppSpacing.md),
                        CustomInputField(
                          controller: budgetController,
                          label: 'Monthly Budget Target',
                          hint: 'Optional, e.g. 5000',
                          prefixText: '₹ ',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            if (value != null &&
                                value.trim().isNotEmpty &&
                                double.tryParse(value.trim()) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                if (isEditing)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      _deleteCategory(category.id!);
                    },
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                CustomButton(
                  label: isEditing ? 'Update' : 'Add',
                  width: 100,
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final name = nameController.text.trim();
                      final budgetText = budgetController.text.trim();
                      final budget = (isExpense && budgetText.isNotEmpty)
                          ? double.tryParse(budgetText)
                          : null;

                      if (isEditing) {
                        await DatabaseHelper.instance.updateCategory(
                          Category(
                            id: category.id,
                            name: name,
                            type: type,
                            monthlyBudget: budget,
                          ),
                        );
                      } else {
                        await DatabaseHelper.instance.createCategory(
                          Category(
                            name: name,
                            type: type,
                            monthlyBudget: budget,
                          ),
                        );
                      }
                      if (!mounted || !dialogCtx.mounted) return;
                      Navigator.pop(dialogCtx);
                      _loadBudgets();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCategory(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: const Text(
          'This will remove the category. Past transactions will remain intact.',
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
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
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
    final totalProgress = _totalBudgetLimit > 0
        ? (_totalSpent / _totalBudgetLimit)
        : 0.0;
    final remainingTotal = (_totalBudgetLimit - _totalSpent).clamp(
      0.0,
      double.infinity,
    );

    final cycle = SalaryCycle.resolve(salaryDay: _salaryDay);
    final expenseCategories = _categories.where((c) => c.isExpense).toList();
    final incomeCategories = _categories.where((c) => c.isIncome).toList();

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
                  // SEGMENTED CONTROL: EXPENSE BUDGETS vs INCOME CATEGORIES
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: SegmentedButton<String>(
                      key: const Key('budget_tab_segmented_button'),
                      segments: const [
                        ButtonSegment<String>(
                          value: 'expense',
                          label: Text('Expense Budgets'),
                          icon: Icon(Icons.pie_chart_outline_rounded),
                        ),
                        ButtonSegment<String>(
                          value: 'income',
                          label: Text('Income Categories'),
                          icon: Icon(Icons.savings_outlined),
                        ),
                      ],
                      selected: {_selectedTab},
                      onSelectionChanged: (newSelection) {
                        setState(() => _selectedTab = newSelection.first);
                      },
                    ),
                  ),

                  if (_selectedTab == 'expense') ...[
                    // 1. TOP SUMMARY CARD
                    _buildBudgetHeaderCard(
                      isDark,
                      totalProgress,
                      remainingTotal,
                      cycle,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 2. SECTION TITLE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Category Allocations',
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${expenseCategories.length} Categories',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark ? AppColors.gray400 : AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 3. CATEGORY LIST
                    if (expenseCategories.isEmpty)
                      CustomCard(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.pie_chart_outline_rounded,
                                  size: 48,
                                  color: isDark
                                      ? AppColors.gray600
                                      : AppColors.gray400,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'No expense budgets configured yet',
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Tap + below to add categories like Groceries, Rent, or Transport.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: isDark
                                        ? AppColors.gray400
                                        : AppColors.gray600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ...expenseCategories.map((cat) {
                        final spent = _spending[cat.id] ?? 0.0;
                        return _buildBudgetItem(cat, spent, isDark);
                      }),
                  ] else ...[
                    // 1. INCOME SUMMARY CARD
                    _buildIncomeHeaderCard(isDark, cycle),
                    const SizedBox(height: AppSpacing.xl),

                    // 2. SECTION TITLE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Income Streams',
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${incomeCategories.length} Categories',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark ? AppColors.gray400 : AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 3. INCOME CATEGORY LIST
                    if (incomeCategories.isEmpty)
                      CustomCard(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.savings_outlined,
                                  size: 48,
                                  color: isDark
                                      ? AppColors.gray600
                                      : AppColors.gray400,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'No income categories configured yet',
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Tap + below to add income sources like Salary, Freelance, or Rental.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: isDark
                                        ? AppColors.gray400
                                        : AppColors.gray600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ...incomeCategories.map((cat) {
                        final income = _incomeMap[cat.id] ?? 0.0;
                        return _buildIncomeItem(cat, income, isDark);
                      }),
                  ],

                  const SizedBox(height: AppSpacing.huge),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'budget-add-fab',
        onPressed: () => _showCategoryDialog(),
        backgroundColor: AppColors.emerald700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _selectedTab == 'expense' ? 'Add Budget' : 'Add Category',
          style: AppTypography.labelLarge,
        ),
      ),
    );
  }

  Widget _buildIncomeHeaderCard(bool isDark, SalaryCycle cycle) {
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total Income (This Cycle)',
                    style: AppTypography.labelMedium.copyWith(
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Tooltip(
                    message:
                        'Cycle: ${cycle.cycleLabel} • ${cycle.resetCountdownText}',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.emerald600.withValues(alpha: 0.12),
                  borderRadius: AppBorderRadius.pillBorder,
                ),
                child: Text(
                  'Income Stream',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.emerald600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppFormatters.currency(_totalIncomeThisCycle),
            style: AppTypography.displayLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.emerald600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeItem(Category cat, double income, bool isDark) {
    final style = CategoryStyle.getStyle(cat.name);
    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.12),
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
                  'Income Category',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            income > 0
                ? '+${AppFormatters.currency(income)}'
                : '₹0 earned',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: income > 0
                  ? AppColors.emerald600
                  : (isDark ? AppColors.gray400 : AppColors.gray600),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: isDark ? AppColors.gray400 : AppColors.gray600,
            ),
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            constraints: const BoxConstraints(),
            tooltip: 'Edit Category',
            onPressed: () => _showCategoryDialog(category: cat),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetHeaderCard(
    bool isDark,
    double totalProgress,
    double remainingTotal,
    SalaryCycle cycle,
  ) {
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total Monthly Budget',
                    style: AppTypography.labelMedium.copyWith(
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Tooltip(
                    message:
                        'Cycle: ${cycle.cycleLabel} • ${cycle.resetCountdownText} • Zero rollover across cycles',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: (isOver ? AppColors.danger : AppColors.emerald600)
                      .withValues(alpha: 0.12),
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
            AppFormatters.currency(_totalBudgetLimit),
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
              backgroundColor: isDark
                  ? AppColors.darkBorder
                  : AppColors.gray200,
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
                        color: isOver
                            ? AppColors.danger
                            : (isDark ? AppColors.darkText : AppColors.gray900),
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
          if (isOver) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: AppBorderRadius.mediumBorder,
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.danger,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Total spend exceeds budget by ${AppFormatters.currency(_totalSpent - _totalBudgetLimit)}. Resets on ${cycle.resetCountdownText.toLowerCase()}.',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetItem(Category cat, double spent, bool isDark) {
    final budget = cat.monthlyBudget;
    if (budget == null) {
      final style = CategoryStyle.getStyle(cat.name);
      return CustomCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.12),
                borderRadius: AppBorderRadius.mediumBorder,
              ),
              child: Icon(style.icon, color: style.color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                cat.name,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              'Spent ${AppFormatters.currency(spent)}',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.gray900,
              ),
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
      );
    }

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
                  color: style.color.withValues(alpha: 0.12),
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
                        color: isOver
                            ? AppColors.danger
                            : (isDark ? AppColors.gray400 : AppColors.gray600),
                        fontWeight: isOver
                            ? FontWeight.bold
                            : FontWeight.normal,
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
                      color: isOver
                          ? AppColors.danger
                          : (isDark ? AppColors.darkText : AppColors.gray900),
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
                padding: const EdgeInsets.all(AppSpacing.xs),
                constraints: const BoxConstraints(
                  minWidth: AppComponentSizes.minTouchTarget,
                  minHeight: AppComponentSizes.minTouchTarget,
                ),
                tooltip: 'Edit Category',
                onPressed: () => _showCategoryDialog(category: cat),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Row 2: OVERFLOW-SAFE PROGRESS BAR WITH ANIMATION
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: AppBorderRadius.pillBorder,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0.0,
                      end: progress.clamp(0.0, 1.0),
                    ),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedVal, _) => LinearProgressIndicator(
                      value: animatedVal,
                      minHeight: 8,
                      backgroundColor: isDark
                          ? AppColors.darkBorder
                          : AppColors.gray200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOver ? AppColors.danger : style.color,
                      ),
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
          if (isOver) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: AppBorderRadius.smallBorder,
              ),
              child: Text(
                '+₹${(spent - budget).toStringAsFixed(0)} over limit',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
