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

  Future<void> _handleExport() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Exporting database...';
    });

    final path = await DatabaseHelper.instance.exportDatabase();
    
    setState(() {
      _isProcessing = false;
      _statusMessage = path != null 
          ? 'Backup exported successfully to $path' 
          : 'Export failed or cancelled';
    });
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
          ? 'Backup imported successfully! Please restart the app.' 
          : 'Import failed or cancelled';
    });
  }

  Future<void> _handleExportJSON() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Exporting as JSON...';
    });

    final path = await DatabaseHelper.instance.exportDatabaseAsJSON();
    
    setState(() {
      _isProcessing = false;
      _statusMessage = path != null 
          ? 'JSON exported successfully to $path' 
          : 'JSON export failed or cancelled';
    });
  }

  Future<void> _handleImportJSON() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Importing from JSON...';
    });

    final success = await DatabaseHelper.instance.importDatabaseFromJSON();
    
    setState(() {
      _isProcessing = false;
      _statusMessage = success 
          ? 'JSON imported successfully! Please restart the app.' 
          : 'JSON import failed or cancelled';
    });
  }

  Future<void> _handleExportCSV() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Exporting transactions as CSV...';
    });

    final path = await DatabaseHelper.instance.exportTransactionsAsCSV();
    
    setState(() {
      _isProcessing = false;
      _statusMessage = path != null 
          ? 'CSV exported successfully to $path' 
          : 'CSV export failed or cancelled';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Backup & Restore', style: AppTypography.titleLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ListView(
          children: [
            Text(
              'Manage your local data. Since Cashflow is local-first, your data stays on your device. Back it up regularly to avoid loss.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Database Backup (.db)',
              style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _handleExport,
              icon: const Icon(Icons.upload),
              label: Text('Export Backup (.db)', style: AppTypography.labelMedium),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _handleImport,
              icon: const Icon(Icons.download),
              label: Text('Import Backup (.db)', style: AppTypography.labelMedium),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'JSON Export/Import',
              style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _handleExportJSON,
              icon: const Icon(Icons.upload),
              label: Text('Export as JSON', style: AppTypography.labelMedium),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _handleImportJSON,
              icon: const Icon(Icons.download),
              label: Text('Import from JSON', style: AppTypography.labelMedium),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Transaction Export',
              style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _handleExportCSV,
              icon: const Icon(Icons.download),
              label: Text('Export Transactions (CSV)', style: AppTypography.labelMedium),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (_statusMessage.isNotEmpty)
              Center(
                child: Text(
                  _statusMessage,
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
