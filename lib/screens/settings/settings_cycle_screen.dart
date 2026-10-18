import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/salary_cycle.dart';
import '../../services/database_helper.dart';
import '../../theme/theme_constants.dart';
import '../../components/custom_card.dart';

class SettingsCycleScreen extends StatefulWidget {
  const SettingsCycleScreen({super.key});

  @override
  State<SettingsCycleScreen> createState() => _SettingsCycleScreenState();
}

class _SettingsCycleScreenState extends State<SettingsCycleScreen> {
  int _salaryDay = 1;
  int _accountsCount = 0;
  int _categoriesCount = 0;
  int _goalsCount = 0;
  int _transactionsCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStats());
  }

  Future<void> _loadStats() async {
    try {
      final db = DatabaseHelper.instance;
      final accounts = await db.readAllAccounts();
      final categories = await db.readAllCategories();
      final goals = await db.readAllGoals();
      final transactions = await db.getTransactionHistory();
      final salaryDay = await db.getSalaryDay();

      if (mounted) {
        setState(() {
          _accountsCount = accounts.length;
          _categoriesCount = categories.length;
          _goalsCount = goals.length;
          _transactionsCount = transactions.length;
          _salaryDay = salaryDay;
        });
      }
    } catch (_) {}
  }

  Future<void> _updateSalaryDay(int day) async {
    await DatabaseHelper.instance.setSalaryDay(day);
    if (mounted) {
      setState(() {
        _salaryDay = day;
      });
      _showFeedback(
        'Salary cycle updated to day $day of the month',
        isSuccess: true,
      );
    }
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  void _showFeedback(
    String message, {
    bool isError = false,
    bool isSuccess = true,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppColors.danger
            : (isSuccess ? AppColors.emerald700 : AppColors.gray700),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Financial Cycle & Storage',
          style: AppTypography.titleLarge,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader('Financial & Cycle Preferences', isDark),
            const SizedBox(height: AppSpacing.xs),
            _buildSalaryPreferencesCard(isDark),
            const SizedBox(height: AppSpacing.xl),
            _buildSectionHeader('Storage & Record Count', isDark),
            const SizedBox(height: AppSpacing.xs),
            _buildStorageOverviewCard(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    bool isDark, {
    bool isDanger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: AppTypography.labelLarge.copyWith(
          color: isDanger
              ? AppColors.danger
              : (isDark ? AppColors.gray400 : AppColors.gray700),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSalaryPreferencesCard(bool isDark) {
    final cycle = SalaryCycle.resolve(salaryDay: _salaryDay);

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.emerald500.withValues(alpha: 0.12),
                  borderRadius: AppBorderRadius.mediumBorder,
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.emerald600,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Salary & Payday Preferences',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Anchors budget cycles, countdowns, and goal savings pacing',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),

          // Primary Interactive Payday Tile
          InkWell(
            key: const Key('salary_day_tile'),
            onTap: () => _showDayPickerBottomSheet(context, isDark),
            borderRadius: AppBorderRadius.mediumBorder,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceElevated
                    : AppColors.gray50,
                borderRadius: AppBorderRadius.mediumBorder,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.gray200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Day Badge / Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.emerald600, AppColors.emerald700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: AppBorderRadius.mediumBorder,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emerald500.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_salaryDay',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          _getDaySuffix(_salaryDay),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Day $_salaryDay of month',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_salaryDay == 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.emerald500.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: AppBorderRadius.pillBorder,
                                ),
                                child: Text(
                                  'Default',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.emerald600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              )
                            else if (_salaryDay >= 28)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gray500.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: AppBorderRadius.pillBorder,
                                ),
                                child: Text(
                                  _salaryDay == 31 ? 'Month-End' : 'Near End',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: isDark
                                        ? AppColors.gray300
                                        : AppColors.gray700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cycle.resetCountdownText,
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark
                                ? AppColors.gray400
                                : AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.emerald500.withValues(alpha: 0.1),
                      borderRadius: AppBorderRadius.pillBorder,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '1–31',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.emerald600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.edit_calendar_rounded,
                          size: 14,
                          color: AppColors.emerald600,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Live Cycle Context Banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.emerald500.withValues(alpha: 0.08),
              borderRadius: AppBorderRadius.mediumBorder,
              border: Border.all(
                color: AppColors.emerald500.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.insights_rounded,
                      size: 16,
                      color: AppColors.emerald600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Active Financial Cycle',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.emerald700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '• Current Cycle: ${cycle.cycleLabel}',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.gray300 : AppColors.gray700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '• Next Paycheck: ${cycle.resetCountdownText}',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.gray300 : AppColors.gray700,
                  ),
                ),
                if (_salaryDay >= 29) ...[
                  const SizedBox(height: 4),
                  Text(
                    '• Note: Auto-clamps to 28th/29th in Feb, 30th in 30-day months',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.emerald700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDayPickerBottomSheet(BuildContext context, bool isDark) {
    unawaited(
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Monthly Payday',
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  Text(
                    'Choose the day of the month when your salary or primary income arrives.',
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 31,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.0,
                        ),
                    itemBuilder: (ctx, index) {
                      final day = index + 1;
                      final isSelected = day == _salaryDay;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: Key('payday_grid_day_$day'),
                          onTap: () {
                            unawaited(_updateSalaryDay(day));
                            Navigator.pop(sheetContext);
                          },
                          borderRadius: AppBorderRadius.mediumBorder,
                          child: Ink(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.emerald600
                                  : (isDark
                                        ? AppColors.darkSurfaceElevated
                                        : AppColors.gray100),
                              borderRadius: AppBorderRadius.mediumBorder,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.emerald600
                                    : (isDark
                                          ? AppColors.darkBorder
                                          : AppColors.gray200),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$day',
                                style: AppTypography.labelLarge.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                            ? AppColors.gray200
                                            : AppColors.gray800),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.gray50,
                      borderRadius: AppBorderRadius.mediumBorder,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.gray200,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.emerald600,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Days 29–31 automatically clamp to the last day of shorter months (e.g. Feb 28/29, Apr 30).',
                            style: AppTypography.labelSmall.copyWith(
                              color: isDark
                                  ? AppColors.gray400
                                  : AppColors.gray600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStorageOverviewCard(bool isDark) {
    return CustomCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStorageStat(
            'Accounts',
            '$_accountsCount',
            Icons.account_balance_rounded,
            isDark,
          ),
          _buildDivider(isDark),
          _buildStorageStat(
            'Budgets',
            '$_categoriesCount',
            Icons.pie_chart_rounded,
            isDark,
          ),
          _buildDivider(isDark),
          _buildStorageStat(
            'Goals',
            '$_goalsCount',
            Icons.savings_rounded,
            isDark,
          ),
          _buildDivider(isDark),
          _buildStorageStat(
            'Transactions',
            '$_transactionsCount',
            Icons.receipt_long_rounded,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 36,
      color: isDark ? AppColors.darkBorder : AppColors.gray200,
    );
  }

  Widget _buildStorageStat(
    String label,
    String count,
    IconData icon,
    bool isDark,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.emerald600),
        const SizedBox(height: 4),
        Text(
          count,
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isDark ? AppColors.gray400 : AppColors.gray600,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
