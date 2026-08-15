import 'package:flutter/material.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Budgets',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Total Reserved: \$800.00', // This ties back to your Usable Balance logic
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 25),

          // We use an Expanded widget here so the list can scroll
          Expanded(
            child: ListView(
              children: [
                _buildBudgetItem('Groceries', 120.0, 300.0, Colors.orange),
                _buildBudgetItem('Transport', 45.0, 100.0, Colors.blue),
                _buildBudgetItem('Entertainment', 180.0, 200.0, Colors.purple),
                _buildBudgetItem(
                  'Dining Out',
                  210.0,
                  200.0,
                  Colors.red,
                ), // Over budget example
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build a Budget Row
  Widget _buildBudgetItem(
    String category,
    double spent,
    double budget,
    Color color,
  ) {
    // Calculate percentage for the progress bar (0.0 to 1.0)
    double progress = spent / budget;

    // Change color to red if spending exceeds budget
    Color barColor = progress > 1.0 ? Colors.red : color;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${spent.toStringAsFixed(0)} / \$${budget.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // --- THE PROGRESS BAR ---
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress > 1.0
                    ? 1.0
                    : progress, // Cap at 1.0 for the visual bar
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),

            const SizedBox(height: 8),

            // Show a warning if over budget
            if (progress > 1.0)
              const Text(
                'Over budget!',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
