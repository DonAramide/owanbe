import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/events_api.dart';
import '../../../../eos/eos.dart';
import '../../../operations/providers/operations_providers.dart';
import '../../providers/organizer_providers.dart';
import '../providers/event_command_center_v3_providers.dart';
import '../widgets/cc_v3_health_cards.dart';

class AttendeesTabV3 extends ConsumerWidget {
  const AttendeesTabV3({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(eventCommandCenterV3Provider(eventId));
    final query = ref.watch(attendeeSearchQueryProvider).toLowerCase();

    return snapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (snap) {
        final event = snap.event;
        final isTicketed = event.isPublicTicketed;
        var guests = event.attendees.asMap().entries.toList();
        if (query.isNotEmpty) {
          guests = guests
              .where((e) =>
                  e.value.name.toLowerCase().contains(query) ||
                  e.value.email.toLowerCase().contains(query) ||
                  e.value.ticketId.toLowerCase().contains(query) ||
                  e.value.tierName.toLowerCase().contains(query))
              .toList();
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isTicketed) ...[
                CcV3HealthCard(
                  title: 'Ticket buyers',
                  progressPercent: event.attendees.isEmpty
                      ? 0.0
                      : (event.checkedInCount / event.attendees.length) * 100,
                  metrics: [
                    CcV3MetricItem(label: 'Buyers', value: '${event.buyersCount}'),
                    CcV3MetricItem(label: 'Tickets', value: '${event.attendees.length}'),
                    CcV3MetricItem(label: 'Checked in', value: '${event.checkedInCount}'),
                    CcV3MetricItem(label: 'Orders', value: '${event.ordersCount}'),
                  ],
                ),
                SizedBox(height: context.eos.spacing.lg),
                const CcV3SectionHeader(
                  title: 'Attendees',
                  subtitle: 'From ticket entitlements — name, email, tier, status',
                ),
                EosTextField(
                  label: 'Search attendees',
                  hint: 'Name, email, ticket, or tier',
                  onChanged: (v) => ref.read(attendeeSearchQueryProvider.notifier).state = v,
                ),
                SizedBox(height: context.eos.spacing.md),
                if (guests.isEmpty)
                  EosSurfaceCard(
                    child: Text(
                      'No ticket buyers yet. Purchases and free registrations appear here.',
                      style: context.eosText.bodyMedium,
                    ),
                  )
                else
                  for (final entry in guests)
                    Padding(
                      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                      child: EosSurfaceCard(
                        child: ListTile(
                          title: Text(entry.value.name, style: context.eosText.titleSmall),
                          subtitle: Text(
                            '${entry.value.email}\n'
                            '${entry.value.tierName} · ${entry.value.ticketId}\n'
                            '${entry.value.checkedIn ? 'Checked in' : 'Issued'}'
                            '${entry.value.purchasedAt != null ? ' · ${entry.value.purchasedAt!.toLocal()}'.split('.').first : ''}',
                            style: context.eosText.bodySmall,
                          ),
                          isThreeLine: true,
                          trailing: Icon(
                            entry.value.checkedIn ? Icons.check_circle : Icons.confirmation_number_outlined,
                          ),
                          onTap: entry.value.checkedIn
                              ? null
                              : () => _checkIn(
                                    context,
                                    ref,
                                    eventId,
                                    entry.value.id,
                                    ticketCode: entry.value.ticketId,
                                    name: entry.value.name,
                                  ),
                        ),
                      ),
                    ),
              ] else ...[
              CcV3HealthCard(
                title: 'Guest management',
                progressPercent: () {
                  final total = event.attendees.length;
                  if (total == 0) return 0.0;
                  final accepted = event.attendees
                      .where((a) =>
                          a.ticketId == 'confirmed' ||
                          a.ticketId.startsWith('INV-') ||
                          a.ticketId.length > 20)
                      .length;
                  return (accepted / total) * 100;
                }(),
                metrics: [
                  CcV3MetricItem(label: 'Invited', value: '${event.attendees.length}'),
                  CcV3MetricItem(
                    label: 'Accepted',
                    value:
                        '${event.attendees.where((a) => a.ticketId == 'confirmed' || a.ticketId.startsWith('INV-') || a.ticketId.length > 20).length}',
                  ),
                  CcV3MetricItem(
                    label: 'Awaiting',
                    value:
                        '${event.attendees.where((a) => a.ticketId == 'pending' || a.ticketId == 'invited').length}',
                  ),
                  CcV3MetricItem(
                    label: 'Declined',
                    value: '${event.attendees.where((a) => a.ticketId == 'declined').length}',
                  ),
                ],
              ),
              SizedBox(height: context.eos.spacing.lg),
              const CcV3SectionHeader(
                title: 'Invited guests',
                subtitle: 'RSVP status and ticket issued from invitations',
              ),
              Wrap(
                spacing: context.eos.spacing.sm,
                runSpacing: context.eos.spacing.sm,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.push('/events/$eventId/invitations'),
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: const Text('Invitation hub'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/events/$eventId/guests'),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text('Guest list'),
                  ),
                ],
              ),
              SizedBox(height: context.eos.spacing.md),
              EosTextField(
                label: 'Search guests',
                hint: 'Name or email',
                onChanged: (v) => ref.read(attendeeSearchQueryProvider.notifier).state = v,
              ),
              SizedBox(height: context.eos.spacing.md),
              if (guests.isEmpty)
                EosSurfaceCard(
                  child: Text(
                    'No guests yet. Add guests and send invitations from the Invitation hub.',
                    style: context.eosText.bodyMedium,
                  ),
                )
              else
                for (final entry in guests)
                  Padding(
                    padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                    child: EosSurfaceCard(
                      child: ListTile(
                        title: Text(entry.value.name, style: context.eosText.titleSmall),
                        subtitle: Text(
                          '${entry.value.email}\n'
                          'RSVP: ${entry.value.ticketId} · ${entry.value.tierName}\n'
                          '${entry.value.purchasedAt != null ? entry.value.purchasedAt!.toLocal().toString().split('.').first : ''}',
                          style: context.eosText.bodySmall,
                        ),
                        isThreeLine: true,
                        trailing: Icon(
                          entry.value.ticketId.startsWith('INV-') || entry.value.ticketId.length > 20
                              ? Icons.confirmation_number_outlined
                              : Icons.mail_outline,
                        ),
                        onTap: () => context.push('/events/$eventId/invitations'),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkIn(
    BuildContext context,
    WidgetRef ref,
    String eventId,
    String entitlementId, {
    String? ticketCode,
    String? name,
  }) async {
    try {
      await performOrganizerAttendeeCheckIn(
        ref,
        eventId: eventId,
        entitlementOrGuestId: entitlementId,
        ticketCode: ticketCode,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${name ?? 'Guest'} checked in')),
        );
      }
    } on EventsApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

