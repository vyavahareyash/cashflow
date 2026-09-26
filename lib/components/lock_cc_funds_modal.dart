import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../models/credit_card_model.dart';
import '../services/database_helper.dart';
import '../theme/theme_constants.dart';
import 'app_dialogs.dart';
import 'custom_input.dart';

class LockCcFundsModal extends StatefulWidget {
  final Account ccAccount;
  final CreditCard creditCard;
  final double lockedAmount;
  final List<Account> bankAccounts;
  final VoidCallback onLockCompleted;

  const LockCcFundsModal({
    super.key,
    required this.ccAccount,
    required this.creditCard,
    required this.lockedAmount,
    required this.bankAccounts,
    required this.onLockCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    required Account ccAccount,
    required CreditCard creditCard,
    required double lockedAmount,
    required List<Account> bankAccounts,
    required VoidCallback onLockCompleted,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => LockCcFundsModal(
        ccAccount: ccAccount,
        creditCard: creditCard,
        lockedAmount: lockedAmount,
        bankAccounts: bankAccounts,
        onLockCompleted: onLockCompleted,
      ),
    );
  }

  @override
  State<LockCcFundsModal> createState() => _LockCcFundsModalState();
}

class _LockCcFundsModalState extends State<LockCcFundsModal> {
  late int? _selectedBankAccountId;
  late TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController();
  Map<int, double> _availableToLockMap = {};
  bool _isLoading = false;
  bool _loadingBalances = true;

  @override
  void initState() {
    super.initState();
    final defaultId = widget.creditCard.defaultLockAccountId;
    final hasDefault = widget.bankAccounts.any((a) => a.id == defaultId);
    _selectedBankAccountId = hasDefault
        ? defaultId
        : (widget.bankAccounts.isNotEmpty
              ? widget.bankAccounts.first.id
              : null);

    final unbacked = max(0.0, widget.ccAccount.balance - widget.lockedAmount);
    final initialAmount = unbacked > 0 ? unbacked : widget.ccAccount.balance;
    _amountController = TextEditingController(
      text: initialAmount > 0 ? initialAmount.toStringAsFixed(0) : '',
    );

    unawaited(_fetchAvailableBalances());
  }

  Future<void> _fetchAvailableBalances() async {
    final map = <int, double>{};
    for (final acc in widget.bankAccounts) {
      if (acc.id != null) {
        map[acc.id!] = await DatabaseHelper.instance.getAccountAvailableToLock(
          acc.id!,
        );
      }
    }
    if (mounted) {
      setState(() {
        _availableToLockMap = map;
        _loadingBalances = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleLock() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      await AppDialogs.showWarning(
        context,
        message: 'Please enter a valid amount to lock.',
      );
      return;
    }

    if (_selectedBankAccountId == null) {
      await AppDialogs.showWarning(
        context,
        message: 'Please select a bank account to lock funds from.',
      );
      return;
    }

    final available = _availableToLockMap[_selectedBankAccountId!] ?? 0.0;
    if (amount > available) {
      final bankAcc = widget.bankAccounts.firstWhere(
        (a) => a.id == _selectedBankAccountId,
        orElse: () => widget.bankAccounts.first,
      );
      await AppDialogs.showWarning(
        context,
        message:
            'Lock amount exceeds available balance in ${bankAcc.name} (${AppFormatters.currency(available)} available).',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await DatabaseHelper.instance.createCreditCardLockTransaction(
        creditCardId: widget.creditCard.id!,
        bankAccountId: _selectedBankAccountId!,
        amount: amount,
        date: DateTime.now().toIso8601String(),
        note: _noteController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onLockCompleted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Locked ${AppFormatters.currency(amount)} for ${widget.ccAccount.name} reserve.',
            ),
            backgroundColor: AppColors.emerald700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await AppDialogs.showWarning(
          context,
          title: 'Lock Failed',
          message: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalDue = widget.ccAccount.balance;
    final locked = widget.lockedAmount;
    final unbacked = max(0.0, totalDue - locked);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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

            // Title Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.15),
                        borderRadius: AppBorderRadius.smallBorder,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: AppColors.purple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Lock Card Reserve',
                      style: AppTypography.headlineMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reserve funds in a bank account to make your credit card balance 100% cash-backed.',
              style: AppTypography.labelSmall.copyWith(
                color: isDark ? AppColors.gray400 : AppColors.gray600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Card Status Breakdown
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceElevated
                    : AppColors.gray50,
                borderRadius: AppBorderRadius.mediumBorder,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.gray200,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Due',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark
                                ? AppColors.gray400
                                : AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.currency(totalDue),
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: totalDue > 0
                                ? AppColors.danger
                                : (isDark
                                      ? AppColors.white
                                      : AppColors.gray900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: isDark ? AppColors.darkBorder : AppColors.gray200,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Already Locked',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.emerald600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.currency(locked),
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.emerald600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: isDark ? AppColors.darkBorder : AppColors.gray200,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unbacked',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark
                                ? AppColors.gray400
                                : AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.currency(unbacked),
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: unbacked > 0
                                ? AppColors.warning
                                : AppColors.emerald600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Quick Fill Chips
            if (unbacked > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.flash_on_rounded, size: 14),
                      label: Text(
                        'Full Unbacked (${AppFormatters.currency(unbacked)})',
                      ),
                      onPressed: () {
                        setState(() {
                          _amountController.text = unbacked.toStringAsFixed(0);
                        });
                      },
                    ),
                  ],
                ),
              ),

            // Amount Input
            CustomInputField(
              controller: _amountController,
              label: 'Amount to Lock',
              prefixText: '₹ ',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              prefixIcon: Icons.lock_outline_rounded,
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),

            // Bank Account Dropdown
            Text(
              'Lock From Bank Account',
              style: AppTypography.labelMedium.copyWith(
                color: isDark ? AppColors.gray300 : AppColors.gray700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (widget.bankAccounts.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: AppBorderRadius.smallBorder,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'No bank accounts available. Please add a bank account first.',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _selectedBankAccountId,
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
                items: widget.bankAccounts.map((acc) {
                  final available = _availableToLockMap[acc.id] ?? 0.0;
                  return DropdownMenuItem<int>(
                    value: acc.id,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            acc.name,
                            style: AppTypography.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _loadingBalances
                              ? '...'
                              : 'Avail: ${AppFormatters.currency(available)}',
                          style: AppTypography.labelSmall.copyWith(
                            color: available > 0
                                ? AppColors.emerald600
                                : (isDark
                                      ? AppColors.gray400
                                      : AppColors.gray600),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedBankAccountId = val);
                },
              ),
            const SizedBox(height: AppSpacing.md),

            // Optional Note
            CustomInputField(
              controller: _noteController,
              label: 'Note (Optional)',
              hint: 'e.g. Reserved for monthly bill',
              prefixIcon: Icons.notes_rounded,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: AppComponentSizes.buttonHeightMedium,
              child: ElevatedButton.icon(
                key: const Key('btn_confirm_lock_cc'),
                onPressed: _isLoading ? null : _handleLock,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_rounded, size: 18),
                label: Text(
                  _isLoading ? 'Locking...' : 'Lock Funds',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppBorderRadius.mediumBorder,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
