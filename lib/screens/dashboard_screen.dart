import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database_helper.dart';
import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/credit_card_model.dart';
import '../models/goal_model.dart';
import '../models/salary_cycle.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';
import '../components/custom_input.dart';
import '../components/category_badge.dart';
import '../components/app_dialogs.dart';
import '../components/walkthrough/walkthrough_keys.dart';
import 'accounts_screen.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int tabIndex, {int? subTabIndex})? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  /// Tracks whether startup privacy mode has been synchronized for this app session.
  static bool _startupPrivacyInitialized = false;

  /// Resets the startup privacy initialization flag (useful for testing).
  @visibleForTesting
  static void resetStartupPrivacyFlag() {
    _startupPrivacyInitialized = false;
  }

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  List<Account> _accounts = [];
  Map<int, CreditCard> _creditCardsMap = {};
  Map<int, double> _accountLocksMap = {};
  List<Goal> _goals = [];
  List<Category> _categories = [];
  List<Map<String, dynamic>> _recentTransactions = [];

  double _totalBalance = 0.0;
  double _lockedAmount = 0.0;
  double _usableBalance = 0.0;
  double _totalBudgetLimit = 0.0;
  double _totalSpentThisMonth = 0.0;

  bool _isLoading = true;
  bool _isPrivate = false;
  bool _showAllAccounts = false;
  int _salaryDay = 1;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadAllData());
    DatabaseHelper.dataRevision.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DatabaseHelper.dataRevision.removeListener(_onDataChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.resumed) {
      unawaited(_handleLifecyclePrivacy());
    }
  }

  Future<void> _handleLifecyclePrivacy() async {
    final startInPrivacy = await DatabaseHelper.instance
        .getStartInPrivacyMode();
    if (startInPrivacy && !_isPrivate && mounted) {
      setState(() {
        _isPrivate = true;
      });
      await DatabaseHelper.instance.setPrivacyMode(true);
    }
  }

  void _onDataChanged() {
    if (mounted) {
      unawaited(_loadAllData());
    }
  }

  Future<void> _loadAllData() async {
    if (_accounts.isEmpty && _goals.isEmpty && _categories.isEmpty) {
      setState(() => _isLoading = true);
    }

    final db = DatabaseHelper.instance;
    if (!DashboardScreen._startupPrivacyInitialized) {
      DashboardScreen._startupPrivacyInitialized = true;
      await db.initStartupPrivacyMode();
    }
    final isPrivate = await db.getPrivacyMode();
    final salaryDay = await db.getSalaryDay();
    final cycle = SalaryCycle.resolve(salaryDay: salaryDay);
    final accountsData = await db.readAllAccounts();
    final creditCardsData = await db.readAllCreditCards();
    final Map<int, CreditCard> creditCardsMap = {
      for (final cc in creditCardsData) cc.accountId: cc,
    };
    final Map<int, double> accountLocksMap = {};
    for (var acc in accountsData) {
      if (!acc.isCreditCard && acc.id != null) {
        final locks = await db.getLocksForAccount(acc.id!);
        accountLocksMap[acc.id!] = locks.fold<double>(
          0.0,
          (sum, l) => sum + l.amount,
        );
      }
    }
    final locked = await db.getTotalLockedAmount();
    final usable = await db.calculateUsableBalance();
    final goalsData = await db.readAllGoals();
    final categoriesData = await db.readAllCategories();
    final transactionsData = await db.getTransactionHistory();

    double totalPhysical = 0;
    for (var acc in accountsData) {
      if (!acc.isCreditCard) {
        totalPhysical += acc.balance;
      }
    }

    final categorySpendingMap = await db.getMonthlySpendingByCategoryId(
      cycle: cycle,
    );
    double totalBudget = 0;
    double totalSpent = 0;
    for (var cat in categoriesData) {
      if (!cat.isExpense) continue;
      final budget = cat.monthlyBudget;
      final hasBudget = budget != null && budget > 0;
      if (hasBudget) {
        totalBudget += budget;
      }
      if (cat.id != null) {
        final spent = categorySpendingMap[cat.id!] ?? 0.0;
        if (hasBudget) {
          totalSpent += spent;
        }
      }
    }

    if (mounted) {
      setState(() {
        _accounts = accountsData;
        _creditCardsMap = creditCardsMap;
        _accountLocksMap = accountLocksMap;
        _goals = goalsData;
        _categories = categoriesData;
        _recentTransactions = transactionsData.take(5).toList();
        _totalBalance = totalPhysical;
        _lockedAmount = locked;
        _usableBalance = usable;
        _totalBudgetLimit = totalBudget;
        _totalSpentThisMonth = totalSpent;
        _isPrivate = isPrivate;
        _salaryDay = salaryDay;
        _isLoading = false;
      });
    }
  }

  void _togglePrivacy() {
    final nextPrivate = !_isPrivate;
    setState(() {
      _isPrivate = nextPrivate;
    });
    unawaited(DatabaseHelper.instance.setPrivacyMode(nextPrivate));
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          100,
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
      key: WalkthroughKeys.balanceCardKey,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF064E3B), // Deep Emerald
            Color(0xFF047857), // Vivid Emerald
            Color(0xFF0D9488), // Teal Accent
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppBorderRadius.xlargeBorder,
        boxShadow: [AppShadows.cardGlow],
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
                      color: Colors.white.withValues(alpha: 0.18),
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
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Tooltip(
                    message: 'After goal sinking funds; budgets remain tracking limits',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
              IconButton(
                key: WalkthroughKeys.privacyToggleKey,
                icon: Icon(
                  _isPrivate
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
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
          const SizedBox(height: AppSpacing.lg),

          // Formula Pills Row
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: AppBorderRadius.mediumBorder,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFormulaPill(
                  'Physical',
                  AppFormatters.compactCurrency(
                    _totalBalance,
                    isPrivate: _isPrivate,
                  ),
                  Colors.white,
                  Icons.account_balance_rounded,
                ),
                const Text(
                  '-',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                _buildFormulaPill(
                  'Locked',
                  AppFormatters.compactCurrency(
                    _lockedAmount,
                    isPrivate: _isPrivate,
                  ),
                  const Color(0xFFFDE68A), // Light amber
                  Icons.lock_clock_rounded,
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                ),
                _buildFormulaPill(
                  'Budget cap',
                  AppFormatters.compactCurrency(
                    _totalBudgetLimit,
                    isPrivate: _isPrivate,
                  ),
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

  Widget _buildFormulaPill(
    String label,
    String amount,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color.withValues(alpha: 0.8)),
            const SizedBox(width: 3),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
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
            key: const Key('dashboard_log_transaction_action'),
            label: 'Log Transaction',
            icon: Icons.add_circle_rounded,
            color: AppColors.emerald600,
            isDark: isDark,
            onTap: () => _showTransactionSheet(context),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildActionButton(
            key: const Key('dashboard_lock_goal_action'),
            label: 'Lock Goal',
            icon: Icons.lock_outline_rounded,
            color: AppColors.warning,
            isDark: isDark,
            onTap: () {
              if (widget.onNavigateTab != null) {
                widget.onNavigateTab!(3, subTabIndex: 2);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountsScreen(initialTabIndex: 2),
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildActionButton(
            key: const Key('dashboard_add_budget_action'),
            label: 'Add Budget',
            icon: Icons.pie_chart_outline_rounded,
            color: AppColors.info,
            isDark: isDark,
            onTap: () {
              if (widget.onNavigateTab != null) {
                widget.onNavigateTab!(3, subTabIndex: 1);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountsScreen(initialTabIndex: 1),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    Key? key,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
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
                  color: color.withValues(alpha: 0.12),
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
    final remainingBudget = (_totalBudgetLimit - _totalSpentThisMonth).clamp(
      0.0,
      double.infinity,
    );
    final progress = _totalBudgetLimit > 0
        ? (_totalSpentThisMonth / _totalBudgetLimit)
        : 0.0;
    final cycle = SalaryCycle.resolve(salaryDay: _salaryDay);
    final daysLeft = cycle.daysLeftInCycle;
    final perDayLeft = daysLeft > 0 ? (remainingBudget / daysLeft) : 0.0;

    return CustomCard(
      onTap: () {
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(3, subTabIndex: 1);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AccountsScreen(initialTabIndex: 1),
            ),
          );
        }
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
                      color: AppColors.emerald500.withValues(alpha: 0.12),
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
              backgroundColor: isDark
                  ? AppColors.darkBorder
                  : AppColors.gray200,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spent so far',
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                    ),
                  ),
                  Text(
                    AppFormatters.currency(
                      _totalSpentThisMonth,
                      isPrivate: _isPrivate,
                    ),
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: progress > 1.0
                          ? AppColors.danger
                          : (isDark ? AppColors.darkText : AppColors.gray900),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Remaining',
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                    ),
                  ),
                  Text(
                    '${AppFormatters.compactCurrency(remainingBudget, isPrivate: _isPrivate)} left of ${AppFormatters.compactCurrency(_totalBudgetLimit, isPrivate: _isPrivate)}',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.emerald600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$daysLeft days left',
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                    ),
                  ),
                ],
              ),
              Text(
                '${AppFormatters.compactCurrency(perDayLeft, isPrivate: _isPrivate)}/day pace',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
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
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () {
                if (widget.onNavigateTab != null) {
                  widget.onNavigateTab!(3, subTabIndex: 2);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountsScreen(initialTabIndex: 2),
                    ),
                  );
                }
              },
              child: Text(
                'View All (${_goals.length})',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.emerald600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_goals.isEmpty)
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
              itemCount: _goals.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final goal = _goals[index];
                final goalProgress = goal.totalTarget > 0
                    ? (goal.currentSaved / goal.totalTarget)
                    : 0.0;
                return SizedBox(
                  width: 210,
                  child: CustomCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    onTap: () {
                      if (widget.onNavigateTab != null) {
                        widget.onNavigateTab!(3, subTabIndex: 2);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const AccountsScreen(initialTabIndex: 2),
                          ),
                        );
                      }
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
                                goal.name,
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(goalProgress * 100).toStringAsFixed(0)}%',
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
                            value: goalProgress.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: isDark
                                ? AppColors.darkBorder
                                : AppColors.gray200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.emerald600,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                goal.deadlineStatusText(),
                                style: AppTypography.labelSmall.copyWith(
                                  color: goal.isOverdue()
                                      ? AppColors.danger
                                      : (isDark
                                            ? AppColors.gray400
                                            : AppColors.gray600),
                                  fontSize: 10,
                                  fontWeight: goal.isOverdue()
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '${AppFormatters.compactCurrency(goal.currentSaved, isPrivate: _isPrivate)} / ${AppFormatters.compactCurrency(goal.totalTarget, isPrivate: _isPrivate)}',
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
    final displayedAccounts = _showAllAccounts
        ? _accounts
        : _accounts.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Physical Accounts',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () {
                if (widget.onNavigateTab != null) {
                  widget.onNavigateTab!(3, subTabIndex: 0);
                }
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
        else ...[
          ...displayedAccounts.map((acc) => _buildAccountItem(acc, isDark)),
          if (_accounts.length > 3)
            Center(
              child: TextButton.icon(
                key: const Key('dashboard_accounts_toggle_show_all'),
                onPressed: () =>
                    setState(() => _showAllAccounts = !_showAllAccounts),
                icon: Icon(
                  _showAllAccounts
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.emerald600,
                ),
                label: Text(
                  _showAllAccounts
                      ? 'Show Less'
                      : 'Show More (${_accounts.length - 3} more)',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.emerald600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildAccountItem(Account acc, bool isDark) {
    final isBank = acc.type == 'Bank';
    final isCC = acc.isCreditCard;
    final totalLocked = _accountLocksMap[acc.id] ?? 0.0;
    final usableBalance = (acc.balance - totalLocked).clamp(
      0.0,
      double.infinity,
    );

    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      onTap: () {
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(3, subTabIndex: 0);
        }
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color:
                  (isCC
                          ? AppColors.purple
                          : (isBank ? AppColors.info : AppColors.emerald600))
                      .withValues(alpha: 0.12),
              borderRadius: AppBorderRadius.mediumBorder,
            ),
            child: Icon(
              isCC
                  ? Icons.credit_card_rounded
                  : (isBank
                        ? Icons.account_balance_rounded
                        : Icons.wallet_rounded),
              color: isCC
                  ? AppColors.purple
                  : (isBank ? AppColors.info : AppColors.emerald600),
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
                  isCC ? 'Credit Card (Liability)' : acc.type,
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
                AppFormatters.currency(acc.balance, isPrivate: _isPrivate),
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: (isCC && acc.balance > 0)
                      ? AppColors.danger
                      : (isDark ? AppColors.darkText : AppColors.gray900),
                ),
              ),
              if (totalLocked > 0 && !isCC)
                Text(
                  '${AppFormatters.compactCurrency(usableBalance, isPrivate: _isPrivate)} usable',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.emerald400 : AppColors.emerald600,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  isCC ? 'Outstanding' : 'Balance',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                ),
            ],
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
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () {
                if (widget.onNavigateTab != null) widget.onNavigateTab!(1);
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
    final type = tx['type'] as String? ?? 'expense';
    final isIncome = type == 'income';
    final isTransfer = type == 'transfer';
    final categoryName = isTransfer
        ? 'Transfer'
        : tx['category_name'] ?? 'General';
    final accountName = tx['account_name'] ?? 'Account';
    final destinationAccountName = tx['destination_account_name'] as String?;
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final note = tx['note'] as String?;
    final accountDescription = isTransfer && destinationAccountName != null
        ? '$accountName → $destinationAccountName'
        : accountName;
    final amountPrefix = isIncome
        ? '+'
        : isTransfer
        ? ''
        : '-';
    final amountColor = isIncome
        ? AppColors.emerald700
        : isTransfer
        ? (isDark ? AppColors.gray300 : AppColors.gray700)
        : AppColors.danger;

    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          CategoryBadge(label: categoryName, iconOnly: true),
          const SizedBox(width: AppSpacing.sm + 2),
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
                  note != null && note.isNotEmpty
                      ? '$categoryName • $accountDescription • ${DateFormat('MMM dd').format(date)}'
                      : '$accountDescription • ${DateFormat('MMM dd').format(date)}',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$amountPrefix${AppFormatters.currency(amount, isPrivate: _isPrivate)}',
            style: AppTypography.titleMedium.copyWith(
              color: amountColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- LOG TRANSACTION BOTTOM SHEET ---
  void _showTransactionSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String selectedType = 'expense';
    int? selectedAccountId = _accounts.isNotEmpty ? _accounts.first.id : null;
    int? selectedDestinationAccountId = _accounts.length > 1
        ? _accounts[1].id
        : null;
    final expenseCategories = _categories.where((c) => c.isExpense).toList();
    final incomeCategories = _categories.where((c) => c.isIncome).toList();
    int? selectedCategoryId = expenseCategories.isNotEmpty
        ? expenseCategories.first.id
        : _categories.firstOrNull?.id;
    int? selectedGoalId = _goals.isNotEmpty ? _goals.first.id : null;

    final initialCc = selectedAccountId != null
        ? _creditCardsMap[selectedAccountId]
        : null;
    bool lockCcFunds = initialCc?.autoLock ?? true;
    final bankAccounts = _accounts.where((a) => !a.isCreditCard).toList();
    int? selectedLockBankAccountId =
        initialCc?.defaultLockAccountId ?? bankAccounts.firstOrNull?.id;

    unawaited(
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
              final availableCats = selectedType == 'income'
                  ? incomeCategories
                  : expenseCategories;
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
                            color: isDark
                                ? AppColors.gray700
                                : AppColors.gray300,
                            borderRadius: AppBorderRadius.pillBorder,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Log Transaction',
                            style: AppTypography.headlineMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Transaction Type Selector
                      Text(
                        'Type',
                        style: AppTypography.labelMedium.copyWith(
                          color: isDark ? AppColors.gray300 : AppColors.gray700,
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
                        items: const [
                          DropdownMenuItem(
                            value: 'expense',
                            child: Text('Expense'),
                          ),
                          DropdownMenuItem(
                            value: 'income',
                            child: Text('Income'),
                          ),
                          DropdownMenuItem(
                            value: 'transfer',
                            child: Text('Transfer'),
                          ),
                          DropdownMenuItem(
                            value: 'goal_lock',
                            child: Text('Goal Lock'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setStateSheet(() {
                              selectedType = val;
                              if (val != 'expense') {
                                final acc = _accounts
                                    .where((a) => a.id == selectedAccountId)
                                    .firstOrNull;
                                if (acc?.isCreditCard == true) {
                                  selectedAccountId =
                                      bankAccounts.firstOrNull?.id;
                                }
                              }
                              if (val == 'income') {
                                if (!incomeCategories.any(
                                  (c) => c.id == selectedCategoryId,
                                )) {
                                  selectedCategoryId =
                                      incomeCategories.firstOrNull?.id;
                                }
                              } else if (val == 'expense') {
                                if (!expenseCategories.any(
                                  (c) => c.id == selectedCategoryId,
                                )) {
                                  selectedCategoryId =
                                      expenseCategories.firstOrNull?.id;
                                }
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Amount input
                      CustomInputField(
                        controller: amountController,
                        label: 'Amount',
                        hint: '0.00',
                        prefixText: '₹ ',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Category Selector (expense & income)
                      if (selectedType != 'transfer' &&
                          selectedType != 'goal_lock') ...[
                        Text(
                          'Category',
                          style: AppTypography.labelMedium.copyWith(
                            color: isDark
                                ? AppColors.gray300
                                : AppColors.gray700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        DropdownButtonFormField<int>(
                          key: ValueKey(
                            'tx_cat_dropdown_${selectedType}_$selectedCategoryId',
                          ),
                          initialValue:
                              availableCats.any(
                                (c) => c.id == selectedCategoryId,
                              )
                              ? selectedCategoryId
                              : availableCats.firstOrNull?.id,
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
                          items: availableCats
                              .map(
                                (cat) => DropdownMenuItem(
                                  value: cat.id,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: CategoryBadge(
                                          label: cat.name,
                                          showIcon: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setStateSheet(() => selectedCategoryId = val),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // Goal Selector (goal_lock only)
                      if (selectedType == 'goal_lock') ...[
                        Text(
                          'Goal',
                          style: AppTypography.labelMedium.copyWith(
                            color: isDark
                                ? AppColors.gray300
                                : AppColors.gray700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (_goals.isEmpty)
                          Text(
                            'No goals available. Create a goal first.',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.danger,
                            ),
                          )
                        else
                          DropdownButtonFormField<int>(
                            initialValue: selectedGoalId,
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
                            items: _goals
                                .map(
                                  (goal) => DropdownMenuItem(
                                    value: goal.id,
                                    child: Text(
                                      '${goal.name} (₹${goal.currentSaved.toStringAsFixed(0)} / ₹${goal.totalTarget.toStringAsFixed(0)})',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setStateSheet(() => selectedGoalId = val),
                          ),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // Account Selector
                      Builder(
                        builder: (context) {
                          final eligibleAccounts = selectedType == 'expense'
                              ? _accounts
                              : bankAccounts;
                          final currentAccId =
                              eligibleAccounts.any(
                                (a) => a.id == selectedAccountId,
                              )
                              ? selectedAccountId
                              : eligibleAccounts.firstOrNull?.id;
                          selectedAccountId = currentAccId;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedType == 'income'
                                    ? 'To Account'
                                    : 'From Account',
                                style: AppTypography.labelMedium.copyWith(
                                  color: isDark
                                      ? AppColors.gray300
                                      : AppColors.gray700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              DropdownButtonFormField<int>(
                                initialValue: selectedAccountId,
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
                                items: eligibleAccounts
                                    .map(
                                      (acc) => DropdownMenuItem(
                                        value: acc.id,
                                        child: Row(
                                          children: [
                                            if (acc.isCreditCard) ...[
                                              const Icon(
                                                Icons.credit_card_rounded,
                                                size: 16,
                                                color: AppColors.purple,
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.xs,
                                              ),
                                            ],
                                            Expanded(
                                              child: Text(
                                                acc.name,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.sm,
                                            ),
                                            Text(
                                              acc.isCreditCard
                                                  ? 'Due: ₹${acc.balance.toStringAsFixed(0)}'
                                                  : '₹${acc.balance.toStringAsFixed(0)}',
                                              style: AppTypography.labelSmall
                                                  .copyWith(
                                                    color: acc.isCreditCard
                                                        ? AppColors.purple
                                                        : (isDark
                                                              ? AppColors
                                                                    .gray400
                                                              : AppColors
                                                                    .gray500),
                                                    fontWeight: acc.isCreditCard
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setStateSheet(() {
                                    selectedAccountId = val;
                                    if (val != null) {
                                      final cc = _creditCardsMap[val];
                                      if (cc != null) {
                                        lockCcFunds = cc.autoLock;
                                        if (cc.defaultLockAccountId != null &&
                                            bankAccounts.any(
                                              (b) =>
                                                  b.id ==
                                                  cc.defaultLockAccountId,
                                            )) {
                                          selectedLockBankAccountId =
                                              cc.defaultLockAccountId;
                                        } else if (selectedLockBankAccountId ==
                                                null ||
                                            !bankAccounts.any(
                                              (b) =>
                                                  b.id ==
                                                  selectedLockBankAccountId,
                                            )) {
                                          selectedLockBankAccountId =
                                              bankAccounts.firstOrNull?.id;
                                        }
                                      }
                                    }
                                  });
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Credit Card Fund Lock Section (for CC expense)
                      if (selectedType == 'expense' &&
                          _accounts
                                  .where((a) => a.id == selectedAccountId)
                                  .firstOrNull
                                  ?.isCreditCard ==
                              true) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.purple.withValues(alpha: 0.12)
                                : AppColors.purple.withValues(alpha: 0.06),
                            borderRadius: AppBorderRadius.mediumBorder,
                            border: Border.all(
                              color: AppColors.purple.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Lock Funds in Bank Account',
                                  style: AppTypography.labelMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Reserve cash to pay this credit card bill',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: isDark
                                        ? AppColors.gray400
                                        : AppColors.gray600,
                                  ),
                                ),
                                value: lockCcFunds,
                                activeThumbColor: AppColors.purple,
                                onChanged: (val) {
                                  setStateSheet(() => lockCcFunds = val);
                                },
                              ),
                              if (lockCcFunds) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Reserve From Account',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: isDark
                                        ? AppColors.gray400
                                        : AppColors.gray600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                DropdownButtonFormField<int>(
                                  initialValue:
                                      bankAccounts.any(
                                        (b) =>
                                            b.id == selectedLockBankAccountId,
                                      )
                                      ? selectedLockBankAccountId
                                      : bankAccounts.firstOrNull?.id,
                                  isExpanded: true,
                                  dropdownColor: isDark
                                      ? AppColors.darkSurfaceElevated
                                      : AppColors.white,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark
                                        ? AppColors.darkSurface
                                        : AppColors.white,
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          AppBorderRadius.mediumBorder,
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? AppColors.darkBorder
                                            : AppColors.gray300,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.sm,
                                    ),
                                  ),
                                  items: bankAccounts
                                      .map(
                                        (acc) => DropdownMenuItem(
                                          value: acc.id,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  acc.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.sm,
                                              ),
                                              Text(
                                                '₹${acc.balance.toStringAsFixed(0)}',
                                                style: AppTypography.labelSmall
                                                    .copyWith(
                                                      color: isDark
                                                          ? AppColors.gray400
                                                          : AppColors.gray500,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    setStateSheet(
                                      () => selectedLockBankAccountId = val,
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      if (selectedType == 'transfer') ...[
                        Text(
                          'To Account',
                          style: AppTypography.labelMedium.copyWith(
                            color: isDark
                                ? AppColors.gray300
                                : AppColors.gray700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Builder(
                          builder: (context) {
                            final eligibleDestinations = bankAccounts
                                .where((acc) => acc.id != selectedAccountId)
                                .toList();
                            final currentDestId =
                                eligibleDestinations.any(
                                  (a) => a.id == selectedDestinationAccountId,
                                )
                                ? selectedDestinationAccountId
                                : eligibleDestinations.firstOrNull?.id;
                            selectedDestinationAccountId = currentDestId;

                            return DropdownButtonFormField<int>(
                              initialValue: selectedDestinationAccountId,
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
                              items: eligibleDestinations
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
                                            '₹${acc.balance.toStringAsFixed(0)}',
                                            style: AppTypography.labelSmall
                                                .copyWith(
                                                  color: isDark
                                                      ? AppColors.gray400
                                                      : AppColors.gray500,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) => setStateSheet(
                                () => selectedDestinationAccountId = val,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],

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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        title: Text(
                          'Date',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark
                                ? AppColors.gray400
                                : AppColors.gray600,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('EEEE, MMM dd, yyyy')
                              .format(_selectedDate),
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
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
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.gray300,
                          ),
                        ),
                        tileColor: isDark
                            ? AppColors.darkSurface
                            : AppColors.gray50,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: AppComponentSizes.buttonHeightLarge,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (amountController.text.isEmpty ||
                                selectedAccountId == null) {
                              await AppDialogs.showWarning(
                                ctx,
                                message: 'Select an account and amount.',
                              );
                              return;
                            }
                            final amount =
                                double.tryParse(amountController.text) ?? 0.0;
                            if (amount <= 0) {
                              await AppDialogs.showWarning(
                                ctx,
                                message: 'Enter an amount greater than zero.',
                              );
                              return;
                            }

                            try {
                              if (selectedType == 'income') {
                                await DatabaseHelper.instance
                                    .createIncomeTransaction(
                                      accountId: selectedAccountId!,
                                      amount: amount,
                                      date: _selectedDate.toIso8601String(),
                                      note: noteController.text.trim(),
                                      categoryId: selectedCategoryId,
                                    );
                              } else if (selectedType == 'transfer') {
                                if (selectedDestinationAccountId == null) {
                                  throw ArgumentError(
                                    'Select a destination account.',
                                  );
                                }
                                final sourceAcc = _accounts.firstWhere(
                                  (acc) => acc.id == selectedAccountId,
                                  orElse: () =>
                                      throw ArgumentError('Select an account.'),
                                );
                                if (sourceAcc.type != 'Credit Card' &&
                                    amount > sourceAcc.balance) {
                                  throw ArgumentError(
                                    'Transfer amount cannot exceed source account balance (₹${sourceAcc.balance.toStringAsFixed(0)} available).',
                                  );
                                }
                                await DatabaseHelper.instance
                                    .createTransferTransaction(
                                      sourceAccountId: selectedAccountId!,
                                      destinationAccountId:
                                          selectedDestinationAccountId!,
                                      amount: amount,
                                      date: _selectedDate.toIso8601String(),
                                      note: noteController.text.trim(),
                                    );
                              } else if (selectedType == 'goal_lock') {
                                if (selectedGoalId == null) {
                                  throw ArgumentError('Select a goal.');
                                }
                                final account = _accounts.firstWhere(
                                  (acc) => acc.id == selectedAccountId,
                                  orElse: () =>
                                      throw ArgumentError('Select an account.'),
                                );
                                if (amount > account.balance) {
                                  throw ArgumentError(
                                    'Lock amount cannot exceed account balance (₹${account.balance.toStringAsFixed(0)}).',
                                  );
                                }
                                await DatabaseHelper.instance
                                    .createGoalLockTransaction(
                                      goalId: selectedGoalId!,
                                      accountId: selectedAccountId!,
                                      amount: amount,
                                      date: _selectedDate.toIso8601String(),
                                      note: noteController.text.trim(),
                                    );
                              } else {
                                if (selectedCategoryId == null) {
                                  throw ArgumentError('Select a category.');
                                }
                                final currentSelectedAcc = _accounts
                                    .where((a) => a.id == selectedAccountId)
                                    .firstOrNull;
                                if (currentSelectedAcc?.isCreditCard == true) {
                                  final cc = _creditCardsMap[selectedAccountId];
                                  final availableCredit =
                                      (cc?.creditLimit ?? 0) -
                                      currentSelectedAcc!.balance;
                                  if (amount > availableCredit) {
                                    throw ArgumentError(
                                      'Transaction amount exceeds available credit limit (₹${availableCredit.toStringAsFixed(0)} available).',
                                    );
                                  }
                                  if (lockCcFunds &&
                                      selectedLockBankAccountId == null) {
                                    throw ArgumentError(
                                      'Please select a bank account to lock funds in.',
                                    );
                                  }
                                  await DatabaseHelper.instance
                                      .createCreditCardExpenseTransaction(
                                        ccAccountId: selectedAccountId!,
                                        categoryId: selectedCategoryId!,
                                        amount: amount,
                                        date: _selectedDate.toIso8601String(),
                                        note: noteController.text.trim(),
                                        lockBankAccountId: lockCcFunds
                                            ? selectedLockBankAccountId
                                            : null,
                                      );
                                } else {
                                  if (amount >
                                      (currentSelectedAcc?.balance ?? 0)) {
                                    throw ArgumentError(
                                      'Expense amount cannot exceed account balance (₹${(currentSelectedAcc?.balance ?? 0).toStringAsFixed(0)} available).',
                                    );
                                  }
                                  await DatabaseHelper.instance
                                      .insertTransaction(
                                        TransactionModel(
                                          accountId: selectedAccountId!,
                                          categoryId: selectedCategoryId!,
                                          amount: amount,
                                          date: _selectedDate.toIso8601String(),
                                          note: noteController.text.trim(),
                                        ),
                                      );
                                  await DatabaseHelper.instance
                                      .subtractFromAccount(
                                        selectedAccountId!,
                                        amount,
                                      );
                                }
                              }
                            } catch (error) {
                              if (ctx.mounted) {
                                await AppDialogs.showWarning(
                                  ctx,
                                  message: error.toString(),
                                );
                              }
                              return;
                            }

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            unawaited(_loadAllData());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emerald700,
                            foregroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppBorderRadius.mediumBorder,
                            ),
                          ),
                          child: Text(
                            selectedType == 'income'
                                ? 'Save Income'
                                : selectedType == 'transfer'
                                ? 'Save Transfer'
                                : 'Save Expense',
                            style: AppTypography.labelLarge,
                          ),
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
      ),
    );
  }
}
