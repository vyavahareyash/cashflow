import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../models/category_model.dart';
import '../services/database_helper.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';

class AnalyticsScreen extends StatefulWidget {
  final int? initialIndex;

  const AnalyticsScreen({super.key, this.initialIndex});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, double> _categorySpending = {};
  final Set<String> _hiddenCategories = {};
  Map<String, double> _monthlySpendings = {};
  Map<String, double> _trendMonthlySpendings = {};
  List<Category> _categories = [];
  int? _selectedTrendCategoryId;
  int _trendMonths = 6;
  bool _isYtd = false;
  Map<String, double> _ytdCashflow = {};
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _startDate = DateTime(today.year, today.month, 1);
    _endDate = today;
    unawaited(_loadAllData());
    DatabaseHelper.dataRevision.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    DatabaseHelper.dataRevision.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      unawaited(_loadAllData());
    }
  }

  Future<void> _loadAllData() async {
    if (_categorySpending.isEmpty) {
      setState(() => _isLoading = true);
    }

    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    final categories = await db.readAllCategories(type: 'expense');

    if (_isYtd) {
      final categoryData = await db.getYtdSpendingByCategory(year: now.year);
      final monthlyData = await db.getYtdMonthlySpendings(year: now.year);
      final cashflowData = await db.getYtdCashflowSummary(year: now.year);
      final trendData = _selectedTrendCategoryId != null
          ? await db.getYtdMonthlySpendings(
              year: now.year,
              categoryId: _selectedTrendCategoryId,
            )
          : monthlyData;
      if (mounted) {
        setState(() {
          _categories = categories;
          _categorySpending = categoryData;
          _monthlySpendings = monthlyData;
          _trendMonthlySpendings = trendData;
          _ytdCashflow = cashflowData;
          _hiddenCategories.removeWhere(
            (c) => !_categorySpending.containsKey(c),
          );
          _isLoading = false;
        });
      }
    } else {
      final categoryData = await db.getSpendingByCategoryForDateRange(
        startDate: _startDate,
        endDate: _endDate,
      );
      final monthlyData = await db.getMonthlySpendings(months: 6);
      final trendData = _selectedTrendCategoryId != null
          ? await db.getMonthlySpendings(
              months: _trendMonths,
              categoryId: _selectedTrendCategoryId,
            )
          : (_trendMonths == 6
                ? monthlyData
                : await db.getMonthlySpendings(months: _trendMonths));
      if (mounted) {
        setState(() {
          _categories = categories;
          _categorySpending = categoryData;
          _monthlySpendings = monthlyData;
          _trendMonthlySpendings = trendData;
          _hiddenCategories.removeWhere(
            (c) => !_categorySpending.containsKey(c),
          );
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onTrendCategoryChanged(int? newCategoryId) async {
    setState(() {
      _selectedTrendCategoryId = newCategoryId;
    });
    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    final trendData = _isYtd
        ? await db.getYtdMonthlySpendings(
            year: now.year,
            categoryId: newCategoryId,
          )
        : await db.getMonthlySpendings(
            months: _trendMonths,
            categoryId: newCategoryId,
          );
    if (mounted) {
      setState(() {
        _trendMonthlySpendings = trendData;
      });
    }
  }

  Future<void> _onTrendMonthsChanged(int months) async {
    if (_trendMonths == months) return;
    setState(() {
      _trendMonths = months;
    });
    final db = DatabaseHelper.instance;
    final trendData = await db.getMonthlySpendings(
      months: months,
      categoryId: _selectedTrendCategoryId,
    );
    if (mounted) {
      setState(() {
        _trendMonthlySpendings = trendData;
      });
    }
  }

  Future<void> _selectDuration() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: Navigator.canPop(context)
          ? AppBar(
              title: const Text(
                'Spending Analytics',
                style: AppTypography.titleLarge,
              ),
            )
          : null,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.emerald700),
            )
          : _buildAnalyticsTab(isDark),
    );
  }

  // ==========================================
  // TAB 2: SPENDING ANALYTICS & CHARTS
  // ==========================================
  Widget _buildAnalyticsTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: AppColors.emerald700,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          100,
        ),
        children: [
          // Month Selector Card
          _buildMonthSelectorCard(isDark),
          const SizedBox(height: AppSpacing.lg),

          // YTD Cashflow Summary Card
          if (_isYtd) ...[
            _buildYtdSummaryCard(isDark),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Category Pie Chart
          if (_categorySpending.isNotEmpty)
            _buildCategoryDistributionCard(isDark)
          else
            CustomCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      Icon(
                        Icons.pie_chart_outline_rounded,
                        size: 40,
                        color: isDark ? AppColors.gray500 : AppColors.gray400,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No spending data logged for the selected duration',
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          // Monthly Trends Chart
          if (_monthlySpendings.isNotEmpty) _buildMonthlyTrendsCard(isDark),
          const SizedBox(height: AppSpacing.lg),

          // 2x2 Responsive Stats Grid (Overflow-proof)
          _buildSpendingStatsGrid(isDark),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  Widget _buildMonthSelectorCard(bool isDark) {
    return CustomCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBorder : AppColors.gray100,
              borderRadius: AppBorderRadius.smallBorder,
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: AppBorderRadius.smallBorder,
                    onTap: () {
                      if (_isYtd) {
                        setState(() {
                          _isYtd = false;
                          _isLoading = true;
                        });
                        unawaited(_loadAllData());
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: !_isYtd
                            ? AppColors.emerald700
                            : Colors.transparent,
                        borderRadius: AppBorderRadius.smallBorder,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Monthly Range',
                        style: AppTypography.labelMedium.copyWith(
                          color: !_isYtd
                              ? Colors.white
                              : (isDark
                                    ? AppColors.gray300
                                    : AppColors.gray700),
                          fontWeight: !_isYtd
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: AppBorderRadius.smallBorder,
                    onTap: () {
                      if (!_isYtd) {
                        setState(() {
                          _isYtd = true;
                          _isLoading = true;
                        });
                        unawaited(_loadAllData());
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: _isYtd
                            ? AppColors.emerald700
                            : Colors.transparent,
                        borderRadius: AppBorderRadius.smallBorder,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Year-to-Date (YTD)',
                        style: AppTypography.labelMedium.copyWith(
                          color: _isYtd
                              ? Colors.white
                              : (isDark
                                    ? AppColors.gray300
                                    : AppColors.gray700),
                          fontWeight: _isYtd
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isYtd ? 'Cumulative Period' : 'Spending Period',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isYtd
                          ? 'Jan 1, ${DateTime.now().year} - ${DateFormat('MMM d, yyyy').format(DateTime.now())}'
                          : '${DateFormat('MMM d, yyyy').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!_isYtd)
                IconButton(
                  tooltip: 'Change duration',
                  onPressed: _selectDuration,
                  icon: const Icon(Icons.date_range_rounded),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.emerald600.withValues(alpha: 0.12),
                    borderRadius: AppBorderRadius.pillBorder,
                  ),
                  child: Text(
                    '${DateTime.now().year} YTD',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.emerald600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYtdSummaryCard(bool isDark) {
    final inflow = _ytdCashflow['inflow'] ?? 0.0;
    final outflow = _ytdCashflow['outflow'] ?? 0.0;
    final netSavings = _ytdCashflow['netSavings'] ?? 0.0;
    final savingsRate = _ytdCashflow['savingsRate'] ?? 0.0;
    final isNetPositive = netSavings >= 0;

    return CustomCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.emerald600,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'YTD Cashflow Summary',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color:
                      (savingsRate >= 20
                              ? AppColors.emerald600
                              : (savingsRate >= 0
                                    ? AppColors.orange
                                    : AppColors.danger))
                          .withValues(alpha: 0.12),
                  borderRadius: AppBorderRadius.pillBorder,
                ),
                child: Text(
                  '${savingsRate.toStringAsFixed(1)}% Saved',
                  style: AppTypography.labelSmall.copyWith(
                    color: savingsRate >= 20
                        ? AppColors.emerald600
                        : (savingsRate >= 0
                              ? AppColors.orange
                              : AppColors.danger),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildYtdMetricItem(
                  'Inflow',
                  AppFormatters.currency(inflow),
                  AppColors.emerald600,
                  isDark,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildYtdMetricItem(
                  'Outflow',
                  AppFormatters.currency(outflow),
                  AppColors.orange,
                  isDark,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildYtdMetricItem(
                  'Net Savings',
                  AppFormatters.currency(netSavings),
                  isNetPositive ? AppColors.emerald600 : AppColors.danger,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYtdMetricItem(
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isDark ? AppColors.gray400 : AppColors.gray600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCategoryDistributionCard(bool isDark) {
    final colors = [
      AppColors.emerald700,
      AppColors.emerald500,
      AppColors.orange,
      AppColors.info,
      AppColors.purple,
      AppColors.pink,
      AppColors.warning,
      const Color(0xFF0284C7),
    ];

    final categoryEntries = _categorySpending.entries.toList();
    final visibleEntries = categoryEntries
        .where((e) => !_hiddenCategories.contains(e.key))
        .toList();

    double visibleTotal = 0.0;
    for (var v in visibleEntries) {
      visibleTotal += v.value;
    }

    final sections = visibleEntries.map((entry) {
      final originalIndex = categoryEntries.indexWhere(
        (e) => e.key == entry.key,
      );
      final percent = visibleTotal > 0
          ? (entry.value / visibleTotal) * 100
          : 0.0;
      return PieChartSectionData(
        color: colors[originalIndex % colors.length],
        value: entry.value,
        title: percent >= 4 ? '${percent.toStringAsFixed(0)}%' : '',
        radius: 50,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      );
    }).toList();

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spending by Category',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hiddenCategories.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => setState(_hiddenCategories.clear),
                      child: Text(
                        'Reset',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.emerald700,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    'Total: ${AppFormatters.currency(visibleTotal)}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.emerald700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          SizedBox(
            height: 180,
            child: sections.isNotEmpty
                ? PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 36,
                      sectionsSpace: 3,
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 36,
                          color: isDark ? AppColors.gray500 : AppColors.gray400,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'All categories hidden',
                          style: AppTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.gray400
                                : AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Tap below to restore categories',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark
                                ? AppColors.gray500
                                : AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Responsive Legend
          ...categoryEntries.asMap().entries.map((e) {
            final index = e.key;
            final entry = e.value;
            final isHidden = _hiddenCategories.contains(entry.key);
            final color = colors[index % colors.length];
            final percent = visibleTotal > 0 && !isHidden
                ? (entry.value / visibleTotal) * 100
                : 0.0;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppBorderRadius.smallBorder,
                onTap: () {
                  setState(() {
                    if (isHidden) {
                      _hiddenCategories.remove(entry.key);
                    } else {
                      _hiddenCategories.add(entry.key);
                    }
                  });
                },
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: isHidden ? 0.38 : 1.0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6.0,
                      horizontal: 4.0,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isHidden ? Colors.transparent : color,
                            border: Border.all(
                              color: isHidden
                                  ? (isDark
                                        ? AppColors.gray500
                                        : AppColors.gray400)
                                  : color,
                              width: 2,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: AppTypography.bodyMedium.copyWith(
                              decoration: isHidden
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isHidden
                                  ? (isDark
                                        ? AppColors.gray500
                                        : AppColors.gray400)
                                  : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          isHidden ? '— ' : '${percent.toStringAsFixed(1)}% ',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark
                                ? AppColors.gray400
                                : AppColors.gray600,
                          ),
                        ),
                        Text(
                          AppFormatters.currency(entry.value),
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isHidden
                                ? (isDark
                                      ? AppColors.gray500
                                      : AppColors.gray400)
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          isHidden
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 15,
                          color: isHidden
                              ? (isDark ? AppColors.gray600 : AppColors.gray400)
                              : (isDark
                                    ? AppColors.gray500
                                    : AppColors.gray400),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendsCard(bool isDark) {
    final sortedMonths = _trendMonthlySpendings.keys.toList()..sort();
    final maxSpendFromData = (_trendMonthlySpendings.values.isEmpty
        ? 1.0
        : _trendMonthlySpendings.values.reduce((a, b) => a > b ? a : b));

    double baselineBudget = 0.0;
    if (_selectedTrendCategoryId == null) {
      for (final cat in _categories) {
        if (cat.monthlyBudget != null && cat.monthlyBudget! > 0) {
          baselineBudget += cat.monthlyBudget!;
        }
      }
    } else {
      final selectedCat = _categories
          .where((c) => c.id == _selectedTrendCategoryId)
          .firstOrNull;
      baselineBudget = selectedCat?.monthlyBudget ?? 0.0;
    }

    final hasBaseline = baselineBudget > 0;
    final maxVal = baselineBudget > maxSpendFromData
        ? baselineBudget
        : maxSpendFromData;
    final maxSpending = maxVal > 0 ? maxVal * 1.25 : 1.0;

    final spots = sortedMonths.asMap().entries.map((e) {
      final index = e.key;
      final month = e.value;
      final amount = _trendMonthlySpendings[month] ?? 0.0;
      return FlSpot(index.toDouble(), amount);
    }).toList();

    final avgSpend = _trendMonthlySpendings.values.isEmpty
        ? 0.0
        : _trendMonthlySpendings.values.reduce((a, b) => a + b) /
              _trendMonthlySpendings.values.length;

    final latestMonthSpend = sortedMonths.isNotEmpty
        ? (_trendMonthlySpendings[sortedMonths.last] ?? 0.0)
        : 0.0;
    final diffFromBudget = latestMonthSpend - baselineBudget;
    final isOverBudget = hasBaseline && diffFromBudget > 0;

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Spending Trends',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!_isYtd)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [3, 6, 12].map((m) {
                    final isSelected = _trendMonths == m;
                    return GestureDetector(
                      onTap: () => _onTrendMonthsChanged(m),
                      child: Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.emerald700
                              : (isDark
                                    ? AppColors.darkSurfaceElevated
                                    : AppColors.gray200),
                          borderRadius: AppBorderRadius.smallBorder,
                        ),
                        child: Text(
                          '${m}M',
                          style: AppTypography.labelSmall.copyWith(
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                      ? AppColors.gray400
                                      : AppColors.gray700),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Controls & Baseline Indicator Row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.gray100,
                    borderRadius: AppBorderRadius.smallBorder,
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.gray300,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedTrendCategoryId,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'All Categories',
                            style: AppTypography.bodySmall,
                          ),
                        ),
                        ..._categories.map(
                          (c) => DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(
                              c.name,
                              style: AppTypography.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: _onTrendCategoryChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: (hasBaseline ? AppColors.orange : AppColors.gray500)
                      .withValues(alpha: 0.12),
                  borderRadius: AppBorderRadius.smallBorder,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 2,
                      decoration: BoxDecoration(
                        color: hasBaseline
                            ? AppColors.orange
                            : AppColors.gray400,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasBaseline
                          ? 'Cap: ${AppFormatters.compactCurrency(baselineBudget)}'
                          : 'No Cap',
                      style: AppTypography.labelSmall.copyWith(
                        color: hasBaseline
                            ? (isDark ? AppColors.gray300 : AppColors.gray700)
                            : (isDark ? AppColors.gray500 : AppColors.gray500),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Average Spend and Variance Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Avg: ${AppFormatters.currency(avgSpend)}/mo',
                style: AppTypography.labelSmall.copyWith(
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                ),
              ),
              if (hasBaseline && sortedMonths.isNotEmpty)
                Text(
                  isOverBudget
                      ? '+${AppFormatters.currency(diffFromBudget)} over budget'
                      : '${AppFormatters.currency(diffFromBudget.abs())} under budget',
                  style: AppTypography.labelSmall.copyWith(
                    color: isOverBudget
                        ? AppColors.danger
                        : AppColors.emerald600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          SizedBox(
            height: 200,
            child: spots.isNotEmpty
                ? LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: sortedMonths.isNotEmpty
                          ? (sortedMonths.length - 1).toDouble()
                          : 1.0,
                      minY: 0,
                      maxY: maxSpending,
                      extraLinesData: ExtraLinesData(
                        extraLinesOnTop: true,
                        horizontalLines: hasBaseline
                            ? [
                                HorizontalLine(
                                  y: baselineBudget,
                                  color: AppColors.orange,
                                  strokeWidth: 1.5,
                                  dashArray: [6, 4],
                                  label: HorizontalLineLabel(
                                    show: true,
                                    alignment: Alignment.topRight,
                                    padding: const EdgeInsets.only(
                                      right: 6,
                                      bottom: 2,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.orange,
                                    ),
                                    labelResolver: (line) => 'Budget',
                                  ),
                                ),
                              ]
                            : [],
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxSpending > 0
                            ? (maxSpending / 4)
                            : 1,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.gray200,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 45,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                AppFormatters.compactCurrency(value),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isDark
                                      ? AppColors.gray400
                                      : AppColors.gray600,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              if ((value - value.round()).abs() > 0.001) {
                                return const SizedBox();
                              }
                              final index = value.round();
                              if (index < 0 || index >= sortedMonths.length) {
                                return const SizedBox();
                              }
                              final m = sortedMonths[index];
                              final hasMultipleYears =
                                  sortedMonths
                                      .map((e) => e.split('-').first)
                                      .toSet()
                                      .length >
                                  1;
                              String label = m.length >= 7 ? m.substring(5) : m;
                              try {
                                final date = DateTime.parse('$m-01');
                                label = hasMultipleYears
                                    ? DateFormat("MMM ''yy").format(date)
                                    : DateFormat('MMM').format(date);
                              } catch (_) {}
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? AppColors.gray400
                                        : AppColors.gray600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppColors.emerald600,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              final spotOverBudget =
                                  hasBaseline && spot.y > baselineBudget;
                              return FlDotCirclePainter(
                                radius: 4,
                                color: spotOverBudget
                                    ? AppColors.danger
                                    : AppColors.emerald700,
                                strokeColor: Colors.white,
                                strokeWidth: 2,
                              );
                            },
                          ),
                        ),
                      ],
                      borderData: FlBorderData(show: false),
                    ),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'No spending logged for this selection',
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingStatsGrid(bool isDark) {
    final sortedAmounts = _monthlySpendings.values.toList()..sort();
    final avgSpending = sortedAmounts.isEmpty
        ? 0.0
        : sortedAmounts.reduce((a, b) => a + b) / sortedAmounts.length;

    String highestMonth = '-';
    double highestAmount = 0.0;
    for (var e in _monthlySpendings.entries) {
      if (e.value > highestAmount) {
        highestAmount = e.value;
        highestMonth = e.key;
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: CustomCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Average Monthly',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.currency(avgSpending),
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.emerald700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: CustomCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Peak Month ($highestMonth)',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.currency(highestAmount),
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.orange,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
