import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/auth/user_role.dart';
import 'package:owambe/identity/experience_navigation.dart';
import 'package:owambe/identity/owanbe_identity_config.dart';
import 'package:owambe/identity/user_identity.dart';
import 'package:owambe/identity/workspace_lifecycle.dart';
import 'package:owambe/identity/workspace_models.dart';
import 'package:owambe/identity/workspace_providers.dart';
import 'package:owambe/router/experience_routes.dart';

void main() {
  group('Unified Identity Phase 1', () {
    test('production identity v2 is enabled', () {
      expect(OwanbeIdentityConfig.identityV2, isTrue);
      expect(OwanbeIdentityConfig.productionUsesDevSeedAccounts, isFalse);
    });

    test('post-login always lands on Hub', () {
      expect(WorkspaceLifecycle.postLoginDestination(null), ExperienceRoutes.hub);
      expect(
        WorkspaceLifecycle.postLoginDestination(
          OwanbeUserIdentity(
            userId: 'u1',
            email: 'new@example.com',
            displayName: 'New User',
            roles: const [],
            workspaces: const [],
          ),
        ),
        ExperienceRoutes.hub,
      );
    });

    test('one identity envelope supports three workspace states', () {
      final identity = OwanbeUserIdentity(
        userId: 'u1',
        email: 'traveler@example.com',
        displayName: 'Traveler',
        roles: const ['client', 'organizer', 'vendor'],
        workspaces: const [
          WorkspaceState(workspace: ExperienceWorkspace.attendee, status: WorkspaceStatus.active),
          WorkspaceState(workspace: ExperienceWorkspace.organizer, status: WorkspaceStatus.inProgress),
          WorkspaceState(workspace: ExperienceWorkspace.vendor, status: WorkspaceStatus.notActivated),
        ],
      );

      expect(identity.canAccess(ExperienceWorkspace.attendee), isTrue);
      expect(identity.canEnter(ExperienceWorkspace.organizer), isTrue);
      expect(identity.canEnter(ExperienceWorkspace.vendor), isFalse);
      expect(identity.workspaceState(ExperienceWorkspace.vendor).needsActivation, isTrue);
    });

    test('launcher routes not-activated workspace to activation (no re-auth)', () {
      final target = WorkspaceLifecycle.launcherDestination(
        workspace: ExperienceWorkspace.vendor,
        state: const WorkspaceState(
          workspace: ExperienceWorkspace.vendor,
          status: WorkspaceStatus.notActivated,
        ),
      );
      expect(target, ExperienceRoutes.activateFor(ExperienceWorkspace.vendor));
    });

    test('returnToHub path is Hub not sign-out', () {
      expect(ExperienceNavigation.returnHome(), ExperienceRoutes.hub);
      expect(ExperienceNavigation.afterSignOut(), isNot(ExperienceRoutes.hub));
    });

    test('resolveUniversalSessionRole prefers active workspace over signup portal', () {
      final role = resolveUniversalSessionRole(
        apiRoles: const ['client', 'organizer', 'vendor'],
        signupPortal: 'client',
        activeWorkspace: ExperienceWorkspace.organizer,
      );
      expect(role, UserRole.organizer);
    });
  });
}
