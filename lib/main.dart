import 'package:flutter/material.dart';
import 'package:cashflow/screens/dashboard_screen.dart';
import 'package:cashflow/screens/budget_screen.dart';
import 'package:cashflow/screens/planner_screen.dart';
import 'package:cashflow/screens/accounts_screen.dart';
import 'package:cashflow/screens/history_screen.dart';
import 'package:cashflow/screens/analytics_screen.dart';
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
          seedColor: AppColors.green700,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.gray50,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.gray900,
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: TextTheme(
          displayLarge: AppTypography.displayLarge.copyWith(color: AppColors.gray900),
          headlineLarge: AppTypography.headlineLarge.copyWith(color: AppColors.gray900),
          headlineMedium: AppTypography.headlineMedium.copyWith(color: AppColors.gray900),
          titleLarge: AppTypography.titleLarge.copyWith(color: AppColors.gray900),
          titleMedium: AppTypography.titleMedium.copyWith(color: AppColors.gray900),
          bodyLarge: AppTypography.bodyLarge.copyWith(color: AppColors.gray900),
          bodyMedium: AppTypography.bodyMedium.copyWith(color: AppColors.gray700),
          labelLarge: AppTypography.labelLarge.copyWith(color: AppColors.green700),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: AppBorderRadius.smallBorder,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.green700,
          unselectedItemColor: AppColors.gray400,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.green700,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: AppColors.darkBg,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.darkSurface,
          foregroundColor: AppColors.darkText,
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: TextTheme(
          displayLarge: AppTypography.displayLarge.copyWith(color: AppColors.darkText),
          headlineLarge: AppTypography.headlineLarge.copyWith(color: AppColors.darkText),
          headlineMedium: AppTypography.headlineMedium.copyWith(color: AppColors.darkText),
          titleLarge: AppTypography.titleLarge.copyWith(color: AppColors.darkText),
          titleMedium: AppTypography.titleMedium.copyWith(color: AppColors.darkText),
          bodyLarge: AppTypography.bodyLarge.copyWith(color: AppColors.darkText),
          bodyMedium: AppTypography.bodyMedium.copyWith(color: AppColors.gray400),
          labelLarge: AppTypography.labelLarge.copyWith(color: AppColors.green500),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkSurface,
          selectedItemColor: AppColors.green500,
          unselectedItemColor: AppColors.gray400,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
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

  // These are the screens we use for navigation
  final List<Widget> _screens = [
    const DashboardScreen(),
    const BudgetScreen(),
    const PlannerScreen(),
    const AccountsScreen(),
    const AnalyticsScreen(),
    const HistoryScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Money Tracker'),
        actions: [
          IconButton(
            onPressed: widget.onThemeToggle,
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark 
                  ? Icons.light_mode 
                  : Icons.dark_mode,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: 'Budget'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Plan'),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'Accounts',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}
