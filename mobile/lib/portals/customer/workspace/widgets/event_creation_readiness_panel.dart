import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../eos/eos.dart';
import '../../../../features/organizer/models/organizer_models.dart';
import '../../../../features/organizer/wizard_v2/event_publish_readiness.dart';
import '../../../../shared/models/event_access_mode.dart';
import '../../models/command_center_models.dart';
import '../../navigation/event_navigator.dart';

/// Post-create guidance — single next-best-action surface (no duplicate editors).
///
/// Journey after Create Event:
/// 1. Event Workspace opens
/// 2. This checklist ranks: public tickets → incomplete details → publish
/// 3. Actions deep-link into existing Tickets / Details modules
class EventCreationReadinessPanel extends ConsumerWidget {
  const EventCreationReadinessPanel({
    super.key,
    required this.eventId,
    required this.snapshot,
  });

  final String eventId;
  final EventCommandCenterSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = snapshot.event;
    final access = event.isPublicTicketed
        ? EventAccessMode.publicTicketed
        : EventAccessMode.privateInvitation;
    final readiness = evaluateEventPublishReadiness(
      title: event.title,
      startsAt: event.startsAt,
      endsAt: event.endsAt,
      accessMode: access,
      venueDeferred: event.venue.isEmpty && event.city.isEmpty,
      venueName: event.venue,
      city: event.city,
      ticketTiers: [
        for (final t in event.ticketTiers)
          OrganizerTicketTier(
            id: t.id,
            name: t.name,
            description: t.description,
            priceMinor: t.priceMinor,
            currency: t.currency,
            capacity: t.capacity,
            remaining: t.remaining,
          ),
      ],
      description: event.description,
      celebrantImageUrl: event.celebrantImageUrl,
    );

    final next = readiness.nextBestActionId;
    final primaryLabel = switch (next) {
      'tickets' => 'Create tickets next',
      'details' => 'Complete event details',
      'venue' => 'Set venue',
      'publish' => readiness.readyToPublish ? 'Ready to publish' : 'Review setup',
      _ => 'Continue setup',
    };

    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Setup checklist', style: context.eosText.titleMedium),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            readiness.readyToPublish
                ? 'Your event is ready to publish when you are. Tickets, guests, and vendors stay in their modules.'
                : 'Finish the items below — we will guide the next best action without duplicating tools.',
            style: context.eosText.bodySmall,
          ),
          SizedBox(height: context.eos.spacing.md),
          for (final item in readiness.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: item.done ? Colors.green : context.eosColors.outline,
                size: 22,
              ),
              title: Text(item.label, style: context.eosText.bodyMedium),
            ),
          SizedBox(height: context.eos.spacing.md),
          FilledButton.icon(
            onPressed: () => _runNext(context, next, readiness),
            icon: Icon(next == 'tickets' ? Icons.confirmation_number_outlined : Icons.flag_outlined),
            label: Text(primaryLabel),
          ),
          if (next == 'tickets') ...[
            SizedBox(height: context.eos.spacing.xs),
            Text(
              'Public ticketed events must have tiers before publish.',
              style: context.eosText.bodySmall?.copyWith(color: EosColors.slate500),
            ),
          ],
        ],
      ),
    );
  }

  void _runNext(BuildContext context, String next, EventPublishReadiness readiness) {
    switch (next) {
      case 'tickets':
        context.eventNav.openTicketsManage(eventId);
      case 'venue':
      case 'details':
        context.eventNav.openOverview(eventId);
      case 'publish':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              readiness.readyToPublish
                  ? 'Checklist complete — publish from the event header or Events list when ready.'
                  : 'Complete remaining checklist items first.',
            ),
          ),
        );
      default:
        context.eventNav.openOverview(eventId);
    }
  }
}
