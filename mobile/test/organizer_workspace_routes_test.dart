import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/identity/workspace_models.dart';
import 'package:owambe/portals/customer/router/event_route_registry.dart';
import 'package:owambe/router/experience_routes.dart';

void main() {
  group('EventRouteRegistry.isOrganizerWorkspacePath', () {
    test('recognizes organizer shell routes', () {
      const shellPaths = [
        EventRouteRegistry.home,
        EventRouteRegistry.createEvent,
        EventRouteRegistry.myEvents,
        EventRouteRegistry.guestsHub,
        EventRouteRegistry.profile,
        '/guests/import',
        '/profile/settings',
      ];
      for (final path in shellPaths) {
        expect(EventRouteRegistry.isOrganizerWorkspacePath(path), isTrue, reason: path);
      }
    });

    test('recognizes event overview and modules', () {
      const paths = [
        '/events/evt_lagos_owanbe_2026',
        '/events/evt_lagos_owanbe_2026/guests',
        '/events/evt_lagos_owanbe_2026/tickets',
        '/events/evt_lagos_owanbe_2026/edit',
        '/events/evt_lagos_owanbe_2026/check-in',
        '/events/evt_lagos_owanbe_2026/live',
        '/events/evt_lagos_owanbe_2026/budget',
        '/events/evt_lagos_owanbe_2026/day',
        '/events/evt_lagos_owanbe_2026/wall/display',
      ];
      for (final path in paths) {
        expect(EventRouteRegistry.isOrganizerWorkspacePath(path), isTrue, reason: path);
      }
    });

    test('excludes public discovery and non-organizer workspaces', () {
      const excluded = [
        '/events',
        '/hub',
        '/attendee',
        '/vendor',
      ];
      for (final path in excluded) {
        expect(EventRouteRegistry.isOrganizerWorkspacePath(path), isFalse, reason: path);
      }
      // Shell reserved segments are organizer workspace (My Events, Create).
      expect(EventRouteRegistry.isOrganizerWorkspacePath('/events/mine'), isTrue);
      expect(EventRouteRegistry.isOrganizerWorkspacePath('/events/create'), isTrue);
    });
  });

  group('ExperienceRoutes.workspaceFromPath', () {
    test('maps organizer registry paths to organizer workspace', () {
      expect(
        ExperienceRoutes.workspaceFromPath('/events/create'),
        ExperienceWorkspace.organizer,
      );
      expect(
        ExperienceRoutes.workspaceFromPath('/events/evt_abc/guests'),
        ExperienceWorkspace.organizer,
      );
      expect(
        ExperienceRoutes.workspaceFromPath('/organizer/onboarding'),
        ExperienceWorkspace.organizer,
      );
    });

    test('does not map launcher or other workspaces', () {
      expect(ExperienceRoutes.workspaceFromPath('/hub'), isNull);
      expect(
        ExperienceRoutes.workspaceFromPath('/attendee/events/x'),
        ExperienceWorkspace.attendee,
      );
      expect(
        ExperienceRoutes.workspaceFromPath('/vendor'),
        ExperienceWorkspace.vendor,
      );
    });
  });
}
