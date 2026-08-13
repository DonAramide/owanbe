import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_notifier.dart';
import '../auth/auth_session.dart';
import '../auth/portal_role.dart';
import '../auth/user_role.dart';
import '../router/portal_routes.dart';
import 'identity_provider.dart';
import 'owanbe_identity_config.dart';
import 'user_identity.dart';
import 'workspace_access.dart';
import 'workspace_models.dart';

/// Workspace state for a single experience (from loaded identity).
final workspaceStateProvider = Provider.family<WorkspaceState?, ExperienceWorkspace>((ref, ws) {
  // valueOrNull: AsyncError must not throw into the widget tree (API down / Failed to fetch).
  final identity = ref.watch(userIdentityProvider).valueOrNull;
  if (identity == null) return null;
  return identity.workspaceState(ws);
});

/// True when the user has an active (fully onboarded) workspace.
final hasActiveWorkspaceProvider = Provider.family<bool, ExperienceWorkspace>((ref, ws) {
  if (OwanbeIdentityConfig.identityV2) {
    final identity = ref.watch(userIdentityProvider).valueOrNull;
    if (identity != null) return identity.canAccess(ws);
    return _legacyRoleMatches(ref.watch(authSessionProvider), ws);
  }
  return _legacyRoleMatches(ref.watch(authSessionProvider), ws);
});

/// True when user may open workspace routes (active or onboarding in progress).
final canEnterWorkspaceProvider = Provider.family<bool, ExperienceWorkspace>((ref, ws) {
  if (OwanbeIdentityConfig.identityV2) {
    final identity = ref.watch(userIdentityProvider).valueOrNull;
    if (identity != null) return identity.canEnter(ws);
    return _sessionHasRoleCode(ref.watch(authSessionProvider), ws.apiCode);
  }
  return _legacyRoleMatches(ref.watch(authSessionProvider), ws);
});

final isAttendeeWorkspaceProvider = Provider<bool>(
  (ref) => ref.watch(canEnterWorkspaceProvider(ExperienceWorkspace.attendee)),
);

final isOrganizerWorkspaceProvider = Provider<bool>(
  (ref) => ref.watch(canEnterWorkspaceProvider(ExperienceWorkspace.organizer)),
);

final isVendorWorkspaceProvider = Provider<bool>(
  (ref) => ref.watch(canEnterWorkspaceProvider(ExperienceWorkspace.vendor)),
);

bool _legacyRoleMatches(AuthSession? session, ExperienceWorkspace ws) {
  if (session == null) return false;
  return PortalRoutes.canonicalRole(session) == ws.userRole;
}

bool _sessionHasRoleCode(AuthSession? session, String code) {
  if (session == null) return false;
  if (session.roles.isNotEmpty) return session.hasRoleCode(code);
  return false;
}

/// Resolves the best [UserRole] for legacy session fields from API roles + active workspace.
UserRole resolveUniversalSessionRole({
  required List<String> apiRoles,
  String? signupPortal,
  ExperienceWorkspace? activeWorkspace,
}) {
  if (activeWorkspace != null) return activeWorkspace.userRole;
  if (OwanbeIdentityConfig.identityV2) {
    if (apiRoles.contains('organizer')) return UserRole.organizer;
    if (apiRoles.contains('vendor') || apiRoles.contains('vendor_pending')) {
      return UserRole.vendor;
    }
    if (apiRoles.contains('client')) return UserRole.client;
    if (apiRoles.any((r) => r.startsWith('admin') || r == 'platform_admin' || r == 'super_admin')) {
      return UserRole.admin;
    }
  }
  return resolvePortalRole(signupPortal: signupPortal, apiRoles: apiRoles);
}

/// Count of activated workspaces (for switcher UI).
final activatedWorkspaceCountProvider = Provider<int>((ref) {
  final identity = ref.watch(userIdentityProvider).valueOrNull;
  if (identity == null) return 0;
  return ExperienceWorkspace.values.where((ws) => identity.canAccess(ws)).length;
});

/// True when the user has an active (fully onboarded) workspace.
final canAccessWorkspaceProvider = Provider.family<bool, ExperienceWorkspace>((ref, ws) {
  final identity = ref.watch(userIdentityProvider).valueOrNull;
  return identity?.canAccess(ws) ?? false;
});
