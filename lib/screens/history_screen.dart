import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database_helper.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';
import '../components/category_badge.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getTransactionHistory();
      if (mounted) {
        setState(() {
          _transactions = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
      }
    }
  }

  Future<void> _deleteTransaction(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text(
          'This will remove the transaction and refund the money back to the account balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete & Refund',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deleteTransaction(id);
        await _loadTransactions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted and balance refunded!'),
            backgroundColor: AppColors.emerald700,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting transaction: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _transactions.where((tx) {
      final note = (tx['note'] as String? ?? '').toLowerCase();
      final category = (tx['category_name'] as String? ?? '').toLowerCase();
      final account = (tx['account_name'] as String? ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase();
      return q.isEmpty || note.contains(q) || category.contains(q) || account.contains(q);
    }).toList();

    // Group transactions by month
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var tx in filtered) {
      final date = DateTime.tryParse(tx['date']) ?? DateTime.now();
      final monthKey = DateFormat('MMMM yyyy').format(date);
      grouped.putIfAbsent(monthKey, () => []).add(tx);
    }

    final sortedMonths = grouped.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('MMMM yyyy').parse(a);
        final dateB = DateFormat('MMMM yyyy').parse(b);
        return dateB.compareTo(dateA);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Ledger', style: AppTypography.titleLarge),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.emerald700),
            )
          : RefreshIndicator(
              onRefresh: _loadTransactions,
              color: AppColors.emerald700,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // Search Box
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search ledger by note, category...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurface : AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: AppBorderRadius.mediumBorder,
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.gray200,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (filtered.isEmpty)
                    CustomCard(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            'No transactions found',
                            style: AppTypography.bodyMedium.copyWith(
                              color: isDark ? AppColors.gray400 : AppColors.gray600,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    ...sortedMonths.map((month) {
                      final txs = grouped[month]!;
                      double monthTotal = 0;
                      for (var t in txs) {
                        monthTotal += (t['amount'] as num?)?.toDouble() ?? 0.0;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  month,
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.emerald700,
                                  ),
                                ),
                                Text(
                                  'Total: ₹${monthTotal.toStringAsFixed(0)}',
                                  style: AppTypography.labelSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...txs.map((tx) {
                            final date = DateTime.tryParse(tx['date']) ?? DateTime.now();
                            final categoryName = tx['category_name'] ?? 'General';
                            final accountName = tx['account_name'] ?? 'Account';
                            final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                            final note = tx['note'] as String?;

                            return CustomCard(
                              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Row(
                                children: [
                                  CategoryBadge(label: categoryName),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          note != null && note.isNotEmpty ? note : categoryName,
                                          style: AppTypography.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '$accountName • ${DateFormat('MMM dd, yyyy').format(date)}',
                                          style: AppTypography.labelSmall.copyWith(
                                            color: isDark ? AppColors.gray400 : AppColors.gray600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '-${AppFormatters.currency(amount)}',
                                    style: AppTypography.titleMedium.copyWith(
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: isDark ? AppColors.gray500 : AppColors.gray400,
                                    ),
                                    onPressed: () => _deleteTransaction(tx['id']),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                  const SizedBox(height: AppSpacing.huge),
                ],
              ),
            ),
    );
  }
}
