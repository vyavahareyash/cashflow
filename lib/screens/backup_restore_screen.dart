import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:cashflow/services/backup_platform.dart';
import 'package:cashflow/services/database_helper.dart';

import '../models/salary_cycle.dart';
import '../theme/theme_constants.dart';
import '../components/custom_card.dart';

enum ExportFormat {
  sqlite,
  json,
  csv,
}

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
  int _goalsCount = 0;
  int _transactionsCount = 0;
  int _salaryDay = 1;
  String? _lastBackupTimestamp;
  String _defaultBackupDirectory = '';
  String _effectiveBackupDirectory = '';

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
      final goals = await db.readAllGoals();
      final transactions = await db.getTransactionHistory();
      final salaryDay = await db.getSalaryDay();
      final lastBackup = await db.getLastBackupTimestamp();
      final defaultDir = kIsWeb ? '' : await db.getDefaultBackupDirectory();
      final effectiveDir = await db.getEffectiveBackupDirectory();

      if (mounted) {
        setState(() {
          _accountsCount = accounts.length;
          _categoriesCount = categories.length;
          _goalsCount = goals.length;
          _transactionsCount = transactions.length;
          _salaryDay = salaryDay;
          _lastBackupTimestamp = lastBackup;
          _defaultBackupDirectory = defaultDir;
          _effectiveBackupDirectory = effectiveDir;
        });
      }
    } catch (_) {}
  }

  String _formatBackupFreshness(String? isoString) {
    if (isoString == null || isoString.isEmpty) {
      return 'Never backed up';
    }
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return 'Never backed up';

    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? "minute" : "minutes"} ago';
    } else if (difference.inHours < 24 && now.day == dt.day) {
      final hrs = difference.inHours;
      return '$hrs ${hrs == 1 ? "hour" : "hours"} ago';
    } else if (difference.inDays == 1 ||
        (difference.inHours < 48 && now.day != dt.day)) {
      return 'Yesterday at ${DateFormat("h:mm a").format(dt)}';
    } else {
      return DateFormat('MMM d, yyyy • h:mm a').format(dt);
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

  String _formatDayOrdinal(int day) {
    return '$day${_getDaySuffix(day)}';
  }

  Future<void> _updateSalaryDay(int newDay) async {
    final clamped = newDay.clamp(1, 31);
    await DatabaseHelper.instance.setSalaryDay(clamped);
    if (mounted) {
      setState(() {
        _salaryDay = clamped;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Salary payday set to ${_formatDayOrdinal(clamped)} of the month'),
          backgroundColor: AppColors.emerald700,
          duration: const Duration(seconds: 2),
        ),
      );
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

  Future<void> _showExportDialog(bool isDark) async {
    final db = DatabaseHelper.instance;
    final defaultDir = _defaultBackupDirectory.isNotEmpty
        ? _defaultBackupDirectory
        : (kIsWeb ? '' : await db.getDefaultBackupDirectory());
    final selectedDirectory = _effectiveBackupDirectory.isNotEmpty
        ? _effectiveBackupDirectory
        : (kIsWeb ? '' : await db.getEffectiveBackupDirectory());

    if (!mounted) return;

    final result = await showDialog<({ExportFormat format, String directory, String fileName})>(
      context: context,
      builder: (dialogCtx) => _ExportBackupDialog(
        isDark: isDark,
        defaultDirectory: defaultDir,
        initialDirectory: selectedDirectory,
      ),
    );

    if (result != null) {
      if (!kIsWeb) {
        if (result.directory == defaultDir) {
          await DatabaseHelper.instance.setCustomBackupPath(null);
        } else {
          await DatabaseHelper.instance.setCustomBackupPath(result.directory);
        }
      }
      await _executeExport(result.format, result.directory, result.fileName);
    }
  }

  Future<void> _executeExport(
    ExportFormat format,
    String directory,
    String fileName,
  ) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Exporting ${format.name.toUpperCase()}...';
    });

    String? path;
    switch (format) {
      case ExportFormat.sqlite:
        path = await DatabaseHelper.instance.exportDatabase(
          destinationDirectory: directory.isEmpty ? null : directory,
          fileName: fileName,
        );
        break;
      case ExportFormat.json:
        path = await DatabaseHelper.instance.exportDatabaseAsJSON(
          destinationDirectory: directory.isEmpty ? null : directory,
          fileName: fileName,
        );
        break;
      case ExportFormat.csv:
        path = await DatabaseHelper.instance.exportTransactionsAsCSV(
          destinationDirectory: directory.isEmpty ? null : directory,
          fileName: fileName,
        );
        break;
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _statusMessage = path != null
            ? 'Backup exported successfully to:\n$path'
            : 'Export cancelled or failed';
      });
      _showFeedback(
        path != null
            ? '${format.name.toUpperCase()} exported successfully!'
            : 'Export cancelled or failed',
        isError: path == null,
      );
    }
    _loadStats();
  }

  Future<void> _showImportDialog(bool isDark) async {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
        title: Text(
          'Import & Restore Data',
          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select the backup file format you want to restore:',
              style: AppTypography.labelSmall.copyWith(
                color: isDark ? AppColors.gray400 : AppColors.gray600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!kIsWeb) ...[
              _buildDialogOptionTile(
                icon: Icons.storage_rounded,
                iconColor: AppColors.emerald700,
                title: 'SQLite Database (.db)',
                subtitle: 'Full binary database restore',
                isDark: isDark,
                onTap: () {
                  Navigator.of(dialogCtx).pop();
                  _handleImport();
                },
              ),
              const Divider(height: 1),
            ],
            _buildDialogOptionTile(
              icon: Icons.data_object_rounded,
              iconColor: AppColors.purple,
              title: 'JSON Backup (.json)',
              subtitle: 'Restore accounts, categories & transactions',
              isDark: isDark,
              onTap: () {
                Navigator.of(dialogCtx).pop();
                _handleImportJSON();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: AppBorderRadius.smallBorder,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: AppTypography.labelLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.gray900,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.labelSmall.copyWith(
            color: isDark ? AppColors.gray400 : AppColors.gray600,
            fontSize: 11,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: AppColors.gray400,
        ),
      ),
    );
  }

  Future<void> _handleImport() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Importing database...';
    });

    final success = await DatabaseHelper.instance.importDatabase();

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _statusMessage = success
            ? 'Database imported successfully! Please refresh screens.'
            : 'Import cancelled or failed';
      });
      _showFeedback(
        success
            ? 'Database imported successfully! Screens updated.'
            : 'Import cancelled or failed',
        isError: !success,
      );
    }
    _loadStats();
  }

  Future<void> _handleImportJSON() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Importing JSON...';
    });

    final success = await DatabaseHelper.instance.importDatabaseFromJSON();

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _statusMessage = success
            ? 'JSON imported successfully!'
            : 'JSON import cancelled or failed';
      });
      _showFeedback(
        success
            ? 'JSON data imported successfully!'
            : 'JSON import cancelled or failed',
        isError: !success,
      );
    }
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
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = 'Sample finances populated successfully!';
          });
          _showFeedback('Sample finances populated successfully!');
        }
        _loadStats();
      } catch (e) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = 'Failed to load sample data: $e';
          });
          _showFeedback('Failed to load sample data: $e', isError: true);
        }
      }
    }
  }

  Future<void> _handleReset() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 24,
            ),
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
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = 'Database reset successfully!';
          });
          _showFeedback('Database reset successfully!');
        }
        _loadStats();
      } catch (e) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = 'Reset failed: $e';
          });
          _showFeedback('Reset failed: $e', isError: true);
        }
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

          // 2. FINANCIAL & CYCLE PREFERENCES
          _buildSectionHeader('Financial & Cycle Preferences', isDark),
          const SizedBox(height: AppSpacing.xs),
          _buildSalaryPreferencesCard(isDark),
          const SizedBox(height: AppSpacing.xl),

          // 3. LOCAL STORAGE SNAPSHOT
          _buildSectionHeader('Storage & Record Count', isDark),
          const SizedBox(height: AppSpacing.xs),
          _buildStorageOverviewCard(isDark),
          const SizedBox(height: AppSpacing.xl),

          // 3. BACKUP & EXPORT ACTIONS
          _buildSectionHeader('Backup & Data Portability', isDark),
          const SizedBox(height: AppSpacing.xs),
          _buildBackupGroupCard(isDark),
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              key: const Key('backup_status_message_banner'),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceElevated
                    : AppColors.emerald50,
                border: Border.all(
                  color: AppColors.emerald500.withValues(alpha: 0.3),
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
          ],
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

          // 6. APP INFO & SYSTEM FOOTER
          _buildSectionHeader('System & About', isDark),
          const SizedBox(height: AppSpacing.xs),
          _buildAboutSystemCard(isDark),
          const SizedBox(height: AppSpacing.huge),
        ],
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

  // --- 1. PRIVACY HERO CARD ---
  Widget _buildPrivacyHeroCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF047857)],
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
              color: Colors.white.withValues(alpha: 0.18),
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
                    color: Colors.white.withValues(alpha: 0.85),
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

  // --- 2. SALARY & CYCLE PREFERENCES CARD ---
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
                    Text('Salary & Payday Preferences', style: AppTypography.titleMedium),
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
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.gray50,
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
                        Row(
                          children: [
                            Text(
                              'Day $_salaryDay of month',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_salaryDay == 1) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.emerald500.withValues(alpha: 0.15),
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
                              ),
                            ] else if (_salaryDay >= 28) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.gray500.withValues(alpha: 0.15),
                                  borderRadius: AppBorderRadius.pillBorder,
                                ),
                                child: Text(
                                  _salaryDay == 31 ? 'Month-End' : 'Near End',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: isDark ? AppColors.gray300 : AppColors.gray700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cycle.resetCountdownText,
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark ? AppColors.gray400 : AppColors.gray600,
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
                // Drag handle
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

                // Header
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

                // 7-column grid of days 1 to 31
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 31,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                          _updateSalaryDay(day);
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

                // Info note
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
    );
  }

  // --- 3. STORAGE OVERVIEW CARD ---
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

  // --- 3. BACKUP GROUP CARD ---
  Widget _buildBackupGroupCard(bool isDark) {
    final freshnessText = _formatBackupFreshness(_lastBackupTimestamp);
    final hasBackup =
        _lastBackupTimestamp != null && _lastBackupTimestamp!.isNotEmpty;

    return CustomCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Backup Freshness Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: (hasBackup ? AppColors.emerald600 : AppColors.gray500)
                  .withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: const BorderRadius.vertical(
                top: AppBorderRadius.large,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasBackup ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  size: 20,
                  color: hasBackup
                      ? AppColors.emerald600
                      : (isDark ? AppColors.gray400 : AppColors.gray500),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backup Status',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        hasBackup
                            ? 'Last backup: $freshnessText'
                            : 'No backups created yet',
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: hasBackup
                              ? (isDark
                                  ? AppColors.emerald400
                                  : AppColors.emerald800)
                              : (isDark ? AppColors.gray400 : AppColors.gray600),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: (hasBackup ? AppColors.emerald600 : AppColors.gray500)
                        .withValues(alpha: 0.15),
                    borderRadius: AppBorderRadius.pillBorder,
                  ),
                  child: Text(
                    hasBackup ? 'Active' : 'Unsaved',
                    style: AppTypography.labelSmall.copyWith(
                      color: hasBackup
                          ? AppColors.emerald600
                          : (isDark ? AppColors.gray400 : AppColors.gray600),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_isProcessing)
            const LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.transparent,
              color: AppColors.emerald600,
            ),
          _buildSettingsTile(
            icon: Icons.file_download_outlined,
            iconColor: AppColors.emerald700,
            title: 'Export Data & Backups',
            subtitle: kIsWeb
                ? 'Export as JSON or CSV spreadsheet'
                : 'Export as SQLite (.db), JSON, or CSV spreadsheet',
            onTap: _isProcessing ? null : () => _showExportDialog(isDark),
            isDark: isDark,
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.file_upload_outlined,
            iconColor: AppColors.info,
            title: 'Import & Restore Data',
            subtitle: kIsWeb
                ? 'Restore categories, accounts & transactions from JSON'
                : 'Restore from SQLite (.db) or JSON backup',
            onTap: _isProcessing ? null : () => _showImportDialog(isDark),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    Key? key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        key: key,
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
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
                  color: AppColors.emerald500.withValues(alpha: 0.12),
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
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
            'Populates sample HDFC & SBI accounts, income, transfers, categorized expenses, goal activity, and history across multiple months.',
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
                backgroundColor: isDark
                    ? AppColors.emerald900.withValues(alpha: 0.6)
                    : AppColors.emerald50,
                foregroundColor: isDark
                    ? AppColors.emerald300
                    : AppColors.emerald800,
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
          color: isDark
              ? AppColors.danger.withValues(alpha: 0.4)
              : const Color(0xFFFECDD3),
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
                  color: AppColors.danger.withValues(alpha: 0.15),
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
              icon: const Icon(
                Icons.delete_forever_rounded,
                size: 18,
                color: Colors.white,
              ),
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
          _buildInfoRow('Version', '3.0.0 (Build 7)', isDark),
          const Divider(height: 16),
          _buildInfoRow('Storage Engine', 'SQLite (Local-First)', isDark),
          const Divider(height: 16),
          _buildInfoRow('Default Currency', '₹ INR (Indian Rupee)', isDark),
          const Divider(height: 16),
          _buildInfoRow(
            'Balance Logic',
            'Usable = Total - Locked goals',
            isDark,
            isAccent: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    bool isDark, {
    bool isAccent = false,
  }) {
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
            color: isAccent
                ? AppColors.emerald700
                : (isDark ? AppColors.darkText : AppColors.gray900),
          ),
        ),
      ],
    );
  }
}

