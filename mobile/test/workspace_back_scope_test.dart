import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:owambe/navigation/enterprise_back_handler.dart';
import 'package:owambe/navigation/enterprise_navigation_policy.dart';
import 'package:owambe/navigation/enterprise_navigation_service.dart';
import 'package:owambe/navigation/enterprise_router_readiness.dart';

void main() {
  group('WorkspaceBackScope — in-route integration', () {
    testWidgets('Android back on workspace root navigates to hub', (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/hub',
            builder: (_, __) => const Scaffold(body: Text('Hub')),
          ),
          GoRoute(
            path: '/home',
            builder: (_, __) => const WorkspaceBackScope(
              child: Scaffold(body: Text('Organizer')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Organizer'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Hub'), findsOneWidget);
      expect(EnterpriseRouterReadiness.currentPath(router), '/hub');
    });

    testWidgets('Android back on pushed event module pops to event desktop', (tester) async {
      final router = GoRouter(
        initialLocation: '/events/e1/guests',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('Organizer')),
          ),
          GoRoute(
            path: '/events/:id',
            builder: (_, __) => const WorkspaceBackScope(
              child: Scaffold(body: Text('Event Desktop')),
            ),
            routes: [
              GoRoute(
                path: 'guests',
                builder: (_, __) => const WorkspaceBackScope(
                  child: Scaffold(body: Text('Guests')),
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Guests'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Event Desktop'), findsOneWidget);
      expect(EnterpriseRouterReadiness.currentPath(router), '/events/e1');
    });

    testWidgets('hub back scope classifies exit zone', (tester) async {
      final router = GoRouter(
        initialLocation: '/hub',
        routes: [
          GoRoute(
            path: '/hub',
            builder: (_, __) => const WorkspaceBackScope(
              child: Scaffold(body: Text('Hub')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final navigation = EnterpriseNavigationService(router);
      expect(navigation.currentLocation, '/hub');
      expect(EnterpriseNavigationPolicy.allowsAppExit('/hub'), isTrue);
    });
  });
}
