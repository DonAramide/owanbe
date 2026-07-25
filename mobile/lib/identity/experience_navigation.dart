import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/app_entrypoint.dart';
import '../auth/user_role.dart';
import '../navigation/enterprise_navigation_service.dart';
import '../router/experience_routes.dart';
import '../router/portal_routes.dart';
import 'owanbe_identity_config.dart';
import 'user_identity.dart';
import 'workspace_lifecycle.dart';
import 'workspace_models.dart';

/// Entry navigation — Customer Hub vs Admin Control Tower by binary entrypoint.
abstract final class ExperienceNavigation {
  static String entryWhenSignedIn() {
    if (AppEntrypoint.isAdminApp) return ExperienceRoutes.adminHome;
    return OwanbeIdentityConfig.identityV2 ? ExperienceRoutes.hub : PortalRoutes.gate;
  }

  static String entryWhenSignedOut() {
    if (AppEntrypoint.isAdminApp) return ExperienceRoutes.adminAuth;
    return OwanbeIdentityConfig.identityV2 ? ExperienceRoutes.auth : PortalRoutes.gate;
  }

  static String afterSignOut() => entryWhenSignedOut();

  static String universalAuth() => entryWhenSignedOut();

  static String signInForRole(UserRole role) {
    if (role == UserRole.admin || role == UserRole.superAdmin) {
      return ExperienceRoutes.adminAuth;
    }
    if (OwanbeIdentityConfig.identityV2) return ExperienceRoutes.auth;
    return PortalRoutes.authFor(role);
  }

  static String workspaceHome(ExperienceWorkspace workspace) =>
      ExperienceRoutes.workspaceHomeFor(workspace);

  static String workspaceOnboarding(ExperienceWorkspace workspace) =>
      ExperienceRoutes.onboardingFor(workspace);

  static String workspaceActivate(ExperienceWorkspace workspace) =>
      ExperienceRoutes.activateFor(workspace);

  /// Universal Home — workspace launcher path.
  static String hub() => ExperienceRoutes.hub;

  /// Post sign-in: restore last workspace or launcher.
  static String postLogin(OwanbeUserIdentity? identity) =>
      WorkspaceLifecycle.postLoginDestination(identity);

  /// Return to launcher without signing out — path only (redirects/bootstrap).
  static String returnHome() => ExperienceRoutes.hub;

  /// **Single implementation for all UI "Home" / launcher navigation.**
  /// Never call [GoRouter.go] to `/hub` directly from screens.
  static void returnToHub(BuildContext context) {
    EnterpriseNavigationService(GoRouter.of(context)).returnToHub();
  }

  /// AppBar / explicit back — pop when possible, else enterprise fallback.
  static void navigateBack(BuildContext context) {
    EnterpriseNavigationService(GoRouter.of(context)).navigateBack();
  }

  /// Open workspace from launcher card.
  static String launcherTarget({
    required ExperienceWorkspace workspace,
    required WorkspaceState state,
  }) =>
      WorkspaceLifecycle.launcherDestination(workspace: workspace, state: state);
}
