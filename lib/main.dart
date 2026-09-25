import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cashflow/screens/dashboard_screen.dart';
import 'package:cashflow/screens/history_screen.dart';
import 'package:cashflow/screens/accounts_screen.dart';
import 'package:cashflow/screens/analytics_screen.dart';
import 'package:cashflow/screens/backup_restore_screen.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/services/platform_database.dart';
import 'package:cashflow/theme/theme_constants.dart';
import 'package:cashflow/components/voice_model_download_sheet.dart';
import 'package:cashflow/components/voice_recording_modal.dart';
import 'package:cashflow/services/model_management_service.dart';
import 'package:cashflow/services/voice_pipeline_coordinator.dart';
import 'package:cashflow/services/platform_security_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configurePlatformDatabase();

  final dbHelper = DatabaseHelper.instance;
  await dbHelper.initStartupPrivacyMode();
  // Seed categories if DB is empty
  final cats = await dbHelper.readAllCategories();
  if (cats.isEmpty) {
    await dbHelper.seedDatabase();
  }

  final appLockSetting = await dbHelper.getSetting('app_lock_enabled');
  final appLockEnabled = appLockSetting == '1';

  runApp(MoneyTrackerApp(initialAppLockEnabled: appLockEnabled));
}

class MoneyTrackerApp extends StatefulWidget {
  final bool initialAppLockEnabled;

  const MoneyTrackerApp({
    super.key,
    this.initialAppLockEnabled = false,
  });

  @override
  State<MoneyTrackerApp> createState() => _MoneyTrackerAppState();
}

