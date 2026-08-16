import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../models/plan_model.dart';
import '../models/account_model.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';
import '../components/custom_input.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  List<Plan> _plans = [];
  double _totalLocked = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final plans = await DatabaseHelper.instance.readAllPlans();
    final locked = await DatabaseHelper.instance.getTotalLockedAmount();
    setState(() {
      _plans = plans;
      _totalLocked = locked;
    });
  }

  void _showAddPlanDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController targetController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create New Plan', style: AppTypography.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomInputField(controller: nameController, label: 'Plan Name'),
            const SizedBox(height: AppSpacing.md),
            CustomInputField(
              controller: targetController,
              label: 'Target Amount',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTypography.labelMedium),
          ),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper.instance.createPlan(
                Plan(
                  name: nameController.text,
                  totalTarget: double.tryParse(targetController.text) ?? 0.0,
                  targetDate: '2024-12-31',
                  currentSaved: 0.0,
                ),
              );
              Navigator.pop(context);
              _loadData();
            },
            child: Text('Save', style: AppTypography.labelMedium),
          ),
        ],
      ),
    );
  }

  void _showEditPlanDialog(Plan plan) {
    TextEditingController nameController = TextEditingController(
      text: plan.name,
    );
    TextEditingController targetController = TextEditingController(
      text: plan.totalTarget.toString(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Plan', style: AppTypography.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomInputField(controller: nameController, label: 'Plan Name'),
            const SizedBox(height: AppSpacing.md),
            CustomInputField(
              controller: targetController,
              label: 'Target Amount',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _confirmDeletePlan(plan),
            child: Text(
              'Delete',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.danger,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTypography.labelMedium),
          ),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper.instance.updatePlan(
                Plan(
                  id: plan.id,
                  name: nameController.text,
                  totalTarget: double.tryParse(targetController.text) ?? 0.0,
                  targetDate: plan.targetDate,
                  currentSaved: plan.currentSaved,
                ),
              );
              Navigator.pop(context);
              _loadData();
            },
            child: Text('Update', style: AppTypography.labelMedium),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlan(Plan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Plan?', style: AppTypography.titleLarge),
        content: Text(
          'Deleting this plan will unlock all saved funds and return them to their original accounts.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTypography.labelMedium),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.deletePlan(plan.id!);
              Navigator.pop(ctx);
              _loadData();
            },
            child: Text(
              'Delete',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContributionLog(Plan plan) async {
    final contributions = await DatabaseHelper.instance.getPlanContributions(
      plan.id!,
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contributions for ${plan.name}',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              contributions.isEmpty
                  ? const Center(child: Text('No contributions yet'))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: contributions.length,
                      itemBuilder: (context, index) {
                        final contrib = contributions[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.account_balance_wallet,
                            color: AppColors.green700,
                          ),
                          title: Text(contrib['account_name']),
                          trailing: Text(
                            ' \₹${contrib['amount'].toStringAsFixed(2)}',
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  void _showContributionDialog(Plan plan) async {
    // 1. FETCH THE DATA FIRST (Outside the builder)
    // We do this here so the data is ready BEFORE the pop-up appears
    final List<Account> accounts = await DatabaseHelper.instance
        .readAllAccounts();

    TextEditingController amountController = TextEditingController();
    int? selectedAccountId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        // 2. REMOVED 'async' from here
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lock Funds for ${plan.name}',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CustomInputField(
                    controller: amountController,
                    label: 'Amount to Lock',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.lock,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int>(
                    value: selectedAccountId,
                    decoration: InputDecoration(
                      labelText: 'Lock in Account',
                      border: OutlineInputBorder(
                        borderRadius: AppBorderRadius.smallBorder,
                      ),
                    ),
                    // Use the accounts list we fetched above
                    items: accounts
                        .map(
                          (acc) => DropdownMenuItem(
                            value: acc.id,
                            child: Text(acc.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setStateSheet(() => selectedAccountId = val),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedAccountId == null) return;

                        // Perform the DB operation
                        await DatabaseHelper.instance.lockFunds(
                          plan.id!,
                          selectedAccountId!,
                          double.tryParse(amountController.text) ?? 0.0,
                        );

                        Navigator.pop(context);
                        _loadData(); // Refresh the planner list
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppBorderRadius.smallBorder,
                        ),
                      ),
                      child: const Text('Confirm Contribution'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPaymentDialog(Plan plan) async {
    final List<Account> accounts = await DatabaseHelper.instance
        .readAllAccounts();

    TextEditingController amountController = TextEditingController();
    int? selectedAccountId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pay Bill for ${plan.name}',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CustomInputField(
                    controller: amountController,
                    label: 'Payment Amount',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.payment,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int>(
                    value: selectedAccountId,
                    decoration: InputDecoration(
                      labelText: 'Pay from Account',
                      border: OutlineInputBorder(
                        borderRadius: AppBorderRadius.smallBorder,
                      ),
                    ),
                    // Use the accounts list we fetched above
                    items: accounts
                        .map(
                          (acc) => DropdownMenuItem(
                            value: acc.id,
                            child: Text(acc.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setStateSheet(() => selectedAccountId = val),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedAccountId == null) return;

                        try {
                          await DatabaseHelper.instance.payBill(
                            plan.id!,
                            selectedAccountId!,
                            double.tryParse(amountController.text) ?? 0.0,
                          );
                          Navigator.pop(context);
                          _loadData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Payment processed successfully'),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Payment failed: $e')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppBorderRadius.smallBorder,
                        ),
                      ),
                      child: const Text('Confirm Payment'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            );
          },
        );
      },
    );
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planned Spends',
                    style: AppTypography.headlineMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Total Locked: \₹${_totalLocked.toStringAsFixed(2)}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.gray700,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _showAddPlanDialog,
                icon: const Icon(
                  Icons.event_repeat,
                  color: AppColors.green700,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: _plans.isEmpty
                ? const Center(child: Text('No plans created yet.'))
                : ListView.builder(
                    itemCount: _plans.length,
                    itemBuilder: (context, index) =>
                        _buildPlanItem(_plans[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanItem(Plan plan) {
    double progress = plan.currentSaved / plan.totalTarget;
    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.green100,
                        borderRadius: AppBorderRadius.smallBorder,
                      ),
                      child: const Icon(
                        Icons.savings,
                        color: AppColors.green700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        plan.name,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
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
                      Icons.history,
                      size: 20,
                      color: AppColors.gray400,
                    ),
                    onPressed: () => _showContributionLog(plan),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      size: 20,
                      color: AppColors.gray400,
                    ),
                    onPressed: () => _showEditPlanDialog(plan),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saved: \₹${plan.currentSaved.toStringAsFixed(2)} / \₹${plan.totalTarget.toStringAsFixed(2)}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.gray700,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.green700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: AppBorderRadius.smallBorder,
            child: LinearProgressIndicator(
              value: progress > 1.0 ? 1.0 : progress,
              minHeight: 8,
              backgroundColor: AppColors.gray200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.green700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildPlanActions(plan),
        ],
      ),
    );
  }

  Widget _buildPlanActions(Plan plan) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: OutlinedButton(
              onPressed: () => _showPaymentDialog(plan),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: AppBorderRadius.smallBorder,
                ),
              ),
              child: Text(
                'Pay Bill',
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall,
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: OutlinedButton(
              onPressed: () => _showContributionDialog(plan),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: AppBorderRadius.smallBorder,
                ),
              ),
              child: Text(
                'Contribute',
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
