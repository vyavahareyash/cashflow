import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, double> _categorySpending = {};
  Map<String, double> _monthlySpendings = {};
  bool _isLoading = true;
  String _selectedMonth = '';

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final categoryData =
        await DatabaseHelper.instance.getSpendingByCategoryForMonth(
      _selectedMonth,
    );
    final monthlyData = await DatabaseHelper.instance.getMonthlySpendings();

    setState(() {
      _categorySpending = categoryData;
      _monthlySpendings = monthlyData;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Spending Analytics',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  _buildMonthSelector(),
                  const SizedBox(height: 32),
                  if (_categorySpending.isNotEmpty)
                    _buildCategoryPieChart()
                  else
                    const Center(
                      child: Text('No spending data for selected month'),
                    ),
                  const SizedBox(height: 40),
                  if (_monthlySpendings.isNotEmpty)
                    _buildMonthlyTrendsChart()
                  else
                    const Center(
                      child: Text('No monthly data available'),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthSelector() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Month',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _selectMonth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green.shade700),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_selectedMonth),
                          Icon(
                            Icons.calendar_today,
                            color: Colors.green.shade700,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                  ),
                  child: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse('$_selectedMonth-01'),
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateFormat('yyyy-MM').format(picked);
      });
      await _loadData();
    }
  }

  Widget _buildCategoryPieChart() {
    final colors = [
      Colors.green.shade700,
      Colors.green.shade600,
      Colors.green.shade500,
      Colors.green.shade400,
      Colors.green.shade300,
      Colors.amber.shade600,
      Colors.amber.shade500,
    ];

    final sections = _categorySpending.entries.toList().asMap().entries.map((e) {
      final index = e.key;
      final entry = e.value;
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: entry.value,
        title: '${entry.value.toStringAsFixed(0)}',
        radius: 60,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spending by Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 0,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildCategoryLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryLegend() {
    final colors = [
      Colors.green.shade700,
      Colors.green.shade600,
      Colors.green.shade500,
      Colors.green.shade400,
      Colors.green.shade300,
      Colors.amber.shade600,
      Colors.amber.shade500,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _categorySpending.entries.toList().asMap().entries.map((e) {
        final index = e.key;
        final entry = e.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colors[index % colors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(entry.key),
              ),
              Text(
                '\$${entry.value.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthlyTrendsChart() {
    final sortedMonths = _monthlySpendings.keys.toList()..sort();
    final maxSpending = (_monthlySpendings.values.isEmpty
        ? 0.0
        : _monthlySpendings.values.reduce((a, b) => a > b ? a : b));

    final spots = sortedMonths.asMap().entries.map((e) {
      final index = e.key;
      final month = e.value;
      final amount = _monthlySpendings[month] ?? 0.0;
      return FlSpot(index.toDouble(), amount);
    }).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Spending Trends',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxSpending / 5,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '\$${(value / 1000).toStringAsFixed(1)}k',
                            style: const TextStyle(fontSize: 10),
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
                            return Text(
                              sortedMonths[index].substring(5),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.green.shade700,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: Colors.green.shade700,
                          strokeWidth: 0,
                        ),
                      ),
                    ),
                  ],
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      left: BorderSide(color: Colors.green.shade700),
                      bottom: BorderSide(color: Colors.green.shade700),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildTrendStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendStats() {
    final sortedAmounts = _monthlySpendings.values.toList()..sort();
    final avgSpending = sortedAmounts.isEmpty
        ? 0.0
        : sortedAmounts.reduce((a, b) => a + b) / sortedAmounts.length;
    final maxMonth = _monthlySpendings.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    final minMonth = _monthlySpendings.entries
        .reduce((a, b) => a.value < b.value ? a : b)
        .key;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Average Monthly',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '\$${avgSpending.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Highest Month',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '$maxMonth',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lowest Month',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '$minMonth',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
