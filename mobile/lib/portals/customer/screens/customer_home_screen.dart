import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import '../providers/customer_home_providers.dart';
import '../router/customer_routes.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/section_header.dart';
import '../widgets/home/home_active_event_card.dart';
import '../widgets/home/home_invitation_card.dart';
import '../widgets/home/home_quick_actions_row.dart';
import '../widgets/home/home_upcoming_event_banner.dart';
import '../widgets/home/home_vendor_carousel.dart';
import '../widgets/home/home_welcome_hero.dart';

/// CUS-020 — Customer Home Hub.
class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  final _scrollController = ScrollController();

  Future<void> _onRefresh() async {
    refreshCustomerHome(ref);
    await ref.read(customerHomeSnapshotProvider.future);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final homeAsync = ref.watch(customerHomeSnapshotProvider);
    final horizontalPad = context.eos.spacing.lg;
    final sectionGap = context.eos.spacing.xl;

    return ColoredBox(
      color: context.eosCanvas,
      child: homeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: EdgeInsets.all(horizontalPad),
          children: [
            EmptyStateCard(
              title: 'Could not load your home',
              message: '$error',
              icon: Icons.cloud_off_outlined,
              actionLabel: 'Try again',
              onAction: _onRefresh,
            ),
          ],
        ),
        data: (snapshot) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                horizontalPad,
                horizontalPad,
                horizontalPad + 24,
              ),
              children: [
                HomeWelcomeHero(
                  displayName: session?.displayName ?? 'Guest',
                  nearestEvent: snapshot.nearestEvent,
                ),
                SizedBox(height: sectionGap),
                if (snapshot.nearestEvent != null) ...[
                  HomeUpcomingEventBanner(
                    event: snapshot.nearestEvent!,
                    onTap: () => context.push(CustomerRoutes.eventDetail(snapshot.nearestEvent!.id)),
                  ),
                  SizedBox(height: sectionGap),
                ],
                SectionHeader(
                  title: 'My active events',
                  subtitle: 'Celebrations you are planning right now.',
                  trailingLabel: 'See all',
                  onTrailingTap: () => context.go(CustomerRoutes.myEvents),
                ),
                if (snapshot.activeEvents.isEmpty)
                  EmptyStateCard(
                    title: 'Start your first celebration',
                    message: 'Weddings, birthdays, naming ceremonies — your event command center begins here.',
                    actionLabel: 'Create event',
                    onAction: () => context.go(CustomerRoutes.createEvent),
                  )
                else
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: snapshot.activeEvents.length,
                      separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.md),
                      itemBuilder: (context, index) {
                        final event = snapshot.activeEvents[index];
                        return HomeActiveEventCard(
                          event: event,
                          onTap: () => context.push(CustomerRoutes.eventDetail(event.id)),
                        );
                      },
                    ),
                  ),
                SizedBox(height: sectionGap),
                const SectionHeader(
                  title: 'Quick actions',
                  subtitle: 'Jump straight into planning.',
                ),
                HomeQuickActionsRow(
                  onCreateEvent: () => context.go(CustomerRoutes.createEvent),
                  onFindVendors: () => context.push(CustomerRoutes.vendors),
                  onInviteGuests: () => context.go(CustomerRoutes.guests),
                  onAiPlanner: () {
                    final nearest = snapshot.nearestEvent;
                    if (nearest != null) {
                      context.push(CustomerRoutes.eventAiPlanner(nearest.id));
                      return;
                    }
                    if (snapshot.activeEvents.isNotEmpty) {
                      context.push(CustomerRoutes.eventAiPlanner(snapshot.activeEvents.first.id));
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Create an event first to use the AI planner.')),
                    );
                  },
                ),
                SizedBox(height: sectionGap),
                SectionHeader(
                  title: 'Upcoming invitations',
                  subtitle: 'Events you are attending or invited to.',
                  trailingLabel: 'My tickets',
                  onTrailingTap: () => context.push('/attendee'),
                ),
                if (snapshot.invitations.isEmpty)
                  EmptyStateCard(
                    title: 'No invitations yet',
                    message: 'When you receive tickets or RSVPs, they will show up here.',
                    icon: Icons.mail_outline,
                    actionLabel: 'Discover events',
                    onAction: () => context.push('/events'),
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
                          onTap: () => context.push('/events/${invite.eventId}'),
                        );
                      },
                    ),
                  ),
                SizedBox(height: sectionGap),
                SectionHeader(
                  title: 'Discover vendors',
                  subtitle: 'Caterers, DJs, photographers, and more.',
                  trailingLabel: 'Browse',
                  onTrailingTap: () => context.push(CustomerRoutes.vendors),
                ),
                HomeVendorCarousel(
                  vendors: snapshot.vendors,
                  onVendorTap: (vendor) => context.push(CustomerRoutes.vendorDetail(vendor.id)),
                ),
                SizedBox(height: sectionGap),
              ],
            ),
          );
        },
      ),
    );
  }
}
