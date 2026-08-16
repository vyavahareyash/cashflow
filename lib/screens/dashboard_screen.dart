import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database_helper.dart';
import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/plan_model.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';
import '../components/custom_input.dart';
import '../components/category_badge.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;

  const DashboardScreen({
    super.key,
    this.onNavigateTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Account> _accounts = [];
  List<Plan> _plans = [];
  List<Category> _categories = [];
  List<Map<String, dynamic>> _recentTransactions = [];

  double _totalBalance = 0.0;
  double _lockedAmount = 0.0;
  double _usableBalance = 0.0;
  double _totalBudgetReserved = 0.0;
  double _totalSpentThisMonth = 0.0;

  bool _isLoading = true;
  bool _isPrivate = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAllData();
    DatabaseHelper.dataRevision.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    DatabaseHelper.dataRevision.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    if (_accounts.isEmpty && _plans.isEmpty && _categories.isEmpty) {
      setState(() => _isLoading = true);
    }

    final db = DatabaseHelper.instance;
    final accountsData = await db.readAllAccounts();
    final locked = await db.getTotalLockedAmount();
    final usable = await db.calculateUsableBalance();
    final plansData = await db.readAllPlans();
    final categoriesData = await db.readAllCategories();
    final transactionsData = await db.getTransactionHistory();

    double totalPhysical = 0;
    for (var acc in accountsData) {
      totalPhysical += acc.balance;
    }

    double totalBudget = 0;
    double totalSpent = 0;
    for (var cat in categoriesData) {
      totalBudget += cat.monthlyBudget;
      if (cat.id != null) {
        final spent = await db.getCategorySpendingForCurrentMonth(cat.id!);
        totalSpent += spent;
      }
    }

    if (mounted) {
      setState(() {
        _accounts = accountsData;
        _plans = plansData;
        _categories = categoriesData;
        _recentTransactions = transactionsData.take(5).toList();
        _totalBalance = totalPhysical;
        _lockedAmount = locked;
        _usableBalance = usable;
        _totalBudgetReserved = totalBudget;
        _totalSpentThisMonth = totalSpent;
        _isLoading = false;
      });
    }
  }

  void _togglePrivacy() {
    setState(() {
      _isPrivate = !_isPrivate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.emerald700),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: AppColors.emerald700,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        children: [
          // 1. HERO USABLE BALANCE CARD
          _buildHeroBalanceCard(isDark),
          const SizedBox(height: AppSpacing.lg),

          // 2. QUICK ACTIONS BAR
          _buildQuickActions(isDark),
          const SizedBox(height: AppSpacing.xl),

          // 3. MONTHLY BUDGET PACE SNAPSHOT
          _buildBudgetSnapshotCard(isDark),
          const SizedBox(height: AppSpacing.xl),

          // 4. SINKING FUNDS / GOALS SNAPSHOT
          _buildGoalsSection(isDark),
          const SizedBox(height: AppSpacing.xl),

          // 5. ACCOUNTS OVERVIEW
          _buildAccountsSection(isDark),
          const SizedBox(height: AppSpacing.xl),

          // 6. RECENT TRANSACTIONS
          _buildRecentTransactionsSection(isDark),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  // --- HERO USABLE BALANCE CARD ---
  Widget _buildHeroBalanceCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF064E3B), // Deep Emerald
            Color(0xFF047857), // Vivid Emerald
            Color(0xFF0D9488), // Teal Accent
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppBorderRadius.xlargeBorder,
        boxShadow: const [AppShadows.cardGlow],
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Label & Privacy Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs + 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: AppBorderRadius.smallBorder,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Safe-to-Spend Balance',
                    style: AppTypography.labelMedium.copyWith(
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  _isPrivate ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white.withOpacity(0.85),
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _togglePrivacy,
                tooltip: _isPrivate ? 'Show Balance' : 'Hide Balance',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Main Balance Display
          Text(
            AppFormatters.currency(_usableBalance, isPrivate: _isPrivate),
            style: AppTypography.displayLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'After planned sinking funds & reserved budgets',
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Formula Pills Row
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
              borderRadius: AppBorderRadius.mediumBorder,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFormulaPill(
                  'Physical',
                  AppFormatters.compactCurrency(_totalBalance, isPrivate: _isPrivate),
                  Colors.white,
                  Icons.account_balance_rounded,
                ),
                const Text(
                  '-',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                _buildFormulaPill(
                  'Locked',
                  AppFormatters.compactCurrency(_lockedAmount, isPrivate: _isPrivate),
                  const Color(0xFFFDE68A), // Light amber
                  Icons.lock_clock_rounded,
                ),
                const Text(
                  '-',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                _buildFormulaPill(
                  'Reserved',
                  AppFormatters.compactCurrency(_totalBudgetReserved, isPrivate: _isPrivate),
                  const Color(0xFF93C5FD), // Light blue
                  Icons.pie_chart_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaPill(String label, String amount, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color.withOpacity(0.8)),
            const SizedBox(width: 3),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: AppTypography.labelMedium.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --- QUICK ACTIONS BAR ---
  Widget _buildQuickActions(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: 'Log Spend',
            icon: Icons.add_circle_rounded,
            color: AppColors.emerald600,
            isDark: isDark,
            onTap: () => _showTransactionSheet(context),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildActionButton(
            label: 'Lock Goal',
            icon: Icons.lock_outline_rounded,
            color: AppColors.warning,
            isDark: isDark,
            onTap: () {
              if (widget.onNavigateTab != null) {
                widget.onNavigateTab!(2); // Navigate to Plans
              }
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildActionButton(
            label: 'Add Budget',
            icon: Icons.pie_chart_outline_rounded,
            color: AppColors.info,
            isDark: isDark,
            onTap: () {
              if (widget.onNavigateTab != null) {
                widget.onNavigateTab!(1); // Navigate to Budgets
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBorderRadius.mediumBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.white,
            borderRadius: AppBorderRadius.mediumBorder,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.gray200,
              width: 1,
            ),
            boxShadow: isDark ? [] : [AppShadows.subtle],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs + 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.gray800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MONTHLY BUDGET SNAPSHOT ---
  Widget _buildBudgetSnapshotCard(bool isDark) {
    final remainingBudget = (_totalBudgetReserved - _totalSpentThisMonth).clamp(0.0, double.infinity);
    final progress = _totalBudgetReserved > 0 ? (_totalSpentThisMonth / _totalBudgetReserved) : 0.0;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = (daysInMonth - now.day) + 1;
    final perDayLeft = daysLeft > 0 ? (remainingBudget / daysLeft) : 0.0;

    return CustomCard(
      onTap: () {
        if (widget.onNavigateTab != null) widget.onNavigateTab!(1);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.emerald500.withOpacity(0.12),
                      borderRadius: AppBorderRadius.smallBorder,
                    ),
                    child: const Icon(
                      Icons.donut_large_rounded,
                      color: AppColors.emerald600,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Monthly Budget Pace',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Details',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.emerald600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.emerald600,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Progress Bar
          ClipRRect(
            borderRadius: AppBorderRadius.pillBorder,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: isDark ? AppColors.darkBorder : AppColors.gray200,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 1.0 ? AppColors.danger : AppColors.emerald600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Metrics Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spent so far',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                    Text(
                      AppFormatters.currency(_totalSpentThisMonth, isPrivate: _isPrivate),
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: progress > 1.0 ? AppColors.danger : (isDark ? AppColors.darkText : AppColors.gray900),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$daysLeft days left (₹${perDayLeft.toStringAsFixed(0)}/day)',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                    Text(
                      '₹${remainingBudget.toStringAsFixed(0)} left of ₹${_totalBudgetReserved.toStringAsFixed(0)}',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.emerald600,
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
  }

  // --- GOALS / PLANS SNAPSHOT ---
  Widget _buildGoalsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sinking Funds & Goals',
              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () {
                if (widget.onNavigateTab != null) widget.onNavigateTab!(2);
              },
              child: Text(
                'View All (${_plans.length})',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.emerald600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_plans.isEmpty)
          CustomCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Icon(
                      Icons.savings_outlined,
                      size: 32,
                      color: isDark ? AppColors.gray500 : AppColors.gray400,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'No sinking funds or goals planned yet',
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
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _plans.length,
              separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final plan = _plans[index];
                final planProgress = plan.totalTarget > 0 ? (plan.currentSaved / plan.totalTarget) : 0.0;
                return SizedBox(
                  width: 200,
                  child: CustomCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    onTap: () {
                      if (widget.onNavigateTab != null) widget.onNavigateTab!(2);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                plan.name,
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(planProgress * 100).toStringAsFixed(0)}%',
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.emerald600,
                              ),
                            ),
                          ],
                        ),
                        ClipRRect(
                          borderRadius: AppBorderRadius.pillBorder,
                          child: LinearProgressIndicator(
                            value: planProgress.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: isDark ? AppColors.darkBorder : AppColors.gray200,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald600),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Locked',
                              style: AppTypography.labelSmall.copyWith(
                                color: isDark ? AppColors.gray400 : AppColors.gray600,
                              ),
                            ),
                            Text(
                              '₹${plan.currentSaved.toStringAsFixed(0)} / ₹${plan.totalTarget.toStringAsFixed(0)}',
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // --- ACCOUNTS SNAPSHOT ---
  Widget _buildAccountsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Physical Accounts',
              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () {
                if (widget.onNavigateTab != null) widget.onNavigateTab!(3);
              },
              child: Text(
                'Manage (${_accounts.length})',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.emerald600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_accounts.isEmpty)
          CustomCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'No accounts added yet. Tap + to add one.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                ),
              ),
            ),
          )
        else
          ..._accounts.map((acc) => _buildAccountItem(acc, isDark)),
      ],
    );
  }

  Widget _buildAccountItem(Account acc, bool isDark) {
    final isBank = acc.type == 'Bank';
    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      onTap: () {
        if (widget.onNavigateTab != null) widget.onNavigateTab!(3);
      },
      child: Row(
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
              size: 20,
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
                    fontWeight: FontWeight.w700,
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
          Text(
            AppFormatters.currency(acc.balance, isPrivate: _isPrivate),
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // --- RECENT TRANSACTIONS ---
  Widget _buildRecentTransactionsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () {
                if (widget.onNavigateTab != null) widget.onNavigateTab!(4);
              },
              child: Text(
                'Full History',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.emerald600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_recentTransactions.isEmpty)
          CustomCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'No transactions logged yet',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                ),
              ),
            ),
          )
        else
          ..._recentTransactions.map((tx) => _buildTransactionItem(tx, isDark)),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx, bool isDark) {
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
                  '$accountName • ${DateFormat('MMM dd').format(date)}',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '-${AppFormatters.currency(amount, isPrivate: _isPrivate)}',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- LOG SPEND BOTTOM SHEET ---
  void _showTransactionSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    int? selectedAccountId = _accounts.isNotEmpty ? _accounts.first.id : null;
    int? selectedCategoryId = _categories.isNotEmpty ? _categories.first.id : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
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
                      'Log New Expense',
                      style: AppTypography.headlineMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Amount input
                    CustomInputField(
                      controller: amountController,
                      label: 'Amount',
                      prefixText: '₹ ',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Category Selector
                    Text(
                      'Category',
                      style: AppTypography.labelMedium.copyWith(
                        color: isDark ? AppColors.gray300 : AppColors.gray700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<int>(
                      value: selectedCategoryId,
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
                      items: _categories
                          .map(
                            (cat) => DropdownMenuItem(
                              value: cat.id,
                              child: Row(
                                children: [
                                  CategoryBadge(label: cat.name, showIcon: true),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setStateSheet(() => selectedCategoryId = val),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Account Selector
                    Text(
                      'From Account',
                      style: AppTypography.labelMedium.copyWith(
                        color: isDark ? AppColors.gray300 : AppColors.gray700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<int>(
                      value: selectedAccountId,
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
                      items: _accounts
                          .map(
                            (acc) => DropdownMenuItem(
                              value: acc.id,
                              child: Text('${acc.name} (₹${acc.balance.toStringAsFixed(0)})'),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setStateSheet(() => selectedAccountId = val),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Note Input
                    CustomInputField(
                      controller: noteController,
                      label: 'Note (Optional)',
                      hint: 'e.g. Weekly grocery shopping',
                      prefixIcon: Icons.notes_rounded,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Date Selector
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      title: Text(
                        'Date',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate),
                        style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.emerald700,
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) {
                          setStateSheet(() => _selectedDate = picked);
                        }
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: AppBorderRadius.mediumBorder,
                        side: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.gray300,
                        ),
                      ),
                      tileColor: isDark ? AppColors.darkSurface : AppColors.gray50,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: AppComponentSizes.buttonHeightLarge,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (amountController.text.isEmpty ||
                              selectedAccountId == null ||
                              selectedCategoryId == null) {
                            return;
                          }
                          final amount = double.tryParse(amountController.text) ?? 0.0;
                          if (amount <= 0) return;

                          await DatabaseHelper.instance.insertTransaction(
                            TransactionModel(
                              accountId: selectedAccountId!,
                              categoryId: selectedCategoryId!,
                              amount: amount,
                              date: _selectedDate.toIso8601String(),
                              note: noteController.text.trim(),
                            ),
                          );
                          await DatabaseHelper.instance.subtractFromAccount(
                            selectedAccountId!,
                            amount,
                          );

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          _loadAllData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppBorderRadius.mediumBorder,
                          ),
                        ),
                        child: const Text('Save Expense', style: AppTypography.labelLarge),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
