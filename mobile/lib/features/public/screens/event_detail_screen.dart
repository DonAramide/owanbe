import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../models/attendee_event_models.dart';
import '../models/public_models.dart';
import '../providers/attendee_events_provider.dart';
import '../providers/public_providers.dart';
import '../widgets/attendee_event_card.dart';
import '../widgets/public_event_hero.dart';
import '../widgets/public_shell_mixin.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(publicEventProvider(eventId));
    final hasTicket = ref.watch(attendeeHasTicketProvider(eventId));
    final myEvent = ref
        .watch(attendeeEventsProvider)
        .valueOrNull
        ?.where((e) => e.eventId == eventId)
        .firstOrNull;

    return buildPublicShell(
      context: context,
      ref: ref,
      child: eventAsync.when(
        data: (event) {
          if (event == null) {
            return Center(child: Text('Event not found', style: context.eosText.titleMedium));
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PublicEventHero(
                  event: event,
                  onCta: hasTicket
                      ? () => showAttendeeQrSheet(
                            context,
                            myEvent ??
                                AttendeeEventView.fromTicket(
                                  AttendeeTicket(
                                    id: 'view',
                                    eventId: eventId,
                                    eventTitle: event.title,
                                    tierName: 'Guest',
                                    venue: event.venue,
                                    city: event.city,
                                    startsAt: event.startsAt,
                                    qrPayload: 'OWANBE:$eventId',
                                    purchasedAt: DateTime.now(),
                                  ),
                                  event,
                                ),
                          )
                      : () => context.push('/events/$eventId/tickets'),
                  ctaLabel: hasTicket ? 'Show my ticket' : 'Select tickets',
                ),
                SizedBox(height: context.eos.spacing.xl),
                if (hasTicket && myEvent != null) ...[
                  EosSection(
                    title: 'Your ticket',
                    subtitle: 'You are registered for this celebration',
                    child: AttendeeEventCard(
                      event: myEvent,
                      onShowQr: () => showAttendeeQrSheet(context, myEvent),
                    ),
                  ),
                  SizedBox(height: context.eos.spacing.xl),
                ],
                EosSection(
                  title: 'About this event',
                  child: Text(event.description, style: context.eosText.bodyLarge),
                ),
                EosSection(
                  title: 'Good to know',
                  child: EosSurfaceCard(
                    child: Column(
                      children: [
                        _InfoRow(icon: Icons.schedule, label: 'When', value: _when(event)),
                        Divider(height: context.eos.spacing.lg),
                        _InfoRow(icon: Icons.place_outlined, label: 'Venue', value: '${event.venue}, ${event.city}'),
                        Divider(height: context.eos.spacing.lg),
                        _InfoRow(icon: Icons.people_outline, label: 'Attending', value: '${event.attendeeCount ?? 0}+'),
                        Divider(height: context.eos.spacing.lg),
                        _InfoRow(icon: Icons.category_outlined, label: 'Category', value: event.category),
                      ],
                    ),
                  ),
                ),
                if (!hasTicket)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.push('/events/$eventId/tickets'),
                      child: const Text('Select tickets'),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  String _when(PublicEvent event) {
    final diff = event.endsAt.difference(event.startsAt);
    final hours = diff.inHours;
    final duration = hours > 0 ? '~$hours hours' : '${diff.inMinutes} min';
    return '${event.startsAt.month}/${event.startsAt.day}/${event.startsAt.year} · $duration';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.eosColors.primary),
        SizedBox(width: context.eos.spacing.sm),
        Text(label, style: context.eosText.labelMedium),
        const Spacer(),
        Flexible(child: Text(value, style: context.eosText.bodyMedium, textAlign: TextAlign.end)),
      ],
    );
  }
}
