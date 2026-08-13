import '../models/ai_planner_models.dart';
import '../models/command_center_models.dart';
import '../models/customer_event_models.dart';
import '../models/customer_guest_models.dart';
import '../models/vendor_crm_models.dart';

/// Operational lifecycle stages for Event OS planning workspace.
enum EventLifecycleStage {
  draft,
  planning,
  vendorsSecured,
  guestsInvited,
  ticketsLive,
  readyForEvent,
  liveEvent,
  completed,
  closing,
  archived,
}

extension EventLifecycleStageX on EventLifecycleStage {
  String get label => switch (this) {
        EventLifecycleStage.draft => 'Draft',
        EventLifecycleStage.planning => 'Planning',
        EventLifecycleStage.vendorsSecured => 'Vendors Secured',
        EventLifecycleStage.guestsInvited => 'Guests Invited',
        EventLifecycleStage.ticketsLive => 'Tickets Live',
        EventLifecycleStage.readyForEvent => 'Ready For Event',
        EventLifecycleStage.liveEvent => 'Live Event',
        EventLifecycleStage.completed => 'Completed',
        EventLifecycleStage.closing => 'Closing',
        EventLifecycleStage.archived => 'Archived',
      };
}

/// Deep-link targets — always routes to an existing Event OS module.
enum PlanningModuleLink {
  guests,
  invitations,
  budget,
  vendors,
  marketplace,
  tickets,
  program,
  seating,
  rentals,
  website,
  wall,
  aiPlanner,
  eventDay,
}

class EventChecklistEntry {
  const EventChecklistEntry({
    required this.label,
    required this.done,
    required this.priority,
    this.moduleLink,
    this.marketplaceCategory,
  });

  final String label;
  final bool done;
  final int priority;
  final PlanningModuleLink? moduleLink;

  /// When set, opens marketplace filtered to this service category (e.g. Catering, DJ).
  final String? marketplaceCategory;
}

class EventVendorStatusSummary {
  const EventVendorStatusSummary({
    required this.waitingForQuotes,
    required this.quoteReceived,
    required this.accepted,
    required this.contractSigned,
    required this.paid,
    required this.completed,
    required this.total,
  });

  final int waitingForQuotes;
  final int quoteReceived;
  final int accepted;
  final int contractSigned;
  final int paid;
  final int completed;
  final int total;
}

class EventGuestStatusSummary {
  const EventGuestStatusSummary({
    required this.invited,
    required this.accepted,
    required this.pending,
    required this.declined,
    required this.checkedIn,
  });

  final int invited;
  final int accepted;
  final int pending;
  final int declined;
  final int checkedIn;
}

class EventTicketStatusSummary {
  const EventTicketStatusSummary({
    required this.tierCount,
    required this.sales,
    required this.revenueMinor,
    required this.capacity,
    required this.publicTiers,
    required this.configured,
  });

  final int tierCount;
  final int sales;
  final int revenueMinor;
  final int capacity;
  final int publicTiers;
  final bool configured;
}

class EventFinanceStatusSummary {
  const EventFinanceStatusSummary({
    required this.estimatedBudgetMinor,
    required this.committedMinor,
    required this.paidMinor,
    required this.outstandingMinor,
    required this.revenueMinor,
    required this.profitProjectionMinor,
  });

  final int estimatedBudgetMinor;
  final int committedMinor;
  final int paidMinor;
  final int outstandingMinor;
  final int revenueMinor;
  final int profitProjectionMinor;
}

class EventReadinessDimension {
  const EventReadinessDimension({
    required this.label,
    required this.score,
    this.moduleLink,
  });

  final String label;
  final int score;
  final PlanningModuleLink? moduleLink;
}

