import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../features/public/models/attendee_event_models.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../../../features/public/widgets/attendee_event_card.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_hub_providers.dart';
import '../widgets/attendee_flow_scaffold.dart';

/// Attendee event management centre — composes tickets, schedule, saved, orders.
class AttendeeMyEventsScreen extends ConsumerStatefulWidget {
  const AttendeeMyEventsScreen({super.key});

  @override
  ConsumerState<AttendeeMyEventsScreen> createState() => _AttendeeMyEventsScreenState();
}

class _AttendeeMyEventsScreenState extends ConsumerState<AttendeeMyEventsScreen> {
  MyEventsFilter _filter = MyEventsFilter.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myEventsBundleProvider);
    final offline = ref.watch(attendeeOfflineProvider);

    return AttendeeFlowScaffold(
      backLabel: 'Dashboard',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.dashboard),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myEventsBundleProvider);
          await ref.read(myEventsBundleProvider.future);
        },
        child: async.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: const [
              EosSurfaceCard(child: SizedBox(height: 64, child: Center(child: CircularProgressIndicator()))),
              SizedBox(height: 12),
              EosSurfaceCard(child: SizedBox(height: 120)),
            ],
          ),
          error: (e, _) => ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              EosAttentionBanner(headline: 'Could not load My Events', message: '$e', severity: 'CRITICAL'),
              TextButton(onPressed: () => ref.invalidate(myEventsBundleProvider), child: const Text('Retry')),
            ],
          ),
          data: (bundle) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              Text('My Events', style: context.eosText.headlineMedium),
              SizedBox(height: context.eos.spacing.xs),
              Text(
                'Your event command centre — tickets, schedule, saved, and history.',
                style: context.eosText.bodySmall,
              ),
              if (offline) ...[
                SizedBox(height: context.eos.spacing.sm),
                const EosAttentionBanner(
                  headline: 'Offline',
                  message: 'Showing cached and local data where available.',
                  severity: 'WARNING',
                ),
              ],
              SizedBox(height: context.eos.spacing.md),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search events',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
              SizedBox(height: context.eos.spacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in MyEventsFilter.values)
                    FilterChip(
                      label: Text(_filterLabel(f)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ],
              ),
              SizedBox(height: context.eos.spacing.lg),
              ..._buildSections(context, bundle),
              SizedBox(height: context.eos.spacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push(AttendeeRoutes.passes),
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('My Passes'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(AttendeeRoutes.orders),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text('Purchase history'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(AttendeeRoutes.registrations),
                    icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                    label: const Text('Registrations'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(AttendeeRoutes.activity),
                    icon: const Icon(Icons.timeline_outlined, size: 18),
                    label: const Text('Activity'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(AttendeeRoutes.personalHistory),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('Personal history'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _filterLabel(MyEventsFilter f) => switch (f) {
        MyEventsFilter.all => 'All',
        MyEventsFilter.upcoming => 'Upcoming',
        MyEventsFilter.ongoing => 'Ongoing',
        MyEventsFilter.past => 'Past',
        MyEventsFilter.saved => 'Saved',
        MyEventsFilter.registered => 'Registered',
        MyEventsFilter.cancelled => 'Cancelled',
        MyEventsFilter.history => 'History',
      };

  bool _matchesQuery(String title) => _query.isEmpty || title.toLowerCase().contains(_query);

  List<Widget> _buildSections(BuildContext context, MyEventsBundle bundle) {
    final registered = bundle.registered.where((e) => _matchesQuery(e.eventTitle)).toList();
    final upcoming = registered.where((e) => e.lifecycle == AttendeeEventLifecycle.upcoming).toList();
    final ongoing = registered.where((e) => e.lifecycle == AttendeeEventLifecycle.ongoing).toList();
    final past = registered.where((e) => e.lifecycle == AttendeeEventLifecycle.past).toList();
    final cancelled = registered.where((e) => e.lifecycle == AttendeeEventLifecycle.cancelled).toList();
    final saved = bundle.saved.where((e) => _matchesQuery(e.title)).toList();

    final show = <MyEventsFilter, bool>{
      MyEventsFilter.all: true,
      MyEventsFilter.upcoming: _filter == MyEventsFilter.upcoming || _filter == MyEventsFilter.all,
      MyEventsFilter.ongoing: _filter == MyEventsFilter.ongoing || _filter == MyEventsFilter.all,
      MyEventsFilter.past: _filter == MyEventsFilter.past || _filter == MyEventsFilter.all,
      MyEventsFilter.saved: _filter == MyEventsFilter.saved || _filter == MyEventsFilter.all,
      MyEventsFilter.registered: _filter == MyEventsFilter.registered || _filter == MyEventsFilter.all,
      MyEventsFilter.cancelled: _filter == MyEventsFilter.cancelled || _filter == MyEventsFilter.all,
      MyEventsFilter.history: _filter == MyEventsFilter.history || _filter == MyEventsFilter.all,
    };

    final widgets = <Widget>[];

    if (_filter == MyEventsFilter.registered || _filter == MyEventsFilter.all) {
      widgets.addAll(_section(
        context,
        'Registered events',
        'Ticketed celebrations you own.',
        registered.isEmpty
            ? [EosSurfaceCard(child: Text('No registered events yet.', style: context.eosText.bodyMedium))]
            : [
                for (final e in registered) ...[
                  AttendeeEventCard(
                    event: e,
                    onOpenDetail: () => context.push(
                      e.lifecycle == AttendeeEventLifecycle.past
                          ? AttendeeRoutes.eventRecap(e.eventId)
                          : AttendeeRoutes.eventDetail(e.eventId),
                    ),
                    onShowQr: () => context.push(
                      e.lifecycle == AttendeeEventLifecycle.past
                          ? AttendeeRoutes.eventRecap(e.eventId)
                          : AttendeeRoutes.entry(e.ticket.id),
                    ),
                  ),
                  SizedBox(height: context.eos.spacing.sm),
                ],
              ],
      ));
    }

    if (show[MyEventsFilter.upcoming]! && _filter != MyEventsFilter.registered) {
      widgets.addAll(_section(
        context,
        'Upcoming',
        'Events starting soon.',
        upcoming.isEmpty
            ? [EosSurfaceCard(child: Text('No upcoming events.', style: context.eosText.bodyMedium))]
            : [_eventTiles(context, upcoming)],
      ));
    }
    if (show[MyEventsFilter.ongoing]! && _filter != MyEventsFilter.registered) {
      widgets.addAll(_section(
        context,
        'Ongoing',
        'Happening now.',
        ongoing.isEmpty
            ? [EosSurfaceCard(child: Text('No ongoing events.', style: context.eosText.bodyMedium))]
            : [_eventTiles(context, ongoing)],
      ));
    }
    if (show[MyEventsFilter.past]! && _filter != MyEventsFilter.registered) {
      widgets.addAll(_section(
        context,
        'Past',
        'Completed and ended events.',
        past.isEmpty
            ? [EosSurfaceCard(child: Text('No past events.', style: context.eosText.bodyMedium))]
            : [_eventTiles(context, past)],
      ));
    }
    if (show[MyEventsFilter.cancelled]! && _filter != MyEventsFilter.registered) {
      widgets.addAll(_section(
        context,
        'Cancelled',
        'Voided or refunded registrations.',
        cancelled.isEmpty
            ? [EosSurfaceCard(child: Text('No cancelled events.', style: context.eosText.bodyMedium))]
            : [_eventTiles(context, cancelled)],
      ));
    }
    if (show[MyEventsFilter.saved]!) {
      widgets.addAll(_section(
        context,
        'Saved events',
        'Bookmarks from Discover and event details.',
        saved.isEmpty
            ? [EosSurfaceCard(child: Text('No saved events yet.', style: context.eosText.bodyMedium))]
            : [
                for (final e in saved)
                  EosFeedItem(
                    title: e.title,
                    subtitle: '${e.city} · ${e.venue}',
                    timestamp: e.startsAt.toLocal().toString().split('.').first,
                    leading: Icon(Icons.bookmark, color: context.eosColors.primary),
                    onTap: () => context.push(AttendeeRoutes.eventDetail(e.id)),
                  ),
              ],
      ));
    }
    if (show[MyEventsFilter.history]!) {
      widgets.addAll(_section(
        context,
        'Event history',
        'Purchase history and past registrations.',
        [
          if (bundle.orders.isEmpty && past.isEmpty)
            EosSurfaceCard(child: Text('No history yet.', style: context.eosText.bodyMedium))
          else ...[
            for (final o in bundle.orders.take(8))
              EosFeedItem(
                title: o.eventTitle,
                subtitle: '${o.status} · order ${o.id.substring(0, 8)}…',
                timestamp: o.createdAt.toLocal().toString().split('.').first,
                leading: Icon(Icons.receipt_long_outlined, color: context.eosColors.primary),
                onTap: () => context.push(AttendeeRoutes.orderDetail(o.id)),
              ),
            for (final e in past.take(8))
              EosFeedItem(
                title: e.eventTitle,
                subtitle: e.lifecycleLabel,
                timestamp: formatAttendeeDateRange(e.startsAt, e.endsAt),
                leading: Icon(Icons.auto_stories_outlined, color: context.eosColors.onSurfaceVariant),
                onTap: () => context.push(AttendeeRoutes.eventRecap(e.eventId)),
              ),
          ],
        ],
      ));
    }

    return widgets;
  }

  Widget _eventTiles(BuildContext context, List<AttendeeEventView> events) {
    return Column(
      children: [
        for (final e in events) ...[
          EosFeedItem(
            title: e.eventTitle,
            subtitle: '${e.lifecycleLabel} · ${e.tierName} · ${e.city}',
            timestamp: formatAttendeeDateRange(e.startsAt, e.endsAt),
            leading: Icon(
              e.lifecycle == AttendeeEventLifecycle.past
                  ? Icons.auto_stories_outlined
                  : e.checkedIn
                      ? Icons.how_to_reg
                      : Icons.celebration_outlined,
              color: context.eosColors.primary,
            ),
            trailing: TextButton(
              onPressed: () => context.push(
                e.lifecycle == AttendeeEventLifecycle.past
                    ? AttendeeRoutes.eventRecap(e.eventId)
                    : e.isOngoing || e.checkedIn
                        ? AttendeeRoutes.live(e.eventId)
                        : AttendeeRoutes.entry(e.ticket.id),
              ),
              child: Text(
                e.lifecycle == AttendeeEventLifecycle.past
                    ? 'Recap'
                    : e.isOngoing || e.checkedIn
                        ? 'Live'
                        : 'Entry',
              ),
            ),
            onTap: () => context.push(
              e.lifecycle == AttendeeEventLifecycle.past
                  ? AttendeeRoutes.eventRecap(e.eventId)
                  : e.isOngoing || e.checkedIn
                      ? AttendeeRoutes.live(e.eventId)
                      : AttendeeRoutes.passDetail(e.ticket.id),
            ),
          ),
          SizedBox(height: context.eos.spacing.sm),
        ],
      ],
    );
  }

  List<Widget> _section(BuildContext context, String title, String subtitle, List<Widget> children) {
    return [
      Text(title, style: context.eosText.titleMedium),
      SizedBox(height: context.eos.spacing.xxs),
      Text(subtitle, style: context.eosText.bodySmall),
      SizedBox(height: context.eos.spacing.sm),
      ...children,
      SizedBox(height: context.eos.spacing.lg),
    ];
  }
}
