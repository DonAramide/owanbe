import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../eos/eos.dart';
import '../../../platform/domains/workspace/identity_workspace_manager.dart';
import '../../../platform/identity/identity_models.dart';
import '../../../platform/identity/identity_platform.dart';

class WorkspaceSelectorScreen extends StatefulWidget {
  const WorkspaceSelectorScreen({super.key});

  @override
  State<WorkspaceSelectorScreen> createState() => _WorkspaceSelectorScreenState();
}

class _WorkspaceSelectorScreenState extends State<WorkspaceSelectorScreen> {
  @override
  Widget build(BuildContext context) {
    final manager = IdentityWorkspaceManager.instance;
    final contextUser = manager.userContext;
    final roles = contextUser?.roles ?? [UserRole.client];

    return Scaffold(
      backgroundColor: EosColors.plumDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: EosSurfaceCard(
              elevated: true,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Select Workspace',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a role profile to proceed to your celebration space.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ...roles.map((role) {
                      final isSelected = contextUser?.activeRole == role;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: OutlinedButton(
                          onPressed: () {
                            manager.selectWorkspace(role);
                            // Navigate based on selected workspace role
                            context.go(role == UserRole.organizer
                                ? '/organizer'
                                : (role == UserRole.vendor ? '/vendor' : '/home'));
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isSelected ? EosColors.champagne : Colors.white30,
                              width: isSelected ? 2 : 1,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: isSelected ? Colors.white.withValues(alpha: 0.05) : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                role == UserRole.organizer
                                    ? Icons.corporate_fare
                                    : (role == UserRole.vendor ? Icons.storefront : Icons.person),
                                color: isSelected ? EosColors.champagne : Colors.white70,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                role.label,
                                style: TextStyle(
                                  color: isSelected ? EosColors.champagne : Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        IdentityPlatform.instance.signOut();
                        context.go('/auth');
                      },
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
