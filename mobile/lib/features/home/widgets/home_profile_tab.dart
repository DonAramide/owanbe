import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import '../../../identity/experience_navigation.dart';
import '../../../identity/identity_provider.dart';
import '../../../identity/user_identity.dart';
import '../../../identity/workspace_models.dart';
import '../../../portals/customer/navigation/event_navigator.dart';
import '../../../portals/customer/widgets/section_header.dart';
import '../../../profile/profile.dart';
import '../widgets/workspace_experience_card.dart';
import 'hub_global_profile_edit_sheet.dart';

/// Profile and account tab on Owanbe Home.
class HomeProfileTab extends ConsumerWidget {
  const HomeProfileTab({super.key});

  int _overallCompletion(OwanbeUserIdentity identity) {
    final active = identity.workspaces.where((w) => w.status != WorkspaceStatus.notActivated);
    if (active.isEmpty) return 0;
    final sum = active.fold<int>(0, (s, w) => s + w.profileCompletionPct);
    return (sum / active.length).round();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(userIdentityProvider);
    final pad = context.eos.spacing.lg;

    return identityAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(
        padding: EdgeInsets.all(pad),
        children: [
          EosSurfaceCard(child: Text('Could not load profile: $e')),
        ],
      ),
      data: (identity) {
        if (identity == null) {
          return const Center(child: Text('Sign in to view your profile'));
        }

        final completion = _overallCompletion(identity);
        final activated = ExperienceWorkspace.values.where(identity.canAccess).length;
        final hasBio = identity.bio != null && identity.bio!.trim().isNotEmpty;
        final hasProfession = (identity.occupation?.trim().isNotEmpty ?? false) ||
            (identity.company?.trim().isNotEmpty ?? false);

        return ListView(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 88),
          children: [
            const SectionHeader(title: 'Profile', subtitle: 'Account and workspace status'),
            EosSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ProfileNetworkAvatar(
                        name: identity.displayName,
                        avatarUrl: identity.avatarUrl,
                        radius: 32,
                        backgroundColor: EosColors.champagne.withValues(alpha: 0.2),
                        foregroundColor: EosColors.champagne,
                      ),
                      SizedBox(width: context.eos.spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(identity.displayName, style: context.eosText.titleMedium),
                            Text(identity.email, style: context.eosText.bodySmall),
                            SizedBox(height: context.eos.spacing.xs),
                            Text(
                              '$activated workspace${activated == 1 ? '' : 's'} active',
                              style: context.eosText.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (hasBio || hasProfession || identity.interests.isNotEmpty) ...[
                    SizedBox(height: context.eos.spacing.md),
                    if (hasProfession)
                      Text(
                        [
                          if (identity.occupation?.trim().isNotEmpty ?? false)
                            identity.occupation!.trim(),
                          if (identity.company?.trim().isNotEmpty ?? false)
                            identity.company!.trim(),
                        ].join(' · '),
                        style: context.eosText.bodySmall,
                      ),
                    if (hasBio) ...[
                      if (hasProfession) SizedBox(height: context.eos.spacing.xs),
                      Text(identity.bio!.trim(), style: context.eosText.bodySmall),
                    ],
                    if (identity.interests.isNotEmpty) ...[
                      SizedBox(height: context.eos.spacing.sm),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final interest in identity.interests.take(8))
                            Chip(
                              label: Text(interest, style: context.eosText.labelSmall),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                    ],
                  ],
                  SizedBox(height: context.eos.spacing.md),
                  OutlinedButton.icon(
                    onPressed: () => showHubGlobalProfileEditor(context, ref),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Profile'),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.eos.spacing.md),
            EosSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Profile completion', style: context.eosText.titleSmall),
                  SizedBox(height: context.eos.spacing.sm),
                  LinearProgressIndicator(
                    value: completion / 100,
                    backgroundColor: Colors.white12,
                    color: EosColors.champagne,
                  ),
                  SizedBox(height: context.eos.spacing.xs),
                  Text('$completion% across activated workspaces', style: context.eosText.bodySmall),
                ],
              ),
            ),
            SizedBox(height: context.eos.spacing.md),
            EosSurfaceCard(
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: context.eosColors.primary),
                  SizedBox(width: context.eos.spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Verification', style: context.eosText.titleSmall),
                        Text(
                          identity.onboardingComplete
                              ? 'Identity verified — full platform access enabled.'
                              : 'Complete onboarding to unlock all workspaces.',
                          style: context.eosText.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.eos.spacing.xl),
            const SectionHeader(title: 'Workspaces', subtitle: 'Manage your experiences'),
            SizedBox(height: context.eos.spacing.sm),
            ...ExperienceWorkspace.values.map((ws) {
              final state = identity.workspaceState(ws);
              return Padding(
                padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                child: WorkspaceExperienceCard(
                  workspace: ws,
                  state: state,
                  compact: true,
                  onPressed: () => _openWorkspace(context, ref, ws, state),
                ),
              );
            }),
            SizedBox(height: context.eos.spacing.md),
            const EosThemeModeSection(),
            SizedBox(height: context.eos.spacing.md),
            ListTile(
              leading: const Icon(Icons.confirmation_number_outlined),
              title: const Text('My tickets'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.eventNav.openAttendeeDashboard(),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                try {
                  await ref.read(authSessionProvider.notifier).signOut();
                  if (context.mounted) {
                    context.go(ExperienceNavigation.afterSignOut());
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sign out failed: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _openWorkspace(
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
}
