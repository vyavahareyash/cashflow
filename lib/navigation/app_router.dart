import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cashflow/screens/backup_restore_screen.dart';

/// Represents a distinct, deep-linkable destination URL in Cashflow.
class AppRoutePath {
  final int
  tabIndex; // 0: Dashboard, 1: Ledger, 2: Analytics, 3: Accounts, -1: Settings
  final int
  accountsSubTabIndex; // 0: My Accounts, 1: Monthly Budgets, 2: Sinking Funds
  final bool isSettings;

  const AppRoutePath._({
    required this.tabIndex,
    this.accountsSubTabIndex = 0,
    this.isSettings = false,
  });

  const AppRoutePath.dashboard() : this._(tabIndex: 0);

  const AppRoutePath.ledger() : this._(tabIndex: 1);

  const AppRoutePath.analytics() : this._(tabIndex: 2);

  const AppRoutePath.accounts({int subTabIndex = 0})
    : this._(tabIndex: 3, accountsSubTabIndex: subTabIndex);

  const AppRoutePath.settings() : this._(tabIndex: -1, isSettings: true);

  String toPath() {
    if (isSettings) return '/settings';
    switch (tabIndex) {
      case 1:
        return '/ledger';
      case 2:
        return '/analytics';
      case 3:
        if (accountsSubTabIndex == 1) return '/accounts/budgets';
        if (accountsSubTabIndex == 2) return '/accounts/sinking-funds';
        return '/accounts';
      case 0:
      default:
        return '/dashboard';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppRoutePath &&
          runtimeType == other.runtimeType &&
          tabIndex == other.tabIndex &&
          accountsSubTabIndex == other.accountsSubTabIndex &&
          isSettings == other.isSettings;

  @override
  int get hashCode => Object.hash(tabIndex, accountsSubTabIndex, isSettings);

  @override
  String toString() => 'AppRoutePath(${toPath()})';
}

/// Parses browser URLs into [AppRoutePath] and vice-versa.
class AppRouteInformationParser extends RouteInformationParser<AppRoutePath> {
  const AppRouteInformationParser();

  @override
  Future<AppRoutePath> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    var path = uri.path;

    // Handle hash-based routing (#/analytics, #/accounts/budgets, etc.)
    if (uri.fragment.isNotEmpty) {
      final fragment = uri.fragment;
      if (fragment.startsWith('/')) {
        path = fragment;
      } else if (fragment.contains('/')) {
        path = '/${fragment.substring(fragment.indexOf('/'))}';
      }
    }

    if (path.isEmpty || path == '/') {
      return const AppRoutePath.dashboard();
    }

    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    final lower = path.toLowerCase();

    if (lower == '/dashboard' || lower == '/home') {
      return const AppRoutePath.dashboard();
    }
    if (lower == '/ledger' || lower == '/activity' || lower == '/history') {
      return const AppRoutePath.ledger();
    }
    if (lower == '/analytics' || lower == '/spending') {
      return const AppRoutePath.analytics();
    }
    if (lower == '/accounts/budgets' || lower == '/budgets') {
      return const AppRoutePath.accounts(subTabIndex: 1);
    }
    if (lower == '/accounts/sinking-funds' ||
        lower == '/accounts/goals' ||
        lower == '/goals') {
      return const AppRoutePath.accounts(subTabIndex: 2);
    }
    if (lower == '/accounts') {
      return const AppRoutePath.accounts(subTabIndex: 0);
    }
    if (lower == '/settings' || lower == '/backup') {
      return const AppRoutePath.settings();
    }

    return const AppRoutePath.dashboard();
  }

  @override
  RouteInformation? restoreRouteInformation(AppRoutePath configuration) {
    return RouteInformation(uri: Uri.parse(configuration.toPath()));
  }
}

typedef MainScreenBuilder = Widget Function(
  BuildContext context,
  AppRoutePath routePath,
  void Function(int index, {int? subTabIndex}) onNavigate,
  VoidCallback onOpenSettings,
);

/// Router delegate orchestrating browser history, declarative paths, and modal back buttons.
class AppRouterDelegate extends RouterDelegate<AppRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRoutePath> {
  @override
  final GlobalKey<NavigatorState> navigatorKey;

  final MainScreenBuilder mainScreenBuilder;
  final WidgetBuilder? settingsScreenBuilder;

  AppRoutePath _currentPath;
  final List<AppRoutePath> _history = [];

  AppRouterDelegate({
    required this.mainScreenBuilder,
    this.settingsScreenBuilder,
    AppRoutePath initialPath = const AppRoutePath.dashboard(),
    GlobalKey<NavigatorState>? navigatorKey,
  }) : _currentPath = initialPath,
       navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>();

  AppRoutePath get currentPath => _currentPath;

  @override
  AppRoutePath get currentConfiguration => _currentPath;

  void setPath(AppRoutePath path) {
    if (_currentPath != path) {
      if (!_currentPath.isSettings && path != _currentPath) {
        _history.add(_currentPath);
        if (_history.length > 20) {
          _history.removeAt(0);
        }
      }
      _currentPath = path;
      notifyListeners();
    }
  }

  void openSettings() {
    setPath(const AppRoutePath.settings());
  }

  void onNavigateTab(int index, {int? subTabIndex}) {
    AppRoutePath nextPath;
    switch (index) {
      case 1:
        nextPath = const AppRoutePath.ledger();
        break;
      case 2:
        nextPath = const AppRoutePath.analytics();
        break;
      case 3:
        nextPath = AppRoutePath.accounts(subTabIndex: subTabIndex ?? 0);
        break;
      case 0:
      default:
        nextPath = const AppRoutePath.dashboard();
        break;
    }
    setPath(nextPath);
  }

  @override
  Future<void> setNewRoutePath(AppRoutePath configuration) async {
    if (_currentPath != configuration) {
      if (!_currentPath.isSettings && configuration != _currentPath) {
        _history.add(_currentPath);
        if (_history.length > 20) {
          _history.removeAt(0);
        }
      }
      _currentPath = configuration;
      notifyListeners();
    }
  }

  @override
  Future<bool> popRoute() async {
    // 1. Give active modals / sheets / dialogs first priority to pop
    final navigator = navigatorKey.currentState;
    if (navigator != null && await navigator.maybePop()) {
      return true;
    }

    // 2. If on settings screen, return to previous screen
    if (_currentPath.isSettings) {
      _currentPath = _history.isNotEmpty
          ? _history.removeLast()
          : const AppRoutePath.dashboard();
      notifyListeners();
      return true;
    }

    // 3. If there is navigation history between tabs, pop to previous tab
    if (_history.isNotEmpty) {
      _currentPath = _history.removeLast();
      notifyListeners();
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: [
        MaterialPage(
          key: const ValueKey('main_screen'),
          child: Builder(
            builder: (innerContext) => mainScreenBuilder(
              innerContext,
              _currentPath,
              onNavigateTab,
              openSettings,
            ),
          ),
        ),
        if (_currentPath.isSettings)
          MaterialPage(
            key: const ValueKey('settings_screen'),
            child: Builder(
              builder: (innerContext) => settingsScreenBuilder != null
                  ? settingsScreenBuilder!(innerContext)
                  : const BackupRestoreScreen(),
            ),
          ),
      ],

      onDidRemovePage: (page) {
        if (_currentPath.isSettings) {
          _currentPath = _history.isNotEmpty
              ? _history.removeLast()
              : const AppRoutePath.dashboard();
          notifyListeners();
        }
      },
    );
  }
}
