import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/draft_transaction.dart';
import '../services/database_helper.dart';
import '../theme/theme_constants.dart';

/// Interactive modal bottom sheet for ephemeral draft transaction review (US 3, 8, 9, 10, 18, 20).
///
/// Presents in-memory [DraftTransaction] items extracted from voice monologues,
/// displaying inline interactive chips for instant editing, visual warning badges
/// for inferred or missing fields, swipeable/dismissible cards, and Privacy Mode bullet masking.
class VoiceTransactionStagingSheet extends StatefulWidget {
  final List<DraftTransaction> drafts;
  final List<Account>? accounts;
  final List<Category>? categories;
  final bool? isPrivate;
  final Future<void> Function(List<DraftTransaction> approvedDrafts)? onCommit;
  final VoidCallback? onDismiss;

  const VoiceTransactionStagingSheet({
    super.key,
    required this.drafts,
    this.accounts,
    this.categories,
    this.isPrivate,
    this.onCommit,
    this.onDismiss,
  });

  /// Displays the staging sheet modal.
  static Future<List<DraftTransaction>?> show(
    BuildContext context, {
    required List<DraftTransaction> drafts,
    List<Account>? accounts,
    List<Category>? categories,
    bool? isPrivate,
    Future<void> Function(List<DraftTransaction> approvedDrafts)? onCommit,
    VoidCallback? onDismiss,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<List<DraftTransaction>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => VoiceTransactionStagingSheet(
        drafts: drafts,
        accounts: accounts,
        categories: categories,
        isPrivate: isPrivate,
        onCommit: onCommit,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  State<VoiceTransactionStagingSheet> createState() =>
      _VoiceTransactionStagingSheetState();
}

class _VoiceTransactionStagingSheetState
    extends State<VoiceTransactionStagingSheet> {
  late List<DraftTransaction> _drafts;
  List<Account> _accounts = [];
  List<Category> _categories = [];
  bool _isPrivate = false;
  bool _isLoading = true;
  bool _isCommitting = false;

  @override
  void initState() {
    super.initState();
    _drafts = List<DraftTransaction>.from(widget.drafts);
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (widget.isPrivate != null) {
      _isPrivate = widget.isPrivate!;
    } else {
      _isPrivate = await DatabaseHelper.instance.getPrivacyMode();
    }

    if (widget.accounts != null) {
      _accounts = widget.accounts!;
    } else {
      _accounts = await DatabaseHelper.instance.readAllAccounts();
    }

    if (widget.categories != null) {
      _categories = widget.categories!;
    } else {
      _categories = await DatabaseHelper.instance.readAllCategories();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _dismissDraft(int index) {
    if (index >= 0 && index < _drafts.length) {
      setState(() {
        _drafts.removeAt(index);
      });
    }
  }

  Future<void> _editAmount(int index, DraftTransaction draft) async {
    final controller = TextEditingController(
      text: draft.amount > 0 ? draft.amount.toStringAsFixed(2) : '',
    );

    final newAmount = await showDialog<double>(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
          title: const Text('Edit Amount', style: AppTypography.titleLarge),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(
                borderRadius: AppBorderRadius.mediumBorder,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald700,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                if (parsed != null && parsed > 0) {
                  Navigator.of(dialogCtx).pop(parsed);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newAmount != null && mounted) {
      setState(() {
        _drafts[index] = draft.copyWith(amount: newAmount);
      });
    }
  }

  Future<void> _selectAccount(
    int index,
    DraftTransaction draft, {
    required bool isDestination,
  }) async {
    final selectedAccount = await showModalBottomSheet<Account>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  isDestination ? 'Select Destination Account' : 'Select Account',
                  style: AppTypography.titleLarge,
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _accounts.length,
                  itemBuilder: (ctx, i) {
                    final acc = _accounts[i];
                    return ListTile(
                      leading: Icon(
                        acc.isCreditCard
                            ? Icons.credit_card_rounded
                            : Icons.account_balance_rounded,
                        color: AppColors.emerald700,
                      ),
                      title: Text(acc.name, style: AppTypography.bodyMedium),
                      subtitle: Text(
                        AppFormatters.currency(acc.balance, isPrivate: _isPrivate),
                        style: AppTypography.labelSmall,
                      ),
                      onTap: () => Navigator.of(sheetCtx).pop(acc),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedAccount != null && mounted) {
      setState(() {
        if (isDestination) {
          _drafts[index] = draft.copyWith(
            destinationAccountId: selectedAccount.id,
          );
        } else {
          _drafts[index] = draft.copyWith(
            accountId: selectedAccount.id,
            hasUnassignedAccount: false,
          );
        }
      });
    }
  }

  Future<void> _selectCategory(int index, DraftTransaction draft) async {
    final availableCats = draft.isIncome
        ? _categories.where((c) => c.isIncome).toList()
        : _categories.where((c) => c.isExpense).toList();

    final selectedCategory = await showModalBottomSheet<Category>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text('Select Category', style: AppTypography.titleLarge),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableCats.length,
                  itemBuilder: (ctx, i) {
                    final cat = availableCats[i];
                    return ListTile(
                      leading: const CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.emerald100,
                        child: Icon(
                          Icons.category_rounded,
                          size: 16,
                          color: AppColors.emerald700,
                        ),
                      ),
                      title: Text(cat.name, style: AppTypography.bodyMedium),
                      onTap: () => Navigator.of(sheetCtx).pop(cat),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedCategory != null && mounted) {
      setState(() {
        _drafts[index] = draft.copyWith(
          categoryId: selectedCategory.id,
          hasUnassignedCategory: false,
        );
      });
    }
  }

  Future<void> _selectDate(int index, DraftTransaction draft) async {
    DateTime initialDate;
    try {
      initialDate = DateFormat('yyyy-MM-dd').parse(draft.date);
    } catch (_) {
      initialDate = DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null && mounted) {
      setState(() {
        _drafts[index] = draft.copyWith(
          date: DateFormat('yyyy-MM-dd').format(picked),
        );
      });
    }
  }

  Future<void> _editNote(int index, DraftTransaction draft) async {
    final controller = TextEditingController(text: draft.note);

    final newNote = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
          title: const Text('Edit Note', style: AppTypography.titleLarge),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Note',
              border: OutlineInputBorder(
                borderRadius: AppBorderRadius.mediumBorder,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newNote != null && mounted) {
      setState(() {
        _drafts[index] = draft.copyWith(note: newNote);
      });
    }
  }

  Future<void> _commitDrafts(List<DraftTransaction> draftsToCommit) async {
    setState(() => _isCommitting = true);
    try {
      if (widget.onCommit != null) {
        await widget.onCommit!(draftsToCommit);
      }

      if (!mounted) return;

      if (draftsToCommit.length >= _drafts.length) {
        Navigator.of(context).pop(draftsToCommit);
      } else {
        setState(() {
          _drafts.removeWhere((d) => draftsToCommit.any((c) => c.id == d.id));
          _isCommitting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCommitting = false);
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final validDrafts = _drafts.where((d) => d.isValid).toList();
    final allValid = _drafts.isNotEmpty && _drafts.every((d) => d.isValid);
    final hasWarningItems = _drafts.any(
      (d) => d.hasUnassignedAccount || d.hasUnassignedCategory || !d.isValid,
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle
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
            const SizedBox(height: AppSpacing.sm),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xs + 2),
                      decoration: BoxDecoration(
                        color: AppColors.emerald700.withValues(alpha: 0.15),
                        borderRadius: AppBorderRadius.smallBorder,
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        color: AppColors.emerald700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Staged Transactions',
                      style: AppTypography.headlineMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '(${_drafts.length})',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPrivate
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: _isPrivate ? AppColors.warning : AppColors.gray500,
                        size: 20,
                      ),
                      tooltip: _isPrivate ? 'Show Amounts' : 'Hide Amounts',
                      onPressed: () {
                        setState(() {
                          _isPrivate = !_isPrivate;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Close and Discard Drafts',
                      onPressed: () {
                        widget.onDismiss?.call();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),

            if (hasWarningItems && _drafts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: AppBorderRadius.smallBorder,
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Some entries have missing or inferred fields. Tap chips to adjust.',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? AppColors.warning : AppColors.gray800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // Main List or Empty State
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_drafts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.emerald700,
                        size: 48,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'No draft transactions remaining',
                        style: AppTypography.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'All drafts have been committed or dismissed cleanly.',
                        style: AppTypography.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _drafts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (ctx, i) {
                    final draft = _drafts[i];
                    return Dismissible(
                      key: ValueKey(draft.id),
                      direction: DismissDirection.horizontal,
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: AppBorderRadius.largeBorder,
                        ),
                        child: const Icon(Icons.delete_rounded, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: AppBorderRadius.largeBorder,
                        ),
                        child: const Icon(Icons.delete_rounded, color: Colors.white),
                      ),
                      onDismissed: (_) => _dismissDraft(i),
                      child: _buildDraftCard(draft, i, isDark),
                    );
                  },
                ),
              ),

            const SizedBox(height: AppSpacing.md),

            // Batch Commit Action Footer
            if (_drafts.isNotEmpty) ...[
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppBorderRadius.mediumBorder,
                        ),
                      ),
                      onPressed: () {
                        widget.onDismiss?.call();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Discard All'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (!allValid && validDrafts.isNotEmpty) ...[
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppBorderRadius.mediumBorder,
                          ),
                        ),
                        onPressed: _isCommitting
                            ? null
                            : () => _commitDrafts(validDrafts),
                        child: _isCommitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text('Approve Valid (${validDrafts.length})'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            allValid ? AppColors.emerald700 : AppColors.gray400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppBorderRadius.mediumBorder,
                        ),
                      ),
                      onPressed: (allValid && !_isCommitting)
                          ? () => _commitDrafts(_drafts)
                          : null,
                      child: _isCommitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Approve All (${_drafts.length})'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDraftCard(DraftTransaction draft, int index, bool isDark) {
    Account? account;
    if (draft.accountId != null) {
      account = _accounts.where((a) => a.id == draft.accountId).firstOrNull;
    }

    Account? destinationAccount;
    if (draft.destinationAccountId != null) {
      destinationAccount = _accounts
          .where((a) => a.id == draft.destinationAccountId)
          .firstOrNull;
    }

    Category? category;
    if (draft.categoryId != null) {
      category = _categories.where((c) => c.id == draft.categoryId).firstOrNull;
    }

    final hasWarnings =
        draft.hasUnassignedAccount || draft.hasUnassignedCategory || !draft.isValid;

    Color typeColor;
    if (draft.isIncome) {
      typeColor = AppColors.emerald700;
    } else if (draft.isTransfer) {
      typeColor = AppColors.info;
    } else {
      typeColor = AppColors.danger;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.white,
        borderRadius: AppBorderRadius.largeBorder,
        border: Border.all(
          color: hasWarnings
              ? AppColors.warning.withValues(alpha: 0.6)
              : (isDark ? AppColors.darkBorder : AppColors.gray200),
          width: hasWarnings ? 1.5 : 1.0,
        ),
        boxShadow: const [AppShadows.subtle],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Type Badge, Note, Discard Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: AppBorderRadius.pillBorder,
                ),
                child: Text(
                  draft.type.toUpperCase(),
                  style: AppTypography.labelSmall.copyWith(
                    color: typeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: GestureDetector(
                  onTap: () => _editNote(index, draft),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          draft.note.isNotEmpty
                              ? draft.note
                              : (draft.rawSpeech ?? 'Untitled draft'),
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: AppColors.gray400,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: AppColors.danger,
                tooltip: 'Dismiss',
                onPressed: () => _dismissDraft(index),
              ),
            ],
          ),

          // Warning Badges (US 8)
          if (draft.hasUnassignedAccount) ...[
            const SizedBox(height: AppSpacing.xs),
            _buildWarningBadge(
              'Default Account Inferred: Review Account',
              isDark,
            ),
          ],
          if (draft.hasUnassignedCategory) ...[
            const SizedBox(height: AppSpacing.xs),
            _buildWarningBadge(
              'Unassigned Category: Tap to Pick',
              isDark,
            ),
          ],
          if (draft.amount <= 0) ...[
            const SizedBox(height: AppSpacing.xs),
            _buildWarningBadge('Missing or invalid amount', isDark, isError: true),
          ],
          if (draft.isTransfer && draft.destinationAccountId == null) ...[
            const SizedBox(height: AppSpacing.xs),
            _buildWarningBadge('Select Destination Account', isDark),
          ],

          const SizedBox(height: AppSpacing.sm),

          // Inline Interactive Chips (US 9)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Amount Chip (US 9, US 18)
              _buildInteractiveChip(
                icon: Icons.payments_outlined,
                label: AppFormatters.currency(
                  draft.amount,
                  isPrivate: _isPrivate,
                ),
                color: AppColors.emerald700,
                onTap: () => _editAmount(index, draft),
              ),

              // Account Chip (US 9, US 8)
              _buildInteractiveChip(
                icon: Icons.account_balance_wallet_outlined,
                label: account?.name ?? 'Select Account',
                color: draft.hasUnassignedAccount
                    ? AppColors.warning
                    : AppColors.gray700,
                isWarning: draft.hasUnassignedAccount,
                onTap: () => _selectAccount(index, draft, isDestination: false),
              ),

              // Category Chip (US 9, US 8)
              if (draft.isExpense)
                _buildInteractiveChip(
                  icon: Icons.category_outlined,
                  label: category != null
                      ? category.name
                      : 'Select Category',
                  color: draft.hasUnassignedCategory
                      ? AppColors.warning
                      : AppColors.gray700,
                  isWarning: draft.hasUnassignedCategory,
                  onTap: () => _selectCategory(index, draft),
                ),

              // Destination Account Chip for Transfer
              if (draft.isTransfer)
                _buildInteractiveChip(
                  icon: Icons.arrow_forward_rounded,
                  label: destinationAccount != null
                      ? 'To: ${destinationAccount.name}'
                      : 'Select Destination',
                  color: destinationAccount == null
                      ? AppColors.warning
                      : AppColors.info,
                  isWarning: destinationAccount == null,
                  onTap: () => _selectAccount(index, draft, isDestination: true),
                ),

              // Date Chip
              _buildInteractiveChip(
                icon: Icons.calendar_today_outlined,
                label: draft.date.isNotEmpty ? draft.date : 'Select Date',
                color: AppColors.gray700,
                onTap: () => _selectDate(index, draft),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBadge(String message, bool isDark, {bool isError = false}) {
    final color = isError ? AppColors.danger : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs - 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppBorderRadius.smallBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            message,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isWarning = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBorderRadius.pillBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: AppSpacing.xs + 1,
          ),
          decoration: BoxDecoration(
            color: isWarning
                ? AppColors.warning.withValues(alpha: 0.12)
                : color.withValues(alpha: 0.08),
            borderRadius: AppBorderRadius.pillBorder,
            border: Border.all(
              color: isWarning
                  ? AppColors.warning
                  : color.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isWarning ? AppColors.warning : color,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: isWarning ? AppColors.warning : color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
