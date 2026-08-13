import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/guest_invitations_api.dart';
import '../../../eos/eos.dart';
import '../../../features/public/models/attendee_event_models.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_hub_providers.dart';
import '../widgets/attendee_flow_scaffold.dart';

/// Registration + RSVP management — reuses entitlements and guest invitation APIs.
class AttendeeRegistrationsScreen extends ConsumerWidget {
  const AttendeeRegistrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(attendeeEventsProvider);
    final rsvpAsync = ref.watch(attendeeGuestInvitationsProvider);
    final pendingTicketsAsync = ref.watch(attendeePendingTicketInvitationsProvider);
    final offline = ref.watch(attendeeOfflineProvider);

    return AttendeeFlowScaffold(
      backLabel: 'Dashboard',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.dashboard),
      body: RefreshIndicator(
        onRefresh: () async {
          invalidateAttendeePassesAfterRsvp(ref);
          ref.invalidate(attendeePendingTicketInvitationsProvider);
          await Future.wait([
            ref.read(attendeeEventsProvider.future),
            ref.read(attendeeGuestInvitationsProvider.future),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            Text('Registration management', style: context.eosText.headlineMedium),
            SizedBox(height: context.eos.spacing.xs),
            Text(
              'Ticket registrations, RSVP responses, and invitation status.',
              style: context.eosText.bodySmall,
            ),
            if (offline) ...[
              SizedBox(height: context.eos.spacing.sm),
              const EosAttentionBanner(
                headline: 'Offline',
                message: 'RSVP actions need a network connection.',
                severity: 'WARNING',
              ),
            ],
            SizedBox(height: context.eos.spacing.lg),
            Text('Ticket registrations', style: context.eosText.titleMedium),
            SizedBox(height: context.eos.spacing.sm),
            ticketsAsync.when(
              loading: () => const EosSurfaceCard(
                child: SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
              ),
              error: (e, _) => EosAttentionBanner(headline: 'Error', message: '$e', severity: 'CRITICAL'),
              data: (events) {
                if (events.isEmpty) {
                  return EosSurfaceCard(
                    child: Text('No ticket registrations yet.', style: context.eosText.bodyMedium),
                  );
                }
                return Column(
                  children: [
                    for (final e in events) ...[
                      EosSurfaceCard(
                        onTap: () => context.push(AttendeeRoutes.registrationDetail(e.ticket.id)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.eventTitle, style: context.eosText.titleSmall),
                                  Text(
                                    'Status: ${e.lifecycleLabel} · ${e.entitlementStatus}',
                                    style: context.eosText.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                      SizedBox(height: context.eos.spacing.sm),
                    ],
                  ],
                );
              },
            ),
            SizedBox(height: context.eos.spacing.xl),
            Text('RSVP invitations', style: context.eosText.titleMedium),
            SizedBox(height: context.eos.spacing.sm),
            rsvpAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => EosAttentionBanner(headline: 'RSVP error', message: '$e', severity: 'CRITICAL'),
              data: (items) {
                if (items.isEmpty) {
                  return EosSurfaceCard(
                    child: Text('No RSVP invitations for your email.', style: context.eosText.bodyMedium),
                  );
                }
                return Column(
                  children: [
                    for (final item in items) ...[
                      _RsvpCard(item: item, offline: offline),
                      SizedBox(height: context.eos.spacing.sm),
                    ],
                  ],
                );
              },
            ),
            SizedBox(height: context.eos.spacing.xl),
            Text('Pending ticket invitations', style: context.eosText.titleMedium),
            SizedBox(height: context.eos.spacing.sm),
            pendingTicketsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (items) {
                if (items.isEmpty) {
                  return EosSurfaceCard(
                    child: Text('No unclaimed ticket invitations.', style: context.eosText.bodyMedium),
                  );
                }
                return Column(
                  children: [
                    for (final i in items)
                      EosFeedItem(
                        title: i.eventTitle,
                        subtitle: '${i.city} · ${i.venue}',
                        timestamp: i.startsAt.toLocal().toString().split('.').first,
                        leading: Icon(Icons.mail_outline, color: context.eosColors.primary),
                        onTap: () => context.push(AttendeeRoutes.eventDetail(i.eventId)),
                      ),
                  ],
                );
              },
            ),
            SizedBox(height: context.eos.spacing.lg),
            OutlinedButton.icon(
              onPressed: () => context.push(AttendeeRoutes.profile),
              icon: const Icon(Icons.accessibility_new, size: 18),
              label: const Text('Update dietary & accessibility (profile)'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push(AttendeeRoutes.orders),
              icon: const Icon(Icons.money_off_outlined, size: 18),
              label: const Text('Cancel via purchase / refund'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RsvpCard extends ConsumerStatefulWidget {
  const _RsvpCard({required this.item, required this.offline});

  final GuestInvitationItem item;
  final bool offline;

  @override
  ConsumerState<_RsvpCard> createState() => _RsvpCardState();
}

class _RsvpCardState extends ConsumerState<_RsvpCard> {
  bool _busy = false;

  Future<void> _respond(String status) async {
    final session = ref.read(authSessionProvider);
    if (session == null || _busy || widget.offline) return;
    setState(() => _busy = true);
    try {
      await ref.read(guestInvitationsApiProvider).respond(
            session: session,
            guestId: widget.item.id,
            status: status,
          );
      invalidateAttendeePassesAfterRsvp(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(status == 'confirmed' ? 'RSVP confirmed' : 'RSVP declined')),
        );
      }
    } on GuestInvitationApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.eventTitle, style: context.eosText.titleSmall),
          Text(
            'RSVP: ${item.rsvpStatus} · ${item.eventCity}',
            style: context.eosText.bodySmall,
          ),
          if (item.isPending) ...[
            SizedBox(height: context.eos.spacing.sm),
            Row(
              children: [
                FilledButton(
                  onPressed: (_busy || widget.offline) ? null : () => _respond('confirmed'),
                  child: const Text('Accept'),
                ),
                SizedBox(width: context.eos.spacing.sm),
                OutlinedButton(
                  onPressed: (_busy || widget.offline) ? null : () => _respond('declined'),
                  child: const Text('Decline'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Single registration detail — ticket entitlement + actions.
class AttendeeRegistrationDetailScreen extends ConsumerWidget {
  const AttendeeRegistrationDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(attendeeEventsProvider).valueOrNull ?? const <AttendeeEventView>[];
    AttendeeEventView? match;
    for (final e in events) {
      if (e.ticket.id == ticketId) {
        match = e;
        break;
      }
    }
    if (match == null) {
      return AttendeeFlowScaffold(
        backLabel: 'Registrations',
        onBack: () => context.go(AttendeeRoutes.registrations),
        body: const Center(child: Text('Registration not found')),
      );
    }
    final e = match;
    return AttendeeFlowScaffold(
      backLabel: 'Registrations',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.registrations),
      body: ListView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: [
          Text(e.eventTitle, style: context.eosText.headlineMedium),
          SizedBox(height: context.eos.spacing.sm),
          EosSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registration status: ${e.lifecycleLabel}', style: context.eosText.titleSmall),
                Text('Entitlement: ${e.entitlementStatus}', style: context.eosText.bodySmall),
                Text('Tier: ${e.tierName}', style: context.eosText.bodySmall),
                Text(formatAttendeeDateRange(e.startsAt, e.endsAt), style: context.eosText.bodySmall),
                Text('${e.venue}, ${e.city}', style: context.eosText.bodySmall),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          FilledButton(
            onPressed: () => context.push(AttendeeRoutes.passes),
            child: const Text('Open digital pass'),
          ),
          OutlinedButton(
            onPressed: () => context.push(AttendeeRoutes.eventDetail(e.eventId)),
            child: const Text('Event details'),
          ),
          OutlinedButton(
            onPressed: () => context.push(AttendeeRoutes.orders),
            child: const Text('Cancel / refund via orders'),
          ),
          TextButton(
            onPressed: () => context.push(AttendeeRoutes.profile),
            child: const Text('Update attendee profile'),
          ),
        ],
      ),
    );
  }
}
