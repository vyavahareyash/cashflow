import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import 'backup_restore_screen.dart';
import '../theme/theme_constants.dart';
import '../components/stat_card.dart';
import '../components/custom_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Account> _accounts = [];
  double _totalBalance = 0.0;
  double _lockedAmount = 0.0;
  double _usableBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    // Fetch physical accounts and total locked funds from DB
    final accountsData = await DatabaseHelper.instance.readAllAccounts();
    final locked = await DatabaseHelper.instance.getTotalLockedAmount();
    final usable = await DatabaseHelper.instance.calculateUsableBalance();

    double sum = 0;
    for (var acc in accountsData) {
      sum += acc.balance;
    }

    setState(() {
      _accounts = accountsData;
      _totalBalance = sum;
      _lockedAmount = locked;
      _usableBalance = usable;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back!',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.gray700),
                    ),
                    Text(
                      'Manage your finances',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.gray400),
                    ),
                  ],
                ),
                CircleAvatar(
                  backgroundColor: AppColors.green100,
                  child: Icon(Icons.person, color: AppColors.green700),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // USABLE BALANCE CARD
            CustomCard(
              backgroundColor: AppColors.green700,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Usable Balance',
                        style: AppTypography.labelSmall.copyWith(color: Colors.white70),
                      ),
                      Icon(Icons.account_balance_wallet, color: Colors.white70, size: 20),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '\$${_usableBalance.toStringAsFixed(2)}',
                    style: AppTypography.displayLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
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
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BackupRestoreScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Backup',
                      style: AppTypography.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ],
                ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Accounts',
                  style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/accounts');
                  },
                  child: Text(
                    'See All',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.green700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

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
        backgroundColor: AppColors.green700,
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
          style: AppTypography.labelSmall.copyWith(color: Colors.white70),
        ),
        Text(
          amount,
          style: AppTypography.titleMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountItem(Account acc) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.green100,
          child: Icon(
            acc.type == 'Bank' ? Icons.account_balance : Icons.wallet,
            color: AppColors.green700,
          ),
        ),
        title: Text(
          acc.name,
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Check account for locked funds',
          style: AppTypography.labelSmall,
        ),
        trailing: Text(
          '\$${acc.balance.toStringAsFixed(2)}',
          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
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
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Log New Expense',
                    style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                        borderRadius: AppBorderRadius.smallBorder,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
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
                            borderRadius: AppBorderRadius.smallBorder,
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
                  const SizedBox(height: AppSpacing.md),
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
                            borderRadius: AppBorderRadius.smallBorder,
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
                  const SizedBox(height: AppSpacing.xl),
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
                        backgroundColor: AppColors.green700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppBorderRadius.smallBorder,
                        ),
                      ),
                      child: const Text('Save Transaction'),
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
}
