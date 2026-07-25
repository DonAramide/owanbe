import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../identity/experience_navigation.dart';
import '../../../identity/identity_provider.dart';
import '../../../identity/user_identity.dart';
import '../../../identity/workspace_models.dart';
import '../../../portals/customer/widgets/section_header.dart';
import '../home_workspace_actions.dart';
import '../providers/living_home_providers.dart';
import 'home_section_async.dart';
import 'launcher_welcome_header.dart';
import 'workspace_experience_card.dart';

/// Legacy launcher feed (Profile still surfaces workspace cards).
class LivingHomeFeed extends ConsumerStatefulWidget {
  const LivingHomeFeed({super.key, this.onOpenActivity});

  final VoidCallback? onOpenActivity;

  @override
  ConsumerState<LivingHomeFeed> createState() => _LivingHomeFeedState();
}

class _LivingHomeFeedState extends ConsumerState<LivingHomeFeed> {
  Future<void> _onRefresh() async {
    refreshLivingHome(ref);
  }

  Future<void> _openWorkspace(
    BuildContext context,
    ExperienceWorkspace ws,
    WorkspaceState state,
  ) =>
      openHomeWorkspace(context, ref, ws, state);

  @override
  Widget build(BuildContext context) {
    final identityAsync = ref.watch(userIdentityProvider);
    final alertCount = ref.watch(homeAlertCountProvider);
    final pad = context.eos.spacing.lg;

    return identityAsync.when(
      loading: () => ListView(
        padding: EdgeInsets.all(pad),
        children: const [
          HomeSectionLoading(title: 'Loading your identity…'),
        ],
      ),
      error: (e, _) => ListView(
        padding: EdgeInsets.all(pad),
        children: [
          HomeSectionError(
            title: 'Could not load identity',
            message: '$e',
            onRetry: () => ref.invalidate(userIdentityProvider),
          ),
        ],
      ),
      data: (identity) {
        if (identity == null) {
          return ListView(
            padding: EdgeInsets.all(pad),
            children: const [
              HomeSectionError(
                title: 'Sign in required',
                message: 'Please sign in to view your home.',
              ),
            ],
          );
        }

        final lastOpened = ExperienceWorkspace.fromApiCode(identity.lastActiveWorkspace);

        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 88),
            children: [
              LauncherWelcomeHeader(
                displayName: identity.displayName,
                avatarUrl: identity.avatarUrl,
                notificationCount: alertCount,
                onNotificationsTap: widget.onOpenActivity,
              ),
              SizedBox(height: context.eos.spacing.xl),
              const SectionHeader(
                title: 'Your experiences',
                subtitle: 'Choose a world to enter — one account, many possibilities',
              ),
              SizedBox(height: context.eos.spacing.md),
              ...ExperienceWorkspace.values.map((ws) {
                final wsState = identity.workspaceState(ws);
                return Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.lg),
                  child: WorkspaceExperienceCard(
                    workspace: ws,
                    state: wsState,
                    isLastOpened: lastOpened == ws && wsState.isActive,
                    onPressed: () => _openWorkspace(context, ws, wsState),
                  ),
                );
              }),
              if (_hasInProgress(identity)) ...[
                SizedBox(height: context.eos.spacing.sm),
                EosSurfaceCard(
                  child: Row(
                    children: [
                      const Icon(Icons.auto_fix_high_outlined, color: EosColors.champagne),
                      SizedBox(width: context.eos.spacing.sm),
                      Expanded(
                        child: Text(
                          'Finish setup on any in-progress workspace to unlock the full experience.',
                          style: context.eosText.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: context.eos.spacing.xl),
              const _LauncherRecentActivity(),
              SizedBox(height: context.eos.spacing.xl),
              const SectionHeader(title: 'Platform', subtitle: 'Announcements'),
              SizedBox(height: context.eos.spacing.sm),
              for (final a in livingHomeAnnouncements)
                Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                  child: EosAttentionBanner(
                    headline: a.title,
                    message: a.body,
                    severity: a.severity,
                  ),
                ),
              SizedBox(height: context.eos.spacing.lg),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.explore_outlined, size: 18),
                    label: const Text('Discover events'),
                    onPressed: () => context.go('/events'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.help_outline, size: 18),
                    label: const Text('Help & support'),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  bool _hasInProgress(OwanbeUserIdentity identity) =>
      identity.workspaces.any((w) => w.status == WorkspaceStatus.inProgress);
}

class _LauncherRecentActivity extends ConsumerWidget {
  const _LauncherRecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(hubLauncherActivityProvider);

    return activityAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'Recent activity',
              subtitle: 'A quick glance across your worlds',
            ),
            SizedBox(height: context.eos.spacing.sm),
            ...items.take(4).map(
                  (a) => Padding(
                    padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                    child: EosFeedItem(
                      title: a.title,
                      subtitle: a.subtitle,
                      timestamp: _relative(a.timestamp),
                      leading: Icon(_iconFor(a.icon), color: EosColors.champagne),
                      onTap: a.workspace != null
                          ? () => context.go(
                                ExperienceNavigation.workspaceHome(a.workspace!),
                              )
                          : null,
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

String _relative(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

IconData _iconFor(String key) => switch (key) {
      'ticket' => Icons.confirmation_number_outlined,
      'organizer' => Icons.celebration_outlined,
      'vendor' => Icons.storefront_outlined,
      _ => Icons.notifications_outlined,
    };
