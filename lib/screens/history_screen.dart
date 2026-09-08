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
  Set<String> _selectedTypes = {};
  Set<String> _selectedCategories = {};
  DateTime? _startDate;
  DateTime? _endDate;
  String? _errorMessage;

  static const _transactionTypes = <String, String>{
    'expense': 'Expenses',
    'income': 'Income',
    'transfer': 'Transfers',
    'goal_lock': 'Goal locks',
    'goal_unlock': 'Goal unlocks',
    'goal_payment': 'Goal payments',
  };

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getTransactionHistory(
        startDate: _startDate,
        endDate: _endDate,
      );
      final filteredData = data.where((transaction) {
        final type = transaction['type'] as String?;
        final category = transaction['category_name'] as String?;
        return (_selectedTypes.isEmpty || _selectedTypes.contains(type)) &&
            (_selectedCategories.isEmpty ||
                _selectedCategories.contains(category));
      }).toList();
      if (mounted) {
        setState(() {
          _transactions = filteredData;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load transaction history.';
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading history: $e')));
      }
    }
  }

  Future<void> _openFilters() async {
    final categories =
        (await DatabaseHelper.instance.readAllCategories())
            .map((category) => category.name)
            .toSet()
            .toList()
          ..sort();
    final draftTypes = {..._selectedTypes};
    final draftCategories = {..._selectedCategories};
    DateTime? draftStart = _startDate;
    DateTime? draftEnd = _endDate;
    var selectedTab = 0;
    if (!mounted) return;

    final result =
        await showModalBottomSheet<
          ({
            Set<String> types,
            Set<String> categories,
            DateTime? start,
            DateTime? end,
          })
        >(
          context: context,
          isScrollControlled: true,
          builder: (sheetContext) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                Future<void> selectDuration() async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: draftStart != null && draftEnd != null
                        ? DateTimeRange(start: draftStart!, end: draftEnd!)
                        : null,
                  );
                  if (picked != null) {
                    setSheetState(() {
                      draftStart = picked.start;
                      draftEnd = picked.end;
                    });
                  }
                }

                final options = selectedTab == 0
                    ? categories
                    : _transactionTypes.keys.toList();
                final labels = selectedTab == 0
                    ? {for (final category in categories) category: category}
                    : _transactionTypes;
                final selected = selectedTab == 0
                    ? draftCategories
                    : draftTypes;

                return SafeArea(
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.7,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              Text('Filters', style: AppTypography.titleLarge),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Close filters',
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              NavigationRail(
                                selectedIndex: selectedTab,
                                onDestinationSelected: (index) =>
                                    setSheetState(() => selectedTab = index),
                                labelType: NavigationRailLabelType.all,
                                destinations: const [
                                  NavigationRailDestination(
                                    icon: Icon(Icons.category_outlined),
                                    selectedIcon: Icon(Icons.category_rounded),
                                    label: Text('Category'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.swap_vert_rounded),
                                    selectedIcon: Icon(Icons.swap_vert_rounded),
                                    label: Text('Type'),
                                  ),
                                ],
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  children: [
                                    Text(
                                      selectedTab == 0
                                          ? 'Choose categories'
                                          : 'Choose transaction types',
                                      style: AppTypography.titleMedium,
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    ...options.map(
                                      (option) => CheckboxListTile(
                                        value: selected.contains(option),
                                        title: Text(labels[option] ?? option),
                                        contentPadding: EdgeInsets.zero,
                                        onChanged: (value) {
                                          setSheetState(() {
                                            if (value == true) {
                                              selected.add(option);
                                            } else {
                                              selected.remove(option);
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const Divider(height: AppSpacing.xl),
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.date_range_rounded,
                                      ),
                                      title: const Text('Duration'),
                                      subtitle: Text(
                                        draftStart == null || draftEnd == null
                                            ? 'Any date'
                                            : '${DateFormat('MMM d, yyyy').format(draftStart!)} - ${DateFormat('MMM d, yyyy').format(draftEnd!)}',
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right_rounded,
                                      ),
                                      onTap: selectDuration,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Row(
                            children: [
                              TextButton(
                                onPressed: () => setSheetState(() {
                                  draftTypes.clear();
                                  draftCategories.clear();
                                  draftStart = null;
                                  draftEnd = null;
                                }),
                                child: const Text('Clear all'),
                              ),
                              const Spacer(),
                              FilledButton(
                                onPressed: () => Navigator.pop(sheetContext, (
                                  types: {...draftTypes},
                                  categories: {...draftCategories},
                                  start: draftStart,
                                  end: draftEnd,
                                )),
                                child: const Text('Apply filters'),
                              ),
                            ],
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

    if (result != null && mounted) {
      setState(() {
        _selectedTypes = result.types;
        _selectedCategories = result.categories;
        _startDate = result.start;
        _endDate = result.end;
      });
      await _loadTransactions();
    }
  }

  String _transactionLabel(String type) =>
      _transactionTypes[type] ?? 'Transaction';

  bool _isCredit(String type) => type == 'income' || type == 'goal_unlock';

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
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deleteTransaction(id);
        await _loadTransactions();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted and balance refunded!'),
            backgroundColor: AppColors.emerald700,
          ),
        );
      } catch (e) {
        if (!mounted) return;
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
      return q.isEmpty ||
          note.contains(q) ||
          category.contains(q) ||
          account.contains(q);
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
        title: const Text(
          'Transaction Ledger',
          style: AppTypography.titleLarge,
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.emerald700),
            )
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_errorMessage!),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _loadTransactions,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
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
                      fillColor: isDark
                          ? AppColors.darkSurface
                          : AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: AppBorderRadius.mediumBorder,
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.gray200,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(
                      _selectedTypes.isEmpty &&
                              _selectedCategories.isEmpty &&
                              _startDate == null
                          ? 'Filters'
                          : 'Filters applied',
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
                              color: isDark
                                  ? AppColors.gray400
                                  : AppColors.gray600,
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
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
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
                                    color: isDark
                                        ? AppColors.gray400
                                        : AppColors.gray600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...txs.map((tx) {
                            final date =
                                DateTime.tryParse(tx['date']) ?? DateTime.now();
                            final categoryName =
                                tx['category_name'] ?? 'General';
                            final accountName = tx['account_name'] ?? 'Account';
                            final amount =
                                (tx['amount'] as num?)?.toDouble() ?? 0.0;
                            final note = tx['note'] as String?;
                            final type = tx['type'] as String? ?? 'expense';
                            final goalName = tx['goal_name'] as String?;
                            final destinationName =
                                tx['destination_account_name'] as String?;
                            final detail = destinationName == null
                                ? accountName
                                : '$accountName → $destinationName';
                            final label = _transactionLabel(type);

                            return CustomCard(
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Row(
                                children: [
                                  CategoryBadge(
                                    label: type == 'expense'
                                        ? categoryName
                                        : label,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          note != null && note.isNotEmpty
                                              ? note
                                              : goalName ??
                                                    (type == 'expense'
                                                        ? categoryName
                                                        : label),
                                          style: AppTypography.bodyMedium
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '$detail • ${DateFormat('MMM dd, yyyy').format(date)}',
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                                color: isDark
                                                    ? AppColors.gray400
                                                    : AppColors.gray600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${_isCredit(type)
                                        ? '+'
                                        : type == 'transfer'
                                        ? ''
                                        : '-'}${AppFormatters.currency(amount)}',
                                    style: AppTypography.titleMedium.copyWith(
                                      color: _isCredit(type)
                                          ? AppColors.success
                                          : type == 'transfer'
                                          ? AppColors.info
                                          : AppColors.danger,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: isDark
                                          ? AppColors.gray500
                                          : AppColors.gray400,
                                    ),
                                    onPressed: () =>
                                        _deleteTransaction(tx['id']),
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
