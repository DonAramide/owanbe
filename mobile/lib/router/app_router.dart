import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_notifier.dart';
import '../auth/user_role.dart';
import '../features/admin/admin_home_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/public/screens/attendee_dashboard_screen.dart';
import '../features/public/screens/checkout_screen.dart';
import '../features/public/screens/discover_screen.dart';
import '../features/public/screens/event_detail_screen.dart';
import '../features/public/screens/landing_screen.dart';
import '../features/public/screens/payment_success_screen.dart';
import '../features/public/screens/public_auth_screen.dart';
import '../features/public/screens/ticket_select_screen.dart';
import '../features/organizer/screens/event_create_wizard_screen.dart';
import '../features/organizer/screens/event_workspace_screen.dart';
import '../features/organizer/screens/organizer_home_screen.dart';
import '../features/vendor/vendor_home_screen.dart';
import 'router_notifier.dart';

String _homePath(UserRole role) => switch (role) {
      UserRole.client => '/attendee',
      UserRole.organizer => '/organizer',
      UserRole.vendor => '/vendor',
      UserRole.admin => '/admin',
    };

bool _isPublicPath(String loc) {
  if (loc == '/') return true;
  if (loc.startsWith('/events')) return true;
  if (loc == '/checkout') return true;
  if (loc.startsWith('/auth')) return true;
  if (loc == '/payment/success') return true;
  return false;
}

bool _pathAllowedForRole(String location, UserRole role) {
  if (location.startsWith('/attendee')) return role == UserRole.client;
  if (location.startsWith('/organizer')) return role == UserRole.organizer;
  if (location.startsWith('/vendor')) return role == UserRole.vendor;
  if (location.startsWith('/admin')) return role == UserRole.admin;
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

      // Public marketplace — always accessible (except attendee dashboard).
      if (_isPublicPath(loc)) {
        if (loc.startsWith('/auth')) return null;
        return null;
      }

      if (loc == '/attendee') {
        if (session == null) {
          return '/auth?return=/attendee';
        }
        if (session.role != UserRole.client) {
          return _homePath(session.role);
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

      if (session == null) {
        return '/';
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
      GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
      GoRoute(path: '/events', builder: (context, state) => const DiscoverScreen()),
      GoRoute(
        path: '/events/:id',
        builder: (context, state) => EventDetailScreen(eventId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'tickets',
            builder: (context, state) => TicketSelectScreen(eventId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(path: '/checkout', builder: (context, state) => const CheckoutScreen()),
      GoRoute(
        path: '/auth',
        builder: (context, state) => PublicAuthScreen(
          returnPath: state.uri.queryParameters['return'] ?? '/attendee',
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
      GoRoute(path: '/vendor', builder: (context, state) => const VendorHomeScreen()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminHomeScreen()),
      GoRoute(
        path: '/organizer',
        builder: (context, state) => const OrganizerHomeScreen(),
        routes: [
          GoRoute(
            path: 'events/new',
            builder: (context, state) => const EventCreateWizardScreen(),
          ),
          GoRoute(
            path: 'events/:eventId',
            builder: (context, state) => EventWorkspaceScreen(
              eventId: state.pathParameters['eventId']!,
              initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0,
            ),
          ),
        ],
      ),
      GoRoute(path: '/client', redirect: (context, state) => '/attendee'),
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
