import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_notifier.dart';
import '../auth/user_role.dart';
import '../features/super_admin/screens/platform_configuration_screen.dart';
import '../features/super_admin/super_admin_home_screen.dart';
import '../features/admin/admin_home_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/public/screens/attendee_dashboard_screen.dart';
import '../features/public/screens/checkout_screen.dart';
import '../features/public/screens/discover_screen.dart';
import '../portals/customer/screens/customer_event_ai_planner_screen.dart';
import '../portals/customer/screens/customer_event_budget_screen.dart';
import '../portals/customer/screens/marketplace_screen.dart';
import '../portals/customer/screens/marketplace_vendor_detail_screen.dart';
import '../portals/customer/screens/customer_event_guests_screen.dart';
import '../portals/customer/screens/customer_event_invitations_screen.dart';
import '../portals/customer/screens/customer_event_route_screen.dart';
import '../portals/customer/screens/customer_event_day_screen.dart';
import '../portals/customer/screens/customer_event_website_screen.dart';
import '../portals/customer/screens/customer_event_wall_screen.dart';
import '../portals/customer/screens/customer_event_wall_display_screen.dart';
import '../portals/customer/screens/customer_event_attire_screen.dart';
import '../portals/customer/screens/customer_event_rentals_screen.dart';
import '../portals/customer/screens/customer_event_seating_screen.dart';
import '../portals/customer/screens/marketplace_rentals_screen.dart';
import '../portals/customer/screens/customer_event_aso_ebi_screen.dart';
import '../features/vendor/screens/vendor_fashion_attire_screen.dart';
import '../features/vendor/screens/vendor_rentals_screen.dart';
import '../features/public/screens/landing_screen.dart';
import '../features/public/screens/payment_success_screen.dart';
import '../features/public/screens/public_auth_screen.dart';
import '../features/public/screens/ticket_select_screen.dart';
import '../features/organizer/wizard_v2/event_create_wizard_v2_screen.dart';
import '../features/organizer/screens/event_workspace_screen.dart';
import '../features/organizer/screens/organizer_home_screen.dart';
import '../features/vendor/vendor_home_screen.dart';
import '../portals/customer/router/customer_routes.dart';
import '../portals/customer/router/customer_shell_route.dart';
import 'router_notifier.dart';

String _homePath(UserRole role) => switch (role) {
      UserRole.client => '/home',
      UserRole.organizer => '/organizer',
      UserRole.vendor => '/vendor',
      UserRole.admin => '/admin',
      UserRole.superAdmin => '/super-admin',
    };

bool _isPublicPath(String loc) {
  if (loc == '/') return true;
  if (loc == '/events') return true;
  if (loc == '/vendors' || loc.startsWith('/vendors/')) return true;
  if (loc == '/checkout') return true;
  if (loc.startsWith('/auth')) return true;
  if (loc == '/payment/success') return true;

  if (CustomerRoutes.isShellPath(loc)) return false;

  final match = RegExp(r'^/events/([^/]+)').firstMatch(loc);
  if (match != null) {
    final segment = match.group(1)!;
    if (segment != 'mine' && segment != 'create') return true;
  }
  return false;
}

