import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashflow/navigation/app_router.dart';
import 'package:cashflow/services/database_io_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chrome Web Declarative Routing & History', () {
    const parser = AppRouteInformationParser();

    test(
      'persists, reads, and deletes walkthrough snapshots in web storage',
      () {
        const sample = '{"snapshot": "web_demo_data"}';
        DatabaseIoHelper.writeWalkthroughSnapshot('', sample);
        expect(DatabaseIoHelper.readWalkthroughSnapshot(''), sample);
        DatabaseIoHelper.deleteWalkthroughSnapshot('');
        expect(DatabaseIoHelper.readWalkthroughSnapshot(''), isNull);
      },
    );

    test('parses web URLs into route paths', () async {
      expect(
        (await parser.parseRouteInformation(
          RouteInformation(uri: Uri.parse('/')),
        )).tabIndex,
        0,
      );
      expect(
        (await parser.parseRouteInformation(
          RouteInformation(uri: Uri.parse('/dashboard')),
        )).tabIndex,
        0,
      );
      expect(
        (await parser.parseRouteInformation(
          RouteInformation(uri: Uri.parse('/ledger')),
        )).tabIndex,
        1,
      );
      expect(
        (await parser.parseRouteInformation(
          RouteInformation(uri: Uri.parse('/analytics')),
        )).tabIndex,
        2,
      );
      expect(
        (await parser.parseRouteInformation(
          RouteInformation(uri: Uri.parse('/accounts')),
        )).tabIndex,
        3,
      );
      expect(
        (await parser.parseRouteInformation(
          RouteInformation(uri: Uri.parse('/accounts/budgets')),
        )).accountsSubTabIndex,
        1,
      );
      expect(
        (await parser.parseRouteInformation(
          RouteInformation(uri: Uri.parse('/accounts/sinking-funds')),
        )).accountsSubTabIndex,
        2,
      );
      expect(
        (await parser.parseRouteInformation(
          RouteInformation(uri: Uri.parse('/settings')),
        )).isSettings,
        isTrue,
      );
    });

    test('parses hash fragments in browser address bar', () async {
      final route = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('http://localhost:8080/#/analytics')),
      );
      expect(route.tabIndex, 2);
    });

    test('restores browser URL paths', () {
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

    testWidgets('AppRouterDelegate updates active tab and history on web', (
      tester,
    ) async {
      late AppRouterDelegate delegate;
      delegate = AppRouterDelegate(
        mainScreenBuilder: (context, path, onNavigate, onOpenSettings) {
          return Scaffold(
            body: Center(child: Text('CurrentPath: ${path.toPath()}')),
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerDelegate: delegate,
          routeInformationParser: parser,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CurrentPath: /dashboard'), findsOneWidget);

      delegate.onNavigateTab(2);
      await tester.pumpAndSettle();
      expect(find.text('CurrentPath: /analytics'), findsOneWidget);

      delegate.openSettings();
      await tester.pumpAndSettle();
      expect(delegate.currentPath.isSettings, isTrue);

      final poppedSettings = await delegate.popRoute();
      expect(poppedSettings, isTrue);
      await tester.pumpAndSettle();
      expect(delegate.currentPath, const AppRoutePath.analytics());

      final poppedTab = await delegate.popRoute();
      expect(poppedTab, isTrue);
      await tester.pumpAndSettle();
      expect(delegate.currentPath, const AppRoutePath.dashboard());
    });
  });
}
