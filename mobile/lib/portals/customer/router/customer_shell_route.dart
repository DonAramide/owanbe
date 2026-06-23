import 'package:go_router/go_router.dart';

import '../screens/customer_create_event_screen.dart';
import '../screens/customer_guests_screen.dart';
import '../screens/customer_home_screen.dart';
import '../screens/customer_my_events_screen.dart';
import '../screens/customer_profile_screen.dart';
import '../shell/customer_shell.dart';
import 'customer_routes.dart';

/// Stateful shell route for the Customer Portal (route persistence per tab).
StatefulShellRoute customerShellRoute() {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) {
      return CustomerShell(navigationShell: navigationShell);
    },
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: CustomerRoutes.home,
            builder: (context, state) => const CustomerHomeScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: CustomerRoutes.myEvents,
            builder: (context, state) => const CustomerMyEventsScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: CustomerRoutes.createEvent,
            builder: (context, state) => const CustomerCreateEventScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: CustomerRoutes.guests,
            builder: (context, state) => const CustomerGuestsScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: CustomerRoutes.profile,
            builder: (context, state) => const CustomerProfileScreen(),
          ),
        ],
      ),
    ],
  );
}
