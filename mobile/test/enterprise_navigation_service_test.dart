import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:owambe/navigation/enterprise_back_handler.dart';
import 'package:owambe/navigation/enterprise_navigation_service.dart';
import 'package:owambe/navigation/enterprise_router_readiness.dart';
import 'package:owambe/router/experience_routes.dart';

void main() {
  group('EnterpriseRouterReadiness', () {
    test('isReady is false before router is mounted', () {
      final router = GoRouter(
        initialLocation: '/hub',
        routes: [
          GoRoute(path: '/hub', builder: (_, __) => const SizedBox.shrink()),
        ],
      );

      expect(EnterpriseRouterReadiness.isReady(router), isFalse);
      expect(EnterpriseRouterReadiness.currentPath(router), isNull);
    });
  });

  group('EnterpriseNavigationService — startup idle', () {
    late GoRouter router;
    late EnterpriseNavigationService navigation;

    setUp(() {
      router = GoRouter(
        initialLocation: '/hub',
        routes: [
          GoRoute(path: '/hub', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/home', builder: (_, __) => const SizedBox.shrink()),
        ],
      );
      navigation = EnterpriseNavigationService(router);
    });

    test('handleSystemBack is a no-op before router mounts', () {
      expect(navigation.isRouterReady, isFalse);
      expect(() => navigation.handleSystemBack(), returnsNormally);
    });

    test('returnToHub is a no-op before router mounts', () {
      expect(() => navigation.returnToHub(), returnsNormally);
    });

    test('canNavigateBack is false while idle', () {
      expect(navigation.canNavigateBack, isFalse);
    });
  });

  group('EnterpriseNavigationService — after mount', () {
    late GoRouter router;
    late EnterpriseNavigationService navigation;

    Future<void> pumpRouter(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );
      await tester.pumpAndSettle();
      navigation = EnterpriseNavigationService(router);
    }

    setUp(() {
      router = GoRouter(
        initialLocation: '/hub',
        routes: [
          GoRoute(path: '/hub', builder: (_, __) => const SizedBox.shrink()),
          GoRoute(path: '/home', builder: (_, __) => const SizedBox.shrink()),
        ],
      );
    });

    testWidgets('router becomes ready after mount', (tester) async {
      await pumpRouter(tester);

      expect(navigation.isRouterReady, isTrue);
      expect(navigation.currentLocation, '/hub');
      expect(navigation.canNavigateBack, isTrue);
    });

    testWidgets('handleSystemBack navigates from workspace root to hub', (tester) async {
      await pumpRouter(tester);

      router.go('/home');
      await tester.pumpAndSettle();
      navigation = EnterpriseNavigationService(router);

      navigation.handleSystemBack();
      await tester.pumpAndSettle();

      expect(EnterpriseRouterReadiness.currentPath(router), ExperienceRoutes.hub);
    });

    testWidgets('returnToHub uses injected router', (tester) async {
      await pumpRouter(tester);

      router.go('/home');
      await tester.pumpAndSettle();
      navigation = EnterpriseNavigationService(router);

      navigation.returnToHub();
      await tester.pumpAndSettle();

      expect(EnterpriseRouterReadiness.currentPath(router), ExperienceRoutes.hub);
    });
  });

  group('WorkspaceBackScope — cold start', () {
    testWidgets('first build does not throw before routes match', (tester) async {
      final router = GoRouter(
        initialLocation: '/hub',
        routes: [
          GoRoute(path: '/hub', builder: (_, __) => const WorkspaceBackScope(child: SizedBox.shrink())),
          GoRoute(path: '/home', builder: (_, __) => const SizedBox.shrink()),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('stress: 20 cold-start cycles without Bad state', (tester) async {
      for (var i = 0; i < 20; i++) {
        final router = GoRouter(
          initialLocation: '/hub',
          routes: [
            GoRoute(
              path: '/hub',
              builder: (_, __) => const WorkspaceBackScope(child: SizedBox.shrink()),
            ),
            GoRoute(path: '/home', builder: (_, __) => const SizedBox.shrink()),
            GoRoute(path: '/attendee', builder: (_, __) => const SizedBox.shrink()),
            GoRoute(path: '/vendor', builder: (_, __) => const SizedBox.shrink()),
          ],
        );
        final navigation = EnterpriseNavigationService(router);

        expect(navigation.isRouterReady, isFalse);
        navigation.handleSystemBack();

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.pumpAndSettle();
        final readyNavigation = EnterpriseNavigationService(router);
        expect(readyNavigation.isRouterReady, isTrue);

        for (final path in ['/home', '/hub', '/attendee', '/hub', '/vendor', '/hub']) {
          router.go(path);
          await tester.pumpAndSettle();
          readyNavigation.handleSystemBack();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    });
  });
}
