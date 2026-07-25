import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../identity/experience_navigation.dart';
import '../../../identity/identity_provider.dart';
import '../../../identity/workspace_models.dart';

/// Existing hub → workspace navigation (unchanged semantics).
Future<void> openHomeWorkspace(
  BuildContext context,
  WidgetRef ref,
  ExperienceWorkspace ws,
  WorkspaceState state,
) async {
  switch (state.status) {
    case WorkspaceStatus.active:
      await ref.read(activeWorkspaceProvider.notifier).switchTo(ws);
      if (!context.mounted) return;
      context.go(ExperienceNavigation.launcherTarget(workspace: ws, state: state));
    case WorkspaceStatus.inProgress:
      if (!context.mounted) return;
      context.push(ExperienceNavigation.workspaceOnboarding(ws));
    case WorkspaceStatus.notActivated:
      if (!context.mounted) return;
      context.push(ExperienceNavigation.workspaceActivate(ws));
    case WorkspaceStatus.suspended:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This workspace is suspended.')),
      );
  }
}
