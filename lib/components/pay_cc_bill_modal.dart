import 'package:flutter/material.dart';
import '../models/account_model.dart';
import '../models/credit_card_model.dart';
import '../services/database_helper.dart';
import '../theme/theme_constants.dart';
import 'app_dialogs.dart';

class PayCcBillModal extends StatefulWidget {
  final Account ccAccount;
  final CreditCard creditCard;
  final double lockedAmount;
  final List<Account> bankAccounts;
  final VoidCallback onPaymentCompleted;

  const PayCcBillModal({
    super.key,
    required this.ccAccount,
    required this.creditCard,
    required this.lockedAmount,
    required this.bankAccounts,
    required this.onPaymentCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    required Account ccAccount,
    required CreditCard creditCard,
    required double lockedAmount,
    required List<Account> bankAccounts,
    required VoidCallback onPaymentCompleted,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => PayCcBillModal(
        ccAccount: ccAccount,
        creditCard: creditCard,
        lockedAmount: lockedAmount,
        bankAccounts: bankAccounts,
        onPaymentCompleted: onPaymentCompleted,
      ),
    );
  }

  @override
  State<PayCcBillModal> createState() => _PayCcBillModalState();
}

class _PayCcBillModalState extends State<PayCcBillModal> {
  late int? _selectedBankAccountId;
  late TextEditingController _amountController;
  int _selectedOption = 0; // 0: locked (if > 0) or full, 1: full, 2: custom
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default to defaultLockAccountId if available, else first bank account
    final defaultId = widget.creditCard.defaultLockAccountId;
    final hasDefault = widget.bankAccounts.any((a) => a.id == defaultId);
    _selectedBankAccountId = hasDefault
        ? defaultId
        : (widget.bankAccounts.isNotEmpty ? widget.bankAccounts.first.id : null);

    final initialAmount = widget.lockedAmount > 0
        ? widget.lockedAmount
        : widget.ccAccount.balance;
    _amountController = TextEditingController(
      text: initialAmount.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double _computeAmount() {
    if (_selectedOption == 0 && widget.lockedAmount > 0) {
      return widget.lockedAmount;
    } else if (_selectedOption == 1 || (_selectedOption == 0 && widget.lockedAmount <= 0)) {
      return widget.ccAccount.balance;
    } else {
      return double.tryParse(_amountController.text) ?? 0.0;
    }
  }

  Future<void> _handlePayment() async {
    final amount = _computeAmount();
    if (amount <= 0) {
      await AppDialogs.showWarning(
        context,
        message: 'Please enter a valid payment amount.',
      );
      return;
    }

    if (_selectedBankAccountId == null) {
      await AppDialogs.showWarning(
        context,
        message: 'Please select a bank account to pay from.',
      );
      return;
    }

    final bankAcc = widget.bankAccounts.firstWhere(
      (a) => a.id == _selectedBankAccountId,
      orElse: () => widget.bankAccounts.first,
    );

    if (amount > bankAcc.balance) {
      await AppDialogs.showWarning(
        context,
        message:
            'Insufficient balance in ${bankAcc.name} (${AppFormatters.currency(bankAcc.balance)} available).',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await DatabaseHelper.instance.payCreditCardBill(
        ccAccountId: widget.ccAccount.id!,
        bankAccountId: _selectedBankAccountId!,
        amount: amount,
        note: 'Payment for ${widget.ccAccount.name}',
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onPaymentCompleted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully paid ${AppFormatters.currency(amount)} towards ${widget.ccAccount.name}.',
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
          title: 'Payment Failed',
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
                        Icons.credit_card_rounded,
                        color: AppColors.purple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Pay Card Bill',
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
            const SizedBox(height: AppSpacing.sm),

            // Outstanding and Locked Breakdown Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.gray50,
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
                            color: isDark ? AppColors.gray400 : AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.currency(totalDue),
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.white : AppColors.gray900,
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
                          'Locked in Bank',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.emerald600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.currency(locked),
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.emerald600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Option Selector
            Text(
              'Select Amount',
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.gray300 : AppColors.gray700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            if (locked > 0)
              RadioListTile<int>(
                value: 0,
                groupValue: _selectedOption,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.emerald700,
                title: Text(
                  'Pay Locked Amount (${AppFormatters.currency(locked)})',
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Releases locked cash reserves from linked bank account',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.gray400 : AppColors.gray500,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _selectedOption = val!;
                    _amountController.text = locked.toStringAsFixed(0);
                  });
                },
              ),

            RadioListTile<int>(
              value: locked > 0 ? 1 : 0,
              groupValue: _selectedOption,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.emerald700,
              title: Text(
                'Pay Full Outstanding (${AppFormatters.currency(totalDue)})',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
              ),
              onChanged: (val) {
                setState(() {
                  _selectedOption = val!;
                  _amountController.text = totalDue.toStringAsFixed(0);
                });
              },
            ),

            RadioListTile<int>(
              value: 2,
              groupValue: _selectedOption,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.emerald700,
              title: Text(
                'Custom Amount',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
              ),
              onChanged: (val) {
                setState(() {
                  _selectedOption = val!;
                });
              },
            ),

            if (_selectedOption == 2) ...[
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: 'Enter amount to pay',
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
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            const SizedBox(height: AppSpacing.md),

            // Pay From Account Selector
            Text(
              'Pay From Bank Account',
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.gray300 : AppColors.gray700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<int>(
              initialValue: _selectedBankAccountId,
              isExpanded: true,
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
              items: widget.bankAccounts
                  .map(
                    (acc) => DropdownMenuItem(
                      value: acc.id,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              acc.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            AppFormatters.currency(acc.balance),
                            style: AppTypography.labelSmall.copyWith(
                              color: isDark ? AppColors.gray400 : AppColors.gray500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedBankAccountId = val),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: AppComponentSizes.buttonHeightLarge,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handlePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppBorderRadius.mediumBorder,
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Confirm Payment',
                        style: AppTypography.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
