import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../operations/data/operations_store.dart';
import '../../operations/providers/operations_providers.dart';
import '../data/organizer_event_store.dart';
import '../models/organizer_models.dart';
import '../providers/organizer_providers.dart';
import '../widgets/organizer_shared.dart';

class EventManagementScreen extends ConsumerWidget {
  const EventManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(organizerEventsProvider);

    return EosPageScaffold(
      title: 'Events',
      subtitle: 'Create, publish, and open event workspaces',
      actions: [
        FilledButton.icon(
          onPressed: () => context.push('/organizer/events/new'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New event'),
        ),
      ],
      body: events.when(
        data: (list) => Column(
          children: [
            for (final e in list) ...[
              _EventManageCard(event: e, ref: ref),
              SizedBox(height: context.eos.spacing.sm),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Text('$err'),
      ),
    );
  }
}

class _EventManageCard extends StatelessWidget {
  const _EventManageCard({required this.event, required this.ref});
  final OrganizerEvent event;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: true,
      onTap: () => context.push('/organizer/events/${event.id}'),
      accentColor: event.status == OrganizerEventStatus.draft ? EosColors.warning : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(event.title, style: context.eosText.titleMedium)),
              EosFinanceChip(label: organizerStatusLabel(event.status)),
              if (event.status == OrganizerEventStatus.live) ...[
                SizedBox(width: context.eos.spacing.xs),
                const EosLiveIndicator(compact: true),
              ],
            ],
          ),
          SizedBox(height: context.eos.spacing.xxs),
          Text(
            '${event.city} · ${formatEventDateRange(event.startsAt, event.endsAt)}',
            style: context.eosText.bodySmall,
          ),
          SizedBox(height: context.eos.spacing.xxs),
          Text(
            '${event.ticketsSold}/${event.totalCapacity} sold · ${event.vendors.length} vendors · ${event.attendees.length} attendees',
            style: context.eosText.labelSmall,
          ),
          SizedBox(height: context.eos.spacing.sm),
          Wrap(
            spacing: context.eos.spacing.xs,
            children: [
              FilledButton(
                onPressed: () => context.push('/organizer/events/${event.id}'),
                child: const Text('Open workspace'),
              ),
              if (event.status == OrganizerEventStatus.draft)
                OutlinedButton(
                  onPressed: () {
                    OrganizerEventStore.instance.publish(event.id);
                    bumpOrganizerRevision(ref);
                  },
                  child: const Text('Publish'),
                ),
              if (event.status == OrganizerEventStatus.published)
                OutlinedButton(
                  onPressed: () {
                    OrganizerEventStore.instance.setLive(event.id);
                    OperationsStore.instance.ensureLive(event.id);
                    bumpOrganizerRevision(ref);
                    bumpOperationsRevision(ref);
                    ref.read(liveOpsEventIdProvider.notifier).state = event.id;
                    ref.read(organizerShellTabProvider.notifier).select(6);
                  },
                  child: const Text('Go live'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
