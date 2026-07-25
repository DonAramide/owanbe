import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../identity/experience_navigation.dart';
import '../../../identity/identity_provider.dart';
import '../../../identity/workspace_models.dart';
import '../../../portals/customer/widgets/section_header.dart';
import '../providers/living_home_providers.dart';
import 'home_section_async.dart';

/// Cross-workspace activity summary — not full workspace dashboards.
class HomeActivityTab extends ConsumerWidget {
  const HomeActivityTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(homeMessagePreviewsProvider);
    final organizerAlertsAsync = ref.watch(hubOrganizerAlertsProvider);
    final vendorStatsAsync = ref.watch(hubVendorDashboardProvider);
    final pad = context.eos.spacing.lg;

    return RefreshIndicator(
      onRefresh: () async => refreshLivingHome(ref),
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 88),
        children: [
          const SectionHeader(
            title: 'Activity',
            subtitle: 'Notifications and updates across your workspaces',
          ),
          SizedBox(height: context.eos.spacing.sm),
          messagesAsync.when(
            loading: () => const HomeSectionLoading(title: 'Loading activity…'),
            error: (e, _) => HomeSectionError(
              title: 'Activity unavailable',
              message: '$e',
              onRetry: () => ref.invalidate(homeMessagePreviewsProvider),
            ),
            data: (messages) {
              if (messages.isEmpty &&
                  (organizerAlertsAsync.valueOrNull?.isEmpty ?? true) &&
                  (vendorStatsAsync.valueOrNull?.totalBookings ?? 0) == 0) {
                return EosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('All caught up', style: context.eosText.titleSmall),
                      SizedBox(height: context.eos.spacing.xs),
                      Text(
                        'Workspace updates will appear here. Enter a workspace for full details.',
                        style: context.eosText.bodySmall,
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: messages
                    .map(
                      (m) => Padding(
                        padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                        child: EosFeedItem(
                          title: m.sender,
                          subtitle: m.preview,
                          timestamp: _relative(m.sentAt),
                          leading: const Icon(
                            Icons.chat_bubble_outline,
                            color: EosColors.champagne,
                          ),
                          onTap: () => _openFromMessage(context, ref, m.sender),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          organizerAlertsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (alerts) => Column(
              children: alerts
                  .map(
                    (item) => Padding(
                      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                      child: EosAttentionBanner(
                        headline: item.headline,
                        message: item.message,
                        severity: item.severity,
                        actionLabel: 'Open organizer',
                        onAction: () => context.go(
                          ExperienceNavigation.workspaceHome(ExperienceWorkspace.organizer),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          vendorStatsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) {
              if (stats == null || stats.totalBookings == 0) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                child: EosAttentionBanner(
                  headline: 'Booking requests',
                  message: '${stats.totalBookings} bookings in your vendor pipeline.',
                  severity: 'WARNING',
                  actionLabel: 'Open vendor',
                  onAction: () => context.go(
                    ExperienceNavigation.workspaceHome(ExperienceWorkspace.vendor),
                  ),
                ),
              );
            },
          ),
          for (final a in livingHomeAnnouncements)
            Padding(
              padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
              child: EosAttentionBanner(
                headline: a.title,
                message: a.body,
                severity: a.severity,
              ),
            ),
        ],
      ),
    );
  }

  void _openFromMessage(BuildContext context, WidgetRef ref, String sender) {
    final identity = ref.read(userIdentityProvider).valueOrNull;
    if (identity == null) return;
    if (identity.canAccess(ExperienceWorkspace.vendor) && sender.contains('Booking')) {
      context.go(ExperienceNavigation.workspaceHome(ExperienceWorkspace.vendor));
    } else if (identity.canAccess(ExperienceWorkspace.organizer)) {
      context.go(ExperienceNavigation.workspaceHome(ExperienceWorkspace.organizer));
    } else {
      context.go('/events');
    }
  }
}

String _relative(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