class EventPlanningWorkspace {
  const EventPlanningWorkspace({
    required this.snapshot,
    required this.lifecycleStage,
    required this.readinessScore,
    required this.readinessDimensions,
    required this.checklist,
    required this.outstandingTasks,
    required this.timeline,
    required this.aiRecommendations,
    required this.nextActionLabel,
    required this.nextActionLink,
    required this.vendorStatus,
    required this.guestStatus,
    required this.ticketStatus,
    required this.financeStatus,
    required this.inProgressCount,
  });

  final EventCommandCenterSnapshot snapshot;
  final EventLifecycleStage lifecycleStage;
  final int readinessScore;
  final List<EventReadinessDimension> readinessDimensions;
  final List<EventChecklistEntry> checklist;
  final List<PlanningTaskItem> outstandingTasks;
  final List<PlannerTimelineItem> timeline;
  final List<PlannerMissingRequirement> aiRecommendations;
  final String? nextActionLabel;
  final PlanningModuleLink? nextActionLink;
  final EventVendorStatusSummary vendorStatus;
  final EventGuestStatusSummary guestStatus;
  final EventTicketStatusSummary ticketStatus;
  final EventFinanceStatusSummary financeStatus;
  final int inProgressCount;
}

EventLifecycleStage deriveEventLifecycleStage({
  required CustomerEvent event,
  required EventCommandCenterSnapshot snapshot,
  VendorCrmSnapshot? crm,
  required List<CustomerGuestView> guests,
}) {
  if (event.status == CustomerEventStatus.cancelled) return EventLifecycleStage.archived;
  if (event.status == CustomerEventStatus.completed) return EventLifecycleStage.completed;
  if (event.status == CustomerEventStatus.live) return EventLifecycleStage.liveEvent;

  final vendorsSecured = snapshot.vendorAccepted > 0 ||
      (crm?.stats.accepted ?? 0) > 0 ||
      event.vendors.any((v) => v.status == CustomerVendorSlotStatus.approved);
  final guestsInvited = guests.isNotEmpty || snapshot.guestInvited > 0;
  final ticketsConfigured = event.ticketTiers.isNotEmpty;
  final ticketsLive = ticketsConfigured &&
      (event.status == CustomerEventStatus.published ||
          event.ticketsSold > 0 ||
          !event.isPublicTicketed);
  final published = event.status == CustomerEventStatus.published;

  final checklistDone = snapshot.tasks.where((t) => t.done).length;
  final checklistTotal = snapshot.tasks.length;
  final planningComplete = checklistTotal > 0 && checklistDone >= checklistTotal - 1;

  if (vendorsSecured && guestsInvited && ticketsLive && published && planningComplete) {
    return EventLifecycleStage.readyForEvent;
  }
  if (ticketsLive && event.isPublicTicketed) return EventLifecycleStage.ticketsLive;
  if (guestsInvited) return EventLifecycleStage.guestsInvited;
  if (vendorsSecured) return EventLifecycleStage.vendorsSecured;
  if (event.title.trim().isNotEmpty || event.vendors.isNotEmpty || guests.isNotEmpty) {
    return EventLifecycleStage.planning;
  }
  return EventLifecycleStage.draft;
}

EventVendorStatusSummary buildVendorStatusSummary(VendorCrmSnapshot? crm, CustomerEvent event) {
  if (crm != null) {
    final s = crm.stats;
    return EventVendorStatusSummary(
      waitingForQuotes: s.newCount,
      quoteReceived: s.negotiating,
      accepted: s.accepted,
      contractSigned: s.scheduled,
      paid: s.arrived,
      completed: s.completed,
      total: s.total,
    );
  }
  final vendors = event.vendors;
  return EventVendorStatusSummary(
    waitingForQuotes: vendors
        .where((v) => v.status == CustomerVendorSlotStatus.invited || v.status == CustomerVendorSlotStatus.pending)
        .length,
    quoteReceived: 0,
    accepted: vendors.where((v) => v.status == CustomerVendorSlotStatus.approved).length,
    contractSigned: 0,
    paid: 0,
    completed: vendors.where((v) => v.status == CustomerVendorSlotStatus.approved && v.ordersCount > 0).length,
    total: vendors.length,
  );
}

