import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../providers/customer_event_command_providers.dart';
import '../router/customer_routes.dart';
import '../widgets/celebration_hero.dart';
import '../widgets/command_center/celebration_suite_row.dart';
import '../widgets/command_center/command_activity_feed.dart';
import '../widgets/command_center/command_quick_actions.dart';
import '../widgets/command_center/command_summary_grid.dart';
import '../widgets/command_center/planning_progress_ring.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/section_header.dart';
import '../models/home_hub_models.dart';

/// CUS-040 Event Command Center — flagship celebration hub at `/events/:eventId`.
class CustomerEventCommandCenterScreen extends ConsumerWidget {
  const CustomerEventCommandCenterScreen({super.key, required this.eventId});

  final String eventId;

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(customerEventCommandProvider(eventId));

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
              context.go(CustomerRoutes.myEvents);
            }
          },
        ),
        title: const Text('Event command center'),
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            EmptyStateCard(
              title: 'Could not load event',
              message: error.toString(),
              actionLabel: 'Back to my events',
              onAction: () => context.go(CustomerRoutes.myEvents),
            ),
          ],
        ),
        data: (data) {
          final event = data.event;
          final countdown = formatCountdown(event.startsAt, DateTime.now());
          final dateLine = '${formatEventDate(event.startsAt)} · ${event.venue}, ${event.city}';

          return RefreshIndicator(
            onRefresh: () async {
              refreshEventCommandCenter(ref);
              await ref.read(customerEventCommandProvider(eventId).future);
            },
            child: ListView(
              padding: EdgeInsets.all(context.eos.spacing.lg),
              children: [
                CelebrationHero(
                  title: event.title,
                  subtitle: dateLine,
                  countdownLabel: countdown,
                ),
                SizedBox(height: context.eos.spacing.lg),
                const SectionHeader(
                  title: 'Planning progress',
                  subtitle: 'Track setup before the big day.',
                ),
                PlanningProgressRing(
                  progress: data.progress,
                  tasksCompleted: data.tasksCompleted,
                  tasksRemaining: data.tasksRemaining,
                  tasks: data.tasks,
                ),
                SizedBox(height: context.eos.spacing.sm),
                OutlinedButton.icon(
                  onPressed: () => context.push(CustomerRoutes.eventAiPlanner(eventId)),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Open AI Event Planner'),
                ),
                SizedBox(height: context.eos.spacing.lg),
                const SectionHeader(
                  title: 'At a glance',
                  subtitle: 'Guests, vendors, and budget in one view.',
                ),
                CommandSummaryGrid(
                  eventAccessMode: event.eventAccessMode,
                  guestInvited: data.guestInvited,
                  guestRsvp: data.guestRsvp,
                  guestCheckedIn: data.guestCheckedIn,
                  ticketsSold: event.ticketsSold,
                  revenueMinor: event.revenueMinor,
                  totalCapacity: event.totalCapacity > 0 ? event.totalCapacity : event.expectedGuests,
                  vendorRequested: data.vendorRequested,
                  vendorAccepted: data.vendorAccepted,
                  vendorCompleted: data.vendorCompleted,
                  budgetMinor: data.budgetMinor,
                  committedMinor: data.committedMinor,
                  remainingMinor: data.remainingMinor,
                  onGuestsTap: () => context.push(CustomerRoutes.eventGuests(eventId)),
                  onTicketsTap: () => context.push('/organizer/events/$eventId?tab=2'),
                  onVendorsTap: () => context.push(CustomerRoutes.vendors),
                  onBudgetTap: () => context.push(CustomerRoutes.eventBudget(eventId)),
                ),
                SizedBox(height: context.eos.spacing.lg),
                const SectionHeader(
                  title: 'Celebration suite',
                  subtitle: 'Website, Aso-Ebi, wall, and registry.',
                ),
                CelebrationSuiteRow(
                  onWebsite: () => _comingSoon(context, 'Website builder'),
                  onAsoEbi: () => _comingSoon(context, 'Aso-Ebi'),
                  onWall: () => _comingSoon(context, 'Celebration wall'),
                  onRegistry: () => _comingSoon(context, 'Gift registry'),
                ),
                SizedBox(height: context.eos.spacing.lg),
                const SectionHeader(
                  title: 'Activity',
                  subtitle: 'Latest updates from your celebration.',
                ),
                CommandActivityFeed(items: data.feed),
                SizedBox(height: context.eos.spacing.lg),
                const SectionHeader(
                  title: 'Quick actions',
                  subtitle: 'Move fast on what matters next.',
                ),
                CommandQuickActions(
                  onInviteGuests: () => context.push(CustomerRoutes.eventInvitations(eventId)),
                  onFindVendors: () => context.push(CustomerRoutes.vendors),
                  onEventDay: () => context.push(CustomerRoutes.eventDay(eventId)),
                ),
                SizedBox(height: context.eos.spacing.xl),
              ],
            ),
          );
        },
      ),
    );
  }
}
