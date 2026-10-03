import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cashflow/theme/theme_constants.dart';
import 'package:cashflow/services/sync/live_sync_service.dart';
import 'package:cashflow/services/sync/sync_models.dart';
import 'package:cashflow/components/custom_card.dart';
import 'package:cashflow/components/custom_button.dart';

class LiveSyncScreen extends StatefulWidget {
  const LiveSyncScreen({super.key});

  @override
  State<LiveSyncScreen> createState() => _LiveSyncScreenState();
}

class _LiveSyncScreenState extends State<LiveSyncScreen> {
  final LiveSyncService _syncService = LiveSyncService.instance;
  late bool _isHostMode;
  MobileScannerController? _scannerController;
  bool _isProcessingScan = false;

  @override
  void initState() {
    super.initState();
    // Default: Desktop acts as Host (shows QR), Mobile acts as Client (scans QR)
    final isDesktop =
        !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
    _isHostMode = isDesktop;

    if (_isHostMode && !_syncService.isConnected) {
      unawaited(_startHost());
    } else if (!_isHostMode) {
      _scannerController = MobileScannerController();
    }
  }

  @override
  void dispose() {
    final controller = _scannerController;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  Future<void> _startHost() async {
    await _syncService.startHost();
  }

  void _toggleMode(bool hostMode) async {
    setState(() {
      _isHostMode = hostMode;
      _isProcessingScan = false;
    });

    if (_isHostMode) {
      final controller = _scannerController;
      if (controller != null) {
        unawaited(controller.dispose());
      }
      _scannerController = null;
      if (!_syncService.isConnected) {
        await _startHost();
      }
    } else {
      await _syncService.disconnect();
      _scannerController = MobileScannerController();
    }
  }

  void _onDetectBarcode(BarcodeCapture capture) async {
    if (_isProcessingScan) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() {
      _isProcessingScan = true;
    });

    final success = await _syncService.connectWithQr(rawValue);
    if (!success && mounted) {
      setState(() {
        _isProcessingScan = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect via QR. Try entering PIN manually.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _showManualConnectDialog() async {
    final ipController = TextEditingController(text: '192.168.');
    final portController = TextEditingController(text: '48921');
    final pinController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Connection Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'Host IP Address',
                hintText: 'e.g. 192.168.43.1',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '48921',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: pinController,
              decoration: const InputDecoration(
                labelText: '6-Digit PIN or Token',
                hintText: 'e.g. 123456',
              ),
              keyboardType: TextInputType.text,
            ),
          ],
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
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (result == true) {
      final ip = ipController.text.trim();
      final port = int.tryParse(portController.text.trim()) ?? 48921;
      final pin = pinController.text.trim();

      if (ip.isNotEmpty && pin.isNotEmpty) {
        final success = await _syncService.connectWithPin(
          host: ip,
          port: port,
          pin: pin,
        );
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection failed. Verify IP, PIN, and network.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Device Sync', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            tooltip: 'Sync Help & Privacy',
            icon: const Icon(Icons.privacy_tip_outlined),
            onPressed: () => _showPrivacyInfoDialog(context),
          ),
        ],
      ),
      body: ValueListenableBuilder<SyncStatus>(
        valueListenable: _syncService.statusNotifier,
        builder: (context, status, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildNetworkRequirementBanner(isDark),
                const SizedBox(height: AppSpacing.md),
                if (status == SyncStatus.connected)
                  _buildConnectedView(isDark)
                else ...[
                  _buildModeToggle(isDark),
                  const SizedBox(height: AppSpacing.lg),
                  if (_isHostMode)
                    _buildHostView(isDark, status)
                  else
                    _buildScannerView(isDark, status),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNetworkRequirementBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.emerald50,
        borderRadius: AppBorderRadius.mediumBorder,
        border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi, color: AppColors.emerald600, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local Network Required',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.emerald400 : AppColors.emerald900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '1. Connect both devices to the same Wi-Fi router, OR\n'
                  '2. Turn on phone Mobile Hotspot & connect Desktop to it.\n'
                  'Zero data ever leaves your local network.',
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark ? AppColors.gray300 : AppColors.gray700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle(bool isDark) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment<bool>(
          value: false,
          label: Text('Scan QR Code'),
          icon: Icon(Icons.qr_code_scanner),
        ),
        ButtonSegment<bool>(
          value: true,
          label: Text('Show QR Code'),
          icon: Icon(Icons.qr_code),
        ),
      ],
      selected: {_isHostMode},
      onSelectionChanged: (Set<bool> newSelection) {
        _toggleMode(newSelection.first);
      },
    );
  }

  Widget _buildHostView(bool isDark, SyncStatus status) {
    return ValueListenableBuilder<String?>(
      valueListenable: _syncService.activeQrPayloadNotifier,
      builder: (context, qrPayload, _) {
        final ip = _syncService.activeIpNotifier.value ?? '127.0.0.1';
        final port = _syncService.activePortNotifier.value ?? 48921;
        final pin = _syncService.activePinNotifier.value ?? '------';

        return Column(
          children: [
            CustomCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Text(
                    'Point Mobile App at this QR Code',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (qrPayload != null && qrPayload.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: AppBorderRadius.mediumBorder,
                      ),
                      child: QrImageView(
                        data: qrPayload,
                        version: QrVersions.auto,
                        size: 220.0,
                        backgroundColor: Colors.white,
                      ),
                    )
                  else
                    const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Listening on local network...',
                    style: AppTypography.bodySmall.copyWith(
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            CustomCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manual Connection Fallback',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.gray200 : AppColors.gray800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '6-Digit PIN:',
                        style: AppTypography.bodySmall,
                      ),
                      SelectableText(
                        pin,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: AppColors.emerald600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'IP Address & Port:',
                        style: AppTypography.bodySmall,
                      ),
                      SelectableText(
                        '$ip:$port',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScannerView(bool isDark, SyncStatus status) {
    return Column(
      children: [
        CustomCard(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            children: [
              Container(
                height: 280,
                decoration: const BoxDecoration(
                  borderRadius: AppBorderRadius.mediumBorder,
                  color: Colors.black,
                ),
                clipBehavior: Clip.antiAlias,
                child: _scannerController != null
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          MobileScanner(
                            controller: _scannerController!,
                            onDetect: _onDetectBarcode,
                          ),
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.emerald500,
                                width: 2,
                              ),
                              borderRadius: AppBorderRadius.mediumBorder,
                            ),
                          ),
                          if (_isProcessingScan)
                            Container(
                              color: Colors.black54,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.emerald400,
                                ),
                              ),
                            ),
                        ],
                      )
                    : const Center(child: Text('Camera unavailable')),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Scan the QR code displayed on your other device',
                style: AppTypography.bodySmall.copyWith(
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        CustomButton(
          label: "Can't scan? Enter 6-digit PIN",
          variant: ButtonVariant.outlined,
          icon: Icons.keyboard_alt_outlined,
          onPressed: () {
            unawaited(_showManualConnectDialog());
          },
        ),
      ],
    );
  }

  Widget _buildConnectedView(bool isDark) {
    final peerName =
        _syncService.peerDeviceNameNotifier.value ?? 'Paired Device';

    return Column(
      children: [
        CustomCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.emerald500.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sync_alt_rounded,
                  size: 48,
                  color: AppColors.emerald600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Live Sync Active',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.emerald600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Connected to $peerName',
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark ? AppColors.gray300 : AppColors.gray700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.gray100,
                  borderRadius: AppBorderRadius.smallBorder,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.emerald500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Real-time P2P encrypted socket',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ValueListenableBuilder<String?>(
                valueListenable: _syncService.lastMergeSummaryNotifier,
                builder: (context, summary, _) {
                  if (summary == null || summary.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.emerald500.withValues(alpha: 0.1),
                      borderRadius: AppBorderRadius.smallBorder,
                      border: Border.all(
                        color: AppColors.emerald500.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      summary,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.emerald600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Every transaction, goal lock, and balance adjustment is synchronized instantly between your devices.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // DIRECTIONAL ACTIONS & RECOVERY
        CustomCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sync & Recovery Actions',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choose how to sync data between devices if changes differ or you need to recover deleted data:',
                style: AppTypography.bodySmall.copyWith(
                  color: isDark ? AppColors.gray400 : AppColors.gray600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              CustomButton(
                label: 'Safe Merge Both Devices (Additive)',
                icon: Icons.call_merge_rounded,
                variant: ButtonVariant.primary,
                onPressed: () {
                  unawaited(_syncService.triggerSafeMerge());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Safe merge requested...')),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              CustomButton(
                label: 'Push & Overwrite Other Device',
                icon: Icons.upload_rounded,
                variant: ButtonVariant.outlined,
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Overwrite Remote Device?'),
                      content: const Text(
                        'This will replace ALL data on the other device with this device\'s current database.\n\n'
                        'Use this if you want this device to be the single source of truth.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Overwrite Remote'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _syncService.triggerForcePush();
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              CustomButton(
                label: 'Restore Local from Other Device',
                icon: Icons.download_rounded,
                variant: ButtonVariant.outlined,
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Restore from Remote Device?'),
                      content: const Text(
                        'This will replace ALL local data on THIS device with the other device\'s data.\n\n'
                        'Use this to recover from accidental deletions.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Replace Local Data'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _syncService.triggerRestoreFromPeer();
                  }
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _syncService.canUndoNotifier,
                builder: (context, canUndo, _) {
                  if (!canUndo) return const SizedBox.shrink();
                  return Column(
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      CustomButton(
                        label: 'Undo Last Sync (Rollback)',
                        icon: Icons.undo_rounded,
                        variant: ButtonVariant.secondary,
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final undone = await _syncService.undoLastSync();
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  undone
                                      ? 'Reverted to pre-sync database snapshot!'
                                      : 'No snapshot to undo.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        CustomButton(
          label: 'Disconnect Live Sync',
          variant: ButtonVariant.danger,
          icon: Icons.link_off,
          onPressed: () {
            unawaited(_syncService.disconnect());
          },
        ),
      ],
    );
  }

  void _showPrivacyInfoDialog(BuildContext context) {
    unawaited(
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Live Sync Privacy Guarantee'),
          content: const Text(
            '• Zero Cloud: Sockets connect directly between your devices over local Wi-Fi or Mobile Hotspot.\n\n'
            '• Zero Analytics / Telemetry: No sync logs or personal financial data ever touch an external server.\n\n'
            '• Local Authentication: Connections are verified with a 1-time session token and PIN.\n\n'
            '• Offline Freedom: If disconnected, both devices continue working fully offline without degradation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }
}
