import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_notifier.dart';
import '../auth/user_role.dart';
import '../features/admin/admin_home_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/client/client_home_screen.dart';
import '../features/vendor/vendor_home_screen.dart';
import 'router_notifier.dart';

String _homePath(UserRole role) => switch (role) {
      UserRole.client => '/client',
      UserRole.vendor => '/vendor',
      UserRole.admin => '/admin',
    };

bool _pathAllowedForRole(String location, UserRole role) {
  if (location.startsWith('/client')) return role == UserRole.client;
  if (location.startsWith('/vendor')) return role == UserRole.vendor;
  if (location.startsWith('/admin')) return role == UserRole.admin;
  return true;
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = RouterNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(authSessionProvider);
      final loc = state.matchedLocation;
      final loggingIn = loc == '/login';

      if (session == null) {
        return loggingIn ? null : '/login';
      }

      if (loggingIn) {
        return _homePath(session.role);
      }

      if (!_pathAllowedForRole(loc, session.role)) {
        return _homePath(session.role);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/client',
        name: 'client',
        builder: (context, state) => const ClientHomeScreen(),
      ),
      GoRoute(
        path: '/vendor',
        name: 'vendor',
        builder: (context, state) => const VendorHomeScreen(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminHomeScreen(),
      ),
    ],
  );
});
