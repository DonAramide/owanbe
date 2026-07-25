import 'package:flutter/material.dart';

import '../identity/experience_navigation.dart';

/// Android back scope — must live **inside** the GoRouter route tree.
///
/// go_router dispatches system back to [PopScope] on active route pages, not to
/// [MaterialApp.router] builders. Mount via [WorkspaceExperienceShell],
/// [EventModuleScaffold], hub, portfolio, and event desktop surfaces.
class WorkspaceBackScope extends StatelessWidget {
  const WorkspaceBackScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ExperienceNavigation.navigateBack(context);
      },
      child: child,
    );
  }
}

/// Policy alias — workspace-oriented naming.
typedef WorkspaceBackHandler = WorkspaceBackScope;
