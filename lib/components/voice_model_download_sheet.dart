import 'package:flutter/material.dart';

import '../screens/backup_restore_screen.dart';
import '../services/model_management_service.dart';
import '../theme/theme_constants.dart';

/// Modal bottom sheet informing the user about the required Offline AI Model Pack (US 14, US 19).
///
/// Explains that voice journaling runs 100% locally on-device without cloud servers,
/// displaying the download size (~230 MB) and routing the user to [BackupRestoreScreen]
/// to initiate the verified Wi-Fi download, or displaying active progress if already downloading.
class VoiceModelDownloadSheet extends StatelessWidget {
  const VoiceModelDownloadSheet({super.key});

  /// Displays the download prompt modal bottom sheet.
  static Future<void> show(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const VoiceModelDownloadSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: ModelManagementService.instance,
      builder: (context, _) {
        final modelService = ModelManagementService.instance;
        final isDownloading = modelService.isDownloading;
        final isVerifying = modelService.status == ModelPackStatus.verifying;
        final isActive = isDownloading || isVerifying;

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.gray700 : AppColors.gray300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Sparkle / Brain Icon
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.emerald900.withValues(alpha: 0.4)
                            : AppColors.emerald50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActive
                            ? Icons.downloading_rounded
                            : Icons.auto_awesome_rounded,
                        size: 32,
                        color: AppColors.emerald500,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Title Header
                  Semantics(
                    header: true,
                    child: Text(
                      isActive
                          ? (isVerifying
                                ? 'Verifying AI Model Pack...'
                                : 'Downloading AI Model Pack')
                          : 'Offline AI Models Required',
                      style: AppTypography.headlineMedium.copyWith(
                        color: isDark ? AppColors.darkText : AppColors.gray900,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Subtitle / Value Proposition or Status Detail
                  Text(
                    isActive
                        ? (modelService.statusDetail.isNotEmpty
                              ? modelService.statusDetail
                              : 'Downloading neural weights for on-device voice journaling...')
                        : 'To protect your financial privacy, speech recognition and transaction extraction run 100% on your device with zero cloud servers.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.gray600,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Feature Highlights Box or Active Progress Box
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.gray50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.gray200,
                      ),
                    ),
                    child: isActive
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isVerifying
                                        ? 'Verifying SHA-256'
                                        : 'Download Progress',
                                    style: AppTypography.labelMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.darkText
                                          : AppColors.gray900,
                                    ),
                                  ),
                                  Text(
                                    isVerifying
                                        ? 'Integrity check'
                                        : '${(modelService.progress * 100).toStringAsFixed(0)}%',
                                    style: AppTypography.labelMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.emerald600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: isVerifying
                                      ? null
                                      : modelService.progress,
                                  backgroundColor: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.gray200,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        AppColors.emerald600,
                                      ),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                '${(modelService.bytesDownloaded / (1024 * 1024)).toStringAsFixed(1)} MB / ${(modelService.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                                style: AppTypography.bodySmall.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.gray600,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _buildFeatureRow(
                                icon: Icons.wifi_off_rounded,
                                title: '100% Offline & Private',
                                subtitle: 'Audio and transactions never leave your phone.',
                                isDark: isDark,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _buildFeatureRow(
                                icon: Icons.storage_rounded,
                                title: 'One-Time Download (~230 MB)',
                                subtitle: 'SmolLM2 SLM neural model for extraction. Speech recognition requires zero download.',
                                isDark: isDark,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _buildFeatureRow(
                                icon: Icons.memory_rounded,
                                title: 'On-Demand Memory',
                                subtitle: 'Models load into RAM only while journaling and free automatically when done.',
                                isDark: isDark,
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Primary Action
                  Semantics(
                    button: true,
                    label: isActive
                        ? 'View download details in Settings'
                        : 'Go to Settings & Data Backup to download AI models',
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        key: const Key('voice_model_download_settings_button'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const BackupRestoreScreen(
                                scrollToVoiceModels: true,
                              ),
                            ),
                          );
                        },
                        icon: Icon(
                          isActive
                              ? Icons.settings_outlined
                              : Icons.download_rounded,
                          size: 20,
                        ),
                        label: Text(
                          isActive
                              ? 'View in Settings'
                              : 'Download in Settings',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald600,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Secondary Action
                  Semantics(
                    button: true,
                    label: isActive
                        ? 'Cancel download'
                        : 'Dismiss offline model pack prompt',
                    child: SizedBox(
                      height: 48,
                      child: TextButton(
                        key: const Key('voice_model_download_cancel_button'),
                        onPressed: () {
                          if (isActive) {
                            modelService.cancelDownload();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Text(
                          isActive ? 'Cancel Download' : 'Not Now',
                          style: TextStyle(
                            color: isActive
                                ? AppColors.danger
                                : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.gray600),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.emerald500),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.gray900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.gray600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
