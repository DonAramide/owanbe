import 'package:flutter/material.dart' show IconData, Icons;

import '../auth/auth_session.dart';
import '../auth/portal_role.dart';
import '../auth/user_role.dart';
import '../portals/customer/router/event_route_registry.dart';

/// Canonical paths for strict portal isolation (Phase 1).
abstract final class PortalRoutes {
  static const gate = '/portal-gate';

  static String authFor(UserRole role) => switch (role) {
        UserRole.client => '/auth/attendee',
        UserRole.organizer => '/auth/organizer',
        UserRole.vendor => '/auth/vendor',
        UserRole.admin => '/auth/admin',
        UserRole.superAdmin => '/auth/admin',
      };

  static String homeFor(UserRole role) => switch (role) {
        UserRole.client => '/attendee',
        UserRole.organizer => '/organizer',
        UserRole.vendor => '/vendor',
        UserRole.admin => '/admin',
        UserRole.superAdmin => '/super-admin',
      };

  static String onboardingFor(UserRole role) => switch (role) {
        UserRole.client => '/attendee/onboarding',
        UserRole.organizer => '/organizer/onboarding',
        UserRole.vendor => '/vendor/onboarding',
        UserRole.admin => '/admin',
        UserRole.superAdmin => '/super-admin',
      };

  static bool isOnboardingPath(String location) =>
      location == '/attendee/onboarding' ||
      location == '/organizer/onboarding' ||
      location == '/vendor/onboarding' ||
      location == '/onboarding/complete';

  /// Immutable portal from API — never the UI portal the user last tapped.
  static UserRole canonicalRole(AuthSession session) {
    if (session.signupPortal != null && session.signupPortal!.trim().isNotEmpty) {
      return roleFromSignupPortal(session.signupPortal);
    }
    return session.role;
  }

  static bool pathAllowedForSession(String location, AuthSession session) =>
      pathAllowedForRole(location, canonicalRole(session));

  /// True when the user still needs the portal first-time setup screen.
  static bool needsOnboarding(AuthSession session) {
    if (!session.onboardingComplete) return true;
    if (canonicalRole(session) != UserRole.client) return false;
    final email = session.email?.trim().toLowerCase() ?? '';
    final name = session.displayName.trim().toLowerCase();
    if (email.isEmpty) return false;
    return name.isEmpty || name == email || name == email.split('@').first;
  }

  static UserRole? roleFromAuthPath(String location) {
    return switch (location) {
      '/auth/attendee' => UserRole.client,
      '/auth/organizer' => UserRole.organizer,
      '/auth/vendor' => UserRole.vendor,
      '/auth/admin' => UserRole.admin,
      _ => null,
    };
  }

  /// Which portal owns a protected route the user tried to open.
  static UserRole? roleFromProtectedPath(String location) {
    if (location.startsWith('/attendee')) return UserRole.client;
    if (location.startsWith('/organizer')) return UserRole.organizer;
    if (location.startsWith('/vendor')) return UserRole.vendor;
    if (location.startsWith('/admin')) return UserRole.admin;
    if (location.startsWith('/super-admin')) return UserRole.superAdmin;
    if (location == '/home' || EventRouteRegistry.isShellPath(location)) {
      return UserRole.organizer;
    }
    if (EventRouteRegistry.isEventModulePath(location)) return UserRole.organizer;
    return null;
  }

  static bool isPortalAuthPath(String location) =>
      location == '/auth/attendee' ||
      location == '/auth/organizer' ||
      location == '/auth/vendor' ||
      location == '/auth/admin';

  static bool allowsGoogleSignIn(UserRole role) =>
      role == UserRole.client ||
      role == UserRole.organizer ||
      role == UserRole.vendor;

  /// Routes any user may visit (signed in or not).
  static bool isPublicPath(String location) {
    if (location == '/' ||
        location == gate ||
        location == '/walkthrough' ||
        location == '/diagnostics/supabase' ||
        location == '/events' ||
        location == '/checkout' ||
        location == '/payment/success') {
      return true;
    }
    if (location == '/vendors' || location.startsWith('/vendors/')) return true;
    if (isPortalAuthPath(location) || location == '/auth') return true;
    if (isOnboardingPath(location)) return true;
    if (location == '/onboarding/complete' || location == '/workspace-selection') return true;
    if (location.startsWith('/events/') && _isPublicEventPath(location)) return true;
    return false;
  }

  static bool _isPublicEventPath(String loc) {
    final match = RegExp(r'^/events/([^/]+)(?:/(.*))?$').firstMatch(loc);
    if (match == null) return false;
    final segment = match.group(1)!;
    if (segment == 'mine' || segment == 'create') return false;
    final sub = match.group(2);
    if (sub == null || sub.isEmpty) return true;
    if (sub == 'wall/display' || sub.startsWith('wall/display')) return true;
    final first = sub.split('/').first;
    // Attendee purchase only — organizer manage requires auth.
    if (first == 'tickets') return sub == 'tickets';
    return first == 'aso-ebi' || first == 'attire';
  }

  static bool pathAllowedForRole(String location, UserRole role) {
    if (isPublicPath(location)) return true;
    if (isOnboardingPath(location)) return true;

    if (location.startsWith('/attendee')) return role == UserRole.client;
    if (location.startsWith('/organizer')) return role == UserRole.organizer;
    if (location.startsWith('/vendor')) return role == UserRole.vendor;
    if (location.startsWith('/admin')) return role == UserRole.admin;
    if (location.startsWith('/super-admin')) return role == UserRole.superAdmin;

    if (EventRouteRegistry.isShellPath(location)) return role == UserRole.organizer;
    if (EventRouteRegistry.isEventModulePath(location)) return role == UserRole.organizer;

    if (location == '/staff/login' || location == '/login') {
      return role == UserRole.admin || role == UserRole.superAdmin;
    }

    return false;
  }
}

extension PortalRoleCopy on UserRole {
  String get portalTitle => switch (this) {
        UserRole.client => 'Attendee Portal',
        UserRole.organizer => 'Organizer Portal',
        UserRole.vendor => 'Vendor Portal',
        UserRole.admin => 'Admin Portal',
        UserRole.superAdmin => 'Control Tower',
      };

  String get portalSubtitle => switch (this) {
        UserRole.client => 'Tickets, invitations, and your celebration wallet.',
        UserRole.organizer => 'Plan events, manage guests, and run your celebration.',
        UserRole.vendor => 'Deliver services, manage orders, and grow your business.',
        UserRole.admin => 'Secure platform operations for Owanbe staff.',
        UserRole.superAdmin => 'Secure platform operations for Owanbe staff.',
      };

  String get gateLabel => switch (this) {
        UserRole.client => "I'm attending an event",
        UserRole.organizer => "I'm planning an event",
        UserRole.vendor => "I'm a vendor",
        UserRole.admin => 'Platform staff',
        UserRole.superAdmin => 'Platform staff',
      };

  IconData get gateIcon => switch (this) {
        UserRole.client => Icons.confirmation_number_outlined,
        UserRole.organizer => Icons.celebration_outlined,
        UserRole.vendor => Icons.storefront_outlined,
        UserRole.admin => Icons.admin_panel_settings_outlined,
        UserRole.superAdmin => Icons.admin_panel_settings_outlined,
      };
}
