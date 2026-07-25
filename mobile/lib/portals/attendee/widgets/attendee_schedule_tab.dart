import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../features/public/models/attendee_event_models.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
import '../navigation/attendee_routes.dart';
import 'attendee_tab_scroll_padding.dart';

/// Attendee celebration timeline — stays inside the workspace shell.
class AttendeeScheduleTab extends ConsumerWidget {
  const AttendeeScheduleTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(attendeeEventsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(attendeeEventsProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(context.eos.spacing.lg).copyWith(
          bottom: attendeeTabScrollPadding(context).bottom,
        ),
        children: [
          Text('Schedule', style: context.eosText.headlineMedium),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            'Your celebration timeline — upcoming events, check-ins, and doors-open times.',
            style: context.eosText.bodyMedium?.copyWith(color: context.eosColors.onSurfaceVariant),
          ),
          SizedBox(height: context.eos.spacing.lg),
          eventsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EosSurfaceCard(child: Text('$e')),
            data: (events) {
              if (events.isEmpty) {
                return EosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No events on your schedule', style: context.eosText.titleMedium),
                      SizedBox(height: context.eos.spacing.sm),
                      Text(
                        'When you buy tickets or accept invitations, your timeline will appear here.',
                        style: context.eosText.bodyMedium,
                      ),
                    ],
                  ),
                );
              }

              final upcoming = events.where((e) => e.lifecycle == AttendeeEventLifecycle.upcoming).toList();
              final ongoing = events.where((e) => e.lifecycle == AttendeeEventLifecycle.ongoing).toList();
              final past = events.where((e) => e.lifecycle == AttendeeEventLifecycle.past).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (ongoing.isNotEmpty) ...[
                    Text('Ongoing', style: context.eosText.titleSmall),
                    SizedBox(height: context.eos.spacing.sm),
                    for (final event in ongoing) ...[
                      _ScheduleTile(event: event),
                      SizedBox(height: context.eos.spacing.sm),
                    ],
                    SizedBox(height: context.eos.spacing.md),
                  ],
                  if (upcoming.isNotEmpty) ...[
                    Text('Upcoming', style: context.eosText.titleSmall),
                    SizedBox(height: context.eos.spacing.sm),
                    for (final event in upcoming) ...[
                      _ScheduleTile(event: event),
                      SizedBox(height: context.eos.spacing.sm),
                    ],
                    SizedBox(height: context.eos.spacing.md),
                  ],
                  if (past.isNotEmpty) ...[
                    Text('Past', style: context.eosText.titleSmall),
                    SizedBox(height: context.eos.spacing.sm),
                    for (final event in past) ...[
                      _ScheduleTile(event: event, muted: true),
                      SizedBox(height: context.eos.spacing.sm),
                    ],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({required this.event, this.muted = false});

  final AttendeeEventView event;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final goLive = event.isOngoing || event.checkedIn;
    return EosFeedItem(
      title: event.eventTitle,
      subtitle: '${event.venue}, ${event.city} · ${event.tierName}'
          '${goLive ? ' · Live available' : ''}',
      timestamp: formatAttendeeDateRange(event.startsAt, event.endsAt),
      leading: Icon(
        event.isOngoing ? Icons.sensors : event.checkedIn ? Icons.how_to_reg : Icons.celebration_outlined,
        color: muted ? context.eosColors.onSurfaceVariant : context.eosColors.primary,
      ),
      trailing: goLive
          ? TextButton(
              onPressed: () => context.push(AttendeeRoutes.live(event.eventId)),
              child: const Text('Live'),
            )
          : null,
      onTap: () => context.push(
        goLive ? AttendeeRoutes.live(event.eventId) : AttendeeRoutes.eventDetail(event.eventId),
      ),
    );
  }
}
