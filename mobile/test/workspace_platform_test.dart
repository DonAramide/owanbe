import 'package:flutter_test/flutter_test.dart';
import 'package:owambe/core/api/identity_api.dart';
import 'package:owambe/identity/user_identity.dart';
import 'package:owambe/identity/workspace_lifecycle.dart';
import 'package:owambe/identity/workspace_models.dart';
import 'package:owambe/router/experience_routes.dart';

OwanbeUserIdentity _identity({
  String? lastActive,
  List<WorkspaceState> workspaces = const [],
}) {
  return OwanbeUserIdentity(
    userId: 'user-1',
    email: 'test@owanbe.dev',
    displayName: 'Test User',
    roles: const ['client', 'organizer', 'vendor'],
    workspaces: workspaces,
    lastActiveWorkspace: lastActive,
  );
}

void main() {
  group('WorkspaceLifecycle', () {
    test('postLoginDestination always lands on Living Home hub', () {
      final identity = _identity(
        lastActive: 'vendor',
        workspaces: [
          WorkspaceState(workspace: ExperienceWorkspace.vendor, status: WorkspaceStatus.active),
        ],
      );
      expect(WorkspaceLifecycle.postLoginDestination(identity), ExperienceRoutes.hub);
    });

    test('postLoginDestination returns hub when nothing active', () {
      final identity = _identity(
        workspaces: [
          WorkspaceState(workspace: ExperienceWorkspace.attendee, status: WorkspaceStatus.notActivated),
        ],
      );
      expect(WorkspaceLifecycle.postLoginDestination(identity), ExperienceRoutes.hub);
    });

    test('launcherDestination routes by workspace status', () {
      expect(
        WorkspaceLifecycle.launcherDestination(
          workspace: ExperienceWorkspace.organizer,
          state: const WorkspaceState(
            workspace: ExperienceWorkspace.organizer,
            status: WorkspaceStatus.active,
          ),
        ),
        '/home',
      );
      expect(
        WorkspaceLifecycle.launcherDestination(
          workspace: ExperienceWorkspace.vendor,
          state: const WorkspaceState(
            workspace: ExperienceWorkspace.vendor,
            status: WorkspaceStatus.inProgress,
          ),
        ),
        '/vendor/onboarding',
      );
    });

    test('restoreWorkspace prefers server last active', () {
      final identity = _identity(
        lastActive: 'client',
        workspaces: [
          WorkspaceState(workspace: ExperienceWorkspace.attendee, status: WorkspaceStatus.active),
          WorkspaceState(workspace: ExperienceWorkspace.organizer, status: WorkspaceStatus.active),
        ],
      );
      expect(WorkspaceLifecycle.restoreWorkspace(identity), ExperienceWorkspace.attendee);
    });
  });
}
