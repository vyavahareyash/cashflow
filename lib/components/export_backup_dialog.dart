import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/backup_platform.dart';
import '../theme/theme_constants.dart';

enum ExportFormat { sqlite, json, csv }

typedef ExportDialogResult = ({
  ExportFormat format,
  String directory,
  String fileName,
});

class ExportBackupDialog extends StatefulWidget {
  final bool isDark;
  final String defaultDirectory;
  final String initialDirectory;
  final ExportFormat initialFormat;
  final bool fixedFormat;
  final String? title;

  const ExportBackupDialog({
    super.key,
    required this.isDark,
    required this.defaultDirectory,
    required this.initialDirectory,
    this.initialFormat = ExportFormat.sqlite,
    this.fixedFormat = false,
    this.title,
  });

  @override
  State<ExportBackupDialog> createState() => _ExportBackupDialogState();
}

class _ExportBackupDialogState extends State<ExportBackupDialog> {
  late ExportFormat _selectedFormat;
  late String _selectedDirectory;
  late TextEditingController _fileNameController;

  @override
  void initState() {
    super.initState();
    if (widget.fixedFormat) {
      _selectedFormat = widget.initialFormat;
    } else {
      _selectedFormat = kIsWeb ? ExportFormat.json : widget.initialFormat;
    }
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
        widget.title ??
            (widget.fixedFormat
                ? 'Export Transactions CSV'
                : 'Export Data & Backups'),
        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.fixedFormat) ...[
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
                      _fileNameController.text = _getDefaultName(
                        ExportFormat.sqlite,
                      );
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
                    _fileNameController.text = _getDefaultName(
                      ExportFormat.json,
                    );
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
                    _fileNameController.text = _getDefaultName(
                      ExportFormat.csv,
                    );
                  });
                },
              ),
            ],
            if (!kIsWeb) ...[
              if (!widget.fixedFormat) const SizedBox(height: AppSpacing.md),
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
                    color: widget.isDark
                        ? AppColors.gray700
                        : AppColors.gray300,
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
                        if (picked != null &&
                            picked.trim().isNotEmpty &&
                            mounted) {
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
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
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
                  color: widget.isDark
                      ? AppColors.emerald400
                      : AppColors.emerald800,
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
          style: FilledButton.styleFrom(backgroundColor: AppColors.emerald600),
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
      borderRadius: AppBorderRadius.mediumBorder,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? AppColors.emerald700.withValues(alpha: 0.25)
                    : AppColors.emerald50)
              : (isDark ? AppColors.darkSurfaceElevated : AppColors.gray100),
          borderRadius: AppBorderRadius.mediumBorder,
          border: Border.all(
            color: isSelected
                ? AppColors.emerald500
                : (isDark ? AppColors.gray700 : AppColors.gray300),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: AppBorderRadius.smallBorder,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
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
                color: AppColors.emerald500,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