bool _pathAllowedForRole(String location, UserRole role) {
  if (CustomerRoutes.isShellPath(location)) return role == UserRole.client;
  if (location.startsWith('/attendee')) return true;
  if (location.startsWith('/organizer')) return role == UserRole.organizer;
  if (location.startsWith('/vendor')) return role == UserRole.vendor;
  if (location.startsWith('/admin')) return role == UserRole.admin;
  if (location.startsWith('/super-admin')) return role == UserRole.superAdmin;
  if (location.startsWith('/client')) return role == UserRole.client;
  return true;
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = RouterNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(authSessionProvider);
      final loc = state.matchedLocation;

      if (CustomerRoutes.isShellPath(loc)) {
        if (session == null) {
          return '/auth?return=${Uri.encodeComponent(loc)}';
        }
        if (session.role != UserRole.client) {
          return _homePath(session.role);
        }
        return null;
      }

      // Public marketplace — always accessible (except attendee dashboard).
      if (_isPublicPath(loc)) {
        if (loc.startsWith('/auth')) return null;
        return null;
      }

      if (loc == '/attendee') {
        if (session == null) {
          return '/auth?return=/attendee';
        }
        return null;
      }

      if (loc == '/staff/login') {
        if (session != null) {
          return _homePath(session.role);
        }
        return null;
      }

      if (loc.startsWith('/organizer')) {
        if (session == null) {
          return '/staff/login';
        }
        if (session.role != UserRole.organizer) {
          return _homePath(session.role);
        }
        return null;
      }

      if (loc.startsWith('/vendor')) {
        if (session == null) {
          return '/staff/login?role=vendor';
        }
        if (session.role != UserRole.vendor) {
          return _homePath(session.role);
        }
        return null;
      }

      if (loc.startsWith('/admin')) {
        if (session == null) {
          return '/staff/login?role=admin';
        }
        if (session.role != UserRole.admin) {
          return _homePath(session.role);
        }
        return null;
      }

      if (loc.startsWith('/super-admin')) {
        if (session == null) {
          return '/staff/login?role=superAdmin';
        }
        if (session.role != UserRole.superAdmin) {
          return _homePath(session.role);
        }
        return null;
      }

      if (session == null) {
        return null;
      }

      if (loc == '/login' || loc == '/client') {
        return _homePath(session.role);
      }

      if (!_pathAllowedForRole(loc, session.role)) {
        return _homePath(session.role);
      }

      return null;
    },
    routes: [
      customerShellRoute(),
      GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
      GoRoute(
        path: '/events',
        builder: (context, state) => const DiscoverScreen(),
        routes: [
          GoRoute(
            path: ':id',
            redirect: (context, state) {
              final id = state.pathParameters['id'];
              if (id == 'mine') return CustomerRoutes.myEvents;
              if (id == 'create') return CustomerRoutes.createEvent;
              return null;
            },
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return CustomerEventRouteScreen(eventId: id);
            },
            routes: [
              GoRoute(
                path: 'tickets',
                builder: (context, state) => TicketSelectScreen(eventId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'budget',
                builder: (context, state) => CustomerEventBudgetScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'guests',
                builder: (context, state) => CustomerEventGuestsScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'invitations',
                builder: (context, state) => CustomerEventInvitationsScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'ai-planner',
                builder: (context, state) => CustomerEventAiPlannerScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'day',
                builder: (context, state) => CustomerEventDayScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'website',
                builder: (context, state) => CustomerEventWebsiteScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'wall',
                builder: (context, state) => CustomerEventWallScreen(
                  eventId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'display',
                    builder: (context, state) => CustomerEventWallDisplayScreen(
                      eventId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'attire',
                builder: (context, state) => CustomerEventAttireScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'rentals',
                builder: (context, state) => CustomerEventRentalsScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'seating',
                builder: (context, state) => CustomerEventSeatingScreen(
                  eventId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'aso-ebi',
                redirect: (context, state) =>
                    '/events/${state.pathParameters['id']}/attire',
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/vendors',
        builder: (context, state) => const MarketplaceScreen(),
        routes: [
          GoRoute(
            path: 'rentals',
            builder: (context, state) => MarketplaceRentalsScreen(
              eventId: state.uri.queryParameters['eventId'],
            ),
          ),
          GoRoute(
            path: ':vendorId',
            builder: (context, state) => MarketplaceVendorDetailScreen(
              vendorId: state.pathParameters['vendorId']!,
            ),
          ),
        ],
      ),
      GoRoute(path: '/checkout', builder: (context, state) => const CheckoutScreen()),
      GoRoute(
        path: '/auth',
        builder: (context, state) => PublicAuthScreen(
          returnPath: state.uri.queryParameters['return'] ?? '/home',
        ),
      ),
      GoRoute(path: '/payment/success', builder: (context, state) => const PaymentSuccessScreen()),
      GoRoute(path: '/attendee', builder: (context, state) => const AttendeeDashboardScreen()),
      GoRoute(
        path: '/staff/login',
        name: 'staff-login',
        builder: (context, state) => LoginScreen(
          initialRole: _roleFromQuery(state.uri.queryParameters['role']),
        ),
      ),
      GoRoute(path: '/login', redirect: (context, state) => '/staff/login'),
      GoRoute(
        path: '/vendor',
        builder: (context, state) => const VendorHomeScreen(),
        routes: [
          GoRoute(
            path: 'fashion-attire',
            builder: (context, state) => const VendorFashionAttireScreen(),
          ),
          GoRoute(
            path: 'rentals',
            builder: (context, state) => const VendorRentalsScreen(),
          ),
        ],
      ),
      GoRoute(path: '/admin', builder: (context, state) => const AdminHomeScreen()),
      GoRoute(path: '/super-admin', builder: (context, state) => const SuperAdminHomeScreen()),
      GoRoute(
        path: '/super-admin/platform-config',
        builder: (context, state) => const PlatformConfigurationScreen(),
      ),
      GoRoute(
        path: '/organizer',
        builder: (context, state) => const OrganizerHomeScreen(),
        routes: [
          GoRoute(
            path: 'events/new',
            builder: (context, state) => const EventCreateWizardV2Screen(),
          ),
          GoRoute(
            path: 'events/:eventId',
            builder: (context, state) => EventWorkspaceScreen(
              eventId: state.pathParameters['eventId']!,
              initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0,
              initialTabKey: state.uri.queryParameters['tabKey'],
            ),
          ),
        ],
      ),
      GoRoute(path: '/client', redirect: (context, state) => '/home'),
    ],
  );
});

UserRole? _roleFromQuery(String? value) {
  if (value == null) return null;
  for (final role in UserRole.values) {
    if (role.name == value) return role;
  }
  return null;
}
