import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_networking_providers.dart';
import '../widgets/attendee_flow_scaffold.dart';
import '../widgets/attendee_networking_widgets.dart';

String _kindLabel(String kind) {
  switch (kind) {
    case 'connection_request':
      return 'Connection request';
    case 'connection_accepted':
      return 'Connection accepted';
    case 'profile_shared':
      return 'Profile shared';
    case 'business_card_shared':
      return 'Business card shared';
    case 'community_activity':
      return 'Community activity';
    default:
      return kind;
  }
}

IconData _kindIcon(String kind) {
  switch (kind) {
    case 'connection_request':
      return Icons.person_add_alt_1_outlined;
    case 'connection_accepted':
      return Icons.handshake_outlined;
    case 'profile_shared':
      return Icons.share_outlined;
    case 'business_card_shared':
      return Icons.badge_outlined;
    case 'community_activity':
      return Icons.forum_outlined;
    default:
      return Icons.notifications_outlined;
  }
}

/// Attendee networking notifications inbox (Phase 8.7).
class AttendeeNetworkingNotificationsScreen extends ConsumerWidget {
  const AttendeeNetworkingNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(networkingNotificationsProvider);
    final offline = ref.watch(attendeeOfflineProvider);

    return AttendeeFlowScaffold(
      backLabel: 'Back',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.dashboard),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(networkingNotificationsProvider);
          await ref.read(networkingNotificationsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            Text('Networking', style: context.eosText.headlineMedium),
            SizedBox(height: context.eos.spacing.xs),
            Text(
              'Connection requests, accepts, and shared profiles or cards.',
              style: context.eosText.bodySmall,
            ),
            if (offline) ...[
              SizedBox(height: context.eos.spacing.sm),
              const EosAttentionBanner(
                headline: 'Offline',
                message: 'Notifications refresh when you are back online.',
                severity: 'WARNING',
              ),
            ],
            SizedBox(height: context.eos.spacing.lg),
            async.when(
              loading: () => const NetworkingListSkeleton(count: 4),
              error: (e, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EosAttentionBanner(
                    headline: 'Notifications unavailable',
                    message: '$e',
                    severity: 'CRITICAL',
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(networkingNotificationsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EosSurfaceCard(
                    child: Text(
                      'No networking notifications yet.',
                      style: context.eosText.bodyMedium,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final n in items) ...[
                      EosSurfaceCard(
                        onTap: () {
                          final eventId = n.data['eventId']?.toString();
                          if (eventId != null && eventId.isNotEmpty) {
                            context.push(AttendeeRoutes.people(eventId, tab: 2));
                          }
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(_kindIcon(n.kind)),
                            SizedBox(width: context.eos.spacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title ?? _kindLabel(n.kind),
                                    style: context.eosText.titleSmall?.copyWith(
                                      fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                                    ),
                                  ),
                                  if (n.body != null)
                                    Text(n.body!, style: context.eosText.bodySmall),
                                  SizedBox(height: context.eos.spacing.xs),
                                  Text(
                                    _kindLabel(n.kind),
                                    style: context.eosText.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.eos.spacing.sm),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