EventGuestStatusSummary buildGuestStatusSummary(List<CustomerGuestView> guests) {
  return EventGuestStatusSummary(
    invited: guests.length,
    accepted: guests.where((g) => g.rsvpStatus == GuestRsvpStatus.confirmed).length,
    pending: guests.where((g) => g.rsvpStatus == GuestRsvpStatus.pending).length,
    declined: guests.where((g) => g.rsvpStatus == GuestRsvpStatus.declined).length,
    checkedIn: guests.where((g) => g.checkedIn).length,
  );
}

EventTicketStatusSummary buildTicketStatusSummary(CustomerEvent event) {
  final capacity = event.ticketTiers.fold<int>(0, (sum, t) => sum + t.capacity);
  final publicTiers =
      event.ticketTiers.where((t) => t.visibility == CustomerTicketVisibility.publicListing).length;
  return EventTicketStatusSummary(
    tierCount: event.ticketTiers.length,
    sales: event.ticketsSold,
    revenueMinor: event.revenueMinor,
    capacity: capacity,
    publicTiers: publicTiers > 0 ? publicTiers : event.ticketTiers.length,
    configured: event.ticketTiers.isNotEmpty,
  );
}

EventFinanceStatusSummary buildFinanceStatusSummary({
  required EventCommandCenterSnapshot snapshot,
  int paidMinor = 0,
}) {
  final revenue = snapshot.event.revenueMinor;
  final profit = revenue - snapshot.committedMinor;
  return EventFinanceStatusSummary(
    estimatedBudgetMinor: snapshot.budgetMinor,
    committedMinor: snapshot.committedMinor,
    paidMinor: paidMinor > 0 ? paidMinor : snapshot.committedMinor,
    outstandingMinor: snapshot.remainingMinor,
    revenueMinor: revenue,
    profitProjectionMinor: profit,
  );
}

/// Maps a Smart checklist label to a marketplace service category.
/// Returns null when the task is not a category-specific vendor booking.
String? marketplaceCategoryForChecklistLabel(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('cater')) return 'Catering';
  if (lower.contains('dj') || lower.contains('entertainment') || lower.contains('music')) {
    return 'DJ';
  }
  if (lower.contains('photo')) return 'Photographer';
  if (lower.contains('decor') || lower.contains('décor') || lower.contains('styling')) {
    return 'Decorator';
  }
  if (lower.contains('mc') || lower.contains('officiant')) return 'MC';
  if (lower.contains('security')) return 'Security';
  if (lower.contains('cake')) return 'Cake';
  if (lower.contains('drink') || lower.contains('bar')) return 'Drinks';
  if (lower.contains('florist') || lower.contains('floral')) return 'Florist';
  if (lower.contains('venue') && lower.contains('book')) return 'Venue';
  return null;
}

PlanningModuleLink? moduleLinkForChecklistLabel(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('guest')) return PlanningModuleLink.guests;
  if (lower.contains('budget')) return PlanningModuleLink.budget;
  if (lower.contains('invitation')) return PlanningModuleLink.invitations;
  if (lower.contains('ticket') || lower.contains('rsvp')) return PlanningModuleLink.tickets;
  if (lower.contains('publish') || lower.contains('page')) return PlanningModuleLink.website;
  // Category-specific booking tasks → filtered marketplace (not the full pipeline).
  if (marketplaceCategoryForChecklistLabel(label) != null) {
    return PlanningModuleLink.marketplace;
  }
  if (lower.contains('vendor') || lower.contains('book')) {
    return PlanningModuleLink.vendors;
  }
  if (lower.contains('venue') || lower.contains('timeline') || lower.contains('program')) {
    return PlanningModuleLink.program;
  }
  return null;
}

