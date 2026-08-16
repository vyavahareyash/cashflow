import 'package:flutter/material.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:intl/intl.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getTransactionHistory();
      setState(() {
        _transactions = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading history: $e')));
    }
  }

  Future<void> _deleteTransaction(int id) async {
    try {
      await DatabaseHelper.instance.deleteTransaction(id);
      await _loadTransactions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted and balance restored'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting transaction: $e')));
    }
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
                      'Transaction History',
                      style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Your recent spending logs',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.gray700),
                    ),
                  ],
                ),
                Icon(
                  Icons.history,
                  color: AppColors.green700,
                  size: 32,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _transactions.isEmpty
                      ? const Center(child: Text('No transactions found'))
                      : ListView.builder(
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final tx = _transactions[index];
                            final date = DateTime.parse(tx['date']);
                            final formattedDate = DateFormat('MMM dd, yyyy').format(date);

                            return CustomCard(
                              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.green100,
                                  child: const Icon(
                                    Icons.receipt_long,
                                    color: AppColors.green700,
                                ),
                                ),
                                title: Text(
                                  '${tx['category_name']} - ${tx['account_name']}',
                                  style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '$formattedDate • ${tx['note'] ?? 'No note'}',
                                  style: AppTypography.labelSmall,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '-\$${tx['amount'].toStringAsFixed(2)}',
                                      style: AppTypography.titleMedium.copyWith(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppColors.gray400,
                                      ),
                                      onPressed: () => _confirmDelete(tx['id']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Transaction?', style: AppTypography.titleLarge),
        content: Text(
          'This will remove the transaction and refund the amount back to the account.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTypography.labelMedium),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteTransaction(id);
            },
            child: Text('Delete', style: AppTypography.labelMedium.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
