import 'package:flutter/material.dart';
import 'package:cashflow/screens/dashboard_screen.dart';
import 'package:cashflow/screens/budget_screen.dart';
import 'package:cashflow/screens/planner_screen.dart';
import 'package:cashflow/screens/accounts_screen.dart';
import 'package:cashflow/screens/analytics_screen.dart';
import 'package:cashflow/screens/backup_restore_screen.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/theme/theme_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbHelper = DatabaseHelper.instance;
  // Seed categories if DB is empty
  final cats = await dbHelper.readAllCategories();
  if (cats.isEmpty) {
    await dbHelper.seedDatabase();
  }

  runApp(const MoneyTrackerApp());
}

class MoneyTrackerApp extends StatefulWidget {
  const MoneyTrackerApp({super.key});

  @override
  State<MoneyTrackerApp> createState() => _MoneyTrackerAppState();
}

class _MoneyTrackerAppState extends State<MoneyTrackerApp> {
  ThemeMode _themeMode = ThemeMode.system;

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cashflow',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.emerald700,
          brightness: Brightness.light,
          primary: AppColors.emerald700,
          surface: AppColors.white,
          background: AppColors.gray50,
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
          iconTheme: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const IconThemeData(color: AppColors.emerald800, size: 22);
            }
            return const IconThemeData(color: AppColors.gray500, size: 22);
          }),
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return AppTypography.labelSmall.copyWith(
                color: AppColors.emerald800,
                fontWeight: FontWeight.bold,
              );
            }
            return AppTypography.labelSmall.copyWith(
              color: AppColors.gray500,
            );
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
          background: AppColors.darkBg,
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
          indicatorColor: AppColors.emerald900.withOpacity(0.6),
          iconTheme: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const IconThemeData(color: AppColors.emerald400, size: 22);
            }
            return const IconThemeData(color: AppColors.gray400, size: 22);
          }),
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return AppTypography.labelSmall.copyWith(
                color: AppColors.emerald400,
                fontWeight: FontWeight.bold,
              );
            }
            return AppTypography.labelSmall.copyWith(
              color: AppColors.gray400,
            );
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
  const MainNavigationScreen({super.key, required this.onThemeToggle});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> screens = [
      DashboardScreen(onNavigateTab: _onItemTapped),
      const BudgetScreen(),
      const PlannerScreen(),
      const AccountsScreen(),
      const AnalyticsScreen(),
    ];

    final titles = [
      'Cashflow',
      'Monthly Budgets',
      'Sinking Funds',
      'My Accounts',
      'Insights & Activity',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs + 2),
              decoration: BoxDecoration(
                color: AppColors.emerald500.withOpacity(0.15),
                borderRadius: AppBorderRadius.smallBorder,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.emerald600,
                size: 20,
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
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Budgets',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings_rounded),
            label: 'Goals',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance_rounded),
            label: 'Accounts',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Insights',
          ),
        ],
      ),
    );
  }
}
