import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../models/plan_model.dart';
import '../models/account_model.dart';

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
        title: const Text('Create New Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Plan Name'),
            ),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target Amount'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
            child: const Text('Save'),
          ),
        ],
      ),
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
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lock Funds for ${plan.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount to Lock',
                      prefixText: '\$ ',
                    ),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<int>(
                    value: selectedAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Lock in Account',
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
                  const SizedBox(height: 20),
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
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text('Confirm Contribution'),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pay Bill for ${plan.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Payment Amount',
                      prefixText: '\$ ',
                    ),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<int>(
                    value: selectedAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Pay from Account',
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
                  const SizedBox(height: 20),
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
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text('Confirm Payment'),
                    ),
                  ),
                  const SizedBox(height: 20),
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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Planned Spends',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            'Total Locked: \$${_totalLocked.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 25),
          Expanded(
            child: _plans.isEmpty
                ? const Center(child: Text('No plans created yet.'))
                : ListView.builder(
                    itemCount: _plans.length,
                    itemBuilder: (context, index) =>
                        _buildPlanItem(_plans[index]),
                  ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showAddPlanDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add New Plan'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanItem(Plan plan) {
    double progress = plan.currentSaved / plan.totalTarget;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('${(progress * 100).toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress > 1.0 ? 1.0 : progress,
              minHeight: 10,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Saved: \$${plan.currentSaved.toStringAsFixed(2)}'),
                Text('Target: \$${plan.totalTarget.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: OutlinedButton(
                      onPressed: () => _showPaymentDialog(plan),
                      child: const Text(
                        'Pay Bill',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: OutlinedButton(
                      onPressed: () => _showContributionDialog(plan),
                      child: const Text(
                        'Contribute',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