PlanningModuleLink? moduleLinkForPlanningTask(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('guest')) return PlanningModuleLink.guests;
  if (lower.contains('vendor')) return PlanningModuleLink.vendors;
  if (lower.contains('ticket')) return PlanningModuleLink.tickets;
  if (lower.contains('invitation')) return PlanningModuleLink.invitations;
  if (lower.contains('publish')) return PlanningModuleLink.website;
  if (lower.contains('detail')) return PlanningModuleLink.aiPlanner;
  return null;
}

PlanningModuleLink? moduleLinkForAiAction(String? actionRoute) => switch (actionRoute) {
      'guests' => PlanningModuleLink.guests,
      'vendors' => PlanningModuleLink.marketplace,
      'budget' => PlanningModuleLink.budget,
      _ => null,
    };

List<EventChecklistEntry> buildEventChecklist(AiPlannerPlan plan) {
  return [
    for (final item in plan.checklist)
      EventChecklistEntry(
        label: item.label,
        done: item.done,
        priority: item.priority,
        moduleLink: moduleLinkForChecklistLabel(item.label),
        marketplaceCategory: marketplaceCategoryForChecklistLabel(item.label),
      ),
  ]..sort((a, b) => a.priority.compareTo(b.priority));
}

List<EventReadinessDimension> computeReadinessDimensions({
  required CustomerEvent event,
  required EventCommandCenterSnapshot snapshot,
  required AiPlannerPlan plan,
  required EventVendorStatusSummary vendorStatus,
  required EventGuestStatusSummary guestStatus,
  required EventTicketStatusSummary ticketStatus,
  required EventFinanceStatusSummary financeStatus,
}) {
  final expectedGuests = event.totalCapacity > 0 ? event.totalCapacity : event.expectedGuests;
  final guestTarget = expectedGuests > 0 ? expectedGuests : 1;
  final guestScore = ((guestStatus.accepted / guestTarget).clamp(0.0, 1.0) * 100).round();

  final ticketScore = event.isPublicTicketed
      ? (ticketStatus.configured
          ? (ticketStatus.capacity > 0
              ? ((ticketStatus.sales / ticketStatus.capacity).clamp(0.0, 1.0) * 60 +
                      (ticketStatus.tierCount > 0 ? 40 : 0))
                  .round()
              : 50)
          : 0)
      : (ticketStatus.configured ? 100 : 80);

  final vendorDenom = vendorStatus.total > 0 ? vendorStatus.total : 1;
  final vendorScore =
      (((vendorStatus.accepted + vendorStatus.completed) / vendorDenom).clamp(0.0, 1.0) * 100).round();

  final venueScore = event.venue.trim().isNotEmpty && event.city.trim().isNotEmpty ? 100 : 20;

  final timelineTotal = plan.timeline.length;
  final timelineComplete = plan.timeline
      .where((t) => t.status == PlannerTimelineStatus.complete || t.status == PlannerTimelineStatus.dueSoon)
      .length;
  final timelineScore = timelineTotal > 0
      ? ((timelineComplete / timelineTotal) * 100).round()
      : (computePlanningProgress(event) * 100).round();

  final financeScore = financeStatus.estimatedBudgetMinor > 0
      ? (financeStatus.outstandingMinor <= financeStatus.estimatedBudgetMinor * 0.15 ? 100 : 65)
      : 40;

  final checklistDone = plan.checklist.where((c) => c.done).length;
  final checklistScore = plan.checklist.isEmpty
      ? (snapshot.progress * 100).round()
      : ((checklistDone / plan.checklist.length) * 100).round();

  final opsScore = event.status == CustomerEventStatus.live
      ? 100
      : event.status == CustomerEventStatus.published
          ? 85
          : 50;

  return [
    EventReadinessDimension(label: 'Guests', score: guestScore, moduleLink: PlanningModuleLink.guests),
    EventReadinessDimension(label: 'Tickets', score: ticketScore, moduleLink: PlanningModuleLink.tickets),
    EventReadinessDimension(label: 'Vendors', score: vendorScore, moduleLink: PlanningModuleLink.vendors),
    EventReadinessDimension(label: 'Venue', score: venueScore, moduleLink: PlanningModuleLink.program),
    EventReadinessDimension(label: 'Timeline', score: timelineScore, moduleLink: PlanningModuleLink.program),
    EventReadinessDimension(label: 'Finance', score: financeScore, moduleLink: PlanningModuleLink.budget),
    EventReadinessDimension(label: 'Checklist', score: checklistScore, moduleLink: PlanningModuleLink.aiPlanner),
    EventReadinessDimension(label: 'Operations', score: opsScore, moduleLink: PlanningModuleLink.eventDay),
  ];
}

