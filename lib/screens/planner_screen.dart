import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database_helper.dart';
import '../models/plan_model.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';
import '../components/custom_input.dart';
import '../components/custom_button.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  List<Plan> _plans = [];
  double _totalLocked = 0.0;
  double _totalTarget = 0.0;
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
    if (_plans.isEmpty) {
      setState(() => _isLoading = true);
    }
    final plans = await DatabaseHelper.instance.readAllPlans();
    final locked = await DatabaseHelper.instance.getTotalLockedAmount();

    double totalTarget = 0.0;
    for (var p in plans) {
      totalTarget += p.totalTarget;
    }

    if (mounted) {
      setState(() {
        _plans = plans;
        _totalLocked = locked;
        _totalTarget = totalTarget;
        _isLoading = false;
      });
    }
  }

  void _showAddPlanDialog() {
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
                      label: 'Goal Name',
                      hint: 'e.g. Car Insurance, Vacation, MacBook',
                      prefixIcon: Icons.savings_rounded,
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Please enter a goal name'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomInputField(
                      controller: targetController,
                      label: 'Target Amount',
                      hint: 'e.g. 50000',
                      prefixText: '₹ ',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      title: Text(
                        'Target Date',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('MMM dd, yyyy').format(targetDate),
                        style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
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
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              CustomButton(
                label: 'Save Goal',
                width: 120,
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    await DatabaseHelper.instance.createPlan(
                      Plan(
                        name: nameController.text.trim(),
                        totalTarget: double.tryParse(targetController.text.trim()) ?? 0.0,
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

  void _showEditPlanDialog(Plan plan) {
    final nameController = TextEditingController(text: plan.name);
    final targetController = TextEditingController(text: plan.totalTarget.toStringAsFixed(0));
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
              'Edit Sinking Fund',
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
                      label: 'Goal Name',
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Please enter a goal name'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomInputField(
                      controller: targetController,
                      label: 'Target Amount',
                      prefixText: '₹ ',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => _confirmDeletePlan(plan),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              CustomButton(
                label: 'Update',
                width: 100,
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    await DatabaseHelper.instance.updatePlan(
                      Plan(
                        id: plan.id,
                        name: nameController.text.trim(),
                        totalTarget: double.tryParse(targetController.text.trim()) ?? 0.0,
                        targetDate: plan.targetDate,
                        currentSaved: plan.currentSaved,
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

  void _confirmDeletePlan(Plan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sinking Fund?'),
        content: Text(
          'Deleting "${plan.name}" will unlock all saved funds (${AppFormatters.currency(plan.currentSaved)}) and return them back to their original physical accounts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.deletePlan(plan.id!);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              _loadData();
            },
            child: const Text(
              'Delete & Unlock',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showContributionLog(Plan plan) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contributions = await DatabaseHelper.instance.getPlanContributions(
      plan.id!,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
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
                'Locked Allocations for ${plan.name}',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Total saved: ${AppFormatters.currency(plan.currentSaved)} of ${AppFormatters.currency(plan.totalTarget)}',
                style: AppTypography.labelSmall.copyWith(
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (contributions.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'No funds have been locked into this goal yet.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                  ),
                )
              else
                ...contributions.map((contrib) {
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
                            const Icon(
                              Icons.account_balance_rounded,
                              color: AppColors.emerald700,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              contrib['account_name'] ?? 'Account',
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          AppFormatters.currency((contrib['amount'] as num?)?.toDouble() ?? 0.0),
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.emerald700,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }

  void _showContributionDialog(Plan plan) async {
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
                      'Lock Funds for "${plan.name}"',
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      value: selectedAccountId,
                      dropdownColor: isDark ? AppColors.darkSurfaceElevated : AppColors.white,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurface : AppColors.gray50,
                        border: OutlineInputBorder(
                          borderRadius: AppBorderRadius.mediumBorder,
                          borderSide: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.gray300,
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
                              child: Text('${acc.name} (Balance: ₹${acc.balance.toStringAsFixed(0)})'),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setStateSheet(() => selectedAccountId = val),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    SizedBox(
                      width: double.infinity,
                      height: AppComponentSizes.buttonHeightLarge,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (selectedAccountId == null || amountController.text.isEmpty) return;
                          final amount = double.tryParse(amountController.text) ?? 0.0;
                          if (amount <= 0) return;

                          await DatabaseHelper.instance.lockFunds(
                            plan.id!,
                            selectedAccountId!,
                            amount,
                          );

                          if (sheetCtx.mounted) {
                            Navigator.pop(sheetCtx);
                          }
                          _loadData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppBorderRadius.mediumBorder,
                          ),
                        ),
                        child: const Text('Confirm Lock Allocation', style: AppTypography.labelLarge),
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

  void _showPaymentDialog(Plan plan) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accounts = await DatabaseHelper.instance.readAllAccounts();
    final amountController = TextEditingController(text: plan.currentSaved.toStringAsFixed(0));
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
                      'Pay / Settle Bill for "${plan.name}"',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'This will deduct payment from the chosen account and release the locked funds.',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    CustomInputField(
                      controller: amountController,
                      label: 'Payment Amount',
                      prefixText: '₹ ',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: Icons.payment_rounded,
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
                      value: selectedAccountId,
                      dropdownColor: isDark ? AppColors.darkSurfaceElevated : AppColors.white,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurface : AppColors.gray50,
                        border: OutlineInputBorder(
                          borderRadius: AppBorderRadius.mediumBorder,
                          borderSide: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.gray300,
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
                              child: Text('${acc.name} (Balance: ₹${acc.balance.toStringAsFixed(0)})'),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setStateSheet(() => selectedAccountId = val),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    SizedBox(
                      width: double.infinity,
                      height: AppComponentSizes.buttonHeightLarge,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (selectedAccountId == null || amountController.text.isEmpty) return;
                          final amount = double.tryParse(amountController.text) ?? 0.0;
                          if (amount <= 0) return;

                          try {
                            await DatabaseHelper.instance.payBill(
                              plan.id!,
                              selectedAccountId!,
                              amount,
                            );
                            if (sheetCtx.mounted) {
                              Navigator.pop(sheetCtx);
                            }
                            _loadData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Payment completed and funds released!'),
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
                        child: const Text('Confirm Payment', style: AppTypography.labelLarge),
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
    final totalProgress = _totalTarget > 0 ? (_totalLocked / _totalTarget) : 0.0;

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
                        style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_plans.length} Goals',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. GOALS LIST
                  if (_plans.isEmpty)
                    CustomCard(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            children: [
                              Icon(
                                Icons.savings_outlined,
                                size: 48,
                                color: isDark ? AppColors.gray600 : AppColors.gray400,
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
                                'Create sinking funds for future planned expenses like insurance, repairs, or vacations.',
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
                    ..._plans.map((plan) => _buildPlanCard(plan, isDark)),

                  const SizedBox(height: AppSpacing.huge),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPlanDialog,
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
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: AppBorderRadius.pillBorder,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded, size: 12, color: AppColors.warning),
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
              backgroundColor: isDark ? AppColors.darkBorder : AppColors.gray200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald600),
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

  Widget _buildPlanCard(Plan plan, bool isDark) {
    final progress = plan.totalTarget > 0 ? (plan.currentSaved / plan.totalTarget) : 0.0;
    final remaining = (plan.totalTarget - plan.currentSaved).clamp(0.0, double.infinity);

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
                  color: AppColors.emerald500.withOpacity(0.12),
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
                      plan.name,
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
                        fontWeight: progress >= 1.0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                ),
                tooltip: 'Contribution Breakdown',
                onPressed: () => _showContributionLog(plan),
              ),
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                ),
                tooltip: 'Edit Plan',
                onPressed: () => _showEditPlanDialog(plan),
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
                    backgroundColor: isDark ? AppColors.darkBorder : AppColors.gray200,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald600),
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
                'Locked: ₹${plan.currentSaved.toStringAsFixed(0)}',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.gray300 : AppColors.gray800,
                ),
              ),
              Text(
                'Target: ₹${plan.totalTarget.toStringAsFixed(0)}',
                style: AppTypography.labelSmall.copyWith(
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                ),
              ),
            ],
          ),
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
                  onPressed: () => _showContributionDialog(plan),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: CustomButton(
                  label: 'Pay / Settle',
                  icon: Icons.payment_rounded,
                  variant: ButtonVariant.outlined,
                  height: AppComponentSizes.buttonHeightSmall,
                  onPressed: () => _showPaymentDialog(plan),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
