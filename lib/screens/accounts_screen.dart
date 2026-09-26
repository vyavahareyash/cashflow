import 'dart:async';

import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../models/account_model.dart';
import '../models/credit_card_model.dart';
import '../models/locked_allocation_model.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';
import '../components/custom_input.dart';
import '../components/custom_button.dart';
import '../components/pay_cc_bill_modal.dart';
import '../components/lock_cc_funds_modal.dart';
import '../components/unlock_cc_funds_modal.dart';
import '../components/app_dialogs.dart';
import '../components/walkthrough/walkthrough_keys.dart';
import 'budget_screen.dart';
import 'goals_screen.dart';

class AccountsScreen extends StatefulWidget {
  final int initialTabIndex;
  final ValueChanged<int>? onTabChanged;

  const AccountsScreen({
    super.key,
    this.initialTabIndex = 0,
    this.onTabChanged,
  });

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<Account> _accounts = [];
  Map<int, CreditCard> _creditCardsMap = {};
  Map<int, double> _ccLockedMap = {};
  Map<int, List<LockedAllocation>> _accountLocks = {};
  double _totalPhysical = 0.0;
  double _totalCreditOutstanding = 0.0;
  double _totalLocked = 0.0;
  bool _isLoading = true;
  final Set<int> _expandedAccountIds = {};
  late int _selectedTab;
  final Set<int> _loadedTabs = {};

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex.clamp(0, 2);
    _loadedTabs.add(_selectedTab);
    if (_selectedTab == 0) {
      unawaited(_refreshAccounts());
    }
    DatabaseHelper.dataRevision.addListener(_onDataChanged);
  }

  @override
  void didUpdateWidget(AccountsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      final newIndex = widget.initialTabIndex.clamp(0, 2);
      setState(() {
        _selectedTab = newIndex;
        if (!_loadedTabs.contains(0) && newIndex == 0) {
          unawaited(_refreshAccounts());
        }
        _loadedTabs.add(newIndex);
      });
    }
  }

  @override
  void dispose() {
    DatabaseHelper.dataRevision.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      unawaited(_refreshAccounts());
    }
  }

  Future<void> _refreshAccounts() async {
    if (_accounts.isEmpty) {
      setState(() => _isLoading = true);
    }
    final data = await DatabaseHelper.instance.readAllAccounts();
    final ccList = await DatabaseHelper.instance.readAllCreditCards();
    final Map<int, CreditCard> ccMap = {
      for (final cc in ccList) cc.accountId: cc,
    };
    final Map<int, double> ccLocks = {};
    for (final cc in ccList) {
      if (cc.id != null) {
        ccLocks[cc.id!] = await DatabaseHelper.instance
            .getLockedAmountForCreditCard(cc.id!);
      }
    }

    double physicalTotal = 0.0;
    double ccTotal = 0.0;
    double lockedTotal = 0.0;
    final Map<int, List<LockedAllocation>> locksMap = {};

    for (var acc in data) {
      if (acc.isCreditCard) {
        ccTotal += acc.balance;
      } else {
        physicalTotal += acc.balance;
      }
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
        _creditCardsMap = ccMap;
        _ccLockedMap = ccLocks;
        _accountLocks = locksMap;
        _totalPhysical = physicalTotal;
        _totalCreditOutstanding = ccTotal;
        _totalLocked = lockedTotal;
        _isLoading = false;
      });
    }
  }

  void _showAddAccountDialog() {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();
    final creditLimitController = TextEditingController();
    final statementDayController = TextEditingController(text: '1');
    final dueDayController = TextEditingController(text: '20');
    String selectedType = 'Bank';
    int? defaultLockAccountId = _accounts
        .where((a) => !a.isCreditCard)
        .firstOrNull
        ?.id;
    bool autoLock = true;
    final formKey = GlobalKey<FormState>();

    unawaited(
      showDialog(
        context: context,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final bankAccounts = _accounts.where((a) => !a.isCreditCard).toList();
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              final isCC = selectedType == 'Credit Card';
              return AlertDialog(
                backgroundColor: isDark
                    ? AppColors.darkSurface
                    : AppColors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppBorderRadius.xlargeBorder,
                ),
                title: Text(
                  'Add New Account',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomInputField(
                          controller: nameController,
                          label: isCC ? 'Card Name' : 'Account Name',
                          hint: isCC
                              ? 'e.g. HDFC Regalia, ICICI Amazon Pay'
                              : 'e.g. HDFC Bank, Cash Wallet, Salary A/C',
                          prefixIcon: isCC
                              ? Icons.credit_card_rounded
                              : Icons.account_balance_rounded,
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Please enter an account name'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Type',
                              style: AppTypography.labelMedium.copyWith(
                                color: isDark
                                    ? AppColors.gray300
                                    : AppColors.gray700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            DropdownButtonFormField<String>(
                              initialValue: selectedType,
                              isExpanded: true,
                              dropdownColor: isDark
                                  ? AppColors.darkSurfaceElevated
                                  : AppColors.white,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark
                                    ? AppColors.darkSurface
                                    : AppColors.gray50,
                                border: OutlineInputBorder(
                                  borderRadius: AppBorderRadius.mediumBorder,
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.gray300,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                  vertical: AppSpacing.md,
                                ),
                              ),
                              items:
                                  [
                                        'Bank',
                                        'Cash',
                                        'Savings',
                                        'Wallet',
                                        'Credit Card',
                                      ]
                                      .map(
                                        (type) => DropdownMenuItem(
                                          value: type,
                                          child: Text(type),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setStateDialog(() => selectedType = val);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CustomInputField(
                          controller: balanceController,
                          label: isCC
                              ? 'Current Outstanding (Owed)'
                              : 'Current Physical Balance',
                          hint: '0.00',
                          prefixText: '₹ ',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
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
                        if (isCC) ...[
                          const SizedBox(height: AppSpacing.md),
                          CustomInputField(
                            controller: creditLimitController,
                            label: 'Total Credit Limit',
                            hint: 'e.g. 100000',
                            prefixText: '₹ ',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter credit limit';
                              }
                              final numVal = double.tryParse(value);
                              if (numVal == null || numVal <= 0) {
                                return 'Please enter a valid positive limit';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: CustomInputField(
                                  controller: statementDayController,
                                  label: 'Statement Day',
                                  hint: '1 - 31',
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    final day = int.tryParse(value ?? '');
                                    if (day == null || day < 1 || day > 31) {
                                      return '1-31';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: CustomInputField(
                                  controller: dueDayController,
                                  label: 'Due Day',
                                  hint: '1 - 31',
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    final day = int.tryParse(value ?? '');
                                    if (day == null || day < 1 || day > 31) {
                                      return '1-31';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (bankAccounts.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Default Account to Lock Funds',
                              style: AppTypography.labelMedium.copyWith(
                                color: isDark
                                    ? AppColors.gray300
                                    : AppColors.gray700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            DropdownButtonFormField<int>(
                              initialValue: defaultLockAccountId,
                              isExpanded: true,
                              dropdownColor: isDark
                                  ? AppColors.darkSurfaceElevated
                                  : AppColors.white,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark
                                    ? AppColors.darkSurface
                                    : AppColors.gray50,
                                border: OutlineInputBorder(
                                  borderRadius: AppBorderRadius.mediumBorder,
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.gray300,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                  vertical: AppSpacing.md,
                                ),
                              ),
                              items: bankAccounts
                                  .map(
                                    (a) => DropdownMenuItem(
                                      value: a.id,
                                      child: Text(a.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) => setStateDialog(
                                () => defaultLockAccountId = val,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Auto-lock funds on spend',
                                style: AppTypography.bodySmall,
                              ),
                              subtitle: Text(
                                'Locks matching funds in the linked bank account to ensure bill is 100% cash-backed.',
                                style: AppTypography.labelSmall.copyWith(
                                  color: isDark
                                      ? AppColors.gray400
                                      : AppColors.gray600,
                                ),
                              ),
                              value: autoLock,
                              activeThumbColor: AppColors.purple,
                              onChanged: (val) =>
                                  setStateDialog(() => autoLock = val),
                            ),
                          ],
                        ],
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
                        final accountId = await DatabaseHelper.instance
                            .createAccount(
                              Account(
                                name: nameController.text.trim(),
                                balance:
                                    double.tryParse(
                                      balanceController.text.trim(),
                                    ) ??
                                    0.0,
                                type: selectedType,
                              ),
                            );
                        if (selectedType == 'Credit Card') {
                          await DatabaseHelper.instance.createCreditCard(
                            CreditCard(
                              accountId: accountId,
                              creditLimit:
                                  double.tryParse(
                                    creditLimitController.text.trim(),
                                  ) ??
                                  0.0,
                              statementDay:
                                  int.tryParse(
                                    statementDayController.text.trim(),
                                  ) ??
                                  1,
                              dueDay:
                                  int.tryParse(dueDayController.text.trim()) ??
                                  20,
                              defaultLockAccountId: defaultLockAccountId,
                              autoLock: autoLock,
                            ),
                          );
                        }
                        if (context.mounted) Navigator.pop(context);
                        unawaited(_refreshAccounts());
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showEditAccountDialog(Account account) {
    unawaited(
      showDialog(
        context: context,
        builder: (dialogCtx) => EditAccountDialog(
          account: account,
          creditCard: _creditCardsMap[account.id],
          bankAccounts: _accounts.where((a) => !a.isCreditCard).toList(),
          onAccountSaved: _refreshAccounts,
          onAccountDeleted: _refreshAccounts,
        ),
      ),
    );
  }

  void _showTransferDialog(Account sourceAccount) {
    final otherAccounts = _accounts
        .where((a) => a.id != sourceAccount.id && !a.isCreditCard)
        .toList();
    if (otherAccounts.isEmpty) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    unawaited(
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetCtx) => TransferFundsModal(
          sourceAccount: sourceAccount,
          destinationAccounts: otherAccounts,
          onTransferCompleted: _refreshAccounts,
        ),
      ),
    );
  }

  void _openUnlockModalForCreditCard(int ccId) {
    CreditCard? cc;
    Account? ccAcc;
    for (final c in _creditCardsMap.values) {
      if (c.id == ccId) {
        cc = c;
        break;
      }
    }
    if (cc != null) {
      for (final a in _accounts) {
        if (a.id == cc.accountId) {
          ccAcc = a;
          break;
        }
      }
    }
    if (cc != null && ccAcc != null) {
      final locked = _ccLockedMap[cc.id!] ?? 0.0;
      unawaited(
        UnlockCcFundsModal.show(
          context,
          ccAccount: ccAcc,
          creditCard: cc,
          lockedAmount: locked,
          onUnlockCompleted: _refreshAccounts,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final availableLiquidity = (_totalPhysical - _totalLocked).clamp(
      0.0,
      double.infinity,
    );
    final physicalAccounts = _accounts.where((a) => !a.isCreditCard).toList();
    final creditAccounts = _accounts.where((a) => a.isCreditCard).toList();

    return Scaffold(
      appBar: Navigator.canPop(context)
          ? AppBar(
              title: Text(
                _selectedTab == 1
                    ? 'Monthly Budgets'
                    : _selectedTab == 2
                    ? 'Sinking Funds'
                    : 'My Accounts',
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  key: const Key('accounts_page_segmented_tabs'),
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: AppTypography.labelMedium,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                  ),
                  segments: const [
                    ButtonSegment<int>(
                      value: 0,
                      label: Text('Accounts', maxLines: 1, softWrap: false),
                      icon: Icon(Icons.account_balance_rounded, size: 18),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      label: Text('Budgets', maxLines: 1, softWrap: false),
                      icon: Icon(Icons.pie_chart_rounded, size: 18),
                    ),
                    ButtonSegment<int>(
                      value: 2,
                      label: Text('Goals', maxLines: 1, softWrap: false),
                      icon: Icon(Icons.savings_rounded, size: 18),
                    ),
                  ],
                  selected: {_selectedTab},
                  onSelectionChanged: (newSelection) {
                    final newIndex = newSelection.first;
                    setState(() {
                      _selectedTab = newIndex;
                      if (!_loadedTabs.contains(0) && newIndex == 0) {
                        unawaited(_refreshAccounts());
                      }
                      _loadedTabs.add(_selectedTab);
                    });
                    widget.onTabChanged?.call(_selectedTab);
                  },
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  _loadedTabs.contains(0)
                      ? _buildAccountsView(
                          isDark,
                          availableLiquidity,
                          physicalAccounts,
                          creditAccounts,
                        )
                      : const SizedBox.shrink(),
                  _loadedTabs.contains(1)
                      ? const BudgetScreen(isEmbedded: true)
                      : const SizedBox.shrink(),
                  _loadedTabs.contains(2)
                      ? const GoalsScreen(isEmbedded: true)
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsView(
    bool isDark,
    double availableLiquidity,
    List<Account> physicalAccounts,
    List<Account> creditAccounts,
  ) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.emerald700),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAccounts,
      color: AppColors.emerald700,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          120,
        ),
        children: [
          // 1. TOP SUMMARY CARD
          _buildHeaderCard(isDark, availableLiquidity),
          const SizedBox(height: AppSpacing.xl),

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
                        'Add your physical bank accounts, cash wallets, or credit cards below.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        key: const Key('accounts_empty_add_pill_btn'),
                        onPressed: _showAddAccountDialog,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Account'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.emerald700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            // 2. BANK & CASH ACCOUNTS SECTION WITH ACTION PILL
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bank & Cash Accounts',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${physicalAccounts.length} Total',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  key: const Key('accounts_add_pill_btn'),
                  onPressed: _showAddAccountDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Add Account',
                    style: AppTypography.labelMedium,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            if (physicalAccounts.isEmpty)
              CustomCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'No bank or cash accounts added yet.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                  ),
                ),
              )
            else
              ...physicalAccounts.map(
                (acc) => AccountCard(
                  account: acc,
                  locks: _accountLocks[acc.id] ?? [],
                  isExpanded:
                      acc.id != null && _expandedAccountIds.contains(acc.id),
                  onExpansionChanged: (expanded) {
                    if (acc.id != null) {
                      setState(() {
                        if (expanded) {
                          _expandedAccountIds.add(acc.id!);
                        } else {
                          _expandedAccountIds.remove(acc.id!);
                        }
                      });
                    }
                  },
                  onTransfer: physicalAccounts.length > 1
                      ? () => _showTransferDialog(acc)
                      : null,
                  onEdit: () => _showEditAccountDialog(acc),
                  onUnlockCreditCardLock: _openUnlockModalForCreditCard,
                ),
              ),

            const SizedBox(height: AppSpacing.xl),

            // 3. CREDIT CARDS SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Credit Cards',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${creditAccounts.length} Total',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            if (creditAccounts.isEmpty)
              CustomCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'No credit cards added. Tap Add Account to add a card.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                  ),
                ),
              )
            else
              ...creditAccounts.map((acc) {
                final cc = _creditCardsMap[acc.id];
                final lockedAmount = cc?.id != null
                    ? (_ccLockedMap[cc!.id!] ?? 0.0)
                    : 0.0;
                return CreditCardAccountCard(
                  account: acc,
                  creditCard: cc,
                  lockedAmount: lockedAmount,
                  onEdit: () => _showEditAccountDialog(acc),
                  onLock: cc != null
                      ? () => LockCcFundsModal.show(
                          context,
                          ccAccount: acc,
                          creditCard: cc,
                          lockedAmount: lockedAmount,
                          bankAccounts: physicalAccounts,
                          onLockCompleted: _refreshAccounts,
                        )
                      : null,
                  onUnlock: cc != null && lockedAmount > 0
                      ? () => UnlockCcFundsModal.show(
                          context,
                          ccAccount: acc,
                          creditCard: cc,
                          lockedAmount: lockedAmount,
                          onUnlockCompleted: _refreshAccounts,
                        )
                      : null,
                  onPayBill: cc != null
                      ? () => PayCcBillModal.show(
                          context,
                          ccAccount: acc,
                          creditCard: cc,
                          lockedAmount: lockedAmount,
                          bankAccounts: physicalAccounts,
                          onPaymentCompleted: _refreshAccounts,
                        )
                      : null,
                );
              }),
          ],

          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark, double availableLiquidity) {
    return Container(
      key: WalkthroughKeys.accountsSummaryKey,
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
          if (_totalCreditOutstanding > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.credit_card_rounded,
                      size: 16,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Card Liabilities (Money Owed)',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                  ],
                ),
                Text(
                  AppFormatters.currency(_totalCreditOutstanding),
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class AggregatedGoalLock {
  final int goalId;
  final String goalName;
  final double amount;
  final bool isCreditCard;

  const AggregatedGoalLock({
    required this.goalId,
    required this.goalName,
    required this.amount,
    this.isCreditCard = false,
  });
}

class AccountCard extends StatefulWidget {
  final Account account;
  final List<LockedAllocation> locks;
  final VoidCallback? onEdit;
  final VoidCallback? onTransfer;
  final bool? isExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final ValueChanged<int>? onUnlockCreditCardLock;

  const AccountCard({
    super.key,
    required this.account,
    this.locks = const [],
    this.onEdit,
    this.onTransfer,
    this.isExpanded,
    this.onExpansionChanged,
    this.onUnlockCreditCardLock,
  });

  static List<AggregatedGoalLock> aggregateLocks(List<LockedAllocation> locks) {
    final Map<String, AggregatedGoalLock> map = {};
    for (final lock in locks) {
      final key = lock.isCreditCardLock
          ? 'cc_${lock.creditCardId ?? 0}'
          : 'goal_${lock.goalId ?? 0}';
      final id = lock.isCreditCardLock
          ? (lock.creditCardId ?? 0)
          : (lock.goalId ?? 0);
      final name = lock.displayName;

      if (map.containsKey(key)) {
        final existing = map[key]!;
        map[key] = AggregatedGoalLock(
          goalId: id,
          goalName: existing.goalName.isNotEmpty ? existing.goalName : name,
          amount: existing.amount + lock.amount,
          isCreditCard: lock.isCreditCardLock,
        );
      } else {
        map[key] = AggregatedGoalLock(
          goalId: id,
          goalName: name,
          amount: lock.amount,
          isCreditCard: lock.isCreditCardLock,
        );
      }
    }
    return map.values.toList();
  }

  @override
  State<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<AccountCard> {
  bool _internalExpanded = false;

  bool get _isExpanded => widget.isExpanded ?? _internalExpanded;

  void _toggleExpanded() {
    final next = !_isExpanded;
    if (widget.onExpansionChanged != null) {
      widget.onExpansionChanged!(next);
    } else {
      setState(() {
        _internalExpanded = next;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final acc = widget.account;
    final isBank = acc.type == 'Bank';
    final aggregatedLocks = AccountCard.aggregateLocks(widget.locks);
    final totalLocked = widget.locks.fold<double>(
      0.0,
      (sum, l) => sum + l.amount,
    );
    final usableBalance = (acc.balance - totalLocked).clamp(
      0.0,
      double.infinity,
    );

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
                  color: (isBank ? AppColors.info : AppColors.emerald600)
                      .withValues(alpha: 0.12),
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
                      color: isDark ? AppColors.darkText : AppColors.gray900,
                    ),
                  ),
                  if (totalLocked > 0)
                    Text(
                      '${AppFormatters.compactCurrency(usableBalance)} usable',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark
                            ? AppColors.emerald400
                            : AppColors.emerald600,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Text(
                      'Balance',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                ],
              ),
              if (widget.onTransfer != null || widget.onEdit != null)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  constraints: const BoxConstraints(
                    minWidth: AppComponentSizes.minTouchTarget,
                    minHeight: AppComponentSizes.minTouchTarget,
                  ),
                  tooltip: 'Account Options',
                  onSelected: (action) {
                    if (action == 'transfer') widget.onTransfer?.call();
                    if (action == 'edit') widget.onEdit?.call();
                  },
                  itemBuilder: (context) => [
                    if (widget.onTransfer != null)
                      const PopupMenuItem(
                        value: 'transfer',
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 18),
                            SizedBox(width: AppSpacing.sm),
                            Text('Transfer Funds'),
                          ],
                        ),
                      ),
                    if (widget.onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: AppSpacing.sm),
                            Text('Edit Account'),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
          if (aggregatedLocks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 12),
            InkWell(
              key: Key('account_locked_funds_toggle_${acc.id ?? 0}'),
              onTap: _toggleExpanded,
              borderRadius: AppBorderRadius.smallBorder,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Locked Funds (${aggregatedLocks.length} ${aggregatedLocks.length == 1 ? "goal" : "goals"})',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      AppFormatters.currency(totalLocked),
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.gray800.withValues(alpha: 0.5)
                              : AppColors.gray100.withValues(alpha: 0.6),
                          borderRadius: AppBorderRadius.smallBorder,
                          border: Border.all(
                            color: isDark
                                ? AppColors.gray700
                                : AppColors.gray200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: aggregatedLocks.map((lock) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          lock.isCreditCard
                                              ? Icons.credit_card_rounded
                                              : Icons.savings_outlined,
                                          size: 14,
                                          color: isDark
                                              ? AppColors.gray400
                                              : AppColors.gray600,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            lock.isCreditCard
                                                ? '${lock.goalName} (Card Reserve)'
                                                : lock.goalName,
                                            style: AppTypography.labelSmall,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    AppFormatters.currency(lock.amount),
                                    style: AppTypography.labelSmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                  if (lock.isCreditCard &&
                                      widget.onUnlockCreditCardLock !=
                                          null) ...[
                                    const SizedBox(width: 4),
                                    InkWell(
                                      key: Key(
                                        'btn_unlock_cc_lock_${lock.goalId}',
                                      ),
                                      onTap: () =>
                                          widget.onUnlockCreditCardLock!(
                                            lock.goalId,
                                          ),
                                      borderRadius: AppBorderRadius.smallBorder,
                                      child: const Padding(
                                        padding: EdgeInsets.all(2.0),
                                        child: Icon(
                                          Icons.lock_open_rounded,
                                          size: 15,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

class CreditCardAccountCard extends StatelessWidget {
  final Account account;
  final CreditCard? creditCard;
  final double lockedAmount;
  final VoidCallback? onPayBill;
  final VoidCallback? onEdit;
  final VoidCallback? onLock;
  final VoidCallback? onUnlock;

  const CreditCardAccountCard({
    super.key,
    required this.account,
    this.creditCard,
    this.lockedAmount = 0.0,
    this.onPayBill,
    this.onEdit,
    this.onLock,
    this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final limit = creditCard?.creditLimit ?? 0.0;
    final outstanding = account.balance;
    final availableCredit = (limit - outstanding).clamp(0.0, double.infinity);
    final utilization = limit > 0 ? (outstanding / limit).clamp(0.0, 1.0) : 0.0;

    final isFullyBacked = outstanding > 0 && lockedAmount >= outstanding;
    final isPartiallyBacked =
        outstanding > 0 && lockedAmount > 0 && !isFullyBacked;

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
                  color: AppColors.purple.withValues(alpha: 0.12),
                  borderRadius: AppBorderRadius.mediumBorder,
                ),
                child: const Icon(
                  Icons.credit_card_rounded,
                  color: AppColors.purple,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (creditCard != null)
                      Text(
                        'Due on ${creditCard!.dueDay}th • Stmt ${creditCard!.statementDay}th',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                        ),
                      )
                    else
                      Text(
                        'Credit Card',
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
                    AppFormatters.currency(outstanding),
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: outstanding > 0
                          ? AppColors.danger
                          : (isDark ? AppColors.darkText : AppColors.gray900),
                    ),
                  ),
                  Text(
                    'Outstanding',
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                key: Key('card_options_${account.id}'),
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                ),
                padding: const EdgeInsets.all(AppSpacing.xs),
                constraints: const BoxConstraints(
                  minWidth: AppComponentSizes.minTouchTarget,
                  minHeight: AppComponentSizes.minTouchTarget,
                ),
                tooltip: 'Card Options',
                onSelected: (action) {
                  if (action == 'lock') onLock?.call();
                  if (action == 'unlock') onUnlock?.call();
                  if (action == 'pay') onPayBill?.call();
                  if (action == 'edit') onEdit?.call();
                },
                itemBuilder: (context) => [
                  if (onLock != null)
                    const PopupMenuItem(
                      value: 'lock',
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 18),
                          SizedBox(width: AppSpacing.sm),
                          Text('Lock Funds'),
                        ],
                      ),
                    ),
                  if (onUnlock != null && lockedAmount > 0)
                    const PopupMenuItem(
                      value: 'unlock',
                      child: Row(
                        children: [
                          Icon(Icons.lock_open_rounded, size: 18),
                          SizedBox(width: AppSpacing.sm),
                          Text('Unlock Funds'),
                        ],
                      ),
                    ),
                  if (onPayBill != null)
                    const PopupMenuItem(
                      value: 'pay',
                      child: Row(
                        children: [
                          Icon(Icons.payment_rounded, size: 18),
                          SizedBox(width: AppSpacing.sm),
                          Text('Pay Bill'),
                        ],
                      ),
                    ),
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: AppSpacing.sm),
                          Text('Edit Card'),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Utilization & Available limit
          if (limit > 0) ...[
            ClipRRect(
              borderRadius: AppBorderRadius.pillBorder,
              child: LinearProgressIndicator(
                value: utilization,
                minHeight: 6,
                backgroundColor: isDark
                    ? AppColors.darkBorder
                    : AppColors.gray200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  utilization > 0.8
                      ? AppColors.danger
                      : (utilization > 0.5
                            ? AppColors.warning
                            : AppColors.purple),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppFormatters.currency(availableCredit)} available',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.gray300 : AppColors.gray700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Limit: ${AppFormatters.currency(limit)}',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          const Divider(height: 16),

          // Bottom Bar: Cash-backed badge
          Row(
            children: [
              if (outstanding <= 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.emerald600.withValues(alpha: 0.12),
                    borderRadius: AppBorderRadius.smallBorder,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 14,
                        color: AppColors.emerald600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Settled (₹0 Due)',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.emerald600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else if (isFullyBacked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.emerald600.withValues(alpha: 0.12),
                    borderRadius: AppBorderRadius.smallBorder,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 14,
                        color: AppColors.emerald600,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${AppFormatters.currency(lockedAmount)} Locked (100% Backed)',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.emerald600,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else if (isPartiallyBacked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: AppBorderRadius.smallBorder,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_clock_rounded,
                        size: 14,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${AppFormatters.currency(lockedAmount)} Locked (${((lockedAmount / outstanding) * 100).toInt()}% Backed)',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gray200.withValues(alpha: 0.5),
                    borderRadius: AppBorderRadius.smallBorder,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_open_rounded,
                        size: 14,
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Unbacked',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Action Buttons: Lock, Unlock, Pay Bill
          Row(
            children: [
              if (onLock != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('btn_lock_cc_${account.id}'),
                    onPressed: onLock,
                    icon: const Icon(Icons.lock_rounded, size: 15),
                    label: const Text('Lock'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.purple,
                      side: const BorderSide(color: AppColors.purple),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 34),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppBorderRadius.smallBorder,
                      ),
                      textStyle: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if ((onUnlock != null && lockedAmount > 0) || onPayBill != null)
                  const SizedBox(width: AppSpacing.xs),
              ],
              if (onUnlock != null && lockedAmount > 0) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('btn_unlock_cc_${account.id}'),
                    onPressed: onUnlock,
                    icon: const Icon(Icons.lock_open_rounded, size: 15),
                    label: const Text('Unlock'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.warning),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 34),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppBorderRadius.smallBorder,
                      ),
                      textStyle: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (onPayBill != null) const SizedBox(width: AppSpacing.xs),
              ],
              if (onPayBill != null)
                Expanded(
                  child: ElevatedButton.icon(
                    key: Key('btn_pay_cc_${account.id}'),
                    onPressed: onPayBill,
                    icon: const Icon(Icons.payment_rounded, size: 15),
                    label: const Text('Pay Bill'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 34),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppBorderRadius.smallBorder,
                      ),
                      textStyle: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class EditAccountDialog extends StatefulWidget {
  final Account account;
  final CreditCard? creditCard;
  final List<Account> bankAccounts;
  final VoidCallback? onAccountSaved;
  final VoidCallback? onAccountDeleted;

  const EditAccountDialog({
    super.key,
    required this.account,
    this.creditCard,
    this.bankAccounts = const [],
    this.onAccountSaved,
    this.onAccountDeleted,
  });

  @override
  State<EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends State<EditAccountDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late String _selectedType;
  late final TextEditingController _creditLimitController;
  late final TextEditingController _statementDayController;
  late final TextEditingController _dueDayController;
  int? _defaultLockAccountId;
  late bool _autoLock;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account.name);
    _balanceController = TextEditingController(
      text: widget.account.balance.toStringAsFixed(0),
    );
    _selectedType = widget.account.type;
    _creditLimitController = TextEditingController(
      text: widget.creditCard?.creditLimit.toStringAsFixed(0) ?? '',
    );
    _statementDayController = TextEditingController(
      text: widget.creditCard?.statementDay.toString() ?? '1',
    );
    _dueDayController = TextEditingController(
      text: widget.creditCard?.dueDay.toString() ?? '20',
    );
    _defaultLockAccountId = widget.creditCard?.defaultLockAccountId;
    _autoLock = widget.creditCard?.autoLock ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _creditLimitController.dispose();
    _statementDayController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  void _showDeleteConfirmation(BuildContext context) {
    unawaited(
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Delete Account?'),
          content: Text(
            'Are you sure you want to delete "${widget.account.name}"? Any past transactions referencing this account will remain in ledger.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await DatabaseHelper.instance.deleteAccount(widget.account.id!);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                if (context.mounted) Navigator.pop(context);
                widget.onAccountDeleted?.call();
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCC = widget.account.isCreditCard;
    final bankAccounts = widget.bankAccounts;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: AppBorderRadius.xlargeBorder,
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              isCC ? 'Edit Credit Card' : 'Edit Account',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
            ),
            tooltip: 'Delete',
            onPressed: () => _showDeleteConfirmation(context),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomInputField(
                controller: _nameController,
                label: isCC ? 'Card Name' : 'Account Name',
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter an account name'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              CustomInputField(
                controller: _balanceController,
                label: isCC ? 'Current Outstanding (Owed)' : 'Balance',
                prefixText: '₹ ',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
              if (!isCC)
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  isExpanded: true,
                  dropdownColor: isDark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.white,
                  decoration: InputDecoration(
                    labelText: 'Account Type',
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSurface
                        : AppColors.gray50,
                    border: const OutlineInputBorder(
                      borderRadius: AppBorderRadius.mediumBorder,
                    ),
                  ),
                  items: ['Bank', 'Cash', 'Savings', 'Wallet']
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedType = val!),
                )
              else ...[
                CustomInputField(
                  controller: _creditLimitController,
                  label: 'Total Credit Limit',
                  prefixText: '₹ ',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter credit limit';
                    }
                    final numVal = double.tryParse(value);
                    if (numVal == null || numVal <= 0) {
                      return 'Please enter a valid positive limit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: CustomInputField(
                        controller: _statementDayController,
                        label: 'Statement Day',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final day = int.tryParse(value ?? '');
                          if (day == null || day < 1 || day > 31) {
                            return '1-31';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: CustomInputField(
                        controller: _dueDayController,
                        label: 'Due Day',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final day = int.tryParse(value ?? '');
                          if (day == null || day < 1 || day > 31) {
                            return '1-31';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                if (bankAccounts.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Default Account to Lock Funds',
                    style: AppTypography.labelMedium.copyWith(
                      color: isDark ? AppColors.gray300 : AppColors.gray700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  DropdownButtonFormField<int>(
                    initialValue: _defaultLockAccountId,
                    isExpanded: true,
                    dropdownColor: isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.white,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSurface
                          : AppColors.gray50,
                      border: OutlineInputBorder(
                        borderRadius: AppBorderRadius.mediumBorder,
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.gray300,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                    ),
                    items: bankAccounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _defaultLockAccountId = val),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Auto-lock funds on spend',
                      style: AppTypography.bodySmall,
                    ),
                    subtitle: Text(
                      'Locks matching funds in the linked bank account to ensure bill is 100% cash-backed.',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                    value: _autoLock,
                    activeThumbColor: AppColors.purple,
                    onChanged: (val) => setState(() => _autoLock = val),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        CustomButton(
          label: 'Update',
          width: 120,
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              await DatabaseHelper.instance.updateAccount(
                Account(
                  id: widget.account.id,
                  name: _nameController.text.trim(),
                  balance:
                      double.tryParse(_balanceController.text.trim()) ?? 0.0,
                  type: _selectedType,
                ),
              );
              if (isCC && widget.creditCard != null) {
                await DatabaseHelper.instance.updateCreditCard(
                  CreditCard(
                    id: widget.creditCard!.id,
                    accountId: widget.account.id!,
                    creditLimit:
                        double.tryParse(_creditLimitController.text.trim()) ??
                        widget.creditCard!.creditLimit,
                    statementDay:
                        int.tryParse(_statementDayController.text.trim()) ??
                        widget.creditCard!.statementDay,
                    dueDay:
                        int.tryParse(_dueDayController.text.trim()) ??
                        widget.creditCard!.dueDay,
                    defaultLockAccountId: _defaultLockAccountId,
                    autoLock: _autoLock,
                  ),
                );
              }
              if (context.mounted) Navigator.pop(context);
              widget.onAccountSaved?.call();
            }
          },
        ),
      ],
    );
  }
}

class TransferFundsModal extends StatefulWidget {
  final Account sourceAccount;
  final List<Account> destinationAccounts;
  final VoidCallback? onTransferCompleted;

  const TransferFundsModal({
    super.key,
    required this.sourceAccount,
    required this.destinationAccounts,
    this.onTransferCompleted,
  });

  @override
  State<TransferFundsModal> createState() => _TransferFundsModalState();
}

class _TransferFundsModalState extends State<TransferFundsModal> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  late int? _destinationAccountId;

  @override
  void initState() {
    super.initState();
    _destinationAccountId = widget.destinationAccounts.isNotEmpty
        ? widget.destinationAccounts.first.id
        : null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.gray700 : AppColors.gray300,
                  borderRadius: AppBorderRadius.pillBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Transfer from "${widget.sourceAccount.name}"',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Move funds between your physical accounts. Balance: ${AppFormatters.currency(widget.sourceAccount.balance)}',
              style: AppTypography.labelSmall.copyWith(
                color: isDark ? AppColors.gray400 : AppColors.gray600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            CustomInputField(
              controller: _amountController,
              label: 'Amount to Transfer',
              prefixText: '₹ ',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              prefixIcon: Icons.swap_horiz_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Destination Account',
              style: AppTypography.labelMedium.copyWith(
                color: isDark ? AppColors.gray300 : AppColors.gray700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<int>(
              initialValue: _destinationAccountId,
              isExpanded: true,
              dropdownColor: isDark
                  ? AppColors.darkSurfaceElevated
                  : AppColors.white,
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
              items: widget.destinationAccounts.map((acc) {
                return DropdownMenuItem<int>(
                  value: acc.id,
                  child: Text(
                    '${acc.name} (${AppFormatters.currency(acc.balance)})',
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _destinationAccountId = val);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            CustomInputField(
              controller: _noteController,
              label: 'Note (Optional)',
              hint: 'e.g. ATM withdrawal, savings transfer',
              prefixIcon: Icons.notes_rounded,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: AppComponentSizes.buttonHeightLarge,
              child: ElevatedButton(
                onPressed: () async {
                  if (_destinationAccountId == null) {
                    await AppDialogs.showWarning(
                      context,
                      message: 'Please select a destination account',
                    );
                    return;
                  }
                  if (_amountController.text.trim().isEmpty) {
                    await AppDialogs.showWarning(
                      context,
                      message: 'Please enter an amount',
                    );
                    return;
                  }
                  final amount =
                      double.tryParse(_amountController.text.trim()) ?? 0.0;
                  if (amount <= 0) {
                    await AppDialogs.showWarning(
                      context,
                      message: 'Please enter an amount > 0',
                    );
                    return;
                  }
                  if (amount > widget.sourceAccount.balance) {
                    await AppDialogs.showWarning(
                      context,
                      message:
                          'Cannot transfer more than account balance (${AppFormatters.currency(widget.sourceAccount.balance)})',
                    );
                    return;
                  }

                  try {
                    await DatabaseHelper.instance.createTransferTransaction(
                      sourceAccountId: widget.sourceAccount.id!,
                      destinationAccountId: _destinationAccountId!,
                      amount: amount,
                      date: DateTime.now().toIso8601String(),
                      note: _noteController.text.trim(),
                    );
                    if (context.mounted) Navigator.pop(context);
                    widget.onTransferCompleted?.call();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Transferred ${AppFormatters.currency(amount)} successfully!',
                          ),
                          backgroundColor: AppColors.emerald700,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      await AppDialogs.showWarning(
                        context,
                        message: 'Transfer failed: $e',
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald700,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppBorderRadius.mediumBorder,
                  ),
                ),
                child: const Text(
                  'Complete Transfer',
                  style: AppTypography.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
