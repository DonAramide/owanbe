import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../core/api/event_services_api.dart';
import '../../../features/public/models/attendee_event_models.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_event_services_providers.dart';
import '../providers/attendee_hub_providers.dart';
import '../widgets/attendee_flow_scaffold.dart';
import '../widgets/attendee_networking_widgets.dart';

/// Phase 10 P2 — consolidated personal history shortcuts (past events, tickets,
/// attendance, service bookings, connections).
class AttendeePersonalHistoryScreen extends ConsumerWidget {
  const AttendeePersonalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleAsync = ref.watch(myEventsBundleProvider);
    final bookingsAsync = ref.watch(myServiceBookingsProvider(null));
    final offline = ref.watch(attendeeOfflineProvider);

    return AttendeeFlowScaffold(
      backLabel: 'My Events',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.myEvents),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myEventsBundleProvider);
          ref.invalidate(attendeeTicketsSyncProvider);
          ref.invalidate(myServiceBookingsProvider(null));
          await Future.wait([
            ref.read(myEventsBundleProvider.future),
            ref.read(myServiceBookingsProvider(null).future),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            Semantics(
              header: true,
              child: Text('Personal history', style: context.eosText.headlineMedium),
            ),
            SizedBox(height: context.eos.spacing.xs),
            Text(
              'Past events, tickets, attendance, service bookings, and networking — one place.',
              style: context.eosText.bodySmall,
            ),
            if (offline) ...[
              SizedBox(height: context.eos.spacing.sm),
              const EosAttentionBanner(
                headline: 'Offline',
                message: 'History may be incomplete until you reconnect.',
                severity: 'WARNING',
              ),
            ],
            SizedBox(height: context.eos.spacing.lg),
            bundleAsync.when(
              loading: () => const NetworkingListSkeleton(count: 2),
              error: (e, _) => EosAttentionBanner(
                headline: 'History unavailable',
                message: '$e',
                severity: 'CRITICAL',
              ),
              data: (bundle) {
                final past = bundle.registered
                    .where((e) => e.lifecycle == AttendeeEventLifecycle.past)
                    .toList();
                final attended = past.where((e) => e.checkedIn).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EosSection(
                      title: 'Past events',
                      subtitle: '${past.length} completed registration${past.length == 1 ? '' : 's'}',
                      child: past.isEmpty
                          ? EosSurfaceCard(
                              child: Text(
                                'No past events yet. After you attend, recaps appear here.',
                                style: context.eosText.bodyMedium,
                              ),
                            )
                          : Column(
                              children: [
                                for (final e in past.take(12))
                                  Padding(
                                    padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                                    child: EosSurfaceCard(
                                      onTap: () =>
                                          context.push(AttendeeRoutes.eventRecap(e.eventId)),
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          e.checkedIn
                                              ? Icons.how_to_reg
                                              : Icons.celebration_outlined,
                                          color: context.eosColors.primary,
                                        ),
                                        title: Text(e.eventTitle),
                                        subtitle: Text(
                                          '${e.lifecycleLabel} · ${formatAttendeeDateRange(e.startsAt, e.endsAt)}',
                                        ),
                                        trailing: const Icon(Icons.chevron_right),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    SizedBox(height: context.eos.spacing.lg),
                    EosSection(
                      title: 'Attendance',
                      subtitle: '${attended.length} check-in${attended.length == 1 ? '' : 's'} recorded',
                      child: attended.isEmpty
                          ? EosSurfaceCard(
                              child: Text(
                                'No check-ins yet. Entry validation appears here after the gate.',
                                style: context.eosText.bodyMedium,
                              ),
                            )
                          : Column(
                              children: [
                                for (final e in attended.take(8))
                                  Padding(
                                    padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                                    child: EosSurfaceCard(
                                      onTap: () => context.push(AttendeeRoutes.entry(e.ticket.id)),
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(e.eventTitle),
                                        subtitle: Text(
                                          e.checkedInAt != null
                                              ? 'Checked in · ${formatAttendeeDateTime(e.checkedInAt!)}'
                                              : 'Checked in',
                                        ),
                                        trailing: const Icon(Icons.chevron_right),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: context.eos.spacing.lg),
            EosSection(
              title: 'Tickets & purchases',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push(AttendeeRoutes.orders),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text('Purchase history'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(AttendeeRoutes.passes),
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('My passes'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(AttendeeRoutes.registrations),
                    icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                    label: const Text('Registrations'),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.eos.spacing.lg),
            EosSection(
              title: 'Service bookings',
              child: bookingsAsync.when(
                loading: () => const NetworkingListSkeleton(count: 1),
                error: (e, _) => EosAttentionBanner(
                  headline: 'Bookings unavailable',
                  message: '$e',
                  severity: 'WARNING',
                ),
                data: (bookings) {
                  if (bookings.isEmpty) {
                    return EosSurfaceCard(
                      child: Text(
                        'No service bookings yet.',
                        style: context.eosText.bodyMedium,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final b in bookings.take(8))
                        Padding(
                          padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                          child: EosSurfaceCard(
                            onTap: () => context.push(
                              AttendeeRoutes.serviceBookings(b.booking.eventId),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(b.booking.itemName),
                              subtitle: Text(
                                '${b.booking.eventTitle} · ${serviceStatusLabel(b.serviceStatus)}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => context.push(AttendeeRoutes.serviceBookings()),
                          child: const Text('View all bookings'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(height: context.eos.spacing.lg),
            EosSection(
              title: 'Connections',
              subtitle: 'Open a past event recap to continue networking for that celebration.',
              child: EosSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connections stay event-scoped. Pick a past event to reopen People Hub.',
                      style: context.eosText.bodyMedium,
                    ),
                    SizedBox(height: context.eos.spacing.sm),
                    OutlinedButton.icon(
                      onPressed: () => context.push(AttendeeRoutes.myEvents),
                      icon: const Icon(Icons.event_available_outlined, size: 18),
                      label: const Text('Browse past events'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: context.eos.spacing.xxl),
          ],
        ),
      ),
    );
  }
}
