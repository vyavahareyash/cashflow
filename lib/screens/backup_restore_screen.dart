import 'package:flutter/material.dart';
import 'package:cashflow/services/database_helper.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Manage your local data. Since Cashflow is local-first, your data stays on your device. Back it up regularly to avoid loss.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _handleExport,
              icon: const Icon(Icons.upload),
              label: const Text('Export Backup (.db)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _handleImport,
              icon: const Icon(Icons.download),
              label: const Text('Import Backup (.db)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 32),
            if (_statusMessage.isNotEmpty)
              Center(
                child: Text(
                  _statusMessage,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
