import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database_helper.dart';
import '../models/goal_model.dart';
import '../models/category_model.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';
import '../components/custom_input.dart';
import '../components/custom_button.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<Goal> _goals = [];
  double _totalLocked = 0.0;
  double _totalTarget = 0.0;
  int _salaryDay = 1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    DatabaseHelper.dataRevision.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    DatabaseHelper.dataRevision.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_goals.isEmpty) {
      setState(() => _isLoading = true);
    }
    final goals = await DatabaseHelper.instance.readAllGoals();
    final locked = await DatabaseHelper.instance.getTotalLockedAmount();
    final salaryDay = await DatabaseHelper.instance.getSalaryDay();

    double totalTarget = 0.0;
    for (var p in goals) {
      totalTarget += p.totalTarget;
    }

    if (mounted) {
      setState(() {
        _goals = goals;
        _totalLocked = locked;
        _totalTarget = totalTarget;
        _salaryDay = salaryDay;
        _isLoading = false;
      });
    }
  }

  void _showAddGoalDialog() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    DateTime targetDate = DateTime.now().add(const Duration(days: 90));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: AppBorderRadius.xlargeBorder,
            ),
            title: Text(
              'Create Sinking Fund / Goal',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomInputField(
                      controller: nameController,
                      label: 'Goal Name',
                      hint: 'e.g. Car Insurance, Vacation, MacBook',
                      prefixIcon: Icons.savings_rounded,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Please enter a goal name'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomInputField(
                      controller: targetController,
                      label: 'Target Amount',
                      hint: 'e.g. 50000',
                      prefixText: '₹ ',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a target amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      title: Text(
                        'Target Date',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('MMM dd, yyyy').format(targetDate),
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.emerald700,
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: targetDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) {
                          setStateDialog(() => targetDate = picked);
                        }
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: AppBorderRadius.mediumBorder,
                        side: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.gray300,
                        ),
                      ),
                      tileColor: isDark
                          ? AppColors.darkSurface
                          : AppColors.gray50,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              CustomButton(
                label: 'Save Goal',
                width: 120,
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    await DatabaseHelper.instance.createGoal(
                      Goal(
                        name: nameController.text.trim(),
                        totalTarget:
                            double.tryParse(targetController.text.trim()) ??
                            0.0,
                        targetDate: DateFormat('yyyy-MM-dd').format(targetDate),
                        currentSaved: 0.0,
                      ),
                    );
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                    _loadData();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditGoalDialog(Goal goal) {
    showDialog(
      context: context,
      builder: (dialogCtx) => EditGoalDialog(
        goal: goal,
        onDelete: () {
          Navigator.pop(dialogCtx);
          _confirmDeleteGoal(goal);
        },
        onUpdate: (updatedGoal) async {
          await DatabaseHelper.instance.updateGoal(updatedGoal);
          _loadData();
        },
      ),
    );
  }

  void _confirmDeleteGoal(Goal goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sinking Fund?'),
        content: Text(
          'Deleting "${goal.name}" will unlock all saved funds (${AppFormatters.currency(goal.currentSaved)}) and return them back to their original physical accounts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.deleteGoal(goal.id!);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              _loadData();
            },
            child: const Text(
              'Delete & Unlock',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContributionLog(Goal goal) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Goal currentGoal = goal;
    List<Map<String, dynamic>> contributions =
        await DatabaseHelper.instance.getGoalContributions(currentGoal.id!);
    List<Map<String, dynamic>> transactions =
        await DatabaseHelper.instance.getGoalTransactions(currentGoal.id!);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> reloadModal() async {
              final updatedGoal =
                  await DatabaseHelper.instance.readGoal(currentGoal.id!);
              final updatedContribs = await DatabaseHelper.instance
                  .getGoalContributions(currentGoal.id!);
              final updatedTxs = await DatabaseHelper.instance
                  .getGoalTransactions(currentGoal.id!);
              if (mounted) {
                setModalState(() {
                  if (updatedGoal != null) currentGoal = updatedGoal;
                  contributions = updatedContribs;
                  transactions = updatedTxs;
                });
              }
            }

            final progress = currentGoal.totalTarget > 0
                ? (currentGoal.currentSaved / currentGoal.totalTarget)
                : 0.0;
            final percent = (progress * 100).clamp(0, 100).toInt();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.md,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.gray700 : AppColors.gray300,
                          borderRadius: AppBorderRadius.pillBorder,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color:
                                AppColors.emerald500.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.savings_rounded,
                            color: AppColors.emerald700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentGoal.name,
                                style: AppTypography.titleLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Goal Contributions & Activity',
                                style: AppTypography.labelSmall.copyWith(
                                  color: isDark
                                      ? AppColors.gray400
                                      : AppColors.gray600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Goal Status & Progress Summary Card
                    CustomCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Saved',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: isDark
                                          ? AppColors.gray400
                                          : AppColors.gray600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${AppFormatters.currency(currentGoal.currentSaved)} / ${AppFormatters.currency(currentGoal.totalTarget)}',
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.emerald700,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.emerald500
                                      .withValues(alpha: 0.12),
                                  borderRadius: AppBorderRadius.smallBorder,
                                ),
                                child: Text(
                                  '$percent% saved',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.emerald700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ClipRRect(
                            borderRadius: AppBorderRadius.pillBorder,
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: isDark
                                  ? AppColors.gray800
                                  : AppColors.gray200,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.emerald600,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: isDark
                                    ? AppColors.gray400
                                    : AppColors.gray600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                currentGoal.formattedTargetDate,
                                style: AppTypography.labelSmall.copyWith(
                                  color: isDark
                                      ? AppColors.gray400
                                      : AppColors.gray600,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                '•',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.gray500
                                      : AppColors.gray400,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                currentGoal.deadlineStatusText(),
                                style: AppTypography.labelSmall.copyWith(
                                  color: currentGoal.isOverdue()
                                      ? AppColors.danger
                                      : (isDark
                                          ? AppColors.gray400
                                          : AppColors.gray600),
                                  fontWeight: currentGoal.isOverdue()
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Section 1: Locked Allocations by Account
                    Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 16,
                          color: AppColors.emerald700,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Locked Funds by Account',
                          style: AppTypography.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (contributions.isEmpty)
                      CustomCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Center(
                          child: Text(
                            'No funds currently locked for this goal.',
                            style: AppTypography.labelMedium.copyWith(
                              color: isDark
                                  ? AppColors.gray400
                                  : AppColors.gray600,
                            ),
                          ),
                        ),
                      )
                    else
                      ...contributions.map((contrib) {
                        final amt =
                            (contrib['amount'] as num?)?.toDouble() ?? 0.0;
                        final pct = currentGoal.currentSaved > 0
                            ? (amt / currentGoal.currentSaved * 100).toInt()
                            : 0;
                        return CustomCard(
                          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.xs),
                                    decoration: BoxDecoration(
                                      color: AppColors.emerald500
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_rounded,
                                      color: AppColors.emerald700,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contrib['account_name'] ?? 'Account',
                                        style:
                                            AppTypography.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (pct > 0)
                                        Text(
                                          '$pct% of total saved',
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                            color: isDark
                                                ? AppColors.gray400
                                                : AppColors.gray600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              Text(
                                AppFormatters.currency(amt),
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.emerald700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: AppSpacing.lg),

                    // Section 2: Contribution & Activity History
                    Row(
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: AppColors.emerald700,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Contribution & Activity History',
                          style: AppTypography.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (transactions.isEmpty)
                      CustomCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 32,
                                color: isDark
                                    ? AppColors.gray600
                                    : AppColors.gray400,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'No transactions recorded for this goal yet.',
                                style: AppTypography.labelMedium.copyWith(
                                  color: isDark
                                      ? AppColors.gray400
                                      : AppColors.gray600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...transactions.map((tx) {
                        final type = tx['type'] as String? ?? 'goal_lock';
                        final amt =
                            (tx['amount'] as num?)?.toDouble() ?? 0.0;
                        final dateStr = tx['date'] as String? ?? '';
                        final date =
                            DateTime.tryParse(dateStr) ?? DateTime.now();
                        final note = tx['note'] as String? ?? '';
                        final accName =
                            tx['account_name'] as String? ?? 'Account';

                        IconData icon;
                        Color typeColor;
                        String typeTitle;
                        String prefix;

                        switch (type) {
                          case 'goal_unlock':
                            icon = Icons.lock_open_rounded;
                            typeColor = AppColors.warning;
                            typeTitle = 'Unlocked Funds';
                            prefix = '−';
                            break;
                          case 'goal_payment':
                            icon = Icons.payments_rounded;
                            typeColor = AppColors.info;
                            typeTitle = 'Goal Settlement';
                            prefix = '−';
                            break;
                          case 'goal_lock':
                          default:
                            icon = Icons.lock_rounded;
                            typeColor = AppColors.emerald700;
                            typeTitle = 'Locked Funds';
                            prefix = '+';
                            break;
                        }

                        return CustomCard(
                          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.xs + 2),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  icon,
                                  color: typeColor,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      typeTitle,
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '$accName • ${DateFormat('MMM dd, yyyy').format(date)}',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: isDark
                                            ? AppColors.gray400
                                            : AppColors.gray600,
                                      ),
                                    ),
                                    if (note.isNotEmpty)
                                      Text(
                                        note,
                                        style:
                                            AppTypography.labelSmall.copyWith(
                                          fontStyle: FontStyle.italic,
                                          color: isDark
                                              ? AppColors.gray400
                                              : AppColors.gray600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$prefix${AppFormatters.currency(amt)}',
                                    style: AppTypography.labelLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: typeColor,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        iconSize: 16,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 28,
                                          minHeight: 28,
                                        ),
                                        tooltip: 'Edit',
                                        onPressed: () => _editGoalTransaction(
                                          sheetContext,
                                          tx,
                                          reloadModal,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                        ),
                                        iconSize: 16,
                                        color: AppColors.danger,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 28,
                                          minHeight: 28,
                                        ),
                                        tooltip: 'Delete',
                                        onPressed: () => _deleteGoalTransaction(
                                          sheetContext,
                                          tx,
                                          reloadModal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editGoalTransaction(
    BuildContext parentContext,
    Map<String, dynamic> tx,
    Future<void> Function() onUpdated,
  ) async {
    final accounts = await DatabaseHelper.instance.readAllAccounts();
    final amountNum = (tx['amount'] as num).toDouble();
    final amountController = TextEditingController(
      text: amountNum.truncateToDouble() == amountNum
          ? amountNum.toStringAsFixed(0)
          : amountNum.toStringAsFixed(2),
    );
    final noteController =
        TextEditingController(text: tx['note'] as String? ?? '');
    DateTime selectedDate =
        DateTime.tryParse(tx['date'] as String? ?? '') ?? DateTime.now();
    int selectedAccountId = tx['account_id'] as int;

    if (!accounts.any((a) => a.id == selectedAccountId) &&
        accounts.isNotEmpty) {
      selectedAccountId = accounts.first.id!;
    }

    if (!parentContext.mounted) return;

    await showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (editCtx) {
        final isDark = Theme.of(editCtx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (_, setEditState) {
            return Container(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
                bottom:
                    MediaQuery.of(editCtx).viewInsets.bottom + AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.white,
                borderRadius: const BorderRadius.vertical(
                  top: AppBorderRadius.xlarge,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Goal Allocation',
                          style: AppTypography.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(editCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      key: const Key('edit_goal_transaction_amount_field'),
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(
                          borderRadius: AppBorderRadius.mediumBorder,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.calendar_today_rounded,
                        color: AppColors.emerald600,
                      ),
                      title: const Text('Transaction Date'),
                      subtitle:
                          Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                      trailing: const Icon(Icons.arrow_drop_down_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: editCtx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setEditState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<int>(
                      key: const Key(
                        'edit_goal_transaction_account_dropdown',
                      ),
                      initialValue: selectedAccountId,
                      decoration: const InputDecoration(
                        labelText: 'Account',
                        border: OutlineInputBorder(
                          borderRadius: AppBorderRadius.mediumBorder,
                        ),
                      ),
                      items: accounts.map((a) {
                        return DropdownMenuItem<int>(
                          value: a.id,
                          child: Text(
                            '${a.name} (${AppFormatters.compactCurrency(a.balance)})',
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setEditState(() => selectedAccountId = val);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      key: const Key('edit_goal_transaction_note_field'),
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note / Description',
                        border: OutlineInputBorder(
                          borderRadius: AppBorderRadius.mediumBorder,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      key: const Key('edit_goal_transaction_save_btn'),
                      onPressed: () async {
                        final parsed =
                            double.tryParse(amountController.text.trim());
                        if (parsed == null || parsed <= 0) {
                          ScaffoldMessenger.of(editCtx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter a valid amount greater than 0',
                              ),
                            ),
                          );
                          return;
                        }

                        try {
                          await DatabaseHelper.instance.updateTransaction(
                            id: tx['id'],
                            amount: parsed,
                            date: selectedDate.toIso8601String(),
                            accountId: selectedAccountId,
                            note: noteController.text.trim(),
                          );
                          if (editCtx.mounted) {
                            Navigator.pop(editCtx);
                          }
                          await onUpdated();
                          if (!parentContext.mounted) return;
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Goal transaction updated successfully.',
                              ),
                              backgroundColor: AppColors.emerald700,
                            ),
                          );
                        } catch (e) {
                          if (editCtx.mounted) {
                            ScaffoldMessenger.of(editCtx).showSnackBar(
                              SnackBar(
                                content: Text('Error updating transaction: $e'),
                              ),
                            );
                          }
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.emerald700,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppBorderRadius.mediumBorder,
                        ),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteGoalTransaction(
    BuildContext parentContext,
    Map<String, dynamic> tx,
    Future<void> Function() onDeleted,
  ) async {
    final type = tx['type'] as String? ?? 'goal_lock';
    final amount = (tx['amount'] as num).toDouble();
    final accountName = tx['account_name'] as String? ?? 'Account';

    String title;
    String content;
    String actionText;

    switch (type) {
      case 'goal_unlock':
        title = 'Delete Goal Unlock?';
        content =
            'This will delete the unlock record and re-lock ${AppFormatters.currency(amount)} into the goal.';
        actionText = 'Delete & Re-lock';
        break;
      case 'goal_payment':
        title = 'Delete Goal Payment?';
        content =
            'This will refund ${AppFormatters.currency(amount)} to $accountName and restore the locked goal balance.';
        actionText = 'Delete & Restore';
        break;
      case 'goal_lock':
      default:
        title = 'Delete Goal Lock?';
        content =
            'This will delete the lock record and release ${AppFormatters.currency(amount)} back to spendable funds in $accountName.';
        actionText = 'Delete & Release';
        break;
    }

    final confirmed = await showDialog<bool>(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('confirm_delete_goal_transaction_btn'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              actionText,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deleteTransaction(tx['id']);
        await onDeleted();
        if (!parentContext.mounted) return;
        ScaffoldMessenger.of(parentContext).showSnackBar(
          const SnackBar(
            content: Text('Goal transaction deleted successfully.'),
            backgroundColor: AppColors.emerald700,
          ),
        );
      } catch (e) {
        if (!parentContext.mounted) return;
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(content: Text('Error deleting transaction: $e')),
        );
      }
    }
  }

  void _showContributionDialog(Goal goal) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accounts = await DatabaseHelper.instance.readAllAccounts();
    final amountController = TextEditingController();
    int? selectedAccountId = accounts.isNotEmpty ? accounts.first.id : null;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.gray700 : AppColors.gray300,
                          borderRadius: AppBorderRadius.pillBorder,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Lock Funds for "${goal.name}"',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'This marks money inside a physical account as reserved for this future goal.',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    CustomInputField(
                      controller: amountController,
                      label: 'Amount to Lock',
                      prefixText: '₹ ',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixIcon: Icons.lock_rounded,
                      autofocus: true,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text(
                      'Source Account',
                      style: AppTypography.labelMedium.copyWith(
                        color: isDark ? AppColors.gray300 : AppColors.gray700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<int>(
                      initialValue: selectedAccountId,
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
                      items: accounts
                          .map(
                            (acc) => DropdownMenuItem(
                              value: acc.id,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      acc.name,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    '₹${acc.balance.toStringAsFixed(0)}',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: isDark
                                          ? AppColors.gray400
                                          : AppColors.gray500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setStateSheet(() => selectedAccountId = val),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    SizedBox(
                      width: double.infinity,
                      height: AppComponentSizes.buttonHeightLarge,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (selectedAccountId == null ||
                              amountController.text.isEmpty) {
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                              const SnackBar(
                                content: Text('Select an account and amount.'),
                              ),
                            );
                            return;
                          }
                          final amount =
                              double.tryParse(amountController.text) ?? 0.0;
                          if (amount <= 0) {
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Enter an amount greater than zero.',
                                ),
                              ),
                            );
                            return;
                          }

                          try {
                            final selectedAcc = accounts.firstWhere(
                              (a) => a.id == selectedAccountId,
                              orElse: () =>
                                  throw ArgumentError('Select an account.'),
                            );
                            if (amount > selectedAcc.balance) {
                              throw ArgumentError(
                                'Lock amount cannot exceed account balance (₹${selectedAcc.balance.toStringAsFixed(0)}).',
                              );
                            }

                            await DatabaseHelper.instance
                                .createGoalLockTransaction(
                                  goalId: goal.id!,
                                  accountId: selectedAccountId!,
                                  amount: amount,
                                  date: DateTime.now().toIso8601String(),
                                  note: 'Locked for ${goal.name}',
                                );

                            if (sheetCtx.mounted) {
                              Navigator.pop(sheetCtx);
                            }
                            _loadData();
                          } catch (error) {
                            if (sheetCtx.mounted) {
                              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppBorderRadius.mediumBorder,
                          ),
                        ),
                        child: const Text(
                          'Confirm Lock Allocation',
                          style: AppTypography.labelLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPaymentDialog(Goal goal) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contributions =
        await DatabaseHelper.instance.getGoalContributions(goal.id!);
    final List<Category> categories =
        await DatabaseHelper.instance.readAllCategories();
    if (!mounted) return;

    if (contributions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No locked funds found to settle for this goal.'),
        ),
      );
      return;
    }

    int? selectedAccountId =
        (contributions.first['account_id'] as num?)?.toInt();
    double maxPayable =
        (contributions.first['amount'] as num?)?.toDouble() ?? 0.0;
    final amountController = TextEditingController(
      text: maxPayable > 0 ? maxPayable.toStringAsFixed(0) : '',
    );
    int? selectedCategoryId =
        categories.isNotEmpty ? categories.first.id : null;
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setStateSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.gray700 : AppColors.gray300,
                          borderRadius: AppBorderRadius.pillBorder,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Pay / Settle from "${goal.name}"',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Deduct payment from locked savings and physical account balance.',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    CustomInputField(
                      controller: amountController,
                      label: 'Payment Amount',
                      prefixText: '₹ ',
                      hint: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixIcon: Icons.payment_rounded,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Max available in selected account: ${AppFormatters.currency(maxPayable)}',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text(
                      'Pay From Account',
                      style: AppTypography.labelMedium.copyWith(
                        color: isDark ? AppColors.gray300 : AppColors.gray700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<int>(
                      initialValue: selectedAccountId,
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
                      items: contributions.map((c) {
                        final accId = (c['account_id'] as num).toInt();
                        final accName = c['account_name'] as String;
                        final amt = (c['amount'] as num).toDouble();
                        return DropdownMenuItem<int>(
                          value: accId,
                          child: Text(
                            '$accName (${AppFormatters.currency(amt)} locked)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final match = contributions.firstWhere(
                            (c) => (c['account_id'] as num).toInt() == val,
                          );
                          setStateSheet(() {
                            selectedAccountId = val;
                            maxPayable = (match['amount'] as num).toDouble();
                            final currentVal =
                                double.tryParse(amountController.text.trim()) ??
                                    0.0;
                            if (currentVal > maxPayable) {
                              amountController.text =
                                  maxPayable.toStringAsFixed(0);
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text(
                      'Expense Category (Optional)',
                      style: AppTypography.labelMedium.copyWith(
                        color: isDark ? AppColors.gray300 : AppColors.gray700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<int?>(
                      initialValue: selectedCategoryId,
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
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('No Category / Sinking Fund'),
                        ),
                        ...categories.map((cat) {
                          final style = CategoryStyle.getStyle(cat.name);
                          return DropdownMenuItem<int?>(
                            value: cat.id,
                            child: Row(
                              children: [
                                Icon(style.icon, size: 18, color: style.color),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    cat.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) =>
                          setStateSheet(() => selectedCategoryId = val),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text(
                      'Payment Date',
                      style: AppTypography.labelMedium.copyWith(
                        color: isDark ? AppColors.gray300 : AppColors.gray700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setStateSheet(() => selectedDate = picked);
                        }
                      },
                      borderRadius: AppBorderRadius.mediumBorder,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.gray50,
                          borderRadius: AppBorderRadius.mediumBorder,
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.gray300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: isDark
                                  ? AppColors.gray400
                                  : AppColors.gray600,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              DateFormat('MMM d, yyyy').format(selectedDate),
                              style: AppTypography.bodyMedium.copyWith(
                                color: isDark
                                    ? AppColors.gray200
                                    : AppColors.gray800,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Change',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.emerald700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    CustomInputField(
                      controller: noteController,
                      label: 'Note / Payee (Optional)',
                      hint: 'e.g. Annual premium policy #5829',
                      prefixIcon: Icons.notes_rounded,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    SizedBox(
                      width: double.infinity,
                      height: AppComponentSizes.buttonHeightLarge,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (selectedAccountId == null ||
                              amountController.text.trim().isEmpty) {
                            return;
                          }
                          final amount =
                              double.tryParse(amountController.text.trim()) ??
                                  0.0;
                          if (amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter an amount > 0'),
                              ),
                            );
                            return;
                          }
                          if (amount > maxPayable) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Cannot pay more than ${AppFormatters.currency(maxPayable)} from this account',
                                ),
                              ),
                            );
                            return;
                          }

                          try {
                            await DatabaseHelper.instance
                                .createGoalPaymentTransaction(
                              goalId: goal.id!,
                              accountId: selectedAccountId!,
                              amount: amount,
                              date: selectedDate.toIso8601String(),
                              categoryId: selectedCategoryId,
                              note: noteController.text.trim().isNotEmpty
                                  ? noteController.text.trim()
                                  : 'Payment for ${goal.name}',
                            );
                            if (sheetCtx.mounted) {
                              Navigator.pop(sheetCtx);
                            }
                            _loadData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Payment of ${AppFormatters.currency(amount)} recorded and funds released!',
                                  ),
                                  backgroundColor: AppColors.emerald700,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Payment failed: $e'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppBorderRadius.mediumBorder,
                          ),
                        ),
                        child: const Text(
                          'Confirm Payment',
                          style: AppTypography.labelLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showUnlockFundsDialog(Goal goal) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contributions =
        await DatabaseHelper.instance.getGoalContributions(goal.id!);
    if (!mounted) return;

    if (contributions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No locked funds found to unlock for this goal.'),
        ),
      );
      return;
    }

    final amountController = TextEditingController();
    final noteController = TextEditingController();
    int? selectedAccountId =
        (contributions.first['account_id'] as num?)?.toInt();
    double maxUnlockable =
        (contributions.first['amount'] as num?)?.toDouble() ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setStateSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.gray700 : AppColors.gray300,
                          borderRadius: AppBorderRadius.pillBorder,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Unlock Funds from "${goal.name}"',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Release locked savings back into your physical account\'s usable balance.',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    CustomInputField(
                      controller: amountController,
                      label: 'Amount to Unlock',
                      prefixText: '₹ ',
                      hint: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixIcon: Icons.lock_open_rounded,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Max available in selected account: ${AppFormatters.currency(maxUnlockable)}',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text(
                      'Release To Account',
                      style: AppTypography.labelMedium.copyWith(
                        color: isDark ? AppColors.gray300 : AppColors.gray700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<int>(
                      initialValue: selectedAccountId,
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
                      items: contributions.map((c) {
                        final accId = (c['account_id'] as num).toInt();
                        final accName = c['account_name'] as String;
                        final amt = (c['amount'] as num).toDouble();
                        return DropdownMenuItem<int>(
                          value: accId,
                          child: Text(
                            '$accName (${AppFormatters.currency(amt)} locked)',
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final match = contributions.firstWhere(
                            (c) => (c['account_id'] as num).toInt() == val,
                          );
                          setStateSheet(() {
                            selectedAccountId = val;
                            maxUnlockable = (match['amount'] as num).toDouble();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    CustomInputField(
                      controller: noteController,
                      label: 'Note (Optional)',
                      hint: 'e.g. Changed priority, emergency liquidity',
                      prefixIcon: Icons.notes_rounded,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    SizedBox(
                      width: double.infinity,
                      height: AppComponentSizes.buttonHeightLarge,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (selectedAccountId == null ||
                              amountController.text.trim().isEmpty) {
                            return;
                          }
                          final amount =
                              double.tryParse(amountController.text.trim()) ??
                              0.0;
                          if (amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter an amount > 0'),
                              ),
                            );
                            return;
                          }
                          if (amount > maxUnlockable) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Cannot unlock more than ${AppFormatters.currency(maxUnlockable)} from this account',
                                ),
                              ),
                            );
                            return;
                          }

                          try {
                            await DatabaseHelper.instance
                                .createGoalUnlockTransaction(
                              goalId: goal.id!,
                              accountId: selectedAccountId!,
                              amount: amount,
                              date: DateTime.now().toIso8601String(),
                              note: noteController.text.trim(),
                            );
                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                            _loadData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Unlocked ${AppFormatters.currency(amount)} back to usable balance!',
                                  ),
                                  backgroundColor: AppColors.emerald700,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Unlock failed: $e'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppBorderRadius.mediumBorder,
                          ),
                        ),
                        child: const Text(
                          'Unlock Funds',
                          style: AppTypography.titleMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalProgress = _totalTarget > 0
        ? (_totalLocked / _totalTarget)
        : 0.0;

    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.emerald700),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.emerald700,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // 1. TOP SINKING FUNDS OVERVIEW
                  _buildHeaderCard(isDark, totalProgress),
                  const SizedBox(height: AppSpacing.xl),

                  // 2. SECTION TITLE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Sinking Funds',
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_goals.length} Goals',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. GOALS LIST
                  if (_goals.isEmpty)
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
                                'No sinking funds or goals yet',
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Create sinking funds for future goalned expenses like insurance, repairs, or vacations.',
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
                    ..._goals.map((goal) => _buildGoalCard(goal, isDark)),

                  const SizedBox(height: AppSpacing.huge),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'goals-add-fab',
        onPressed: _showAddGoalDialog,
        backgroundColor: AppColors.emerald700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Goal', style: AppTypography.labelLarge),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark, double totalProgress) {
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
                'Total Locked Funds',
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
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: AppBorderRadius.pillBorder,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Reserved for Goals',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppFormatters.currency(_totalLocked),
            style: AppTypography.displayLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkText : AppColors.gray900,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          ClipRRect(
            borderRadius: AppBorderRadius.pillBorder,
            child: LinearProgressIndicator(
              value: totalProgress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: isDark
                  ? AppColors.darkBorder
                  : AppColors.gray200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.emerald600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(totalProgress * 100).toStringAsFixed(0)}% of total targets saved',
                style: AppTypography.labelSmall.copyWith(
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                ),
              ),
              Text(
                'Target: ${AppFormatters.currency(_totalTarget)}',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.emerald700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(Goal goal, bool isDark) {
    return GoalCard(
      goal: goal,
      salaryDay: _salaryDay,
      onHistory: () => _showContributionLog(goal),
      onEdit: () => _showEditGoalDialog(goal),
      onLockFunds: () => _showContributionDialog(goal),
      onPay: () => _showPaymentDialog(goal),
      onUnlock: () => _showUnlockFundsDialog(goal),
    );
  }
}

class EditGoalDialog extends StatefulWidget {
  final Goal goal;
  final Future<void> Function(Goal updatedGoal) onUpdate;
  final VoidCallback? onDelete;

  const EditGoalDialog({
    super.key,
    required this.goal,
    required this.onUpdate,
    this.onDelete,
  });

  @override
  State<EditGoalDialog> createState() => _EditGoalDialogState();
}

class _EditGoalDialogState extends State<EditGoalDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late DateTime _targetDate;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal.name);
    _targetController = TextEditingController(
      text: widget.goal.totalTarget.toStringAsFixed(0),
    );
    _targetDate =
        widget.goal.parsedTargetDate ??
        DateTime.now().add(const Duration(days: 90));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.xlargeBorder),
      title: Text(
        'Edit Sinking Fund',
        style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomInputField(
                controller: _nameController,
                label: 'Goal Name',
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a goal name'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              CustomInputField(
                controller: _targetController,
                label: 'Target Amount',
                prefixText: '₹ ',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter target amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                title: Text(
                  'Target Date',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                ),
                subtitle: Text(
                  DateFormat('MMM dd, yyyy').format(_targetDate),
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.emerald700,
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _targetDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null) {
                    setState(() => _targetDate = picked);
                  }
                },
                shape: RoundedRectangleBorder(
                  borderRadius: AppBorderRadius.mediumBorder,
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.gray300,
                  ),
                ),
                tileColor: isDark ? AppColors.darkSurface : AppColors.gray50,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.onDelete != null)
          TextButton(
            onPressed: widget.onDelete,
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
          label: 'Update',
          width: 120,
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final updated = widget.goal.copyWith(
                name: _nameController.text.trim(),
                totalTarget:
                    double.tryParse(_targetController.text.trim()) ?? 0.0,
                targetDate: DateFormat('yyyy-MM-dd').format(_targetDate),
              );
              await widget.onUpdate(updated);
              if (context.mounted) {
                Navigator.pop(context);
              }
            }
          },
        ),
      ],
    );
  }
}

class GoalCard extends StatelessWidget {
  final Goal goal;
  final int? salaryDay;
  final VoidCallback? onHistory;
  final VoidCallback? onEdit;
  final VoidCallback? onLockFunds;
  final VoidCallback? onPay;
  final VoidCallback? onUnlock;

  const GoalCard({
    super.key,
    required this.goal,
    this.salaryDay,
    this.onHistory,
    this.onEdit,
    this.onLockFunds,
    this.onPay,
    this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = goal.progress;
    final remaining = goal.remainingAmount;
    final isCompleted = goal.isCompleted;
    final isOverdue = goal.isOverdue();
    final pace = goal.recommendedMonthlyPace(salaryDay: salaryDay);
    final adviceText = goal.pacingAdviceText(
      salaryDay: salaryDay,
      currencyFormatter: (amt) => AppFormatters.currency(amt),
    );

    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.emerald500.withValues(alpha: 0.12),
                  borderRadius: AppBorderRadius.mediumBorder,
                ),
                child: const Icon(
                  Icons.savings_rounded,
                  color: AppColors.emerald600,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      progress >= 1.0
                          ? 'Goal reached! Ready to settle'
                          : '₹${remaining.toStringAsFixed(0)} left to save',
                      style: AppTypography.labelSmall.copyWith(
                        color: progress >= 1.0
                            ? AppColors.emerald600
                            : (isDark ? AppColors.gray400 : AppColors.gray600),
                        fontWeight: progress >= 1.0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (onUnlock != null && goal.currentSaved > 0)
                IconButton(
                  key: Key('goal_card_unlock_${goal.id ?? 0}'),
                  icon: const Icon(
                    Icons.lock_open_rounded,
                    size: 20,
                    color: AppColors.warning,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  constraints: const BoxConstraints(
                    minWidth: AppComponentSizes.minTouchTarget,
                    minHeight: AppComponentSizes.minTouchTarget,
                  ),
                  tooltip: 'Unlock Funds',
                  onPressed: onUnlock,
                ),
              if (onHistory != null)
                IconButton(
                  icon: Icon(
                    Icons.history_rounded,
                    size: 20,
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  constraints: const BoxConstraints(
                    minWidth: AppComponentSizes.minTouchTarget,
                    minHeight: AppComponentSizes.minTouchTarget,
                  ),
                  tooltip: 'Contribution Breakdown',
                  onPressed: onHistory,
                ),
              if (onEdit != null)
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
                  tooltip: 'Edit Goal',
                  onPressed: onEdit,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Progress Bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: AppBorderRadius.pillBorder,
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: isDark
                        ? AppColors.darkBorder
                        : AppColors.gray200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.emerald600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.emerald600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Locked: ₹${goal.currentSaved.toStringAsFixed(0)}',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.gray300 : AppColors.gray800,
                ),
              ),
              Text(
                'Target: ₹${goal.totalTarget.toStringAsFixed(0)}',
                style: AppTypography.labelSmall.copyWith(
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Target Date & Deadline Badge Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Due ${goal.formattedTargetDate}',
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.emerald500.withValues(alpha: 0.15)
                      : isOverdue
                      ? AppColors.danger.withValues(alpha: 0.15)
                      : (isDark
                            ? AppColors.darkSurfaceElevated
                            : AppColors.gray100),
                  borderRadius: AppBorderRadius.pillBorder,
                  border: Border.all(
                    color: isCompleted
                        ? AppColors.emerald500.withValues(alpha: 0.3)
                        : isOverdue
                        ? AppColors.danger.withValues(alpha: 0.3)
                        : (isDark ? AppColors.darkBorder : AppColors.gray200),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  goal.deadlineStatusText(),
                  style: AppTypography.labelSmall.copyWith(
                    color: isCompleted
                        ? AppColors.emerald600
                        : isOverdue
                        ? AppColors.danger
                        : (isDark ? AppColors.gray300 : AppColors.gray700),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          // Recommended Monthly Savings Pace or Overdue warning banner
          if (!isCompleted && pace != null && pace > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.emerald500.withValues(alpha: 0.08),
                borderRadius: AppBorderRadius.mediumBorder,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    size: 14,
                    color: AppColors.emerald600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      adviceText ??
                          'Save ~${AppFormatters.currency(pace)}/mo to hit target on time',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark
                            ? AppColors.emerald400
                            : AppColors.emerald800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isOverdue) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: AppBorderRadius.mediumBorder,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Target date passed — ₹${remaining.toStringAsFixed(0)} still needed',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: 'Lock Funds',
                  icon: Icons.lock_outline_rounded,
                  variant: ButtonVariant.secondary,
                  height: AppComponentSizes.buttonHeightSmall,
                  onPressed: onLockFunds ?? () {},
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: CustomButton(
                  label: 'Pay / Settle',
                  icon: Icons.payment_rounded,
                  variant: ButtonVariant.outlined,
                  height: AppComponentSizes.buttonHeightSmall,
                  onPressed: onPay ?? () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
