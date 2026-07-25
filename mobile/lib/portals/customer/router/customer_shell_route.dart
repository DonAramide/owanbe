import 'package:go_router/go_router.dart';

import '../../../features/workspace/widgets/workspace_experience_shell.dart';
import '../../../identity/workspace_models.dart';
import '../screens/customer_create_event_screen.dart';
import '../screens/customer_guests_screen.dart';
import '../../organizer/screens/organizer_home_hub_screen.dart';
import '../screens/customer_my_events_screen.dart';
import '../screens/customer_profile_screen.dart';
import '../shell/customer_shell.dart';
import 'event_route_registry.dart';

/// Stateful shell route for the Customer Portal (route persistence per tab).
StatefulShellRoute customerShellRoute() {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) {
      return WorkspaceExperienceShell(
        workspace: ExperienceWorkspace.organizer,
        child: CustomerShell(navigationShell: navigationShell),
      );
    },
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: EventRouteRegistry.home,
            builder: (context, state) => const OrganizerHomeHubScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: EventRouteRegistry.myEvents,
            builder: (context, state) => const CustomerMyEventsScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: EventRouteRegistry.createEvent,
            builder: (context, state) => const CustomerCreateEventScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: EventRouteRegistry.guestsHub,
            builder: (context, state) => const CustomerGuestsScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: EventRouteRegistry.profile,
            builder: (context, state) => const CustomerProfileScreen(),
          ),
        ],
      ),
    ],
  );
}
