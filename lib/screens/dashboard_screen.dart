import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Account> _accounts = [];
  double _totalBalance = 0.0;
  double _lockedAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    // Fetch physical accounts and total locked funds from DB
    final accountsData = await DatabaseHelper.instance.readAllAccounts();
    final locked = await DatabaseHelper.instance.getTotalLockedAmount();

    double sum = 0;
    for (var acc in accountsData) {
      sum += acc.balance;
    }

    setState(() {
      _accounts = accountsData;
      _totalBalance = sum;
      _lockedAmount = locked;
    });
  }

  @override
  Widget build(BuildContext context) {
    double usableBalance = _totalBalance - _lockedAmount;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50),
            const Text(
              'Welcome Back!',
              style: TextStyle(fontSize: 20, color: Colors.grey),
            ),
            const SizedBox(height: 10),

            // USABLE BALANCE CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade700, Colors.green.shade400],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Usable Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${usableBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBalanceDetail(
                        'Total',
                        '\$${_totalBalance.toStringAsFixed(2)}',
                      ),
                      _buildBalanceDetail(
                        'Locked',
                        '\$${_lockedAmount.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Text(
              'My Accounts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            Expanded(
              child: _accounts.isEmpty
                  ? const Center(child: Text('No accounts found.'))
                  : ListView.builder(
                      itemCount: _accounts.length,
                      itemBuilder: (context, index) =>
                          _buildAccountItem(_accounts[index]),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTransactionSheet(context),
        label: const Text('Log Spend'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBalanceDetail(String label, String amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          amount,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountItem(Account acc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(
            acc.type == 'Bank' ? Icons.account_balance : Icons.wallet,
            color: Colors.green.shade700,
          ),
        ),
        title: Text(
          acc.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Check account for locked funds'),
        trailing: Text(
          '\$${acc.balance.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showTransactionSheet(BuildContext context) {
    TextEditingController amountController = TextEditingController();
    int? selectedAccountId;
    int? selectedCategoryId;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Log New Expense',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  FutureBuilder<List<Category>>(
                    future: DatabaseHelper.instance.readAllCategories(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const LinearProgressIndicator();
                      return DropdownButtonFormField<int>(
                        value: selectedCategoryId,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: snapshot.data!
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat.id,
                                child: Text(cat.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setStateSheet(() => selectedCategoryId = val),
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  FutureBuilder<List<Account>>(
                    future: DatabaseHelper.instance.readAllAccounts(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const LinearProgressIndicator();
                      return DropdownButtonFormField<int>(
                        value: selectedAccountId,
                        decoration: InputDecoration(
                          labelText: 'From Account',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: snapshot.data!
                            .map(
                              (acc) => DropdownMenuItem(
                                value: acc.id,
                                child: Text(acc.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setStateSheet(() => selectedAccountId = val),
                      );
                    },
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (amountController.text.isEmpty ||
                            selectedAccountId == null ||
                            selectedCategoryId == null)
                          return;
                        final amount =
                            double.tryParse(amountController.text) ?? 0.0;
                        await DatabaseHelper.instance.insertTransaction(
                          TransactionModel(
                            accountId: selectedAccountId!,
                            categoryId: selectedCategoryId!,
                            amount: amount,
                            date: DateTime.now().toIso8601String(),
                            note: '',
                          ),
                        );
                        await DatabaseHelper.instance.subtractFromAccount(
                          selectedAccountId!,
                          amount,
                        );
                        Navigator.pop(context);
                        _loadData();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save Transaction'),
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
}
