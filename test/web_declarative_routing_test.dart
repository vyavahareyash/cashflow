import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:cashflow/navigation/app_router.dart';
import 'package:cashflow/main.dart';
import 'package:cashflow/services/database_helper.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.setTestDatabaseName(inMemoryDatabasePath);

  Future<void> settleApp(WidgetTester tester) async {
    await tester.pump();
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  setUp(() async {
    await DatabaseHelper.instance.close();
    await DatabaseHelper.instance.seedDatabase();
    await DatabaseHelper.instance.setWalkthroughCompleted(completed: true);
  });

  group('Issue #152: AppRouteInformationParser Deep Link & URL Parsing', () {
    const parser = AppRouteInformationParser();

    test('parses root and dashboard URLs', () async {
      final root = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/')),
      );
      expect(root.tabIndex, 0);
      expect(root.isSettings, isFalse);

      final dashboard = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/dashboard')),
      );
      expect(dashboard.tabIndex, 0);

      final home = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/home')),
      );
      expect(home.tabIndex, 0);
    });

    test('parses activity ledger URLs', () async {
      final ledger = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/ledger')),
      );
      expect(ledger.tabIndex, 1);

      final activity = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/activity')),
      );
      expect(activity.tabIndex, 1);
    });

    test('parses spending analytics URLs', () async {
      final analytics = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/analytics')),
      );
      expect(analytics.tabIndex, 2);

      final spending = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/spending')),
      );
      expect(spending.tabIndex, 2);
    });

    test('parses accounts and sub-tab URLs', () async {
      final accounts = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/accounts')),
      );
      expect(accounts.tabIndex, 3);
      expect(accounts.accountsSubTabIndex, 0);

      final budgets = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/accounts/budgets')),
      );
      expect(budgets.tabIndex, 3);
      expect(budgets.accountsSubTabIndex, 1);

      final sinkingFunds = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/accounts/sinking-funds')),
      );
      expect(sinkingFunds.tabIndex, 3);
      expect(sinkingFunds.accountsSubTabIndex, 2);

      final goals = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/goals')),
      );
      expect(goals.tabIndex, 3);
      expect(goals.accountsSubTabIndex, 2);
    });

    test('parses settings and backup URLs', () async {
      final settings = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/settings')),
      );
      expect(settings.isSettings, isTrue);

      final backup = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/backup')),
      );
      expect(backup.isSettings, isTrue);
    });

    test('parses hash-based navigation URLs', () async {
      final hashAnalytics = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('http://localhost:8080/#/analytics')),
      );
      expect(hashAnalytics.tabIndex, 2);

      final hashBudgets = await parser.parseRouteInformation(
        RouteInformation(
          uri: Uri.parse('http://localhost:8080/#/accounts/budgets'),
        ),
      );
      expect(hashBudgets.tabIndex, 3);
      expect(hashBudgets.accountsSubTabIndex, 1);
    });

    test('restores canonical route information URLs', () {
      expect(
        parser
            .restoreRouteInformation(const AppRoutePath.dashboard())
            ?.uri
            .path,
        '/dashboard',
      );
      expect(
        parser.restoreRouteInformation(const AppRoutePath.ledger())?.uri.path,
        '/ledger',
      );
      expect(
        parser
            .restoreRouteInformation(const AppRoutePath.analytics())
            ?.uri
            .path,
        '/analytics',
      );
      expect(
        parser.restoreRouteInformation(const AppRoutePath.accounts())?.uri.path,
        '/accounts',
      );
      expect(
        parser
            .restoreRouteInformation(
              const AppRoutePath.accounts(subTabIndex: 1),
            )
            ?.uri
            .path,
        '/accounts/budgets',
      );
      expect(
        parser
            .restoreRouteInformation(
              const AppRoutePath.accounts(subTabIndex: 2),
            )
            ?.uri
            .path,
        '/accounts/sinking-funds',
      );
      expect(
        parser.restoreRouteInformation(const AppRoutePath.settings())?.uri.path,
        '/settings',
      );
    });
  });

  group('Issue #152: AppRouterDelegate History & Modal Dismissal', () {
    testWidgets('navigating tabs updates route path and retains history', (
      tester,
    ) async {
      late AppRouterDelegate routerDelegate;
      routerDelegate = AppRouterDelegate(
        mainScreenBuilder: (context, path, onNavigate, onOpenSettings) {
          return Scaffold(
            body: Column(
              children: [
                Text('Active: ${path.toPath()}'),
                ElevatedButton(
                  key: const Key('go_analytics'),
                  onPressed: () => onNavigate(2),
                  child: const Text('Go Analytics'),
                ),
                ElevatedButton(
                  key: const Key('go_settings'),
                  onPressed: onOpenSettings,
                  child: const Text('Go Settings'),
                ),
              ],
            ),
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerDelegate: routerDelegate,
          routeInformationParser: const AppRouteInformationParser(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active: /dashboard'), findsOneWidget);

      await tester.tap(find.byKey(const Key('go_analytics')));
      await tester.pumpAndSettle();
      expect(find.text('Active: /analytics'), findsOneWidget);
      expect(routerDelegate.currentPath, const AppRoutePath.analytics());

      // Browser back button should pop back to /dashboard
      final handledBack = await routerDelegate.popRoute();
      expect(handledBack, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Active: /dashboard'), findsOneWidget);
      expect(routerDelegate.currentPath, const AppRoutePath.dashboard());
    });

    testWidgets(
      'pressing browser back button dismisses open bottom sheet before leaving view',
      (tester) async {
        late AppRouterDelegate routerDelegate;
        routerDelegate = AppRouterDelegate(
          mainScreenBuilder: (context, path, onNavigate, onOpenSettings) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open_sheet'),
                  onPressed: () {
                    unawaited(
                      showModalBottomSheet(
                        context: context,
                        builder: (sheetContext) => const SizedBox(
                          key: Key('sample_bottom_sheet'),
                          height: 200,
                          child: Text('Open Sheet'),
                        ),
                      ),
                    );
                  },

                  child: const Text('Open Sheet'),
                ),
              ),
            );
          },
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerDelegate: routerDelegate,
            routeInformationParser: const AppRouteInformationParser(),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to Analytics first to establish history
        routerDelegate.setPath(const AppRoutePath.analytics());
        await tester.pumpAndSettle();
        expect(routerDelegate.currentPath, const AppRoutePath.analytics());

        // Open bottom sheet
        await tester.tap(find.byKey(const Key('open_sheet')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('sample_bottom_sheet')), findsOneWidget);

        // Press browser back button
        final poppedModal = await routerDelegate.popRoute();
        expect(poppedModal, isTrue);
        await tester.pumpAndSettle();

        // Sheet is dismissed, but current route is still /analytics
        expect(find.byKey(const Key('sample_bottom_sheet')), findsNothing);
        expect(routerDelegate.currentPath, const AppRoutePath.analytics());

        // Second back button goes back to previous route
        final poppedRoute = await routerDelegate.popRoute();
        expect(poppedRoute, isTrue);
        await tester.pumpAndSettle();
        expect(routerDelegate.currentPath, const AppRoutePath.dashboard());
      },
    );
  });

  group('Issue #152: Deep Link Direct Navigation & Page Reload State', () {
    testWidgets('direct deep link loads Spending Analytics view directly', (
      tester,
    ) async {
      await tester.pumpWidget(
        MoneyTrackerApp(
          routeInformationProvider: PlatformRouteInformationProvider(
            initialRouteInformation: RouteInformation(
              uri: Uri.parse('/analytics'),
            ),
          ),
        ),
      );
      await settleApp(tester);

      // Heading should immediately be Spending Analytics
      expect(find.text('Spending Analytics'), findsOneWidget);
    });

    testWidgets(
      'direct deep link to /accounts/budgets selects budget sub-tab',
      (tester) async {
        await tester.pumpWidget(
          MoneyTrackerApp(
            routeInformationProvider: PlatformRouteInformationProvider(
              initialRouteInformation: RouteInformation(
                uri: Uri.parse('/accounts/budgets'),
              ),
            ),
          ),
        );
        await settleApp(tester);

        expect(find.text('Monthly Budgets'), findsOneWidget);
      },
    );

    testWidgets(
      'direct deep link to /settings loads Settings & Backup screen',
      (tester) async {
        await tester.pumpWidget(
          MoneyTrackerApp(
            routeInformationProvider: PlatformRouteInformationProvider(
              initialRouteInformation: RouteInformation(
                uri: Uri.parse('/settings'),
              ),
            ),
          ),
        );
        await settleApp(tester);

        expect(find.text('Settings & Data'), findsOneWidget);
      },
    );
  });
}
