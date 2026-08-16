import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../models/account_model.dart';
import '../models/locked_allocation_model.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';
import '../components/custom_input.dart';
import '../components/custom_button.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<Account> _accounts = [];
  Map<int, List<LockedAllocation>> _accountLocks = {};
  double _totalPhysical = 0.0;
  double _totalLocked = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshAccounts();
    DatabaseHelper.dataRevision.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    DatabaseHelper.dataRevision.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      _refreshAccounts();
    }
  }

  Future<void> _refreshAccounts() async {
    if (_accounts.isEmpty) {
      setState(() => _isLoading = true);
    }
    final data = await DatabaseHelper.instance.readAllAccounts();
    double total = 0.0;
    double lockedTotal = 0.0;
    Map<int, List<LockedAllocation>> locksMap = {};

    for (var acc in data) {
      total += acc.balance;
      if (acc.id != null) {
        final locks = await DatabaseHelper.instance.getLocksForAccount(acc.id!);
        locksMap[acc.id!] = locks;
        for (var l in locks) {
          lockedTotal += l.amount;
        }
      }
    }

    if (mounted) {
      setState(() {
        _accounts = data;
        _accountLocks = locksMap;
        _totalPhysical = total;
        _totalLocked = lockedTotal;
        _isLoading = false;
      });
    }
  }

  void _showAddAccountDialog() {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();
    String selectedType = 'Bank';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: AppBorderRadius.xlargeBorder,
            ),
            title: Text(
              'Add New Account',
              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomInputField(
                      controller: nameController,
                      label: 'Account Name',
                      hint: 'e.g. HDFC Bank, Cash Wallet, Salary A/C',
                      prefixIcon: Icons.account_balance_rounded,
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Please enter an account name'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomInputField(
                      controller: balanceController,
                      label: 'Current Physical Balance',
                      hint: '0.00',
                      prefixText: '₹ ',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a balance';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Type',
                          style: AppTypography.labelMedium.copyWith(
                            color: isDark ? AppColors.gray300 : AppColors.gray700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        DropdownButtonFormField<String>(
                          value: selectedType,
                          dropdownColor: isDark ? AppColors.darkSurfaceElevated : AppColors.white,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? AppColors.darkSurface : AppColors.gray50,
                            border: OutlineInputBorder(
                              borderRadius: AppBorderRadius.mediumBorder,
                              borderSide: BorderSide(
                                color: isDark ? AppColors.darkBorder : AppColors.gray300,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                          ),
                          items: ['Bank', 'Cash', 'Savings', 'Wallet']
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                          onChanged: (val) => setStateDialog(() => selectedType = val!),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              CustomButton(
                label: 'Save Account',
                width: 130,
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    await DatabaseHelper.instance.createAccount(
                      Account(
                        name: nameController.text.trim(),
                        balance: double.tryParse(balanceController.text.trim()) ?? 0.0,
                        type: selectedType,
                      ),
                    );
                    Navigator.pop(context);
                    _refreshAccounts();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditAccountDialog(Account account) {
    final nameController = TextEditingController(text: account.name);
    final balanceController = TextEditingController(text: account.balance.toStringAsFixed(0));
    String selectedType = account.type;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: AppBorderRadius.xlargeBorder,
            ),
            title: Text(
              'Edit Account',
              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomInputField(
                      controller: nameController,
                      label: 'Account Name',
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Please enter an account name'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomInputField(
                      controller: balanceController,
                      label: 'Balance',
                      prefixText: '₹ ',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter balance';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      dropdownColor: isDark ? AppColors.darkSurfaceElevated : AppColors.white,
                      decoration: InputDecoration(
                        labelText: 'Account Type',
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurface : AppColors.gray50,
                        border: OutlineInputBorder(
                          borderRadius: AppBorderRadius.mediumBorder,
                        ),
                      ),
                      items: ['Bank', 'Cash', 'Savings', 'Wallet']
                          .map(
                            (type) => DropdownMenuItem(value: type, child: Text(type)),
                          )
                          .toList(),
                      onChanged: (val) => setStateDialog(() => selectedType = val!),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => _showDeleteConfirmation(account),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              CustomButton(
                label: 'Update',
                width: 100,
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    await DatabaseHelper.instance.updateAccount(
                      Account(
                        id: account.id,
                        name: nameController.text.trim(),
                        balance: double.tryParse(balanceController.text.trim()) ?? 0.0,
                        type: selectedType,
                      ),
                    );
                    Navigator.pop(context);
                    _refreshAccounts();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(Account account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Text(
          'Are you sure you want to delete "${account.name}"? Any past transactions referencing this account will remain in ledger.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.deleteAccount(account.id!);
              Navigator.pop(context); // close delete dialog
              Navigator.pop(context); // close edit dialog
              _refreshAccounts();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final availableLiquidity = (_totalPhysical - _totalLocked).clamp(0.0, double.infinity);

    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.emerald700),
            )
          : RefreshIndicator(
              onRefresh: _refreshAccounts,
              color: AppColors.emerald700,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // 1. TOP SUMMARY CARD
                  _buildHeaderCard(isDark, availableLiquidity),
                  const SizedBox(height: AppSpacing.xl),

                  // 2. SECTION TITLE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'All Accounts',
                        style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_accounts.length} Total',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. ACCOUNTS LIST
                  if (_accounts.isEmpty)
                    CustomCard(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            children: [
                              Icon(
                                Icons.account_balance_outlined,
                                size: 48,
                                color: isDark ? AppColors.gray600 : AppColors.gray400,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'No accounts added yet',
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Add your physical bank accounts, cash wallets, or savings accounts below.',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ..._accounts.map((acc) => _buildAccountCard(acc, isDark)),

                  const SizedBox(height: AppSpacing.huge),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAccountDialog,
        backgroundColor: AppColors.emerald700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Account', style: AppTypography.labelLarge),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark, double availableLiquidity) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: AppBorderRadius.xlargeBorder,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.gray200,
          width: 1,
        ),
        boxShadow: isDark ? [] : [AppShadows.level1],
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Physical Wealth',
            style: AppTypography.labelMedium.copyWith(
              color: isDark ? AppColors.gray400 : AppColors.gray600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppFormatters.currency(_totalPhysical),
            style: AppTypography.displayLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkText : AppColors.gray900,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Locked in Sinking Funds',
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                    ),
                  ),
                  Text(
                    AppFormatters.currency(_totalLocked),
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Available Liquidity',
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                    ),
                  ),
                  Text(
                    AppFormatters.currency(availableLiquidity),
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.emerald600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(Account acc, bool isDark) {
    final locks = _accountLocks[acc.id] ?? [];
    double lockedInAcc = 0;
    for (var l in locks) {
      lockedInAcc += l.amount;
    }
    final isBank = acc.type == 'Bank';

    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: (isBank ? AppColors.info : AppColors.emerald600).withOpacity(0.12),
                  borderRadius: AppBorderRadius.mediumBorder,
                ),
                child: Icon(
                  isBank ? Icons.account_balance_rounded : Icons.wallet_rounded,
                  color: isBank ? AppColors.info : AppColors.emerald600,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      acc.name,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      acc.type,
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormatters.currency(acc.balance),
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (lockedInAcc > 0)
                    Text(
                      '₹${lockedInAcc.toStringAsFixed(0)} locked',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                ),
                onPressed: () => _showEditAccountDialog(acc),
              ),
            ],
          ),
          if (locks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 12),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Locked Funds in this account:',
              style: AppTypography.labelSmall.copyWith(
                color: isDark ? AppColors.gray400 : AppColors.gray600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ...locks.map((lock) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '• ${lock.planName}',
                        style: AppTypography.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      AppFormatters.currency(lock.amount),
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
