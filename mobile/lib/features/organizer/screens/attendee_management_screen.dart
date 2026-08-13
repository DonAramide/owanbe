import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/events_api.dart';
import '../../../eos/eos.dart';
import '../../operations/providers/operations_providers.dart';
import '../providers/organizer_providers.dart';
import '../widgets/organizer_shared.dart';

class AttendeeManagementScreen extends ConsumerWidget {
  const AttendeeManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventId = ref.watch(selectedOrganizerEventIdProvider);
    final query = ref.watch(attendeeSearchQueryProvider).toLowerCase();
    final eventAsync = eventId == null ? null : ref.watch(organizerEventProvider(eventId));

    return EosPageScaffold(
      title: 'Attendee management',
      subtitle: 'Search, purchase history, and attendance timeline',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OrganizerEventPicker(),
          SizedBox(height: context.eos.spacing.md),
          EosTextField(
            label: 'Search attendees',
            hint: 'Name, email, or ticket ID',
            onChanged: (v) => ref.read(attendeeSearchQueryProvider.notifier).state = v,
          ),
          SizedBox(height: context.eos.spacing.lg),
          if (eventId == null)
            EosSurfaceCard(child: Text('Select an event', style: context.eosText.bodyMedium))
          else
            eventAsync!.when(
              data: (event) {
                if (event == null) return const Text('Event not found');
                final filtered = event.attendees.where((a) {
                  if (query.isEmpty) return true;
                  return a.name.toLowerCase().contains(query) ||
                      a.email.toLowerCase().contains(query) ||
                      a.ticketId.toLowerCase().contains(query);
                }).toList();
                final checkedIn = event.checkedInCount;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: context.eos.spacing.md,
                      children: [
                        SizedBox(
                          width: 200,
                          child: EosKpiCard(
                            title: 'Registered',
                            value: '${event.attendees.length}',
                            icon: Icons.people_outline,
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: EosKpiCard(
                            title: 'Checked in',
                            value: '$checkedIn',
                            attention: checkedIn > 0 ? EosKpiAttention.info : EosKpiAttention.none,
                            icon: Icons.qr_code_scanner,
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: EosKpiCard(
                            title: 'No-shows',
                            value: '${event.noShowCount}',
                            icon: Icons.person_off_outlined,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.eos.spacing.lg),
                    if (filtered.isEmpty)
                      EosSurfaceCard(
                        child: Text('No matching attendees', style: context.eosText.bodyMedium),
                      )
                    else
                      for (final a in filtered)
                        Padding(
                          padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                          child: EosSurfaceCard(
                            child: ExpansionTile(
                              title: Text(a.name, style: context.eosText.titleSmall),
                              subtitle: Text('${a.tierName} · ${a.email}'),
                              trailing: EosCheckinStatus(checkedIn: a.checkedIn),
                              children: [
                                for (final p in a.purchases)
                                  ListTile(
                                    dense: true,
                                    title: Text(p.item),
                                    subtitle: Text('${p.purchasedAt}'),
                                    trailing: OrganizerMoneyText(minor: p.amountMinor, compact: true),
                                  ),
                                for (final t in a.timeline)
                                  ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.timeline, size: 18),
                                    title: Text(t.label),
                                    subtitle: Text('${t.at}'),
                                  ),
                                if (!a.checkedIn)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: () async {
                                        try {
                                          await performOrganizerAttendeeCheckIn(
                                            ref,
                                            eventId: event.id,
                                            entitlementOrGuestId: a.id,
                                            ticketCode: a.ticketId,
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('${a.name} checked in')),
                                            );
                                          }
                                        } on EventsApiException catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(e.message)),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('$e')),
                                            );
                                          }
                                        }
                                      },
                                      child: const Text('Check in'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
        ],
      ),
    );
  }
}
