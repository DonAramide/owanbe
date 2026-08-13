import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../operations/providers/operations_providers.dart';
import '../data/organizer_persistence.dart';
import '../models/organizer_models.dart';
import '../providers/organizer_event_list_filters.dart';
import '../providers/organizer_providers.dart';
import '../widgets/organizer_command_center.dart';
import '../widgets/organizer_shared.dart';

class EventManagementScreen extends ConsumerWidget {
  const EventManagementScreen({super.key});

  static const _pageSize = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(filteredOrganizerEventsProvider);
    final query = ref.watch(organizerEventSearchQueryProvider);
    final statusFilter = ref.watch(organizerEventStatusFilterProvider);
    final sort = ref.watch(organizerEventSortProvider);

    return EosPageScaffold(
      title: 'Events',
      subtitle: 'Create, publish, filter, and open event workspaces',
      actions: [
        OutlinedButton.icon(
          onPressed: () => showOrganizerTemplatePicker(context, ref),
          icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
          label: const Text('Templates'),
        ),
        FilledButton.icon(
          onPressed: () => context.push('/organizer/events/new'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New event'),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EosSearchField(
            hint: 'Search events by title or city…',
            onChanged: (v) => ref.read(organizerEventSearchQueryProvider.notifier).state = v,
            onSubmitted: (v) => ref.read(organizerEventSearchQueryProvider.notifier).state = v,
          ),
          if (query.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => ref.read(organizerEventSearchQueryProvider.notifier).state = '',
                child: const Text('Clear search'),
              ),
            ),
          SizedBox(height: context.eos.spacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusChip(
                  label: 'All',
                  selected: statusFilter == null,
                  onTap: () => ref.read(organizerEventStatusFilterProvider.notifier).state = null,
                ),
                for (final status in OrganizerEventStatus.values)
                  _StatusChip(
                    label: organizerStatusLabel(status),
                    selected: statusFilter == status,
                    onTap: () => ref.read(organizerEventStatusFilterProvider.notifier).state = status,
                  ),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.sm),
          Row(
            children: [
              Text('Sort', style: context.eosText.labelSmall),
              SizedBox(width: context.eos.spacing.sm),
              DropdownButton<OrganizerEventSort>(
                value: sort,
                items: [
                  for (final s in OrganizerEventSort.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) {
                  if (v != null) ref.read(organizerEventSortProvider.notifier).state = v;
                },
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.md),
          events.when(
            data: (list) {
              if (list.isEmpty) {
                return EosSurfaceCard(
                  child: Padding(
                    padding: EdgeInsets.all(context.eos.spacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.celebration_outlined, size: 40),
                        SizedBox(height: context.eos.spacing.sm),
                        Text(
                          statusFilter != null || query.isNotEmpty
                              ? 'No events match your filters'
                              : 'No events yet',
                          style: context.eosText.titleSmall,
                        ),
                        SizedBox(height: context.eos.spacing.sm),
                        FilledButton(
                          onPressed: () => context.push('/organizer/events/new'),
                          child: const Text('Create event'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final visible = list.take(_pageSize).toList();
              final hasMore = list.length > _pageSize;
              return Column(
                children: [
                  for (final e in visible) ...[
                    _EventManageCard(event: e, ref: ref),
                    SizedBox(height: context.eos.spacing.sm),
                  ],
                  if (hasMore)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: context.eos.spacing.md),
                      child: Text(
                        'Showing ${visible.length} of ${list.length} events — refine search to narrow results.',
                        style: context.eosText.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => EosSurfaceCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load events', style: context.eosText.titleSmall),
                  Text('$err', style: context.eosText.bodySmall),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(filteredOrganizerEventsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: context.eos.spacing.xs),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
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
                  onPressed: () async {
                    await publishEvent(ref, event.id);
                  },
                  child: const Text('Publish'),
                ),
              if (event.status == OrganizerEventStatus.published)
                OutlinedButton(
                  onPressed: () async {
                    await goLiveEvent(ref, event.id);
                    bumpOperationsRevision(ref);
                    ref.read(liveOpsEventIdProvider.notifier).state = event.id;
                    ref.read(organizerShellTabProvider.notifier).select(6);
                  },
                  child: const Text('Go live'),
                ),
              OutlinedButton.icon(
                onPressed: () {
                  duplicateOrganizerEvent(ref, event);
                  context.push('/organizer/events/new');
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Duplicate'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