int computeEventReadinessScore(List<EventReadinessDimension> dimensions) {
  if (dimensions.isEmpty) return 0;
  final total = dimensions.fold<int>(0, (sum, d) => sum + d.score);
  return (total / dimensions.length).round();
}

EventPlanningWorkspace buildEventPlanningWorkspace({
  required EventCommandCenterSnapshot snapshot,
  required AiPlannerPlan plan,
  VendorCrmSnapshot? crm,
  required List<CustomerGuestView> guests,
  int paidMinor = 0,
}) {
  final event = snapshot.event;
  final checklist = buildEventChecklist(plan);
  final vendorStatus = buildVendorStatusSummary(crm, event);
  final guestStatus = buildGuestStatusSummary(guests);
  final ticketStatus = buildTicketStatusSummary(event);
  final financeStatus = buildFinanceStatusSummary(snapshot: snapshot, paidMinor: paidMinor);
  final dimensions = computeReadinessDimensions(
    event: event,
    snapshot: snapshot,
    plan: plan,
    vendorStatus: vendorStatus,
    guestStatus: guestStatus,
    ticketStatus: ticketStatus,
    financeStatus: financeStatus,
  );
  final readinessScore = computeEventReadinessScore(dimensions);
  final lifecycleStage = deriveEventLifecycleStage(
    event: event,
    snapshot: snapshot,
    crm: crm,
    guests: guests,
  );

  final outstandingTasks = snapshot.tasks.where((t) => !t.done).toList();
  final upcomingTimeline = plan.timeline
      .where((t) => t.status != PlannerTimelineStatus.complete)
      .take(5)
      .toList();

  final aiRecommendations = plan.missingRequirements.take(4).toList();

  String? nextActionLabel;
  PlanningModuleLink? nextActionLink;

  final nextChecklist = checklist.where((c) => !c.done).toList();
  if (nextChecklist.isNotEmpty) {
    nextActionLabel = nextChecklist.first.label;
    nextActionLink = nextChecklist.first.moduleLink;
  } else if (aiRecommendations.isNotEmpty) {
    final rec = aiRecommendations.first;
    nextActionLabel = rec.title;
    nextActionLink = moduleLinkForAiAction(rec.actionRoute);
  } else if (outstandingTasks.isNotEmpty) {
    nextActionLabel = outstandingTasks.first.label;
    nextActionLink = moduleLinkForPlanningTask(outstandingTasks.first.label);
  }

  final inProgressCount = vendorStatus.quoteReceived +
      vendorStatus.waitingForQuotes +
      guestStatus.pending +
      outstandingTasks.length;

  return EventPlanningWorkspace(
    snapshot: snapshot,
    lifecycleStage: lifecycleStage,
    readinessScore: readinessScore,
    readinessDimensions: dimensions,
    checklist: checklist,
    outstandingTasks: outstandingTasks,
    timeline: upcomingTimeline,
    aiRecommendations: aiRecommendations,
    nextActionLabel: nextActionLabel,
    nextActionLink: nextActionLink,
    vendorStatus: vendorStatus,
    guestStatus: guestStatus,
    ticketStatus: ticketStatus,
    financeStatus: financeStatus,
    inProgressCount: inProgressCount,
  );
}
