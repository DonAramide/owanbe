import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../providers/customer_invitation_providers.dart';
import '../router/customer_routes.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/invitations/invitation_preview_card.dart';
import '../widgets/invitations/invitation_qr_card.dart';
import '../widgets/invitations/invitation_share_actions.dart';
import '../widgets/invitations/invitation_stats_row.dart';
import '../widgets/section_header.dart';

/// Invitation Hub at `/events/:eventId/invitations`.
class CustomerEventInvitationsScreen extends ConsumerWidget {
  const CustomerEventInvitationsScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(customerEventInvitationProvider(eventId));

    return Scaffold(
      backgroundColor: EosColors.canvas,
      appBar: AppBar(
        backgroundColor: EosColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(CustomerRoutes.eventDetail(eventId));
            }
          },
        ),
        title: const Text('Invitation hub'),
        actions: [
          IconButton(
            tooltip: 'Manage guests',
            onPressed: () => context.push(CustomerRoutes.eventGuests(eventId)),
            icon: const Icon(Icons.groups_outlined),
          ),
        ],
      ),
      body: hub.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            EmptyStateCard(
              title: 'Could not load invitations',
              message: error.toString(),
              actionLabel: 'Back to event',
              onAction: () => context.go(CustomerRoutes.eventDetail(eventId)),
            ),
          ],
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            refreshInvitationHub(ref);
            await ref.read(customerEventInvitationProvider(eventId).future);
          },
          child: ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              SectionHeader(
                title: data.event.title,
                subtitle: 'Invitation dashboard · ${data.guestCount} guests on your list',
              ),
              SizedBox(height: context.eos.spacing.md),
              const SectionHeader(
                title: 'Statistics',
                subtitle: 'Sent, delivered, opened, and RSVP funnel.',
              ),
              InvitationStatsRow(stats: data.stats),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(
                title: 'Invitation preview',
                subtitle: 'How your celebration invite appears to guests.',
              ),
              InvitationPreviewCard(event: data.event),
              SizedBox(height: context.eos.spacing.lg),
              const SectionHeader(
                title: 'Share & QR',
                subtitle: 'Spread the word across channels.',
              ),
              InvitationShareActions(share: data.share),
              SizedBox(height: context.eos.spacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 640;
                  final qrCards = [
                    InvitationQrCard(
                      title: 'QR invitation',
                      subtitle: 'Guests scan to view your celebration invite.',
                      payload: data.share.inviteQrPayload,
                    ),
                    InvitationQrCard(
                      title: 'QR RSVP',
                      subtitle: 'Direct RSVP and ticket selection.',
                      payload: data.share.rsvpQrPayload,
                    ),
                  ];
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: qrCards[0]),
                        SizedBox(width: context.eos.spacing.md),
                        Expanded(child: qrCards[1]),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      qrCards[0],
                      SizedBox(height: context.eos.spacing.md),
                      qrCards[1],
                    ],
                  );
                },
              ),
              SizedBox(height: context.eos.spacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
