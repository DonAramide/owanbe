import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../auth/user_role.dart';
import '../../../eos/eos.dart';
import '../../../identity/identity_provider.dart';
import '../../../identity/workspace_access.dart';
import '../../../identity/experience_navigation.dart';
import '../../../identity/workspace_models.dart';
import '../../../router/experience_routes.dart';
import '../auth_error_messages.dart';
import 'auth_error_banner.dart';

/// Blocks workspace UI when the account has not activated (or cannot access) the workspace.
///
/// Owanbe 2.0: workspace activation state from [userIdentityProvider].
class PortalAccessGuard extends ConsumerWidget {
  const PortalAccessGuard({
    super.key,
    required this.requiredRole,
    required this.child,
  });

  final UserRole requiredRole;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _WorkspaceAccessBody(requiredRole: requiredRole, child: child);
  }
}

class _WorkspaceAccessBody extends ConsumerWidget {
  const _WorkspaceAccessBody({
    required this.requiredRole,
    required this.child,
  });

  final UserRole requiredRole;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(userIdentityProvider);
    final session = ref.watch(authSessionProvider.select((s) => s));
    final identity = identityAsync.valueOrNull;

    // Keep the current screen mounted during identity loading/refresh.
    if (identity == null) {
      if (identityAsync.hasError &&
          !canEnterWorkspaceExperience(
            requiredRole: requiredRole,
            session: session,
          )) {
        return _AccessDeniedScaffold(
          requiredRole: requiredRole,
          title: 'Could not verify workspace access',
          body: 'Sign in again or activate this workspace from Owanbe Home.',
          primaryAction: 'Go to Owanbe Home',
          onPrimary: () => ExperienceNavigation.returnToHub(context),
        );
      }
      return child;
    }

    if (canEnterWorkspaceExperience(
      requiredRole: requiredRole,
      identity: identity,
      session: session,
    )) {
      return child;
    }

    final workspace = ExperienceWorkspace.fromUserRole(requiredRole);
    final wsTitle = workspace?.title ?? requiredRole.label;
    final state = workspace != null ? identity.workspaceState(workspace) : null;

    if (state != null && state.needsActivation) {
      return _AccessDeniedScaffold(
        requiredRole: requiredRole,
        title: '$wsTitle workspace not activated',
        body: 'Activate $wsTitle from Owanbe Home to use this experience.',
        primaryAction: 'Activate $wsTitle',
        onPrimary: () {
          if (workspace != null) {
            context.push(ExperienceRoutes.activateFor(workspace));
          } else {
            ExperienceNavigation.returnToHub(context);
          }
        },
        secondaryLabel: 'Back to Owanbe Home',
        onSecondary: () => ExperienceNavigation.returnToHub(context),
      );
    }

    return _AccessDeniedScaffold(
      requiredRole: requiredRole,
      title: 'Workspace unavailable',
      body: 'You do not have access to $wsTitle right now.',
      primaryAction: 'Go to Owanbe Home',
      onPrimary: () => ExperienceNavigation.returnToHub(context),
    );
  }
}

class _AccessDeniedScaffold extends StatelessWidget {
  const _AccessDeniedScaffold({
    required this.requiredRole,
    required this.title,
    required this.body,
    required this.primaryAction,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final UserRole requiredRole;
  final String title;
  final String body;
  final String primaryAction;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final error = formatAuthError(
      Exception(body),
      roleLabel: requiredRole.label,
    ).copyWith(title: title, body: body);

    return Scaffold(
      backgroundColor: context.eosCanvas,
      appBar: AppBar(title: Text(requiredRole.label)),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: EosSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthErrorBanner(error: error),
                  SizedBox(height: context.eos.spacing.lg),
                  FilledButton(onPressed: onPrimary, child: Text(primaryAction)),
                  if (secondaryLabel != null && onSecondary != null) ...[
                    TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on AuthErrorMessage {
  AuthErrorMessage copyWith({String? title, String? body}) {
    return AuthErrorMessage(
      title: title ?? this.title,
      body: body ?? this.body,
      steps: steps,
    );
  }
}
