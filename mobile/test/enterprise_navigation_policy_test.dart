import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/navigation/enterprise_navigation_policy.dart';
import 'package:owambe/portals/customer/router/event_route_registry.dart';
import 'package:owambe/router/experience_routes.dart';

void main() {
  group('EnterpriseNavigationPolicy.classify', () {
    test('hub and workspaces', () {
      expect(EnterpriseNavigationPolicy.classify('/hub'), NavigationZone.hub);
      expect(EnterpriseNavigationPolicy.classify('/home'), NavigationZone.organizerShell);
      expect(EnterpriseNavigationPolicy.classify('/attendee'), NavigationZone.attendeeRoot);
      expect(EnterpriseNavigationPolicy.classify('/vendor'), NavigationZone.vendorRoot);
      expect(EnterpriseNavigationPolicy.classify('/portfolio'), NavigationZone.organizerPortfolio);
    });

    test('event desktop and modules', () {
      expect(
        EnterpriseNavigationPolicy.classify('/events/abc123'),
        NavigationZone.eventOverview,
      );
      expect(
        EnterpriseNavigationPolicy.classify('/events/abc123/guests'),
        NavigationZone.eventModule,
      );
      expect(
        EnterpriseNavigationPolicy.classify('/events/abc123/ai-planner'),
        NavigationZone.eventModule,
      );
    });
  });

  group('EnterpriseNavigationPolicy.resolveBackFallback', () {
    test('hub is the only exit zone', () {
      expect(EnterpriseNavigationPolicy.resolveBackFallback('/hub'), isNull);
      expect(EnterpriseNavigationPolicy.allowsAppExit('/hub'), isTrue);
    });

    test('workspace roots fall back to hub', () {
      expect(
        EnterpriseNavigationPolicy.resolveBackFallback('/home'),
        ExperienceRoutes.hub,
      );
      expect(
        EnterpriseNavigationPolicy.resolveBackFallback('/attendee'),
        ExperienceRoutes.hub,
      );
      expect(
        EnterpriseNavigationPolicy.resolveBackFallback('/vendor'),
        ExperienceRoutes.hub,
      );
    });

    test('event hierarchy', () {
      expect(
        EnterpriseNavigationPolicy.resolveBackFallback('/events/e1/guests'),
        EventRouteRegistry.event('e1'),
      );
      expect(
        EnterpriseNavigationPolicy.resolveBackFallback('/events/e1'),
        EventRouteRegistry.home,
      );
      expect(
        EnterpriseNavigationPolicy.resolveBackFallback('/portfolio'),
        ExperienceRoutes.hub,
      );
    });

    test('attendee sub-flow fallbacks', () {
      expect(
        EnterpriseNavigationPolicy.resolveBackFallback('/attendee/events/e1/tickets'),
        '/attendee/events/e1',
      );
      expect(
        EnterpriseNavigationPolicy.resolveBackFallback('/attendee/events/e1'),
        '/attendee',
      );
    });
  });

  group('validation matrix (policy-level)', () {
    const eventId = 'evt-1';

    test('Hub → Organizer → back fallback → Hub', () {
      expect(
        EnterpriseNavigationPolicy.resolveBackFallback(EventRouteRegistry.home),
        ExperienceRoutes.hub,
      );
    });

    test('Hub → Attendee → back fallback → Hub', () {
      expect(
        EnterpriseNavigationPolicy.resolveBackFallback('/attendee'),
        ExperienceRoutes.hub,
      );
    });

    test('Hub → Vendor → back fallback → Hub', () {
      expect(
        EnterpriseNavigationPolicy.resolveBackFallback('/vendor'),
        ExperienceRoutes.hub,
      );
    });

    test('Event Desktop → back fallback → Organizer', () {
      expect(
        EnterpriseNavigationPolicy.resolveBackFallback(EventRouteRegistry.event(eventId)),
        EventRouteRegistry.home,
      );
    });

    test('Event Module → back fallback → Event Desktop', () {
      expect(
        EnterpriseNavigationPolicy.resolveBackFallback(
          EventRouteRegistry.eventGuests(eventId),
        ),
        EventRouteRegistry.event(eventId),
      );
    });

    test('Organizer shell → back fallback → Hub', () {
      expect(
        EnterpriseNavigationPolicy.resolveBackFallback('/guests'),
        ExperienceRoutes.hub,
      );
    });

    test('Hub → back → app may exit', () {
      expect(EnterpriseNavigationPolicy.allowsAppExit('/hub'), isTrue);
      expect(EnterpriseNavigationPolicy.resolveBackFallback('/hub'), isNull);
    });
  });
}
