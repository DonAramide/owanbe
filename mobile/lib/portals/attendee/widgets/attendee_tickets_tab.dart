import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/guest_invitations_api.dart';
import '../../../eos/eos.dart';
import '../../../features/public/models/attendee_event_models.dart';
import '../../../features/public/models/attendee_pass_status.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../../../features/public/providers/public_providers.dart';
import '../../../features/public/widgets/attendee_event_card.dart';
import '../../../features/public/widgets/public_event_grid.dart';
import '../../../identity/identity_provider.dart';
import '../../customer/models/home_hub_models.dart';
import '../../customer/providers/customer_home_providers.dart';
import '../../customer/widgets/home/home_invitation_card.dart';
import '../../customer/widgets/home/home_welcome_hero.dart';
import '../commerce/purchase_notifications_provider.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_hub_providers.dart';
import '../screens/attendee_profile_card_sheet.dart';
import 'attendee_tab_scroll_padding.dart';

/// Primary attendee home — tickets, invitations, recommendations, and quick actions.
class AttendeeTicketsTab extends ConsumerWidget {
  const AttendeeTicketsTab({
    super.key,
    required this.onDiscover,
    required this.onSchedule,
  });

  final VoidCallback onDiscover;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(attendeeEventsProvider);
    final statsAsync = ref.watch(attendeeDashboardStatsProvider);
    final snapshotAsync = ref.watch(attendeeHomeSnapshotProvider);
    final recommendedAsync = ref.watch(publicEventsProvider);
    final purchaseNotices = ref.watch(purchaseNotificationsProvider);
    final pendingTicketsAsync = ref.watch(attendeePendingTicketInvitationsProvider);
    final guestInvitesAsync = ref.watch(attendeeGuestInvitationsProvider);
    final offline = ref.watch(attendeeOfflineProvider);

