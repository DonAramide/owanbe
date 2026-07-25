import 'user_identity.dart';
import 'workspace_models.dart';
import '../router/experience_routes.dart';

/// Workspace lifecycle — enter, restore, and post-auth routing (Owanbe 2.0 Phase 3).
abstract final class WorkspaceLifecycle {
  /// Phase 4: Living Home is always the first landing after sign-in.
  static String postLoginDestination(OwanbeUserIdentity? identity) {
    return ExperienceRoutes.hub;
  }

  /// Returns the workspace to restore after re-login, or null for launcher-only.
  static ExperienceWorkspace? restoreWorkspace(OwanbeUserIdentity identity) {
    final last = ExperienceWorkspace.fromApiCode(identity.lastActiveWorkspace);
    if (last != null && identity.canAccess(last)) return last;
    return identity.suggestedWorkspace;
  }

  /// Destination when opening a workspace from the launcher.
  static String launcherDestination({
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

  /// Whether the user may navigate directly into a workspace route.
  static bool canOpenWorkspaceRoute({
    required OwanbeUserIdentity identity,
    required ExperienceWorkspace workspace,
  }) {
    return identity.canEnter(workspace);
  }
}
