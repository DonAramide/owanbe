import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../../../identity/identity_provider.dart';
import '../../../identity/experience_navigation.dart';
import '../../../identity/workspace_models.dart';
import '../../../router/experience_routes.dart';

/// Starts workspace activation — no re-authentication.
class WorkspaceActivationScreen extends ConsumerStatefulWidget {
  const WorkspaceActivationScreen({super.key, required this.workspace});

  final ExperienceWorkspace workspace;

  @override
  ConsumerState<WorkspaceActivationScreen> createState() => _WorkspaceActivationScreenState();
}

class _WorkspaceActivationScreenState extends ConsumerState<WorkspaceActivationScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _beginActivation() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(identityApiProvider).activateWorkspace(workspace: widget.workspace.apiCode);
      await ref.read(activeWorkspaceProvider.notifier).switchTo(widget.workspace);
      await ref.read(userIdentityProvider.notifier).refresh();
      if (!mounted) return;
      context.go(ExperienceRoutes.onboardingFor(widget.workspace));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(userIdentityProvider).valueOrNull;

    return Scaffold(
      backgroundColor: EosColors.plumDark,
      appBar: AppBar(
        title: Text('Become ${widget.workspace.title}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ExperienceNavigation.returnToHub(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Activate your ${widget.workspace.title} workspace',
              style: context.eosText.headlineSmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              identity != null
                  ? "You're signed in as ${identity.email}. No need to sign in again — we'll collect ${widget.workspace.title.toLowerCase()}-specific details next."
                  : 'Complete your profile to unlock this workspace.',
              style: context.eosText.bodyMedium?.copyWith(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 24),
            ...widget.workspace.highlights.take(4).map(
                  (h) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: EosColors.champagne, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(h, style: const TextStyle(color: Colors.white))),
                      ],
                    ),
                  ),
                ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const Spacer(),
            FilledButton(
              onPressed: _busy ? null : _beginActivation,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Continue to ${widget.workspace.title} setup'),
            ),
          ],
        ),
      ),
    );
  }
}
