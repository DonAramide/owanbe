import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../identity/experience_navigation.dart';
import '../../../identity/identity_provider.dart';
import '../../../identity/workspace_models.dart';
import '../../../identity/workspace_providers.dart';
import '../../../router/experience_routes.dart';

/// Instant workspace switching — no sign-out, no re-authentication.
class WorkspaceSwitcher extends ConsumerWidget {
  const WorkspaceSwitcher({
    super.key,
    this.iconColor,
    this.tooltip = 'Switch workspace',
  });

  final Color? iconColor;
  final String tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(activatedWorkspaceCountProvider);
    if (count < 1) {
      return IconButton(
        tooltip: 'Owanbe Home',
        icon: Icon(Icons.home_outlined, color: iconColor),
        onPressed: () => ExperienceNavigation.returnToHub(context),
      );
    }

    return IconButton(
      tooltip: tooltip,
      icon: Icon(Icons.swap_horiz, color: iconColor),
      onPressed: () => _showSwitcher(context, ref),
    );
  }

  static Future<void> _showSwitcher(BuildContext context, WidgetRef ref) async {
    final identity = ref.read(userIdentityProvider).valueOrNull;
    if (identity == null) return;

    final activated = ExperienceWorkspace.values
        .where((ws) => identity.canAccess(ws))
        .toList();
    final active = ref.read(activeWorkspaceProvider);

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: EosColors.plumDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Switch workspace',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'One account — move between your activated experiences instantly.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                for (final ws in activated)
                  ListTile(
                    leading: Icon(_iconFor(ws), color: EosColors.champagne),
                    title: Text(ws.title, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      active == ws ? 'Current workspace' : 'Active',
                      style: TextStyle(
                        color: active == ws
                            ? EosColors.champagne
                            : Colors.greenAccent.withValues(alpha: 0.9),
                      ),
                    ),
                    trailing: active == ws
                        ? const Icon(Icons.check_circle, color: EosColors.champagne)
                        : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await ref.read(activeWorkspaceProvider.notifier).switchTo(ws);
                      if (!context.mounted) return;
                      context.go(ExperienceNavigation.workspaceHome(ws));
                    },
                  ),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: const Icon(Icons.home_outlined, color: Colors.white70),
                  title: const Text('Workspace Launcher', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Return to Owanbe Home', style: TextStyle(color: Colors.white54)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ExperienceNavigation.returnToHub(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static IconData _iconFor(ExperienceWorkspace ws) => switch (ws) {
        ExperienceWorkspace.attendee => Icons.confirmation_number_outlined,
        ExperienceWorkspace.organizer => Icons.celebration_outlined,
        ExperienceWorkspace.vendor => Icons.storefront_outlined,
      };
}
