import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../services/database_helper.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';
import '../components/category_badge.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Analytics state
  Map<String, double> _categorySpending = {};
  Map<String, double> _monthlySpendings = {};
  String _selectedMonth = '';
  double _monthTotalSpending = 0.0;

  // History state
  List<Map<String, dynamic>> _transactions = [];
  String _searchQuery = '';
  String? _selectedCategoryFilter;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
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
    if (_transactions.isEmpty && _categorySpending.isEmpty) {
      setState(() => _isLoading = true);
    }

    final db = DatabaseHelper.instance;
    final categoryData = await db.getSpendingByCategoryForMonth(_selectedMonth);
    final monthlyData = await db.getMonthlySpendings(months: 6);
    final monthTotal = await db.getTotalSpendingForMonth(_selectedMonth);
    final transactionsData = await db.getTransactionHistory();

    if (mounted) {
      setState(() {
        _categorySpending = categoryData;
        _monthlySpendings = monthlyData;
        _monthTotalSpending = monthTotal;
        _transactions = transactionsData;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTransaction(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text(
          'This will remove the transaction and refund the money back to the account balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete & Refund',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteTransaction(id);
      _loadAllData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted & balance refunded!'),
          backgroundColor: AppColors.emerald700,
        ),
      );
    }
  }

  Future<void> _selectMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse('$_selectedMonth-01') ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateFormat('yyyy-MM').format(picked);
      });
      _loadAllData();
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
            unselectedLabelColor: isDark ? AppColors.gray400 : AppColors.gray600,
            labelStyle: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Activity Ledger'),
              Tab(icon: Icon(Icons.pie_chart_rounded, size: 18), text: 'Analytics & Trends'),
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
              children: [
                _buildLedgerTab(isDark),
                _buildAnalyticsTab(isDark),
              ],
            ),
    );
  }

  // ==========================================
  // TAB 1: SEARCHABLE TRANSACTION LEDGER
  // ==========================================
  Widget _buildLedgerTab(bool isDark) {
    // Filter transactions by search query and category
    final filtered = _transactions.where((tx) {
      final note = (tx['note'] as String? ?? '').toLowerCase();
      final category = (tx['category_name'] as String? ?? '').toLowerCase();
      final account = (tx['account_name'] as String? ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesQuery = q.isEmpty || note.contains(q) || category.contains(q) || account.contains(q);
      final matchesCategory = _selectedCategoryFilter == null ||
          tx['category_name'] == _selectedCategoryFilter;

      return matchesQuery && matchesCategory;
    }).toList();

    // Group filtered by month
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var tx in filtered) {
      final date = DateTime.tryParse(tx['date']) ?? DateTime.now();
      final monthKey = DateFormat('MMMM yyyy').format(date);
      grouped.putIfAbsent(monthKey, () => []).add(tx);
    }

    final sortedMonths = grouped.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('MMMM yyyy').parse(a);
        final dateB = DateFormat('MMMM yyyy').parse(b);
        return dateB.compareTo(dateA);
      });

    // Unique categories for filter chips
    final uniqueCategories = _transactions
        .map((e) => e['category_name'] as String?)
        .where((e) => e != null)
        .cast<String>()
        .toSet()
        .toList();

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: AppColors.emerald700,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: AppTypography.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Search by note, category, or account...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : AppColors.white,
              border: OutlineInputBorder(
                borderRadius: AppBorderRadius.mediumBorder,
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.gray200,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Category Filter Chips
          if (uniqueCategories.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedCategoryFilter == null,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCategoryFilter = null);
                    },
                    selectedColor: AppColors.emerald700,
                    labelStyle: TextStyle(
                      color: _selectedCategoryFilter == null ? Colors.white : null,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ...uniqueCategories.map((cat) {
                    final isSelected = _selectedCategoryFilter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategoryFilter = selected ? cat : null;
                          });
                        },
                        selectedColor: AppColors.emerald700,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),

          // Grouped List
          if (filtered.isEmpty)
            CustomCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 40,
                        color: isDark ? AppColors.gray500 : AppColors.gray400,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No transactions match your criteria',
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
            ...sortedMonths.map((month) {
              final txs = grouped[month]!;
              double monthSpent = 0;
              for (var t in txs) {
                monthSpent += (t['amount'] as num?)?.toDouble() ?? 0.0;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          month,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.emerald700,
                          ),
                        ),
                        Text(
                          'Total: ₹${monthSpent.toStringAsFixed(0)}',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark ? AppColors.gray400 : AppColors.gray600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...txs.map((tx) {
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
                                  '$accountName • ${DateFormat('MMM dd, yyyy').format(date)}',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '-${AppFormatters.currency(amount)}',
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: isDark ? AppColors.gray500 : AppColors.gray400,
                            ),
                            onPressed: () => _deleteTransaction(tx['id']),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            }),

          const SizedBox(height: AppSpacing.huge),
        ],
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
                        'No spending data logged for $_selectedMonth',
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
          if (_monthlySpendings.isNotEmpty)
            _buildMonthlyTrendsCard(isDark),
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
          Column(
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
                _selectedMonth,
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _selectMonth,
            icon: const Icon(Icons.calendar_month_rounded, size: 16),
            label: const Text('Change Month'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.emerald700,
              shape: RoundedRectangleBorder(
                borderRadius: AppBorderRadius.mediumBorder,
              ),
            ),
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

    final sections = _categorySpending.entries.toList().asMap().entries.map((e) {
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
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
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
            style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
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
                            color: isDark ? AppColors.gray400 : AppColors.gray600,
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
                              color: isDark ? AppColors.gray400 : AppColors.gray600,
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
