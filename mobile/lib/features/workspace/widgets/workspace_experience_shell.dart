import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/widgets/portal_access_guard.dart';
import '../../../identity/experience_navigation.dart';
import '../../../identity/identity_provider.dart';
import '../../../identity/workspace_models.dart';
import '../../../navigation/enterprise_back_handler.dart';
import '../../../eos/layout/eos_adaptive.dart';
import 'workspace_switcher.dart';

/// Unified workspace shell — access control, active context, and platform chrome.
class WorkspaceExperienceShell extends ConsumerStatefulWidget {
  const WorkspaceExperienceShell({
    super.key,
    required this.workspace,
    required this.child,
  });

  final ExperienceWorkspace workspace;
  final Widget child;

  @override
  ConsumerState<WorkspaceExperienceShell> createState() => _WorkspaceExperienceShellState();
}

class _WorkspaceExperienceShellState extends ConsumerState<WorkspaceExperienceShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(activeWorkspaceProvider.notifier).switchTo(widget.workspace);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PortalAccessGuard(
      requiredRole: widget.workspace.userRole,
      child: WorkspaceBackScope(
        child: widget.child,
      ),
    );
  }
}

/// Shared platform actions — return to launcher + instant workspace switching.
///
/// Compact windows use icon-only chrome to avoid top-bar overflow.
class WorkspaceContextActions extends ConsumerWidget {
  const WorkspaceContextActions({super.key, this.iconColor, this.forceCompact});

  final Color? iconColor;
  final bool? forceCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWorkspaceProvider);
    final compact = forceCompact ?? EosAdaptive.isCompact(context);
    final color = iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant;

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Owanbe Home',
            visualDensity: VisualDensity.compact,
            onPressed: () => ExperienceNavigation.returnToHub(context),
            icon: Icon(Icons.home_outlined, color: color),
          ),
          WorkspaceSwitcher(iconColor: color),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (active != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: WorkspaceContextChip(workspace: active, compact: true),
          ),
        Tooltip(
          message: 'Owanbe Home',
          child: TextButton.icon(
            onPressed: () => ExperienceNavigation.returnToHub(context),
            icon: Icon(Icons.arrow_back, size: 18, color: color),
            label: Text(
              'Owanbe Home',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        WorkspaceSwitcher(iconColor: color),
      ],
    );
  }
}

/// Compact workspace label for top bars and switcher sheets.
class WorkspaceContextChip extends StatelessWidget {
  const WorkspaceContextChip({
    super.key,
    required this.workspace,
    this.compact = false,
  });

  final ExperienceWorkspace workspace;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        compact ? workspace.title : '${workspace.title} Workspace',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