class _MoneyTrackerAppState extends State<MoneyTrackerApp>
    with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;
  late bool _locked;
  late bool _appLockEnabled;

  @override
  void initState() {
    super.initState();
    _appLockEnabled = widget.initialAppLockEnabled;
    _locked = widget.initialAppLockEnabled;
    WidgetsBinding.instance.addObserver(this);
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
    } else {
      _syncAppLock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _syncAppLock() async {
    final enabled = await DatabaseHelper.instance.getSetting('app_lock_enabled');
    final isEnabled = enabled == '1';
    if (mounted && isEnabled != _appLockEnabled) {
      setState(() {
        _appLockEnabled = isEnabled;
        if (isEnabled) {
          _locked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_appLockEnabled) {
        setState(() => _locked = true);
      }
    } else if (state == AppLifecycleState.resumed) {
      _syncAppLock().then((_) {
        if (_appLockEnabled && _locked) {
          _tryUnlock();
        }
      });
    }
  }

  Future<void> _tryUnlock() async {
    final success = await PlatformSecurityService.instance.authenticate();
    if (success && mounted) {
      setState(() => _locked = false);
    }
  }

  void _toggleTheme() {
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
      } else if (_themeMode == ThemeMode.dark) {
        _themeMode = ThemeMode.light;
      } else {
        // If system, switch to dark first
        _themeMode = ThemeMode.dark;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_locked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Cashflow',
        themeMode: _themeMode,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.emerald700),
          scaffoldBackgroundColor: AppColors.gray50,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.emerald700,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: AppColors.darkBg,
        ),
        home: Scaffold(
          body: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _tryUnlock,
              child: SizedBox.expand(
                child: Stack(
                  children: [
                    Align(
                      alignment: const Alignment(0, -0.6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/icon/app_icon.jpeg',
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: AppColors.emerald700,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Builder(
                        builder: (context) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          return Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: (isDark ? AppColors.emerald400 : AppColors.emerald700)
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_rounded,
                              size: 32,
                              color: isDark ? AppColors.emerald400 : AppColors.emerald700,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cashflow',
      builder: (context, child) {
        if (!kIsWeb) return child ?? const SizedBox.shrink();

        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.emerald700,
          brightness: Brightness.light,
          primary: AppColors.emerald700,
          surface: AppColors.white,
        ),
        scaffoldBackgroundColor: AppColors.gray50,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.gray900,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.white,
          elevation: 3,
          indicatorColor: AppColors.emerald100,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.emerald800, size: 22);
            }
            return const IconThemeData(color: AppColors.gray500, size: 22);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTypography.labelSmall.copyWith(
                color: AppColors.emerald800,
                fontWeight: FontWeight.bold,
              );
            }
            return AppTypography.labelSmall.copyWith(color: AppColors.gray500);
          }),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.gray200,
          thickness: 1,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.emerald700,
          brightness: Brightness.dark,
          primary: AppColors.emerald500,
          surface: AppColors.darkSurface,
        ),
        scaffoldBackgroundColor: AppColors.darkBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkSurface,
          foregroundColor: AppColors.darkText,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.darkSurface,
          elevation: 3,
          indicatorColor: AppColors.emerald900.withValues(alpha: 0.6),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.emerald400, size: 22);
            }
            return const IconThemeData(color: AppColors.gray400, size: 22);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTypography.labelSmall.copyWith(
                color: AppColors.emerald400,
                fontWeight: FontWeight.bold,
              );
            }
            return AppTypography.labelSmall.copyWith(color: AppColors.gray400);
          }),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.darkBorder,
          thickness: 1,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.darkSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
      ),
      themeMode: _themeMode,
      home: MainNavigationScreen(onThemeToggle: _toggleTheme),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final VoicePipelineCoordinator? voiceCoordinator;

  const MainNavigationScreen({
    super.key,
    required this.onThemeToggle,
    this.voiceCoordinator,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  int _accountsSubTabIndex = 0;

  void _onItemTapped(int index, {int? subTabIndex}) {
    setState(() {
      if (index == 3 && _selectedIndex == 3 && subTabIndex == null) {
        _accountsSubTabIndex = 0;
      } else if (subTabIndex != null) {
        _accountsSubTabIndex = subTabIndex;
      }
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> screens = [
      DashboardScreen(onNavigateTab: _onItemTapped),
      const HistoryScreen(),
      const AnalyticsScreen(),
      AccountsScreen(
        initialTabIndex: _accountsSubTabIndex,
        onTabChanged: (subTab) {
          setState(() {
            _accountsSubTabIndex = subTab;
          });
        },
      ),
    ];

    final titles = [
      'Cashflow',
      'Activity Ledger',
      'Spending Analytics',
      _accountsSubTabIndex == 1
          ? 'Monthly Budgets'
          : _accountsSubTabIndex == 2
              ? 'Sinking Funds'
              : 'My Accounts',
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: AppBorderRadius.smallBorder,
              child: Image.asset(
                'assets/icon/app_icon.jpeg',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  padding: const EdgeInsets.all(AppSpacing.xs + 2),
                  decoration: BoxDecoration(
                    color: AppColors.emerald500.withValues(alpha: 0.15),
                    borderRadius: AppBorderRadius.smallBorder,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppColors.emerald600,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              titles[_selectedIndex],
              style: AppTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings & Data Backup',
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? AppColors.darkText : AppColors.gray700,
              size: 22,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BackupRestoreScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Toggle Theme',
            onPressed: widget.onThemeToggle,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? AppColors.warning : AppColors.gray700,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: AnimatedBuilder(
        animation: ModelManagementService.instance,
        builder: (context, child) {
          final modelService = ModelManagementService.instance;
          final isDownloading = modelService.isDownloading ||
              modelService.status == ModelPackStatus.verifying;

          return Column(
            children: [
              if (isDownloading)
                _buildGlobalDownloadBanner(context, modelService, isDark),
              Expanded(child: child!),
            ],
          );
        },
        child: IndexedStack(index: _selectedIndex, children: screens),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
                if (isDark)
                  BoxShadow(
                    color: AppColors.emerald500.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF14201C).withValues(alpha: 0.78)
                        : Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF284136).withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.9),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildNavItem(
                        index: 0,
                        icon: Icons.dashboard_outlined,
                        selectedIcon: Icons.dashboard_rounded,
                        label: 'Home',
                        isDark: isDark,
                      ),
                      _buildNavItem(
                        index: 1,
                        icon: Icons.receipt_long_outlined,
                        selectedIcon: Icons.receipt_long_rounded,
                        label: 'Activity',
                        isDark: isDark,
                      ),
                      _buildVoiceCenterButton(isDark),
                      _buildNavItem(
                        index: 2,
                        icon: Icons.pie_chart_outline_rounded,
                        selectedIcon: Icons.pie_chart_rounded,
                        label: 'Analytics',
                        isDark: isDark,
                      ),
                      _buildNavItem(
                        index: 3,
                        icon: Icons.account_balance_outlined,
                        selectedIcon: Icons.account_balance_rounded,
                        label: 'Accounts',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalDownloadBanner(
    BuildContext context,
    ModelManagementService modelService,
    bool isDark,
  ) {
    final pct = (modelService.progress * 100).toStringAsFixed(0);
    final isVerifying = modelService.status == ModelPackStatus.verifying;

    return Material(
      color: isDark ? AppColors.darkSurfaceElevated : AppColors.emerald50,
      elevation: 2,
      child: InkWell(
        key: const Key('global_model_download_banner'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BackupRestoreScreen(
                scrollToVoiceModels: true,
              ),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs + 2,
              ),
              child: Row(
                children: [
                  Icon(
                    isVerifying
                        ? Icons.security_rounded
                        : Icons.downloading_rounded,
                    color: AppColors.emerald600,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      isVerifying
                          ? 'Verifying AI Model Pack...'
                          : 'Downloading AI Model Pack ($pct%)',
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText : AppColors.gray900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'View in Settings',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.emerald600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.emerald600,
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: isVerifying ? null : modelService.progress,
              backgroundColor:
                  isDark ? AppColors.darkBorder : AppColors.emerald100,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.emerald600),
              minHeight: 2.5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceCenterButton(bool isDark) {
    return Expanded(
      child: Tooltip(
        message: 'AI Voice Transaction Journaling',
        child: InkWell(
          key: const Key('dashboard_voice_entry_fab'),
          onTap: () async {
            final isInstalled =
                await ModelManagementService.instance.isModelPackInstalled();
            if (!mounted) return;
            if (!isInstalled) {
              await VoiceModelDownloadSheet.show(context);
            } else {
              await VoiceRecordingModal.show(
                context,
                coordinator: widget.voiceCoordinator,
              );
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [
                            Color(0xFF34D399),
                            Color(0xFF10B981),
                            Color(0xFF059669),
                            Color(0xFF047857),
                          ]
                        : const [
                            Color(0xFF34D399),
                            Color(0xFF10B981),
                            Color(0xFF059669),
                            Color(0xFF047857),
                          ],
                  ),
                  border: Border.all(
                    color: isDark ? const Color(0xFF6EE7B7) : Colors.white,
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981)
                          .withValues(alpha: isDark ? 0.55 : 0.40),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/icon/ai_voice_icon.jpg',
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.mic_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                        Positioned(
                          top: 3,
                          right: 3,
                          child: Icon(
                            Icons.auto_awesome,
                            color: Colors.amber.shade300,
                            size: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Voice',
                style: AppTypography.labelSmall.copyWith(
                  color: isDark ? AppColors.emerald300 : AppColors.emerald800,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _selectedIndex == index;
    final primaryColor = isDark ? AppColors.emerald300 : AppColors.emerald800;
    final unselectedColor = isDark ? AppColors.gray400 : AppColors.gray500;
    final color = isSelected ? primaryColor : unselectedColor;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                          ? AppColors.emerald900.withValues(alpha: 0.5)
                          : AppColors.emerald100)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: color,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 10.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
