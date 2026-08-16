import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../models/account_model.dart';
import '../models/locked_allocation_model.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';
import '../components/custom_input.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<Account> _accounts = [];

  @override
  void initState() {
    super.initState();
    _refreshAccounts();
  }

  void _refreshAccounts() async {
    final data = await DatabaseHelper.instance.readAllAccounts();
    setState(() {
      _accounts = data;
    });
  }

  void _showAddAccountDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController balanceController = TextEditingController();
    String selectedType = 'Bank';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Add New Account', style: AppTypography.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomInputField(
                controller: nameController,
                label: 'Account Name',
              ),
              const SizedBox(height: AppSpacing.md),
              CustomInputField(
                controller: balanceController,
                label: 'Initial Balance',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                value: selectedType,
                isExpanded: true,
                items: ['Bank', 'Cash']
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (val) => setStateDialog(() => selectedType = val!),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: AppBorderRadius.smallBorder,
                  ),
                ),
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
                await DatabaseHelper.instance.createAccount(
                  Account(
                    name: nameController.text,
                    balance: double.tryParse(balanceController.text) ?? 0.0,
                    type: selectedType,
                  ),
                );
                Navigator.pop(context);
                _refreshAccounts();
              },
              child: Text('Save', style: AppTypography.labelMedium),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalPhysical = 0;
    for (var acc in _accounts) {
      totalPhysical += acc.balance;
    }

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
                    'My Accounts',
                    style: AppTypography.headlineMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Total Physical Balance: \₹${totalPhysical.toStringAsFixed(2)}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.gray700,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _showAddAccountDialog,
                icon: const Icon(
                  Icons.add_circle,
                  color: AppColors.green700,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: _accounts.isEmpty
                ? const Center(child: Text('No accounts added yet.'))
                : ListView.builder(
                    itemCount: _accounts.length,
                    itemBuilder: (context, index) =>
                        _buildAccountCard(_accounts[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(Account acc) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.green100,
                child: Icon(
                  acc.type == 'Bank' ? Icons.account_balance : Icons.wallet,
                  color: AppColors.green700,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      acc.name,
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      acc.type,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.gray700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\₹${acc.balance.toStringAsFixed(2)}',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditAccountDialog(acc);
                  } else if (value == 'delete') {
                    _showDeleteConfirmation(acc);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const Divider(height: 30),
          Text(
            'Locked Funds Breakdown:',
            style: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FutureBuilder<List<LockedAllocation>>(
            future: DatabaseHelper.instance.getLocksForAccount(acc.id!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              if (snapshot.data!.isEmpty)
                return Text(
                  'No funds locked in this account',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.gray700,
                  ),
                );

              return Column(
                children: snapshot.data!
                    .map(
                      (lock) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              lock.planName,
                              style: AppTypography.labelSmall,
                            ),
                            Text(
                              '\₹${lock.amount.toStringAsFixed(2)}',
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showEditAccountDialog(Account account) {
    TextEditingController nameController = TextEditingController(
      text: account.name,
    );
    TextEditingController balanceController = TextEditingController(
      text: account.balance.toString(),
    );
    String selectedType = account.type;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Edit Account', style: AppTypography.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomInputField(
                controller: nameController,
                label: 'Account Name',
              ),
              const SizedBox(height: AppSpacing.md),
              CustomInputField(
                controller: balanceController,
                label: 'Balance',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                value: selectedType,
                isExpanded: true,
                items: ['Bank', 'Cash']
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (val) => setStateDialog(() => selectedType = val!),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: AppBorderRadius.smallBorder,
                  ),
                ),
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
                await DatabaseHelper.instance.updateAccount(
                  Account(
                    id: account.id,
                    name: nameController.text,
                    balance: double.tryParse(balanceController.text) ?? 0.0,
                    type: selectedType,
                  ),
                );
                Navigator.pop(context);
                _refreshAccounts();
              },
              child: Text('Save', style: AppTypography.labelMedium),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Account account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account?', style: AppTypography.titleLarge),
        content: Text(
          'Are you sure you want to delete "${account.name}"? This action cannot be undone.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTypography.labelMedium),
          ),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper.instance.deleteAccount(account.id!);
              Navigator.pop(context);
              _refreshAccounts();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: AppBorderRadius.smallBorder,
              ),
            ),
            child: Text('Delete', style: AppTypography.labelMedium),
          ),
        ],
      ),
    );
  }
}
