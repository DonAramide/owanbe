import '../../../features/operations/models/operations_models.dart';
import '../../../features/organizer/finance/organizer_finance_api.dart';
import '../../../features/organizer/models/organizer_models.dart';
import 'home_hub_models.dart';

class EventCommandCenterSnapshot {
  const EventCommandCenterSnapshot({
    required this.event,
    required this.progress,
    required this.tasksCompleted,
    required this.tasksRemaining,
    required this.tasks,
    required this.guestInvited,
    required this.guestRsvp,
    required this.guestCheckedIn,
    required this.vendorRequested,
    required this.vendorAccepted,
    required this.vendorCompleted,
    required this.budgetMinor,
    required this.committedMinor,
    required this.remainingMinor,
    required this.feed,
  });

  final OrganizerEvent event;
  final double progress;
  final int tasksCompleted;
  final int tasksRemaining;
  final List<PlanningTaskItem> tasks;
  final int guestInvited;
  final int guestRsvp;
  final int guestCheckedIn;
  final int vendorRequested;
  final int vendorAccepted;
  final int vendorCompleted;
  final int budgetMinor;
  final int committedMinor;
  final int remainingMinor;
  final List<OpsFeedEvent> feed;
}

class PlanningTaskItem {
  const PlanningTaskItem({required this.label, required this.done});

  final String label;
  final bool done;
}

List<PlanningTaskItem> buildPlanningTasks(OrganizerEvent event) {
  final tasks = <PlanningTaskItem>[
    PlanningTaskItem(
      label: 'Set event details',
      done: event.title.trim().isNotEmpty && event.venue.trim().isNotEmpty,
    ),
  ];
  if (event.isPrivateCelebration) {
    tasks.add(PlanningTaskItem(
      label: 'Add guests',
      done: event.attendees.isNotEmpty || event.expectedGuests > 0,
    ));
  }
  tasks.add(PlanningTaskItem(
    label: 'Book vendors',
    done: event.vendors.any((v) => v.status == VendorSlotStatus.approved),
  ));
  if (event.isPublicTicketed) {
    tasks.add(PlanningTaskItem(
      label: 'Configure tickets',
      done: event.ticketTiers.isNotEmpty,
    ));
  } else {
    tasks.add(PlanningTaskItem(
      label: 'Send invitations',
      done: event.attendees.isNotEmpty,
    ));
  }
  tasks.add(PlanningTaskItem(
    label: 'Publish celebration',
    done: event.status == OrganizerEventStatus.published ||
        event.status == OrganizerEventStatus.live ||
        event.status == OrganizerEventStatus.completed,
  ));
  return tasks;
}

GuestCommandStats guestStats(OrganizerEvent event, List<OpsGuest> opsGuests) {
  final invited = opsGuests.isNotEmpty ? opsGuests.length : event.attendees.length;
  final rsvp = event.attendees.where((a) => a.ticketId.isNotEmpty || a.purchasedAt != null).length;
  final checkedIn = opsGuests.isNotEmpty
      ? opsGuests.where((g) => g.checkedIn).length
      : event.attendees.where((a) => a.checkedIn).length;
  return GuestCommandStats(invited: invited, rsvp: rsvp > 0 ? rsvp : invited, checkedIn: checkedIn);
}

class GuestCommandStats {
  const GuestCommandStats({
    required this.invited,
    required this.rsvp,
    required this.checkedIn,
  });

  final int invited;
  final int rsvp;
  final int checkedIn;
}

VendorCommandStats vendorStats(OrganizerEvent event) {
  final vendors = event.vendors;
  return VendorCommandStats(
    requested: vendors
        .where((v) => v.status == VendorSlotStatus.invited || v.status == VendorSlotStatus.pending)
        .length,
    accepted: vendors.where((v) => v.status == VendorSlotStatus.approved).length,
    completed: vendors.where((v) => v.status == VendorSlotStatus.approved && v.ordersCount > 0).length,
  );
}

class VendorCommandStats {
  const VendorCommandStats({
    required this.requested,
    required this.accepted,
    required this.completed,
  });

  final int requested;
  final int accepted;
  final int completed;
}

BudgetCommandStats budgetStats(OrganizerEvent event, OrganizerEventFinanceSummary? finance) {
  final estimatedBudget = event.budgetMinor > 0
      ? event.budgetMinor
      : event.ticketTiers.fold<int>(
          0,
          (sum, t) => sum + (t.capacity * t.priceMinor),
        );
  final committed = finance != null
      ? int.tryParse(finance.grossCollectedMinor) ?? event.revenueMinor
      : event.revenueMinor;
  final budget = estimatedBudget > 0 ? estimatedBudget : (committed > 0 ? committed : 0);
  final remaining = (budget - committed).clamp(0, budget);
  return BudgetCommandStats(budgetMinor: budget, committedMinor: committed, remainingMinor: remaining);
}

class BudgetCommandStats {
  const BudgetCommandStats({
    required this.budgetMinor,
    required this.committedMinor,
    required this.remainingMinor,
  });

  final int budgetMinor;
  final int committedMinor;
  final int remainingMinor;
}

EventCommandCenterSnapshot buildCommandCenterSnapshot({
  required OrganizerEvent event,
  required List<OpsGuest> opsGuests,
  required List<OpsFeedEvent> feed,
  OrganizerEventFinanceSummary? finance,
}) {
  final tasks = buildPlanningTasks(event);
  final done = tasks.where((t) => t.done).length;
  final guests = guestStats(event, opsGuests);
  final vendors = vendorStats(event);
  final budget = budgetStats(event, finance);

  return EventCommandCenterSnapshot(
    event: event,
    progress: computePlanningProgress(event),
    tasksCompleted: done,
    tasksRemaining: tasks.length - done,
    tasks: tasks,
    guestInvited: guests.invited,
    guestRsvp: guests.rsvp,
    guestCheckedIn: guests.checkedIn,
    vendorRequested: vendors.requested,
    vendorAccepted: vendors.accepted,
    vendorCompleted: vendors.completed,
    budgetMinor: budget.budgetMinor,
    committedMinor: budget.committedMinor,
    remainingMinor: budget.remainingMinor,
    feed: feed,
  );
}

String formatTimeAgo(DateTime timestamp) {
  final diff = DateTime.now().difference(timestamp);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatEventDate(timestamp);
}
