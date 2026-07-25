import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../features/home/providers/living_home_providers.dart';
import '../../../features/public/data/recently_viewed_events_store.dart';
import '../../../features/public/data/saved_events_store.dart';
import '../../../features/public/models/public_models.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../../../features/public/providers/public_providers.dart';
import '../../../portals/attendee/commerce/purchase_notifications_provider.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_hub_providers.dart';
import '../widgets/attendee_flow_scaffold.dart';

/// Personal activity hub — reuses stores, orders, notifications, hub messages.
class AttendeeActivityScreen extends ConsumerWidget {
  const AttendeeActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(attendeeActivityTimelineProvider);
    final notices = ref.watch(purchaseNotificationsProvider);
    final messagesAsync = ref.watch(homeMessagePreviewsProvider);
    final savedIds = ref.watch(savedEventIdsProvider);
    final recentIds = ref.watch(recentlyViewedEventIdsProvider);
    final catalog = ref.watch(publicEventsProvider).valueOrNull ?? const <PublicEvent>[];
    final offline = ref.watch(attendeeOfflineProvider);

    PublicEvent? byId(String id) {
      for (final e in catalog) {
        if (e.id == id) return e;
      }
      return null;
    }

    return AttendeeFlowScaffold(
      backLabel: 'Dashboard',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.dashboard),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeMessagePreviewsProvider);
          ref.invalidate(publicEventsProvider);
          await ref.read(homeMessagePreviewsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            Text('Activity', style: context.eosText.headlineMedium),
            SizedBox(height: context.eos.spacing.xs),
            Text(
              'Recently viewed, saved events, purchases, notifications, and messages.',
              style: context.eosText.bodySmall,
            ),
            if (offline) ...[
              SizedBox(height: context.eos.spacing.sm),
              const EosAttentionBanner(
                headline: 'Offline',
                message: 'Local activity remains available.',
                severity: 'WARNING',
              ),
            ],
            SizedBox(height: context.eos.spacing.lg),
            Text('Recently viewed', style: context.eosText.titleMedium),
            SizedBox(height: context.eos.spacing.sm),
            if (recentIds.isEmpty)
              EosSurfaceCard(child: Text('No recently viewed events.', style: context.eosText.bodyMedium))
            else
              for (final id in recentIds.take(8))
                if (byId(id) != null)
                  EosFeedItem(
                    title: byId(id)!.title,
                    subtitle: byId(id)!.city,
                    timestamp: 'Viewed',
                    leading: Icon(Icons.history, color: context.eosColors.primary),
                    onTap: () => context.push(AttendeeRoutes.eventDetail(id)),
                  ),
            SizedBox(height: context.eos.spacing.lg),
            Text('Saved events', style: context.eosText.titleMedium),
            SizedBox(height: context.eos.spacing.sm),
            if (savedIds.isEmpty)
              EosSurfaceCard(child: Text('No saved events.', style: context.eosText.bodyMedium))
            else
              for (final id in savedIds)
                if (byId(id) != null)
                  EosFeedItem(
                    title: byId(id)!.title,
                    subtitle: byId(id)!.venue,
                    timestamp: 'Saved',
                    leading: Icon(Icons.bookmark, color: context.eosColors.primary),
                    onTap: () => context.push(AttendeeRoutes.eventDetail(id)),
                  ),
            SizedBox(height: context.eos.spacing.lg),
            Row(
              children: [
                Expanded(child: Text('Purchase history', style: context.eosText.titleMedium)),
                TextButton(onPressed: () => context.push(AttendeeRoutes.orders), child: const Text('Open')),
              ],
            ),
            EosSurfaceCard(
              child: Text(
                'Orders and refunds live in Purchase history — same Phase 4 commerce module.',
                style: context.eosText.bodyMedium,
              ),
            ),
            SizedBox(height: context.eos.spacing.lg),
            Text('Notifications', style: context.eosText.titleMedium),
            SizedBox(height: context.eos.spacing.sm),
            if (notices.isEmpty)
              EosSurfaceCard(child: Text('No purchase notifications yet.', style: context.eosText.bodyMedium))
            else
              for (final n in notices.take(10))
                EosFeedItem(
                  title: n.title,
                  subtitle: n.body,
                  timestamp: n.createdAt.toLocal().toString().split('.').first,
                  leading: Icon(Icons.notifications_outlined, color: context.eosColors.primary),
                ),
            SizedBox(height: context.eos.spacing.lg),
            Text('Messages', style: context.eosText.titleMedium),
            SizedBox(height: context.eos.spacing.sm),
            messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  EosAttentionBanner(headline: 'Messages unavailable', message: '$e', severity: 'WARNING'),
              data: (messages) {
                if (messages.isEmpty) {
                  return EosSurfaceCard(
                    child: Text('No messages from the Living Home hub.', style: context.eosText.bodyMedium),
                  );
                }
                return Column(
                  children: [
                    for (final m in messages)
                      EosFeedItem(
                        title: m.sender,
                        subtitle: m.preview,
                        timestamp: m.sentAt.toLocal().toString().split('.').first,
                        leading: Icon(
                          m.unread ? Icons.mark_email_unread_outlined : Icons.mail_outline,
                          color: context.eosColors.primary,
                        ),
                      ),
                  ],
                );
              },
            ),
            SizedBox(height: context.eos.spacing.lg),
            Text('Activity timeline', style: context.eosText.titleMedium),
            SizedBox(height: context.eos.spacing.sm),
            if (timeline.isEmpty)
              EosSurfaceCard(
                child: Text('Activity will appear as you attend events.', style: context.eosText.bodyMedium),
              )
            else
              for (final item in timeline.take(20))
                EosFeedItem(
                  title: item.title,
                  subtitle: item.subtitle,
                  timestamp: item.at.toLocal().toString().split('.').first,
                  leading: Icon(
                    item.kind == 'message'
                        ? Icons.chat_bubble_outline
                        : item.kind == 'notification'
                            ? Icons.notifications_active_outlined
                            : Icons.confirmation_number_outlined,
                    color: context.eosColors.primary,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
