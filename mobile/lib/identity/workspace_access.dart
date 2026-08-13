import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_notifier.dart';
import '../auth/auth_session.dart';
import '../auth/user_role.dart';
import '../identity/identity_provider.dart';
import '../identity/owanbe_identity_config.dart';
import '../identity/user_identity.dart';
import '../identity/workspace_models.dart';
import '../router/portal_routes.dart';

/// Resolves whether the signed-in user may enter a workspace experience.
///
/// Owanbe 2.0: uses [OwanbeUserIdentity.workspaces] (multi-role safe).
/// Legacy: falls back to immutable [signupPortal] / single role.
bool canEnterWorkspaceExperience({
  required UserRole requiredRole,
  OwanbeUserIdentity? identity,
  AuthSession? session,
}) {
  if (OwanbeIdentityConfig.identityV2 && identity != null) {
    final workspace = ExperienceWorkspace.fromUserRole(requiredRole);
    if (workspace == null) {
      return _legacyPortalAllows(requiredRole, session);
    }
    return identity.canEnter(workspace);
  }
  return _legacyPortalAllows(requiredRole, session);
}

bool _legacyPortalAllows(UserRole requiredRole, AuthSession? session) {
  if (session == null) return true;
  return PortalRoutes.canonicalRole(session) == requiredRole;
}

/// Watches identity and returns whether the user can enter [requiredRole]'s workspace.
final canEnterWorkspaceByRoleProvider = Provider.family<bool, UserRole>((ref, requiredRole) {
  final identity = ref.watch(userIdentityProvider).valueOrNull;
  final session = ref.watch(authSessionProvider);
  return canEnterWorkspaceExperience(
    requiredRole: requiredRole,
    identity: identity,
    session: session,
  );
});
