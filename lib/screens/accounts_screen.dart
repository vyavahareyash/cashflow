import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../models/account_model.dart';
import '../models/locked_allocation_model.dart';

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
          title: const Text('Add New Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Account Name'),
              ),
              TextField(
                controller: balanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Initial Balance'),
              ),
              const SizedBox(height: 15),
              DropdownButton<String>(
                value: selectedType,
                isExpanded: true,
                items: ['Bank', 'Cash']
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (val) => setStateDialog(() => selectedType = val!),
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
              child: const Text('Save'),
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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Accounts',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            'Total Physical Balance: \$${totalPhysical.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 25),
          Expanded(
            child: _accounts.isEmpty
                ? const Center(child: Text('No accounts added yet.'))
                : ListView.builder(
                    itemCount: _accounts.length,
                    itemBuilder: (context, index) =>
                        _buildAccountCard(_accounts[index]),
                  ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showAddAccountDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add New Account'),
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

  Widget _buildAccountCard(Account acc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Icon(
                    acc.type == 'Bank' ? Icons.account_balance : Icons.wallet,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        acc.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        acc.type,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${acc.balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
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
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 30),
            const Text(
              'Locked Funds Breakdown:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<LockedAllocation>>(
              future: DatabaseHelper.instance.getLocksForAccount(acc.id!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                if (snapshot.data!.isEmpty)
                  return const Text(
                    'No funds locked in this account',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                '\$${lock.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
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
      ),
    );
  }

  void _showEditAccountDialog(Account account) {
    TextEditingController nameController =
        TextEditingController(text: account.name);
    TextEditingController balanceController =
        TextEditingController(text: account.balance.toString());
    String selectedType = account.type;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Edit Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Account Name'),
              ),
              TextField(
                controller: balanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Balance'),
              ),
              const SizedBox(height: 15),
              DropdownButton<String>(
                value: selectedType,
                isExpanded: true,
                items: ['Bank', 'Cash']
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (val) => setStateDialog(() => selectedType = val!),
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
              child: const Text('Save'),
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
        title: const Text('Delete Account?'),
        content: Text(
            'Are you sure you want to delete "${account.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper.instance.deleteAccount(account.id!);
              Navigator.pop(context);
              _refreshAccounts();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
