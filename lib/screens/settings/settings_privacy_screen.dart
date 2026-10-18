import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/database_helper.dart';
import '../../services/platform_security_service.dart';
import '../../theme/theme_constants.dart';
import '../../components/custom_card.dart';

class SettingsPrivacyScreen extends StatefulWidget {
  const SettingsPrivacyScreen({super.key});

  @override
  State<SettingsPrivacyScreen> createState() => _SettingsPrivacyScreenState();
}

class _SettingsPrivacyScreenState extends State<SettingsPrivacyScreen> {
  bool _startInPrivacyMode = false;
  bool _appLockEnabled = false;
  bool _canUseBiometric = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    try {
      final db = DatabaseHelper.instance;
      final startInPrivacy = await db.getStartInPrivacyMode();
      final appLockVal = await db.getSetting('app_lock_enabled');
      final canBiometric = await PlatformSecurityService.instance
          .canAuthenticate();

      if (mounted) {
        setState(() {
          _startInPrivacyMode = startInPrivacy;
          _appLockEnabled = appLockVal == '1';
          _canUseBiometric = canBiometric;
        });
      }
    } catch (_) {}
  }

  Future<void> _updateStartInPrivacyMode(bool value) async {
    await DatabaseHelper.instance.setStartInPrivacyMode(value);
    if (mounted) {
      setState(() {
        _startInPrivacyMode = value;
      });
      _showFeedback(
        value
            ? 'Balances will be masked on app startup'
            : 'Balances will be visible on app startup',
        isSuccess: true,
      );
    }
  }

  Future<void> _updateAppLock(bool value) async {
    final authenticated = await PlatformSecurityService.instance.authenticate();
    if (!authenticated) {
      _showFeedback(
        'Authentication required to change App Lock setting',
        isError: true,
      );
      return;
    }
    await DatabaseHelper.instance.setSetting(
      'app_lock_enabled',
      value ? '1' : '0',
    );
    if (mounted) {
      setState(() {
        _appLockEnabled = value;
      });
      _showFeedback(
        value
            ? 'App Lock enabled with biometric / device PIN'
            : 'App Lock disabled',
        isSuccess: true,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy & Security',
          style: AppTypography.titleLarge,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPrivacyHeroCard(isDark),
            const SizedBox(height: AppSpacing.lg),
            _buildPrivacyPreferencesCard(isDark),
            if (_canUseBiometric) ...[
              const SizedBox(height: AppSpacing.md),
              _buildAppLockCard(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyHeroCard(bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppBorderRadius.largeBorder,
        boxShadow: [AppShadows.level1],
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

  Widget _buildPrivacyPreferencesCard(bool isDark) {
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
                  Icons.visibility_off_outlined,
                  color: AppColors.emerald600,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Start in Privacy Mode',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mask balances and financial figures whenever the app launches',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: const Key('start_in_privacy_mode_switch'),
                value: _startInPrivacyMode,
                activeTrackColor: AppColors.emerald600,
                onChanged: _updateStartInPrivacyMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppLockCard(bool isDark) {
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
                  Icons.fingerprint_rounded,
                  color: AppColors.emerald600,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('App Lock', style: AppTypography.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Require Biometric or Device PIN when opening or resuming Cashflow',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: const Key('app_lock_switch'),
                value: _appLockEnabled,
                activeTrackColor: AppColors.emerald600,
                onChanged: _updateAppLock,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
