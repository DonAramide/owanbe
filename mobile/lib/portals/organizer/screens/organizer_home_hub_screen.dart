import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import '../../../features/organizer/widgets/organizer_dashboard_kpi_strip.dart';
import '../../../features/organizer/providers/organizer_providers.dart';
import '../../customer/navigation/event_navigator.dart';
import '../../customer/providers/customer_home_providers.dart';
import '../../customer/workspace/widgets/event_friendly_errors.dart';
import '../../customer/workspace/widgets/event_loading_skeleton.dart';
import '../../customer/widgets/empty_state_card.dart';
import '../../customer/widgets/section_header.dart';
import '../../customer/widgets/home/home_active_event_card.dart';
import '../../customer/widgets/home/home_quick_actions_row.dart';
import '../../customer/widgets/home/home_upcoming_event_banner.dart';
import '../../customer/widgets/home/home_vendor_carousel.dart';
import '../../customer/widgets/home/home_welcome_hero.dart';

/// Organizer-only home hub — event planning, no attendee/ticket UI.
class OrganizerHomeHubScreen extends ConsumerStatefulWidget {
  const OrganizerHomeHubScreen({super.key});

  @override
  ConsumerState<OrganizerHomeHubScreen> createState() => _OrganizerHomeHubScreenState();
}

class _OrganizerHomeHubScreenState extends ConsumerState<OrganizerHomeHubScreen> {
  final _scrollController = ScrollController();

  Future<void> _onRefresh() async {
    refreshCustomerHome(ref);
    ref.invalidate(organizerDashboardStatsProvider);
    await ref.read(organizerHomeSnapshotProvider.future);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final homeAsync = ref.watch(organizerHomeSnapshotProvider);
    final horizontalPad = context.eos.spacing.lg;
    final sectionGap = context.eos.spacing.xl;

    return ColoredBox(
      color: context.eosCanvas,
      child: homeAsync.when(
        loading: () => const EventLoadingSkeleton(variant: EventLoadingVariant.workspace),
        error: (_, _) => ListView(
          padding: EosSpacing.pagePadding,
          children: [
            EmptyStateCard(
              title: EventFriendlyErrors.genericHeadline,
              message: EventFriendlyErrors.genericMessage,
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
                  displayName: session?.displayName ?? 'Organizer',
                  nearestEvent: snapshot.nearestEvent,
                ),
                SizedBox(height: sectionGap),
                EosSurfaceCard(
                  child: ListTile(
                    leading: const Icon(Icons.dashboard_outlined),
                    title: const Text('Organizer command center'),
                    subtitle: const Text('Full dashboard, events, tickets, vendors, analytics, and live ops.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/organizer'),
                  ),
                ),
                SizedBox(height: sectionGap),
                const SectionHeader(
                  title: 'Portfolio KPIs',
                  subtitle: 'Live metrics from your organizer dashboard API.',
                ),
                OrganizerDashboardKpiStrip(
                  onEventsTap: () => context.go('/organizer'),
                  onTicketsTap: () => context.go('/organizer'),
                  onVendorsTap: () => context.go('/organizer'),
                  onAttendeesTap: () => context.go('/organizer'),
                  onAnalyticsTap: () => context.go('/organizer'),
                ),
                SizedBox(height: sectionGap),
                if (snapshot.nearestEvent != null) ...[
                  HomeUpcomingEventBanner(
                    event: snapshot.nearestEvent!,
                    onTap: () => context.eventNav.openOverview(snapshot.nearestEvent!.id),
                  ),
                  SizedBox(height: sectionGap),
                ],
                SectionHeader(
                  title: 'My active events',
                  subtitle: 'Celebrations you are planning right now.',
                  trailingLabel: 'See all',
                  onTrailingTap: () => context.eventNav.goMyEvents(),
                ),
                if (snapshot.activeEvents.isEmpty)
                  EmptyStateCard(
                    title: 'Start your first celebration',
                    message: 'Weddings, birthdays, naming ceremonies — your event command center begins here.',
                    actionLabel: 'Create event',
                    onAction: () => context.eventNav.goCreateEvent(),
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
                          onTap: () => context.eventNav.openOverview(event.id),
                        );
                      },
                    ),
                  ),
                SizedBox(height: sectionGap),
                SectionHeader(
                  title: 'Portfolio intelligence',
                  subtitle: 'Enterprise view across all your events.',
                  trailingLabel: 'Open portfolio',
                  onTrailingTap: () => context.eventNav.openPortfolio(),
                ),
                EosSurfaceCard(
                  child: ListTile(
                    leading: const Icon(Icons.insights_outlined),
                    title: const Text('Organizer Portfolio Workspace'),
                    subtitle: const Text(
                      'Revenue, vendor rankings, AI copilot, templates, and executive dashboard.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.eventNav.openPortfolio(),
                  ),
                ),
                SizedBox(height: sectionGap),
                const SectionHeader(
                  title: 'Quick actions',
                  subtitle: 'Jump straight into planning.',
                ),
                HomeQuickActionsRow(
                  onCreateEvent: () => context.eventNav.goCreateEvent(),
                  onFindVendors: () => context.eventNav.openMarketplace(),
                  onInviteGuests: () => context.eventNav.goGuestsHub(),
                  onAiPlanner: () {
                    final nearest = snapshot.nearestEvent;
                    if (nearest != null) {
                      context.eventNav.openAiPlanner(nearest.id);
                      return;
                    }
                    if (snapshot.activeEvents.isNotEmpty) {
                      context.eventNav.openAiPlanner(snapshot.activeEvents.first.id);
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Create an event first to use the AI planner.')),
                    );
                  },
                ),
                SizedBox(height: sectionGap),
                SectionHeader(
                  title: 'Discover vendors',
                  subtitle: 'Caterers, DJs, photographers, and more.',
                  trailingLabel: 'Browse',
                  onTrailingTap: () => context.eventNav.openMarketplace(),
                ),
                HomeVendorCarousel(
                  vendors: snapshot.vendors,
                  onVendorTap: (vendor) => context.eventNav.openVendorDetail(vendor.id),
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
