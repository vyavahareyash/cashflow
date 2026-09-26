import 'dart:async';

import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../models/credit_card_model.dart';
import '../services/database_helper.dart';
import '../theme/theme_constants.dart';
import 'app_dialogs.dart';
import 'custom_input.dart';

class UnlockCcFundsModal extends StatefulWidget {
  final Account ccAccount;
  final CreditCard creditCard;
  final double lockedAmount;
  final VoidCallback onUnlockCompleted;

  const UnlockCcFundsModal({
    super.key,
    required this.ccAccount,
    required this.creditCard,
    required this.lockedAmount,
    required this.onUnlockCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    required Account ccAccount,
    required CreditCard creditCard,
    required double lockedAmount,
    required VoidCallback onUnlockCompleted,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => UnlockCcFundsModal(
        ccAccount: ccAccount,
        creditCard: creditCard,
        lockedAmount: lockedAmount,
        onUnlockCompleted: onUnlockCompleted,
      ),
    );
  }

  @override
  State<UnlockCcFundsModal> createState() => _UnlockCcFundsModalState();
}

class _UnlockCcFundsModalState extends State<UnlockCcFundsModal> {
  List<Map<String, dynamic>> _contributions = [];
  bool _isLoadingAllocations = true;
  bool _unlockAllAccounts = false;
  int? _selectedAccountId;
  late TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    unawaited(_fetchAllocations());
  }

  Future<void> _fetchAllocations() async {
    final rows = await DatabaseHelper.instance.getCreditCardLockedAllocations(
      widget.creditCard.id!,
    );
    if (mounted) {
      setState(() {
        _contributions = rows;
        _isLoadingAllocations = false;
        if (rows.isNotEmpty) {
          _selectedAccountId = (rows.first['account_id'] as num?)?.toInt();
          final firstAmt = (rows.first['amount'] as num?)?.toDouble() ?? 0.0;
          _amountController.text = firstAmt.toStringAsFixed(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double _getMaxUnlockable() {
    if (_contributions.isEmpty || _selectedAccountId == null) return 0.0;
    final row = _contributions.firstWhere(
      (c) => (c['account_id'] as num).toInt() == _selectedAccountId,
      orElse: () => _contributions.first,
    );
    return (row['amount'] as num?)?.toDouble() ?? 0.0;
  }

  double _getTotalAcrossAll() {
    return _contributions.fold<double>(
      0.0,
      (sum, c) => sum + ((c['amount'] as num?)?.toDouble() ?? 0.0),
    );
  }

  Future<void> _handleUnlock() async {
    if (_contributions.isEmpty) {
      await AppDialogs.showWarning(
        context,
        message: 'No locked funds found to unlock for this card.',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final dateStr = DateTime.now().toIso8601String();
    final note = _noteController.text.trim();

    try {
      if (_unlockAllAccounts) {
        final amountsPerAccount = <int, double>{};
        for (final c in _contributions) {
          final accId = (c['account_id'] as num).toInt();
          final amt = (c['amount'] as num).toDouble();
          if (amt > 0) {
            amountsPerAccount[accId] = amt;
          }
        }
        await DatabaseHelper.instance
            .createMultiAccountCreditCardUnlockTransactions(
              creditCardId: widget.creditCard.id!,
              amountsPerAccount: amountsPerAccount,
              date: dateStr,
              note: note.isNotEmpty
                  ? note
                  : 'Unlocked all credit card reserves',
            );

        if (mounted) {
          Navigator.pop(context);
          widget.onUnlockCompleted();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unlocked ${AppFormatters.currency(_getTotalAcrossAll())} across ${amountsPerAccount.length} accounts back to spendable funds!',
              ),
              backgroundColor: AppColors.emerald700,
            ),
          );
        }
      } else {
        final enteredAmount =
            double.tryParse(_amountController.text.trim()) ?? 0.0;
        final maxUnlockable = _getMaxUnlockable();

        if (enteredAmount <= 0) {
          setState(() => _isSubmitting = false);
          await AppDialogs.showWarning(
            context,
            message: 'Please enter a valid amount to unlock.',
          );
          return;
        }

        if (enteredAmount > maxUnlockable) {
          setState(() => _isSubmitting = false);
          await AppDialogs.showWarning(
            context,
            message:
                'Unlock amount cannot exceed locked amount (${AppFormatters.currency(maxUnlockable)}).',
          );
          return;
        }

        await DatabaseHelper.instance.createCreditCardUnlockTransaction(
          creditCardId: widget.creditCard.id!,
          bankAccountId: _selectedAccountId!,
          amount: enteredAmount,
          date: dateStr,
          note: note.isNotEmpty
              ? note
              : 'Unlocked from ${widget.ccAccount.name} reserve',
        );

        if (mounted) {
          Navigator.pop(context);
          widget.onUnlockCompleted();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unlocked ${AppFormatters.currency(enteredAmount)} back to spendable bank balance!',
              ),
              backgroundColor: AppColors.emerald700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        await AppDialogs.showWarning(
          context,
          title: 'Unlock Failed',
          message: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMultipleAccounts = _contributions.length > 1;
    final maxUnlockable = _getMaxUnlockable();
    final totalAcrossAll = _getTotalAcrossAll();

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
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: AppBorderRadius.smallBorder,
                      ),
                      child: const Icon(
                        Icons.lock_open_rounded,
                        color: AppColors.warning,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Unlock Card Reserve',
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
              'Release reserved funds from your credit card back into your bank account\'s spendable balance.',
              style: AppTypography.labelSmall.copyWith(
                color: isDark ? AppColors.gray400 : AppColors.gray600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            if (_isLoadingAllocations)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_contributions.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: AppBorderRadius.mediumBorder,
                ),
                child: const Text(
                  'No funds are currently locked for this credit card.',
                  style: AppTypography.bodyMedium,
                ),
              )
            else ...[
              // Summary card
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
                            'Card Outstanding',
                            style: AppTypography.labelSmall.copyWith(
                              color: isDark
                                  ? AppColors.gray400
                                  : AppColors.gray600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.currency(widget.ccAccount.balance),
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.white
                                  : AppColors.gray900,
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
                            'Total Locked',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.currency(totalAcrossAll),
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Multi-Account Segmented Toggle
              if (hasMultipleAccounts) ...[
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.gray100,
                    borderRadius: AppBorderRadius.pillBorder,
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.gray200,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _unlockAllAccounts = false;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_unlockAllAccounts
                                  ? (isDark
                                        ? AppColors.darkSurface
                                        : AppColors.white)
                                  : Colors.transparent,
                              borderRadius: AppBorderRadius.pillBorder,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Specific Account',
                              style: AppTypography.labelMedium.copyWith(
                                fontWeight: !_unlockAllAccounts
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: !_unlockAllAccounts
                                    ? (isDark
                                          ? AppColors.white
                                          : AppColors.gray900)
                                    : (isDark
                                          ? AppColors.gray400
                                          : AppColors.gray600),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _unlockAllAccounts = true;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _unlockAllAccounts
                                  ? (isDark
                                        ? AppColors.darkSurface
                                        : AppColors.white)
                                  : Colors.transparent,
                              borderRadius: AppBorderRadius.pillBorder,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Unlock All (${AppFormatters.currency(totalAcrossAll)})',
                              style: AppTypography.labelMedium.copyWith(
                                fontWeight: _unlockAllAccounts
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: _unlockAllAccounts
                                    ? (isDark
                                          ? AppColors.white
                                          : AppColors.gray900)
                                    : (isDark
                                          ? AppColors.gray400
                                          : AppColors.gray600),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              if (!_unlockAllAccounts) ...[
                if (hasMultipleAccounts) ...[
                  Text(
                    'Unlock From Account',
                    style: AppTypography.labelMedium.copyWith(
                      color: isDark ? AppColors.gray300 : AppColors.gray700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedAccountId,
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
                    items: _contributions.map((c) {
                      final accId = (c['account_id'] as num).toInt();
                      final accName = c['account_name'] as String;
                      final amt = (c['amount'] as num).toDouble();
                      return DropdownMenuItem<int>(
                        value: accId,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                accName,
                                style: AppTypography.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'Locked: ${AppFormatters.currency(amt)}',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedAccountId = val;
                          final row = _contributions.firstWhere(
                            (c) => (c['account_id'] as num).toInt() == val,
                          );
                          final amt = (row['amount'] as num).toDouble();
                          _amountController.text = amt.toStringAsFixed(0);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Account: ${_contributions.first['account_name']} (${AppFormatters.currency(maxUnlockable)} locked)',
                      style: AppTypography.bodyMedium.copyWith(
                        color: isDark ? AppColors.gray300 : AppColors.gray700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                // Quick Chip: Full Amount
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.flash_on_rounded, size: 14),
                        label: Text(
                          'Full Amount (${AppFormatters.currency(maxUnlockable)})',
                        ),
                        onPressed: () {
                          setState(() {
                            _amountController.text = maxUnlockable
                                .toStringAsFixed(0);
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Amount Input
                CustomInputField(
                  controller: _amountController,
                  label: 'Amount to Unlock',
                  prefixText: '₹ ',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  prefixIcon: Icons.lock_open_rounded,
                  autofocus: true,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Optional Note
              CustomInputField(
                controller: _noteController,
                label: 'Note (Optional)',
                hint: 'e.g. Unlocked unused reserve',
                prefixIcon: Icons.notes_rounded,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: AppComponentSizes.buttonHeightMedium,
                child: ElevatedButton.icon(
                  key: const Key('btn_confirm_unlock_cc'),
                  onPressed: _isSubmitting ? null : _handleUnlock,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_open_rounded, size: 18),
                  label: Text(
                    _isSubmitting
                        ? 'Unlocking...'
                        : (_unlockAllAccounts
                              ? 'Unlock All (${AppFormatters.currency(totalAcrossAll)})'
                              : 'Unlock Funds'),
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppBorderRadius.mediumBorder,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
