import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_session.dart';
import '../identity/owanbe_identity_config.dart';
import '../identity/user_identity.dart';
import '../identity/workspace_models.dart';
import 'experience_routes.dart';
import 'portal_routes.dart';

/// Workspace-aware route guards for Owanbe 2.0 (sync — uses cached identity).
String? experienceWorkspaceRouteGuard({
  required String loc,
  required AuthSession? session,
  OwanbeUserIdentity? identity,
}) {
  if (!OwanbeIdentityConfig.identityV2 || session == null) return null;

  final workspace = ExperienceRoutes.workspaceFromPath(loc);
  if (workspace == null) return null;

  if (ExperienceRoutes.isActivationPath(loc) || PortalRoutes.isOnboardingPath(loc)) {
    return null;
  }

  if (identity == null) return null;

  final state = identity.workspaceState(workspace);

  if (state.status == WorkspaceStatus.notActivated) {
    return ExperienceRoutes.activateFor(workspace);
  }

  if (state.status == WorkspaceStatus.inProgress && !PortalRoutes.isOnboardingPath(loc)) {
    return ExperienceRoutes.onboardingFor(workspace);
  }

  if (state.status == WorkspaceStatus.suspended) {
    return ExperienceRoutes.hub;
  }

  return null;
}

/// Post-auth destination for a workspace (onboarding vs home).
String resolveWorkspacePostAuthDestination({
  required ExperienceWorkspace workspace,
  required WorkspaceState state,
}) {
  return switch (state.status) {
    WorkspaceStatus.active => ExperienceRoutes.workspaceHomeFor(workspace),
    WorkspaceStatus.inProgress => ExperienceRoutes.onboardingFor(workspace),
    WorkspaceStatus.notActivated => ExperienceRoutes.activateFor(workspace),
    WorkspaceStatus.suspended => ExperienceRoutes.hub,
  };
}
