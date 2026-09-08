import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../services/database_helper.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';
import 'history_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, double> _categorySpending = {};
  Map<String, double> _monthlySpendings = {};
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final today = DateTime.now();
    _startDate = DateTime(today.year, today.month, 1);
    _endDate = today;
    _loadAllData();
    DatabaseHelper.dataRevision.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    DatabaseHelper.dataRevision.removeListener(_onDataChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    if (_categorySpending.isEmpty) {
      setState(() => _isLoading = true);
    }

    final db = DatabaseHelper.instance;
    final categoryData = await db.getSpendingByCategoryForDateRange(
      startDate: _startDate,
      endDate: _endDate,
    );
    final monthlyData = await db.getMonthlySpendings(months: 6);
    if (mounted) {
      setState(() {
        _categorySpending = categoryData;
        _monthlySpendings = monthlyData;
        _isLoading = false;
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.emerald600,
            indicatorWeight: 3,
            labelColor: isDark ? AppColors.emerald400 : AppColors.emerald700,
            unselectedLabelColor: isDark
                ? AppColors.gray400
                : AppColors.gray600,
            tabs: const [
              Tab(
                icon: Icon(Icons.receipt_long_rounded, size: 18),
                text: 'Activity Ledger',
              ),
              Tab(
                icon: Icon(Icons.pie_chart_rounded, size: 18),
                text: 'Analytics & Trends',
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.emerald700),
            )
          : TabBarView(
              controller: _tabController,
              children: [const HistoryScreen(), _buildAnalyticsTab(isDark)],
            ),
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Month Selector Card
          _buildMonthSelectorCard(isDark),
          const SizedBox(height: AppSpacing.lg),

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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spending Period',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('MMM d, yyyy').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Change duration',
            onPressed: _selectDuration,
            icon: const Icon(Icons.date_range_rounded),
          ),
        ],
      ),
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
      Color(0xFF0284C7),
    ];

    double total = 0.0;
    for (var v in _categorySpending.values) {
      total += v;
    }

    final sections = _categorySpending.entries.toList().asMap().entries.map((
      e,
    ) {
      final index = e.key;
      final entry = e.value;
      final percent = total > 0 ? (entry.value / total) * 100 : 0.0;
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: entry.value,
        title: '${percent.toStringAsFixed(0)}%',
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
              Text(
                'Total: ${AppFormatters.currency(total)}',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.emerald700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 36,
                sectionsSpace: 3,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Responsive Legend
          ..._categorySpending.entries.toList().asMap().entries.map((e) {
            final index = e.key;
            final entry = e.value;
            final color = colors[index % colors.length];
            final percent = total > 0 ? (entry.value / total) * 100 : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: AppTypography.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${percent.toStringAsFixed(1)}% ',
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                    ),
                  ),
                  Text(
                    AppFormatters.currency(entry.value),
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendsCard(bool isDark) {
    final sortedMonths = _monthlySpendings.keys.toList()..sort();
    final maxSpending = (_monthlySpendings.values.isEmpty
        ? 1.0
        : _monthlySpendings.values.reduce((a, b) => a > b ? a : b));

    final spots = sortedMonths.asMap().entries.map((e) {
      final index = e.key;
      final month = e.value;
      final amount = _monthlySpendings[month] ?? 0.0;
      return FlSpot(index.toDouble(), amount);
    }).toList();

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Spending Trends',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxSpending > 0 ? (maxSpending / 4) : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? AppColors.darkBorder : AppColors.gray200,
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
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < sortedMonths.length) {
                          final m = sortedMonths[index];
                          return Text(
                            m.length >= 7 ? m.substring(5) : m,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.gray400
                                  : AppColors.gray600,
                            ),
                          );
                        }
                        return const SizedBox();
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
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 4,
                            color: AppColors.emerald700,
                            strokeColor: Colors.white,
                            strokeWidth: 2,
                          ),
                    ),
                  ),
                ],
                borderData: FlBorderData(show: false),
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
