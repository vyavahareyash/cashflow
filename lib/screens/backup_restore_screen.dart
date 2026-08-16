import 'package:flutter/material.dart';
import 'package:cashflow/services/database_helper.dart';

import '../theme/theme_constants.dart';
import '../components/custom_card.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isProcessing = false;
  String _statusMessage = '';
  int _accountsCount = 0;
  int _categoriesCount = 0;
  int _plansCount = 0;
  int _transactionsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final db = DatabaseHelper.instance;
      final accounts = await db.readAllAccounts();
      final categories = await db.readAllCategories();
      final plans = await db.readAllPlans();
      final transactions = await db.getTransactionHistory();

      if (mounted) {
        setState(() {
          _accountsCount = accounts.length;
          _categoriesCount = categories.length;
          _plansCount = plans.length;
          _transactionsCount = transactions.length;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleExport() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Exporting database...';
    });

    final path = await DatabaseHelper.instance.exportDatabase();

    setState(() {
      _isProcessing = false;
      _statusMessage = path != null
          ? 'Backup exported successfully to:\n$path'
          : 'Export cancelled or failed';
    });
    _loadStats();
  }

  Future<void> _handleImport() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Importing database...';
    });

    final success = await DatabaseHelper.instance.importDatabase();

    setState(() {
      _isProcessing = false;
      _statusMessage = success
          ? 'Database imported successfully! Please refresh screens.'
          : 'Import cancelled or failed';
    });
    _loadStats();
  }

  Future<void> _handleExportJSON() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Exporting JSON backup...';
    });

    final path = await DatabaseHelper.instance.exportDatabaseAsJSON();

    setState(() {
      _isProcessing = false;
      _statusMessage = path != null
          ? 'JSON exported successfully to:\n$path'
          : 'JSON export cancelled';
    });
    _loadStats();
  }

  Future<void> _handleImportJSON() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Importing JSON...';
    });

    final success = await DatabaseHelper.instance.importDatabaseFromJSON();

    setState(() {
      _isProcessing = false;
      _statusMessage = success
          ? 'JSON imported successfully!'
          : 'JSON import cancelled or failed';
    });
    _loadStats();
  }

  Future<void> _handleExportCSV() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Exporting CSV transactions...';
    });

    final path = await DatabaseHelper.instance.exportTransactionsAsCSV();

    setState(() {
      _isProcessing = false;
      _statusMessage = path != null
          ? 'CSV exported successfully to:\n$path'
          : 'CSV export cancelled';
    });
    _loadStats();
  }

  Future<void> _handleSeedDemoData() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Populate Sample Demo Finances?'),
        content: const Text(
          'This will reset your current local data and load a rich set of realistic accounts, monthly budgets, sinking funds, and transactions to test all features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Load Demo Data'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Populating sample finances...';
      });

      try {
        await DatabaseHelper.instance.seedSampleData();
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Sample finances populated successfully!';
        });
        _loadStats();
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Failed to load sample data: $e';
        });
      }
    }
  }

  Future<void> _handleReset() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
            SizedBox(width: 8),
            Text('Reset All Data?'),
          ],
        ),
        content: const Text(
          'This will permanently delete all accounts, transactions, budget categories, and sinking funds from your device.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Erase Everything'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Resetting database...';
      });

      try {
        await DatabaseHelper.instance.resetDatabase();
        await DatabaseHelper.instance.seedDatabase();
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Database reset successfully!';
        });
        _loadStats();
      } catch (e) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Reset failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Data', style: AppTypography.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        children: [
          // 1. PRIVACY HERO CARD
          _buildPrivacyHeroCard(isDark),
          const SizedBox(height: AppSpacing.xl),

          // 2. LOCAL STORAGE SNAPSHOT
          _buildSectionHeader('Storage & Record Count', isDark),
          const SizedBox(height: AppSpacing.xs),
          _buildStorageOverviewCard(isDark),
          const SizedBox(height: AppSpacing.xl),

          // 3. BACKUP & EXPORT ACTIONS
          _buildSectionHeader('Backup & Data Portability', isDark),
          const SizedBox(height: AppSpacing.xs),
          _buildBackupGroupCard(isDark),
          const SizedBox(height: AppSpacing.xl),

          // 4. DEMO DATA GENERATOR
          _buildSectionHeader('Demo & Testing', isDark),
          const SizedBox(height: AppSpacing.xs),
          _buildDemoDataCard(isDark),
          const SizedBox(height: AppSpacing.xxl),

          // 5. DANGER ZONE
          _buildSectionHeader('Danger Zone', isDark, isDanger: true),
          const SizedBox(height: AppSpacing.xs),
          _buildDangerZoneCard(isDark),
          const SizedBox(height: AppSpacing.xl),

          // Status message indicator
          if (_statusMessage.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.emerald50,
                border: Border.all(
                  color: AppColors.emerald500.withOpacity(0.3),
                ),
                borderRadius: AppBorderRadius.mediumBorder,
              ),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.emerald400 : AppColors.emerald800,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // 6. APP INFO & SYSTEM FOOTER
          _buildSectionHeader('System & About', isDark),
          const SizedBox(height: AppSpacing.xs),
          _buildAboutSystemCard(isDark),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark, {bool isDanger = false}) {
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

  // --- 1. PRIVACY HERO CARD ---
  Widget _buildPrivacyHeroCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF064E3B),
            Color(0xFF047857),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppBorderRadius.largeBorder,
        boxShadow: const [AppShadows.level1],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '100% Local & Offline',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your financial data never leaves this device. No servers, trackers, or cloud subscriptions.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. STORAGE OVERVIEW CARD ---
  Widget _buildStorageOverviewCard(bool isDark) {
    return CustomCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStorageStat('Accounts', '$_accountsCount', Icons.account_balance_rounded, isDark),
          _buildDivider(isDark),
          _buildStorageStat('Budgets', '$_categoriesCount', Icons.pie_chart_rounded, isDark),
          _buildDivider(isDark),
          _buildStorageStat('Goals', '$_plansCount', Icons.savings_rounded, isDark),
          _buildDivider(isDark),
          _buildStorageStat('Transactions', '$_transactionsCount', Icons.receipt_long_rounded, isDark),
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

  Widget _buildStorageStat(String label, String count, IconData icon, bool isDark) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.emerald600),
        const SizedBox(height: 4),
        Text(
          count,
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
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

  // --- 3. BACKUP GROUP CARD ---
  Widget _buildBackupGroupCard(bool isDark) {
    return CustomCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.storage_rounded,
            iconColor: AppColors.emerald700,
            title: 'Export SQLite Database (.db)',
            subtitle: 'Complete exact binary database backup',
            onTap: _isProcessing ? null : _handleExport,
            isDark: isDark,
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.restore_page_rounded,
            iconColor: AppColors.info,
            title: 'Import SQLite Database (.db)',
            subtitle: 'Restore database from previous .db file',
            onTap: _isProcessing ? null : _handleImport,
            isDark: isDark,
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.data_object_rounded,
            iconColor: AppColors.purple,
            title: 'Export as JSON',
            subtitle: 'Human-readable structured data backup',
            onTap: _isProcessing ? null : _handleExportJSON,
            isDark: isDark,
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.file_upload_rounded,
            iconColor: AppColors.orange,
            title: 'Import from JSON',
            subtitle: 'Restore categories, accounts & transactions',
            onTap: _isProcessing ? null : _handleImportJSON,
            isDark: isDark,
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.table_chart_rounded,
            iconColor: AppColors.pink,
            title: 'Export Transactions as CSV',
            subtitle: 'Open in Excel, Google Sheets, or Numbers',
            onTap: _isProcessing ? null : _handleExportCSV,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: AppBorderRadius.smallBorder,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.labelSmall.copyWith(
          color: isDark ? AppColors.gray400 : AppColors.gray600,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppColors.gray400,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
    );
  }

  // --- 4. DEMO DATA CARD ---
  Widget _buildDemoDataCard(bool isDark) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.emerald500.withOpacity(0.12),
                  borderRadius: AppBorderRadius.smallBorder,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.emerald600,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Load Sample Financial Data',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Quickly test charts, budget pace, and goals',
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
          Text(
            'Populates sample HDFC & SBI accounts, categorized expenses (Groceries, Dining, Fuel, Utilities), and sinking fund goals.',
            style: AppTypography.bodyMedium.copyWith(
              color: isDark ? AppColors.gray300 : AppColors.gray700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: AppComponentSizes.buttonHeightMedium,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _handleSeedDemoData,
              icon: const Icon(Icons.dataset_rounded, size: 18),
              label: const Text('Populate Sample Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.emerald900.withOpacity(0.6) : AppColors.emerald50,
                foregroundColor: isDark ? AppColors.emerald300 : AppColors.emerald800,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppBorderRadius.mediumBorder,
                  side: BorderSide(
                    color: isDark ? AppColors.emerald700 : AppColors.emerald200,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. DANGER ZONE CARD ---
  Widget _buildDangerZoneCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF200E11) : const Color(0xFFFFF1F2),
        borderRadius: AppBorderRadius.largeBorder,
        border: Border.all(
          color: isDark ? AppColors.danger.withOpacity(0.4) : const Color(0xFFFECDD3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs + 2),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'Erase All Local Data',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Permanently deletes all bank balances, sinking fund goals, monthly budgets, and transaction ledgers from this device.',
            style: TextStyle(
              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: AppComponentSizes.buttonHeightMedium,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _handleReset,
              icon: const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.white),
              label: const Text(
                'Reset All App Data',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppBorderRadius.mediumBorder,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 6. ABOUT & SYSTEM INFO CARD ---
  Widget _buildAboutSystemCard(bool isDark) {
    return CustomCard(
      child: Column(
        children: [
          _buildInfoRow('Application', 'Cashflow', isDark),
          const Divider(height: 16),
          _buildInfoRow('Version', '1.0.0 (Build 1)', isDark),
          const Divider(height: 16),
          _buildInfoRow('Storage Engine', 'SQLite (Local-First)', isDark),
          const Divider(height: 16),
          _buildInfoRow('Default Currency', '₹ INR (Indian Rupee)', isDark),
          const Divider(height: 16),
          _buildInfoRow('Balance Logic', 'Usable = Total - Locked - Budget', isDark, isAccent: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {bool isAccent = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isDark ? AppColors.gray400 : AppColors.gray600,
          ),
        ),
        Text(
          value,
          style: AppTypography.labelSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: isAccent ? AppColors.emerald700 : (isDark ? AppColors.darkText : AppColors.gray900),
          ),
        ),
      ],
    );
  }
}
