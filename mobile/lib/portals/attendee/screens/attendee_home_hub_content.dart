import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import '../../customer/models/home_hub_models.dart';
import '../../customer/providers/customer_home_providers.dart';
import '../../customer/widgets/empty_state_card.dart';
import '../../customer/widgets/section_header.dart';
import '../../customer/widgets/home/home_invitation_card.dart';
import '../../customer/widgets/home/home_welcome_hero.dart';
import '../navigation/attendee_routes.dart';

/// Attendee-only home sections — column children (no nested scrollables).
///
/// Used by legacy embeds; primary attendee home is [AttendeeTicketsTab].
class AttendeeHomeHubContent extends ConsumerWidget {
  const AttendeeHomeHubContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(attendeeHomeSnapshotProvider);

    return homeAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _buildSnapshot(context, ref, const AttendeeHomeSnapshot(invitations: [])),
      data: (snapshot) => _buildSnapshot(context, ref, snapshot),
    );
  }

  Widget _buildSnapshot(BuildContext context, WidgetRef ref, AttendeeHomeSnapshot snapshot) {
    final session = ref.watch(authSessionProvider);
    final sectionGap = context.eos.spacing.xl;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeWelcomeHero(
          displayName: session?.displayName ?? 'Guest',
          nearestEvent: nearestEventSummary,
        ),
        SizedBox(height: sectionGap),
        SectionHeader(
          title: 'Upcoming invitations',
          subtitle: 'Tickets and RSVPs for celebrations you are invited to.',
          trailingLabel: 'Find ticket',
          onTrailingTap: () => context.push(AttendeeRoutes.findTicket),
        ),
        if (snapshot.invitations.isEmpty)
          EmptyStateCard(
            title: 'No invitations yet',
            message: 'When you receive tickets or RSVPs, they will show up here.',
            icon: Icons.mail_outline,
            actionLabel: 'Discover events',
            onAction: () => context.go(AttendeeRoutes.dashboard),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: snapshot.invitations.length,
              separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.md),
              itemBuilder: (context, index) {
                final invite = snapshot.invitations[index];
                return HomeInvitationCard(
                  invitation: invite,
                  onTap: () => context.push(AttendeeRoutes.eventDetail(invite.eventId)),
                );
              },
            ),
          ),
        SizedBox(height: sectionGap),
        const SectionHeader(
          title: 'Quick links',
          subtitle: 'Everything you need as a guest.',
        ),
        Wrap(
          spacing: context.eos.spacing.sm,
          runSpacing: context.eos.spacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.go(AttendeeRoutes.dashboard),
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('Discover events'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push(AttendeeRoutes.findTicket),
              icon: const Icon(Icons.search_outlined, size: 18),
              label: const Text('Find my ticket'),
            ),
          ],
        ),
      ],
    );
  }
}