    return RefreshIndicator(
      onRefresh: () async {
        refreshCustomerHome(ref);
        invalidateAttendeePassesAfterRsvp(ref);
        ref.invalidate(attendeePendingTicketInvitationsProvider);
        await Future.wait([
          ref.refresh(attendeeHomeSnapshotProvider.future),
          ref.refresh(attendeeEventsProvider.future),
          ref.refresh(publicEventsProvider.future),
          ref.refresh(attendeeGuestInvitationsProvider.future),
        ]);
      },
      child: eventsAsync.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.eos.spacing.lg).copyWith(
            bottom: attendeeTabScrollPadding(context).bottom,
          ),
          children: const [Center(child: CircularProgressIndicator())],
        ),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [EosSurfaceCard(child: Text('$e'))],
        ),
        data: (events) {
          final snapshot = snapshotAsync.valueOrNull ?? const AttendeeHomeSnapshot(invitations: []);
          final stats = statsAsync.valueOrNull;
          final session = ref.watch(authSessionProvider);
          final identity = ref.watch(userIdentityProvider).valueOrNull;
          final nearestInvite = snapshot.nearestInvitation;
          final nearestEventSummary = nearestInvite == null
              ? null
              : CustomerEventSummary(
                  id: nearestInvite.eventId,
                  title: nearestInvite.eventTitle,
                  startsAt: nearestInvite.startsAt,
                  venue: nearestInvite.venue,
                  city: nearestInvite.city,
                  status: CustomerEventStatus.published,
                  guestCount: 0,
                  progress: 0,
                  coverGradientStart: 0xFF4A1942,
                  coverGradientEnd: 0xFF7B2D6E,
                  isLive: nearestInvite.startsAt.isBefore(DateTime.now().add(const Duration(hours: 6))) &&
                      nearestInvite.startsAt.isAfter(DateTime.now().subtract(const Duration(hours: 6))),
                );

          final ticketInvites = pendingTicketsAsync.valueOrNull ?? const [];
          final rsvpPending = (guestInvitesAsync.valueOrNull ?? const [])
              .where((i) => i.isPending)
              .toList();
          final recommended = recommendedAsync.valueOrNull
                  ?.where((e) => e.isFeatured || e.status.toLowerCase() == 'upcoming')
                  .take(4)
                  .toList() ??
              [];

          Future<void> respondRsvp(GuestInvitationItem item, String status) async {
            final session = ref.read(authSessionProvider);
            if (session == null || offline) return;
            try {
              await ref.read(guestInvitationsApiProvider).respond(
                    session: session,
                    guestId: item.id,
                    status: status,
                  );
              invalidateAttendeePassesAfterRsvp(ref);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(status == 'confirmed' ? 'RSVP confirmed' : 'RSVP declined')),
                );
              }
            } on GuestInvitationApiException catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
              }
            }
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: attendeeTabScrollPadding(context).bottom),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.eos.spacing.lg,
                  context.eos.spacing.lg,
                  context.eos.spacing.lg,
                  0,
                ),
                child: HomeWelcomeHero(
                  displayName: identity?.displayName ?? session?.displayName ?? 'Guest',
                  avatarUrl: identity?.avatarUrl,
                  onAvatarTap: () => showAttendeeProfileCard(context, ref),
                  nearestEvent: nearestEventSummary,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.eos.spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: context.eos.spacing.lg),
                    if (offline)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: EosAttentionBanner(
                          headline: 'Offline',
                          message: 'Some command-centre actions need a connection.',
                          severity: 'WARNING',
                        ),
                      ),
                    if (stats != null) _KpiRow(stats: stats),
                    if (stats?.nextEvent != null) ...[
                      SizedBox(height: context.eos.spacing.lg),
                      EosAttentionBanner(
                        headline: 'Next up',
                        message:
                            '${stats!.nextEvent!.eventTitle} · ${formatAttendeeDateRange(stats.nextEvent!.startsAt, stats.nextEvent!.endsAt)}',
                        severity: 'INFO',
                        actionLabel: 'View details',
                        onAction: () => context.push(AttendeeRoutes.eventDetail(stats.nextEvent!.eventId)),
                      ),
                    ],
                    SizedBox(height: context.eos.spacing.lg),
                    _SectionHeader(
                      title: 'Command centre',
                      subtitle: 'Manage events, passes, registrations, and activity from one place.',
                    ),
                    SizedBox(height: context.eos.spacing.md),
                    Wrap(
                      spacing: context.eos.spacing.sm,
                      runSpacing: context.eos.spacing.sm,
                      children: [
                        FilledButton.icon(
                          onPressed: () => context.push(AttendeeRoutes.myEvents),
                          icon: const Icon(Icons.celebration_outlined, size: 18),
                          label: const Text('My Events'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push(AttendeeRoutes.passes),
                          icon: const Icon(Icons.qr_code_2, size: 18),
                          label: const Text('My Passes'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push(AttendeeRoutes.services),
                          icon: const Icon(Icons.handyman_outlined, size: 18),
                          label: const Text('Services'),
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
                          onPressed: () => context.push(AttendeeRoutes.orders),
                          icon: const Icon(Icons.receipt_long_outlined, size: 18),
                          label: const Text('Orders'),
                        ),
                        OutlinedButton.icon(
                          onPressed: onSchedule,
                          icon: const Icon(Icons.calendar_month_outlined, size: 18),
                          label: const Text('Schedule'),
                        ),
                      ],
                    ),
                    SizedBox(height: context.eos.spacing.xl),
                    if (purchaseNotices.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'Purchase alerts',
                        subtitle: 'Payment and ticket delivery updates.',
                        actionLabel: 'Orders',
                        onAction: () => context.push(AttendeeRoutes.orders),
                      ),
                      SizedBox(height: context.eos.spacing.md),
                      for (final n in purchaseNotices.take(5)) ...[
                        EosFeedItem(
                          title: n.title,
                          subtitle: n.body,
                          timestamp: n.createdAt.toLocal().toString().split('.').first,
                          leading: Icon(
                            n.type == PurchaseNotificationType.paymentFailure
                                ? Icons.error_outline
                                : Icons.notifications_active_outlined,
                            color: context.eosColors.primary,
                          ),
                        ),
                        SizedBox(height: context.eos.spacing.sm),
                      ],
                      SizedBox(height: context.eos.spacing.lg),
                    ],
                    _SectionHeader(
                      title: 'My tickets',
                      subtitle: 'Digital passes and QR check-in for events you own.',
                      actionLabel: 'My Passes',
                      onAction: () => context.push(AttendeeRoutes.passes),
                    ),
                    SizedBox(height: context.eos.spacing.md),
                    if (events.isEmpty)
                      EosSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('No tickets yet', style: context.eosText.titleMedium),
                            SizedBox(height: context.eos.spacing.sm),
                            Text(
                              'Buy a ticket or accept an invitation — your passes will appear here.',
                              style: context.eosText.bodyMedium,
                            ),
                            SizedBox(height: context.eos.spacing.md),
                            FilledButton(onPressed: onDiscover, child: const Text('Discover events')),
                          ],
                        ),
                      )
                    else
                      for (final event in events) ...[
                        AttendeeEventCard(
                          event: event,
                          onOpenDetail: () => context.push(AttendeeRoutes.eventDetail(event.eventId)),
                          onShowQr: () => context.push(AttendeeRoutes.entry(event.ticket.id)),
                        ),
                        SizedBox(height: context.eos.spacing.md),
                      ],
                    SizedBox(height: context.eos.spacing.lg),
                    _SectionHeader(
                      title: 'Pending invitations',
                      subtitle: 'Unclaimed ticket invitations for your email.',
                      actionLabel: 'Registrations',
                      onAction: () => context.push(AttendeeRoutes.registrations),
                    ),
                    SizedBox(height: context.eos.spacing.md),
                    if (ticketInvites.isEmpty)
                      EosSurfaceCard(
                        child: Text(
                          'No pending ticket invitations. When organizers send you tickets, they appear here.',
                          style: context.eosText.bodyMedium,
                        ),
                      )
                    else
                      SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: ticketInvites.length,
                          separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.md),
                          itemBuilder: (context, index) {
                            final invite = ticketInvites[index];
                            return HomeInvitationCard(
                              invitation: invite,
                              onTap: () => context.push(AttendeeRoutes.eventDetail(invite.eventId)),
                            );
                          },
                        ),
                      ),
                    SizedBox(height: context.eos.spacing.xl),
                    _SectionHeader(
                      title: 'RSVP requests',
                      subtitle: 'Respond to invitations awaiting your confirmation.',
                      actionLabel: 'Manage',
                      onAction: () => context.push(AttendeeRoutes.registrations),
                    ),
                    SizedBox(height: context.eos.spacing.md),
                    if (rsvpPending.isEmpty)
                      EosSurfaceCard(
                        child: Text(
                          'No RSVP requests right now.',
                          style: context.eosText.bodyMedium,
                        ),
                      )
                    else
                      for (final invite in rsvpPending) ...[
                        EosSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(invite.eventTitle, style: context.eosText.titleSmall),
                              Text(
                                '${invite.eventCity} · ${invite.rsvpStatus}',
                                style: context.eosText.bodySmall,
                              ),
                              SizedBox(height: context.eos.spacing.sm),
                              Row(
                                children: [
                                  FilledButton(
                                    onPressed: offline ? null : () => respondRsvp(invite, 'confirmed'),
                                    child: const Text('Accept'),
                                  ),
                                  SizedBox(width: context.eos.spacing.sm),
                                  OutlinedButton(
                                    onPressed: offline ? null : () => respondRsvp(invite, 'declined'),
                                    child: const Text('Decline'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: context.eos.spacing.sm),
                      ],
                    SizedBox(height: context.eos.spacing.xl),
                    _SectionHeader(
                      title: 'Check-in status',
                      subtitle: 'Live admission status — tap a chip to open Event Entry.',
                      actionLabel: 'My Passes',
                      onAction: () => context.push(AttendeeRoutes.passes),
                    ),
                    SizedBox(height: context.eos.spacing.md),
                    if (events.isEmpty)
                      EosSurfaceCard(
                        child: Text('Check-in status appears after you have tickets.', style: context.eosText.bodyMedium),
                      )
                    else
                      Wrap(
                        spacing: context.eos.spacing.sm,
                        runSpacing: context.eos.spacing.sm,
                        children: [
                          for (final event in events)
                            ActionChip(
                              avatar: Icon(
                                event.liveStatus.isCheckedInState
                                    ? Icons.check_circle
                                    : event.liveStatus == AttendeePassLiveStatus.readyForEntry
                                        ? Icons.login
                                        : event.isCancelled
                                            ? Icons.cancel_outlined
                                            : Icons.schedule,
                                size: 18,
                                color: event.liveStatus.isCheckedInState
                                    ? Colors.green
                                    : context.eosColors.onSurfaceVariant,
                              ),
                              label: Text(
                                '${event.liveStatusLabel}: ${event.eventTitle}',
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () => context.push(AttendeeRoutes.entry(event.ticket.id)),
                            ),
                        ],
                      ),
                    SizedBox(height: context.eos.spacing.xl),
                    _SectionHeader(
                      title: 'Recommended for you',
                      subtitle: 'Curated celebrations you might love.',
                      actionLabel: 'See all',
                      onAction: onDiscover,
                    ),
                    SizedBox(height: context.eos.spacing.md),
                    if (recommended.isEmpty)
                      EosSurfaceCard(
                        child: Text('Recommendations will appear as more events go live.', style: context.eosText.bodyMedium),
                      )
                    else
                      PublicEventGrid(
                        events: recommended,
                        onEventTap: (event) => context.push(AttendeeRoutes.eventDetail(event.id)),
                      ),
                    SizedBox(height: context.eos.spacing.xl),
                    _SectionHeader(
                      title: 'Recent activity',
                      subtitle: 'Your latest ticket and RSVP updates.',
                    ),
                    SizedBox(height: context.eos.spacing.md),
                    if (events.isEmpty)
                      EosSurfaceCard(
                        child: Text('Activity will show here once you attend your first event.', style: context.eosText.bodyMedium),
                      )
                    else
              for (final event in events.take(5)) ...[
                        EosFeedItem(
                          title: '${event.lifecycleLabel} · ${event.eventTitle}',
                          subtitle: '${event.tierName} · ${event.city}',
                          timestamp: formatAttendeeDateRange(event.startsAt, event.endsAt),
                          leading: Icon(
                            event.checkedIn ? Icons.how_to_reg : Icons.confirmation_number_outlined,
                            color: context.eosColors.primary,
                          ),
                          onTap: () => context.push(AttendeeRoutes.eventDetail(event.eventId)),
                        ),
                        SizedBox(height: context.eos.spacing.sm),
                      ],
                    SizedBox(height: context.eos.spacing.xl),
                    _SectionHeader(
                      title: 'Quick actions',
                      subtitle: 'Everything you need as a guest.',
                    ),
                    SizedBox(height: context.eos.spacing.md),
                    Wrap(
                      spacing: context.eos.spacing.sm,
                      runSpacing: context.eos.spacing.sm,
                      children: [
                        FilledButton.icon(
                          onPressed: () => context.push(AttendeeRoutes.myEvents),
                          icon: const Icon(Icons.celebration_outlined, size: 18),
                          label: const Text('My Events'),
                        ),
                        OutlinedButton.icon(
                          onPressed: onDiscover,
                          icon: const Icon(Icons.explore_outlined, size: 18),
                          label: const Text('Discover events'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push(AttendeeRoutes.findTicket),
                          icon: const Icon(Icons.search_outlined, size: 18),
                          label: const Text('Find my ticket'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push(AttendeeRoutes.passes),
                          icon: const Icon(Icons.qr_code_2, size: 18),
                          label: const Text('My Passes'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push(AttendeeRoutes.services),
                          icon: const Icon(Icons.handyman_outlined, size: 18),
                          label: const Text('Services'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push(AttendeeRoutes.orders),
                          icon: const Icon(Icons.receipt_long_outlined, size: 18),
                          label: const Text('Purchase history'),
                        ),
                        OutlinedButton.icon(
                          onPressed: onSchedule,
                          icon: const Icon(Icons.calendar_month_outlined, size: 18),
                          label: const Text('View schedule'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push(AttendeeRoutes.profile),
                          icon: const Icon(Icons.person_outline, size: 18),
                          label: const Text('Edit Attendee Profile'),
                        ),
                      ],
                    ),
                    SizedBox(height: context.eos.spacing.lg),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.stats});

  final AttendeeDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.eos.spacing.md,
      runSpacing: context.eos.spacing.md,
      children: [
        _kpi(context, 'My tickets', '${stats.totalTickets}', Icons.confirmation_number_outlined),
        _kpi(context, 'Upcoming', '${stats.upcoming}', Icons.event_outlined),
        _kpi(context, 'Checked in', '${stats.checkedIn}', Icons.how_to_reg_outlined),
      ],
    );
  }

  Widget _kpi(BuildContext context, String title, String value, IconData icon) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = width < 600 ? (width - context.eos.spacing.lg * 2 - context.eos.spacing.md) / 2 : 200.0;
    return SizedBox(
      width: cardWidth.clamp(140, 220),
      child: EosKpiCard(title: title, value: value, icon: icon),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.eosText.titleMedium),
              SizedBox(height: context.eos.spacing.xxs),
              Text(subtitle, style: context.eosText.bodySmall),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}
