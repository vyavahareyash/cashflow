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
  DateTime? _selectedPeriod;
  String? _errorMessage;

  static const _transactionTypes = <String, String>{
    'expense': 'Expenses',
    'income': 'Income',
    'transfer': 'Transfers',
    'goal_lock': 'Goal locks',
    'goal_unlock': 'Goal unlocks',
    'goal_payment': 'Goal payments',
    'cc_payment': 'Card bill payments',
    'cc_lock': 'Card locks',
    'cc_unlock': 'Card unlocks',
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

  Future<void> _exportCSV() async {
    try {
      final path = await DatabaseHelper.instance.exportTransactionsAsCSV();
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV exported successfully to:\n$path'),
            backgroundColor: AppColors.emerald700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV export cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Widget _buildQuickFilterChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    bool isDark,
  ) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? (isDark ? AppColors.emerald400 : AppColors.emerald800)
              : (isDark ? AppColors.gray400 : AppColors.gray700),
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.gray100,
      selectedColor: isDark
          ? AppColors.emerald700.withValues(alpha: 0.25)
          : AppColors.emerald100,
      checkmarkColor: isDark ? AppColors.emerald400 : AppColors.emerald700,
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.pillBorder,
        side: BorderSide(
          color: isSelected
              ? AppColors.emerald600
              : (isDark ? AppColors.darkBorder : AppColors.gray300),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  String _transactionLabel(String type) {
    switch (type) {
      case 'cc_payment':
        return 'Card Bill Payment';
      case 'cc_lock':
        return 'Card Lock';
      case 'cc_unlock':
        return 'Card Unlock';
      default:
        return _transactionTypes[type] ?? 'Transaction';
    }
  }

  bool _isCredit(String type) =>
      type == 'income' || type == 'goal_unlock' || type == 'cc_unlock';

  void _setPeriod(DateTime? period) {
    setState(() {
      _selectedPeriod = period;
      if (period != null) {
        _startDate = DateTime(period.year, period.month, 1);
        _endDate = DateTime(period.year, period.month + 1, 0, 23, 59, 59);
      } else {
        _startDate = null;
        _endDate = null;
      }
    });
    _loadTransactions();
  }

  void _stepPeriod(int monthDelta) {
    final current =
        _selectedPeriod ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    final next = DateTime(current.year, current.month + monthDelta, 1);
    _setPeriod(next);
  }

  Future<void> _pickPeriodMonthYear() async {
    final current = _selectedPeriod ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      _setPeriod(DateTime(picked.year, picked.month, 1));
    }
  }

  Future<void> _deleteTransaction(Map<String, dynamic> tx) async {
    final id = tx['id'] as int;
    final type = tx['type'] as String? ?? 'expense';
    final amount = (tx['amount'] as num).toDouble();
    final accountName = tx['account_name'] as String? ?? 'Account';
    final destName = tx['destination_account_name'] as String? ?? 'Destination';

    String title;
    String content;
    String actionText;

    switch (type) {
      case 'expense':
        title = 'Delete Expense?';
        content =
            'This will delete the expense and refund ${AppFormatters.currency(amount)} back to $accountName.';
        actionText = 'Delete & Refund';
        break;
      case 'income':
        title = 'Delete Income?';
        content =
            'This will delete the income and deduct ${AppFormatters.currency(amount)} from $accountName.';
        actionText = 'Delete & Deduct';
        break;
      case 'transfer':
        title = 'Delete Transfer?';
        content =
            'This will reverse the transfer by returning ${AppFormatters.currency(amount)} to $accountName and deducting it from $destName.';
        actionText = 'Delete & Revert';
        break;
      case 'goal_lock':
        title = 'Delete Goal Lock?';
        content =
            'This will delete the lock record and release ${AppFormatters.currency(amount)} back to spendable funds.';
        actionText = 'Delete & Release';
        break;
      case 'goal_unlock':
        title = 'Delete Goal Unlock?';
        content =
            'This will delete the unlock record and re-lock ${AppFormatters.currency(amount)} into the goal.';
        actionText = 'Delete & Re-lock';
        break;
      case 'goal_payment':
        title = 'Delete Goal Payment?';
        content =
            'This will refund ${AppFormatters.currency(amount)} to $accountName and restore the locked goal balance.';
        actionText = 'Delete & Restore';
        break;
      case 'cc_payment':
        title = 'Delete Card Bill Payment?';
        content =
            'This will reverse the bill payment: refund ${AppFormatters.currency(amount)} to $destName and restore liability on $accountName.';
        actionText = 'Delete & Reverse';
        break;
      case 'cc_lock':
        title = 'Delete Card Lock?';
        content =
            'This will delete the card lock record and release ${AppFormatters.currency(amount)} back to spendable bank funds.';
        actionText = 'Delete & Release';
        break;
      case 'cc_unlock':
        title = 'Delete Card Unlock?';
        content =
            'This will delete the card unlock record and re-lock ${AppFormatters.currency(amount)} for credit card bill payment.';
        actionText = 'Delete & Re-lock';
        break;
      default:
        title = 'Delete Transaction?';
        content =
            'This will delete the transaction and update account balances.';
        actionText = 'Delete';
        break;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('confirm_delete_transaction_btn'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              actionText,
              style: const TextStyle(
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
            content: Text('Transaction deleted and balances updated.'),
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

  Future<void> _showEditTransactionDialog(Map<String, dynamic> tx) async {
    final type = tx['type'] as String? ?? 'expense';
    if (type == 'cc_payment' || type == 'cc_lock' || type == 'cc_unlock') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Card bill payment and lock records cannot be edited directly. Delete to reverse instead.',
          ),
        ),
      );
      return;
    }
    final isTransfer = type == 'transfer';
    final isGoal =
        type == 'goal_lock' || type == 'goal_unlock' || type == 'goal_payment';

    final accounts = await DatabaseHelper.instance.readAllAccounts();
    final categories = await DatabaseHelper.instance.readAllCategories();

    final amountNum = (tx['amount'] as num).toDouble();
    final amountController = TextEditingController(
      text: amountNum.truncateToDouble() == amountNum
          ? amountNum.toStringAsFixed(0)
          : amountNum.toStringAsFixed(2),
    );
    final noteController =
        TextEditingController(text: tx['note'] as String? ?? '');

    DateTime selectedDate =
        DateTime.tryParse(tx['date'] as String? ?? '') ?? DateTime.now();
    int selectedAccountId = tx['account_id'] as int;
    int? selectedDestAccountId = tx['destination_account_id'] as int?;
    int? selectedCategoryId = tx['category_id'] as int?;

    if (!accounts.any((a) => a.id == selectedAccountId) && accounts.isNotEmpty) {
      selectedAccountId = accounts.first.id!;
    }
    if (isTransfer &&
        selectedDestAccountId != null &&
        !accounts.any((a) => a.id == selectedDestAccountId)) {
      selectedDestAccountId =
          accounts.where((a) => a.id != selectedAccountId).firstOrNull?.id;
    }
    if (selectedCategoryId != null &&
        !categories.any((c) => c.id == selectedCategoryId)) {
      selectedCategoryId = null;
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (_, setDialogState) {
            return Container(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom +
                    AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.white,
                borderRadius: const BorderRadius.vertical(
                  top: AppBorderRadius.xlarge,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit ${_transactionLabel(type)}',
                          style: AppTypography.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (isGoal && tx['goal_name'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.emerald500.withValues(alpha: 0.1),
                          borderRadius: AppBorderRadius.smallBorder,
                          border: Border.all(
                            color: AppColors.emerald500.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.savings_rounded,
                              size: 18,
                              color: AppColors.emerald700,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Goal: ${tx['goal_name']}',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.emerald700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    TextField(
                      key: const Key('edit_transaction_amount_field'),
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(
                          borderRadius: AppBorderRadius.mediumBorder,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.calendar_today_rounded,
                        color: AppColors.emerald600,
                      ),
                      title: const Text('Transaction Date'),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd').format(selectedDate),
                      ),
                      trailing: const Icon(Icons.arrow_drop_down_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const Divider(),
                    DropdownButtonFormField<int>(
                      key: const Key('edit_transaction_account_dropdown'),
                      initialValue: selectedAccountId,
                      decoration: InputDecoration(
                        labelText: isTransfer ? 'Source Account' : 'Account',
                        border: const OutlineInputBorder(
                          borderRadius: AppBorderRadius.mediumBorder,
                        ),
                      ),
                      items: accounts.map((a) {
                        return DropdownMenuItem<int>(
                          value: a.id,
                          child: Text(
                            '${a.name} (${AppFormatters.compactCurrency(a.balance)})',
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedAccountId = val);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (isTransfer) ...[
                      DropdownButtonFormField<int>(
                        key: const Key('edit_transaction_dest_account_dropdown'),
                        initialValue: selectedDestAccountId,
                        decoration: const InputDecoration(
                          labelText: 'Destination Account',
                          border: OutlineInputBorder(
                            borderRadius: AppBorderRadius.mediumBorder,
                          ),
                        ),
                        items: accounts
                            .where((a) => a.id != selectedAccountId)
                            .map((a) {
                              return DropdownMenuItem<int>(
                                value: a.id,
                                child: Text(
                                  '${a.name} (${AppFormatters.compactCurrency(a.balance)})',
                                ),
                              );
                            })
                            .toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedDestAccountId = val);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (!isTransfer &&
                        type != 'goal_lock' &&
                        type != 'goal_unlock' &&
                        categories.isNotEmpty) ...[
                      DropdownButtonFormField<int?>(
                        key: const Key('edit_transaction_category_dropdown'),
                        initialValue: selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(
                            borderRadius: AppBorderRadius.mediumBorder,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Uncategorized'),
                          ),
                          ...categories.map((c) {
                            return DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(c.name),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setDialogState(() => selectedCategoryId = val);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    TextField(
                      key: const Key('edit_transaction_note_field'),
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note / Description',
                        border: OutlineInputBorder(
                          borderRadius: AppBorderRadius.mediumBorder,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      key: const Key('edit_transaction_save_btn'),
                      onPressed: () async {
                        final parsed =
                            double.tryParse(amountController.text.trim());
                        if (parsed == null || parsed <= 0) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter a valid amount greater than 0',
                              ),
                            ),
                          );
                          return;
                        }
                        if (isTransfer && selectedDestAccountId == null) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select a destination account',
                              ),
                            ),
                          );
                          return;
                        }

                        try {
                          await DatabaseHelper.instance.updateTransaction(
                            id: tx['id'],
                            amount: parsed,
                            date: selectedDate.toIso8601String(),
                            accountId: selectedAccountId,
                            destinationAccountId: selectedDestAccountId,
                            categoryId: selectedCategoryId,
                            note: noteController.text.trim(),
                          );
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          await _loadTransactions();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Transaction updated successfully.'),
                              backgroundColor: AppColors.emerald700,
                            ),
                          );
                        } catch (e) {
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(
                                content: Text('Error updating transaction: $e'),
                              ),
                            );
                          }
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.emerald700,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppBorderRadius.mediumBorder,
                        ),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _transactions.where((tx) {
      final note = (tx['note'] as String? ?? '').toLowerCase();
      final category = (tx['category_name'] as String? ?? '').toLowerCase();
      final account = (tx['account_name'] as String? ?? '').toLowerCase();
      final goal = (tx['goal_name'] as String? ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase();
      return q.isEmpty ||
          note.contains(q) ||
          category.contains(q) ||
          account.contains(q) ||
          goal.contains(q);
    }).toList();

    double totalOutflow = 0;
    double totalInflow = 0;
    for (final tx in filtered) {
      final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final type = tx['type'] as String? ?? 'expense';
      if (type == 'expense' ||
          type == 'goal_payment' ||
          type == 'goal_lock' ||
          type == 'cc_payment' ||
          type == 'cc_lock') {
        totalOutflow += amt;
      } else if (type == 'income' ||
          type == 'goal_unlock' ||
          type == 'cc_unlock') {
        totalInflow += amt;
      }
    }
    final netCashflow = totalInflow - totalOutflow;

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
                  // Search & Action Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('activity_ledger_search_field'),
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
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
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        key: const Key('activity_ledger_export_csv_btn'),
                        icon: const Icon(Icons.download_rounded),
                        tooltip: 'Export CSV',
                        style: IconButton.styleFrom(
                          backgroundColor: isDark
                              ? AppColors.darkSurface
                              : AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppBorderRadius.mediumBorder,
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.gray200,
                            ),
                          ),
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _exportCSV,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      IconButton(
                        key: const Key('activity_ledger_open_filters_btn'),
                        icon: Icon(
                          Icons.tune_rounded,
                          color: (_selectedCategories.isNotEmpty ||
                                  _startDate != null)
                              ? AppColors.emerald600
                              : null,
                        ),
                        tooltip: 'Advanced Filters',
                        style: IconButton.styleFrom(
                          backgroundColor: isDark
                              ? AppColors.darkSurface
                              : AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppBorderRadius.mediumBorder,
                            side: BorderSide(
                              color: (_selectedCategories.isNotEmpty ||
                                      _startDate != null)
                                  ? AppColors.emerald600
                                  : (isDark
                                      ? AppColors.darkBorder
                                      : AppColors.gray200),
                            ),
                          ),
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _openFilters,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Horizontal Quick Filter Chips Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickFilterChip(
                          'All',
                          _selectedTypes.isEmpty,
                          () {
                            setState(() => _selectedTypes.clear());
                            _loadTransactions();
                          },
                          isDark,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _buildQuickFilterChip(
                          'Expenses',
                          _selectedTypes.length == 1 &&
                              _selectedTypes.contains('expense'),
                          () {
                            setState(() {
                              if (_selectedTypes.contains('expense')) {
                                _selectedTypes.clear();
                              } else {
                                _selectedTypes = {'expense'};
                              }
                            });
                            _loadTransactions();
                          },
                          isDark,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _buildQuickFilterChip(
                          'Income',
                          _selectedTypes.length == 1 &&
                              _selectedTypes.contains('income'),
                          () {
                            setState(() {
                              if (_selectedTypes.contains('income')) {
                                _selectedTypes.clear();
                              } else {
                                _selectedTypes = {'income'};
                              }
                            });
                            _loadTransactions();
                          },
                          isDark,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _buildQuickFilterChip(
                          'Transfers',
                          _selectedTypes.length == 1 &&
                              _selectedTypes.contains('transfer'),
                          () {
                            setState(() {
                              if (_selectedTypes.contains('transfer')) {
                                _selectedTypes.clear();
                              } else {
                                _selectedTypes = {'transfer'};
                              }
                            });
                            _loadTransactions();
                          },
                          isDark,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _buildQuickFilterChip(
                          'Goal Locks',
                          _selectedTypes.contains('goal_lock') ||
                              _selectedTypes.contains('goal_unlock'),
                          () {
                            setState(() {
                              if (_selectedTypes.contains('goal_lock')) {
                                _selectedTypes.clear();
                              } else {
                                _selectedTypes = {
                                  'goal_lock',
                                  'goal_unlock',
                                  'goal_payment',
                                };
                              }
                            });
                            _loadTransactions();
                          },
                          isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Period Selector & Summary Card
                  CustomCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  key: const Key('activity_ledger_prev_period_btn'),
                                  icon: const Icon(Icons.chevron_left_rounded),
                                  tooltip: 'Previous Month',
                                  onPressed: () => _stepPeriod(-1),
                                  visualDensity: VisualDensity.compact,
                                ),
                                InkWell(
                                  key: const Key('activity_ledger_pick_period_btn'),
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: _pickPeriodMonthYear,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xs,
                                      vertical: AppSpacing.xs,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _selectedPeriod == null
                                              ? Icons.all_inclusive_rounded
                                              : Icons.calendar_month_rounded,
                                          size: 18,
                                          color: AppColors.emerald600,
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Text(
                                          _selectedPeriod == null
                                              ? 'All Time'
                                              : DateFormat('MMMM yyyy').format(_selectedPeriod!),
                                          style: AppTypography.titleMedium.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  key: const Key('activity_ledger_next_period_btn'),
                                  icon: const Icon(Icons.chevron_right_rounded),
                                  tooltip: 'Next Month',
                                  onPressed: () => _stepPeriod(1),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            TextButton(
                              key: const Key('activity_ledger_toggle_all_time_btn'),
                              onPressed: () => _setPeriod(
                                _selectedPeriod == null
                                    ? DateTime(
                                        DateTime.now().year,
                                        DateTime.now().month,
                                        1,
                                      )
                                    : null,
                              ),
                              child: Text(
                                _selectedPeriod == null ? 'Show Month' : 'All Time',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  'Outflow',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: isDark
                                        ? AppColors.gray400
                                        : AppColors.gray600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '-${AppFormatters.compactCurrency(totalOutflow)}',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  'Inflow',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: isDark
                                        ? AppColors.gray400
                                        : AppColors.gray600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '+${AppFormatters.compactCurrency(totalInflow)}',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  'Net',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: isDark
                                        ? AppColors.gray400
                                        : AppColors.gray600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${netCashflow >= 0 ? '+' : ''}${AppFormatters.compactCurrency(netCashflow)}',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: netCashflow >= 0
                                        ? AppColors.emerald600
                                        : AppColors.danger,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  'Count',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: isDark
                                        ? AppColors.gray400
                                        : AppColors.gray600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${filtered.length}',
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
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

                                    final isGoalTx = type == 'goal_lock' ||
                                        type == 'goal_unlock' ||
                                        type == 'goal_payment';
                                    final dateFormatted =
                                        DateFormat('MMM dd').format(date);
                                    String tileTitle;
                                    String tileSubtitle;

                                    if (isGoalTx) {
                                      final planDisplay = goalName ?? label;
                                      final catInfo = (type == 'goal_payment' &&
                                              categoryName != 'General' &&
                                              categoryName.isNotEmpty)
                                          ? ' • $categoryName'
                                          : '';
                                      if (note != null && note.isNotEmpty) {
                                        tileTitle = note;
                                        tileSubtitle =
                                            '$label • Goal: $planDisplay$catInfo • $detail • $dateFormatted';
                                      } else {
                                        tileTitle = planDisplay;
                                        tileSubtitle =
                                            '$label$catInfo • $detail • $dateFormatted';
                                      }
                                    } else {
                                      if (note != null && note.isNotEmpty) {
                                        tileTitle = note;
                                        tileSubtitle =
                                            '${type == 'expense' ? categoryName : label} • $detail • $dateFormatted';
                                      } else {
                                        tileTitle = type == 'expense'
                                            ? categoryName
                                            : label;
                                        tileSubtitle =
                                            '$detail • $dateFormatted';
                                      }
                                    }

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
                                            iconOnly: true,
                                          ),
                                          const SizedBox(width: AppSpacing.sm + 2),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  tileTitle,
                                                  style: AppTypography.bodyMedium
                                                      .copyWith(
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  tileSubtitle,
                                                  style: AppTypography.labelSmall
                                                      .copyWith(
                                                        color: isDark
                                                            ? AppColors.gray400
                                                            : AppColors.gray600,
                                                      ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
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
                                          PopupMenuButton<String>(
                                            key: Key('options_tx_${tx['id']}'),
                                            icon: Icon(
                                              Icons.more_vert_rounded,
                                              size: 18,
                                              color: isDark
                                                  ? AppColors.gray400
                                                  : AppColors.gray600,
                                            ),
                                            tooltip: 'Transaction options',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            splashRadius: 16,
                                            color: isDark
                                                ? AppColors.darkSurface
                                                : AppColors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  AppBorderRadius.mediumBorder,
                                              side: BorderSide(
                                                color: isDark
                                                    ? AppColors.darkBorder
                                                    : AppColors.gray200,
                                                width: 1,
                                              ),
                                            ),
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _showEditTransactionDialog(tx);
                                              } else if (value == 'delete') {
                                                _deleteTransaction(tx);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              if (tx['type'] != 'cc_payment' &&
                                                  tx['type'] != 'cc_lock' &&
                                                  tx['type'] != 'cc_unlock')
                                                PopupMenuItem(
                                                  value: 'edit',
                                                  height: 36,
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.edit_outlined,
                                                        size: 16,
                                                        color: isDark
                                                            ? AppColors.gray300
                                                            : AppColors.gray700,
                                                      ),
                                                      const SizedBox(
                                                          width: AppSpacing.sm),
                                                      Text(
                                                        'Edit',
                                                        style: AppTypography.labelMedium
                                                            .copyWith(
                                                          color: isDark
                                                              ? AppColors.darkText
                                                              : AppColors.gray900,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                height: 36,
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.delete_outline_rounded,
                                                      size: 16,
                                                      color: AppColors.danger,
                                                    ),
                                                    const SizedBox(
                                                        width: AppSpacing.sm),
                                                    Text(
                                                      'Delete',
                                                      style: AppTypography.labelMedium
                                                          .copyWith(
                                                        color: AppColors.danger,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
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