class _ExportBackupDialog extends StatefulWidget {
  final bool isDark;
  final String defaultDirectory;
  final String initialDirectory;

  const _ExportBackupDialog({
    required this.isDark,
    required this.defaultDirectory,
    required this.initialDirectory,
  });

  @override
  State<_ExportBackupDialog> createState() => _ExportBackupDialogState();
}

class _ExportBackupDialogState extends State<_ExportBackupDialog> {
  late ExportFormat _selectedFormat;
  late String _selectedDirectory;
  late TextEditingController _fileNameController;

  @override
  void initState() {
    super.initState();
    _selectedFormat = kIsWeb ? ExportFormat.json : ExportFormat.sqlite;
    _selectedDirectory = widget.initialDirectory;
    _fileNameController = TextEditingController(
      text: _getDefaultName(_selectedFormat),
    );
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  String _getDefaultName(ExportFormat fmt) {
    switch (fmt) {
      case ExportFormat.sqlite:
        return 'cashflow_backup.db';
      case ExportFormat.json:
        return 'cashflow_backup.json';
      case ExportFormat.csv:
        return 'cashflow_transactions.csv';
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveName = _fileNameController.text.trim().isEmpty
        ? _getDefaultName(_selectedFormat)
        : _fileNameController.text.trim();
    final previewPath = kIsWeb
        ? effectiveName
        : p.join(_selectedDirectory, effectiveName);

    return AlertDialog(
      backgroundColor: widget.isDark ? AppColors.darkSurface : AppColors.white,
      title: Text(
        'Export Data & Backups',
        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose File Format',
              style: AppTypography.labelSmall.copyWith(
                color: widget.isDark ? AppColors.gray400 : AppColors.gray600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (!kIsWeb) ...[
              _buildOptionCard(
                title: 'SQLite Database (.db)',
                subtitle: 'Full binary database backup & restore',
                icon: Icons.storage_rounded,
                iconColor: AppColors.emerald700,
                isSelected: _selectedFormat == ExportFormat.sqlite,
                isDark: widget.isDark,
                onTap: () {
                  setState(() {
                    _selectedFormat = ExportFormat.sqlite;
                    _fileNameController.text = _getDefaultName(ExportFormat.sqlite);
                  });
                },
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            _buildOptionCard(
              title: 'JSON Backup (.json)',
              subtitle: 'Portable structured accounts & transactions',
              icon: Icons.data_object_rounded,
              iconColor: AppColors.purple,
              isSelected: _selectedFormat == ExportFormat.json,
              isDark: widget.isDark,
              onTap: () {
                setState(() {
                  _selectedFormat = ExportFormat.json;
                  _fileNameController.text = _getDefaultName(ExportFormat.json);
                });
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            _buildOptionCard(
              title: 'Transactions CSV (.csv)',
              subtitle: 'Spreadsheet format for Excel & Google Sheets',
              icon: Icons.table_chart_rounded,
              iconColor: AppColors.pink,
              isSelected: _selectedFormat == ExportFormat.csv,
              isDark: widget.isDark,
              onTap: () {
                setState(() {
                  _selectedFormat = ExportFormat.csv;
                  _fileNameController.text = _getDefaultName(ExportFormat.csv);
                });
              },
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Destination Directory',
                style: AppTypography.labelSmall.copyWith(
                  color: widget.isDark ? AppColors.gray400 : AppColors.gray600,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.gray100,
                  borderRadius: AppBorderRadius.smallBorder,
                  border: Border.all(
                    color: widget.isDark ? AppColors.gray700 : AppColors.gray300,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedDirectory,
                        key: const Key('export_destination_directory_text'),
                        style: AppTypography.labelSmall.copyWith(
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      key: const Key('export_browse_directory_button'),
                      icon: const Icon(Icons.folder_open_rounded, size: 20),
                      tooltip: 'Browse Directory',
                      onPressed: () async {
                        final picked = await pickBackupDirectory(
                          initialDirectory: _selectedDirectory,
                        );
                        if (picked != null && picked.trim().isNotEmpty && mounted) {
                          setState(() {
                            _selectedDirectory = picked.trim();
                          });
                        }
                      },
                    ),
                    if (_selectedDirectory != widget.defaultDirectory) ...[
                      IconButton(
                        key: const Key('export_reset_directory_button'),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        tooltip: 'Reset to default folder',
                        onPressed: () {
                          setState(() {
                            _selectedDirectory = widget.defaultDirectory;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              'File Name',
              style: AppTypography.labelSmall.copyWith(
                color: widget.isDark ? AppColors.gray400 : AppColors.gray600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            TextField(
              controller: _fileNameController,
              key: const Key('export_filename_input'),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppBorderRadius.smallBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Save Destination Preview:',
              style: AppTypography.labelSmall.copyWith(
                color: widget.isDark ? AppColors.gray400 : AppColors.gray600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? AppColors.darkSurfaceElevated.withValues(alpha: 0.5)
                    : AppColors.gray50,
                borderRadius: AppBorderRadius.smallBorder,
              ),
              child: Text(
                previewPath,
                key: const Key('export_full_path_preview'),
                style: AppTypography.labelSmall.copyWith(
                  color: widget.isDark ? AppColors.emerald400 : AppColors.emerald800,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('export_cancel_button'),
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('export_confirm_button'),
          onPressed: () {
            final name = _fileNameController.text.trim();
            Navigator.of(context).pop((
              format: _selectedFormat,
              directory: _selectedDirectory,
              fileName: name.isEmpty ? _getDefaultName(_selectedFormat) : name,
            ));
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.emerald600,
          ),
          child: const Text('Confirm & Save'),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppBorderRadius.smallBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? AppColors.emerald600.withValues(alpha: 0.2)
                  : AppColors.emerald50)
              : (isDark
                  ? AppColors.darkSurfaceElevated
                  : AppColors.gray50),
          border: Border.all(
            color: isSelected
                ? AppColors.emerald600
                : (isDark ? AppColors.gray700 : AppColors.gray300),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: AppBorderRadius.smallBorder,
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.labelLarge.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.gray900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.emerald600,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

