import '../../../features/operations/models/operations_models.dart';
import '../models/ai_planner_models.dart';
import '../models/budget_dashboard_models.dart';
import '../models/command_center_models.dart';
import '../models/customer_event_models.dart';
import '../models/customer_finance_models.dart';
import '../models/customer_guest_models.dart';
import '../models/program_models.dart';
import '../models/vendor_crm_models.dart';
import '../planning/event_planning_models.dart';

/// Post-event closing lifecycle (Phase 5).
enum EventClosingPhase {
  active,
  archived,
}

/// Deep-link targets for closing workspace sections.
enum ClosingModuleLink {
  budget,
  guests,
  vendors,
  tickets,
  program,
  wall,
  aiPlanner,
}

class EventSummarySnapshot {
  const EventSummarySnapshot({
    required this.eventName,
    required this.venue,
    required this.city,
    required this.startsAt,
    required this.endsAt,
    required this.durationHours,
    required this.status,
    required this.guestsInvited,
    required this.guestsAttended,
    required this.ticketsSold,
    required this.revenueMinor,
    required this.expensesMinor,
    required this.profitMinor,
    required this.vendorsUsed,
    required this.timelineCompletionPct,
    required this.checkInRatePct,
  });

  final String eventName;
  final String venue;
  final String city;
  final DateTime startsAt;
  final DateTime endsAt;
  final double durationHours;
  final CustomerEventStatus status;
  final int guestsInvited;
  final int guestsAttended;
  final int ticketsSold;
  final int revenueMinor;
  final int expensesMinor;
  final int profitMinor;
  final int vendorsUsed;
  final int timelineCompletionPct;
  final int checkInRatePct;
}

class EventFinancialClosureSnapshot {
  const EventFinancialClosureSnapshot({
    required this.budgetMinor,
    required this.actualSpendMinor,
    required this.outstandingMinor,
    required this.vendorPaymentsMinor,
    required this.ticketRevenueMinor,
    required this.refundsMinor,
    required this.settlementEligible,
    required this.profitLossMinor,
  });

  final int budgetMinor;
  final int actualSpendMinor;
  final int outstandingMinor;
  final int vendorPaymentsMinor;
  final int ticketRevenueMinor;
  final int refundsMinor;
  final bool settlementEligible;
  final int profitLossMinor;
}

class EventVendorPerformanceRow {
  const EventVendorPerformanceRow({
    required this.vendorId,
    required this.service,
    required this.businessName,
    required this.arrivalLabel,
    required this.completionStatus,
    required this.paymentStatus,
    required this.repeatHire,
    required this.notes,
  });

  final String vendorId;
  final String service;
  final String businessName;
  final String arrivalLabel;
  final String completionStatus;
  final String paymentStatus;
  final bool repeatHire;
  final String notes;
}

class EventGuestIntelligenceSnapshot {
  const EventGuestIntelligenceSnapshot({
    required this.invited,
    required this.accepted,
    required this.declined,
    required this.checkedIn,
    required this.walkIns,
    required this.noShows,
    required this.vipAttendance,
    required this.averageArrivalLabel,
  });

  final int invited;
  final int accepted;
  final int declined;
  final int checkedIn;
  final int walkIns;
  final int noShows;
  final int vipAttendance;
  final String averageArrivalLabel;
}

class EventTicketAnalyticsSnapshot {
  const EventTicketAnalyticsSnapshot({
    required this.sales,
    required this.revenueMinor,
    required this.capacity,
    required this.attendance,
    required this.tierBreakdown,
    required this.qrScans,
    required this.refunds,
    required this.sellThroughPct,
  });

  final int sales;
  final int revenueMinor;
  final int capacity;
  final int attendance;
  final List<(String name, int sold, int capacity)> tierBreakdown;
  final int qrScans;
  final int refunds;
  final int sellThroughPct;
}

class EventAiDebrief {
  const EventAiDebrief({
    required this.wentWell,
    required this.delays,
    required this.vendorObservations,
    required this.guestObservations,
    required this.financialObservations,
    required this.recommendations,
    required this.missingOpportunities,
    required this.improvements,
  });

  final List<String> wentWell;
  final List<String> delays;
  final List<String> vendorObservations;
  final List<String> guestObservations;
  final List<String> financialObservations;
  final List<String> recommendations;
  final List<String> missingOpportunities;
  final List<String> improvements;
}

class EventMediaSummary {
  const EventMediaSummary({
    required this.photos,
    required this.videos,
    required this.documents,
    required this.highlights,
  });

  final List<String> photos;
  final List<String> videos;
  final List<String> documents;
  final List<String> highlights;
}

class HistoricalSuccessDimension {
  const HistoricalSuccessDimension({
    required this.label,
    required this.score,
    required this.summary,
  });

  final String label;
  final int score;
  final String summary;
}

class EventClosingWorkspace {
  const EventClosingWorkspace({
    required this.phase,
    required this.lifecycleStage,
    required this.summary,
    required this.financial,
    required this.guestIntel,
    required this.ticketAnalytics,
    required this.vendorPerformance,
    required this.debrief,
    required this.media,
    required this.historicalScore,
    required this.historicalDimensions,
    required this.openIncidents,
    required this.feedbackCount,
    required this.isReadOnly,
  });

  final EventClosingPhase phase;
  final EventLifecycleStage lifecycleStage;
  final EventSummarySnapshot summary;
  final EventFinancialClosureSnapshot financial;
  final EventGuestIntelligenceSnapshot guestIntel;
  final EventTicketAnalyticsSnapshot ticketAnalytics;
  final List<EventVendorPerformanceRow> vendorPerformance;
  final EventAiDebrief debrief;
  final EventMediaSummary media;
  final int historicalScore;
  final List<HistoricalSuccessDimension> historicalDimensions;
  final int openIncidents;
  final int feedbackCount;
  final bool isReadOnly;
}

EventSummarySnapshot buildEventSummarySnapshot({
  required CustomerEvent event,
  required EventCommandCenterSnapshot snapshot,
  required ProgramSnapshot program,
  required List<CustomerGuestView> guests,
  required List<OpsGuest> opsGuests,
}) {
  final duration = event.endsAt.difference(event.startsAt).inMinutes / 60.0;
  final invited = guests.isNotEmpty ? guests.length : snapshot.guestInvited;
  final attended = opsGuests.where((g) => g.checkedIn).length;
  final checkInRate = invited > 0 ? ((attended / invited) * 100).round() : 0;
  final expenses = snapshot.committedMinor;
  final profit = event.revenueMinor - expenses;
  final completedItems = program.items.where((i) => i.status == 'completed').length;
  final timelinePct = program.items.isEmpty
      ? 100
      : ((completedItems / program.items.length) * 100).round();

  return EventSummarySnapshot(
    eventName: event.title,
    venue: event.venueName.isNotEmpty ? event.venueName : event.venue,
    city: event.city,
    startsAt: event.startsAt,
    endsAt: event.endsAt,
    durationHours: duration,
    status: event.status,
    guestsInvited: invited,
    guestsAttended: attended > 0 ? attended : snapshot.guestCheckedIn,
    ticketsSold: event.ticketsSold,
    revenueMinor: event.revenueMinor,
    expensesMinor: expenses,
    profitMinor: profit,
    vendorsUsed: event.vendors.where((v) => v.status == CustomerVendorSlotStatus.approved).length,
    timelineCompletionPct: timelinePct,
    checkInRatePct: checkInRate,
  );
}

EventFinancialClosureSnapshot buildFinancialClosureSnapshot({
  required CustomerEvent event,
  required EventCommandCenterSnapshot snapshot,
  BudgetDashboardSnapshot? budget,
  CustomerEventFinanceSummary? finance,
}) {
  final budgetMinor = budget?.budgetMinor ?? snapshot.budgetMinor;
  final actual = budget?.committedMinor ?? snapshot.committedMinor;
  final outstanding = budget?.remainingMinor ?? snapshot.remainingMinor;
  final vendorPay = event.vendors.fold<int>(0, (s, v) => s + v.revenueMinor);
  final revenue = finance != null
      ? int.tryParse(finance.ticketRevenueMinor) ?? event.revenueMinor
      : event.revenueMinor;

  return EventFinancialClosureSnapshot(
    budgetMinor: budgetMinor,
    actualSpendMinor: actual,
    outstandingMinor: outstanding,
    vendorPaymentsMinor: vendorPay,
    ticketRevenueMinor: revenue,
    refundsMinor: event.refundRequests,
    settlementEligible: finance?.payoutEligible ?? false,
    profitLossMinor: revenue - actual,
  );
}

List<EventVendorPerformanceRow> buildVendorPerformanceRows({
  VendorCrmSnapshot? crm,
  required CustomerEvent event,
}) {
  if (crm != null && crm.items.isNotEmpty) {
    return [
      for (final r in crm.items)
        EventVendorPerformanceRow(
          vendorId: r.vendorId,
          service: r.serviceLabel ?? 'Vendor service',
          businessName: r.vendorName ?? r.vendorId,
          arrivalLabel: r.stage == 'arrived' || r.stage == 'completed' ? 'On time' : 'Scheduled',
          completionStatus: r.stage,
          paymentStatus: r.stage == 'completed' ? 'Paid' : 'Pending',
          repeatHire: r.stage == 'completed',
          notes: r.message,
        ),
    ];
  }

  return [
    for (final v in event.vendors)
      EventVendorPerformanceRow(
        vendorId: v.id,
        service: v.category,
        businessName: v.businessName,
        arrivalLabel: v.status == CustomerVendorSlotStatus.approved ? 'Confirmed' : v.status.name,
        completionStatus: v.ordersCount > 0 ? 'completed' : v.status.name,
        paymentStatus: v.revenueMinor > 0 ? 'Paid' : 'Pending',
        repeatHire: v.ordersCount > 0,
        notes: '',
      ),
  ];
}

EventGuestIntelligenceSnapshot buildGuestIntelligenceSnapshot({
  required List<CustomerGuestView> guests,
  required EventCommandCenterSnapshot snapshot,
}) {
  final invited = guests.isNotEmpty ? guests.length : snapshot.guestInvited;
  final accepted = guests.where((g) => g.rsvpStatus == GuestRsvpStatus.confirmed).length;
  final declined = guests.where((g) => g.rsvpStatus == GuestRsvpStatus.declined).length;
  final checkedIn = guests.where((g) => g.checkedIn).length;
  final noShows = (accepted - checkedIn).clamp(0, invited);
  final vip = guests.where((g) => g.tier == GuestTier.vip || g.tier == GuestTier.vvip).length;

  return EventGuestIntelligenceSnapshot(
    invited: invited,
    accepted: accepted,
    declined: declined,
    checkedIn: checkedIn > 0 ? checkedIn : snapshot.guestCheckedIn,
    walkIns: 0,
    noShows: noShows,
    vipAttendance: vip,
    averageArrivalLabel: checkedIn > 0 ? 'During reception window' : 'N/A',
  );
}

EventTicketAnalyticsSnapshot buildTicketAnalyticsSnapshot({
  required CustomerEvent event,
  required EventCommandCenterSnapshot snapshot,
}) {
  final capacity = event.ticketTiers.fold<int>(0, (s, t) => s + t.capacity);
  final tiers = event.ticketTiers
      .map((t) => (t.name, t.capacity - t.remaining, t.capacity))
      .toList();
  final sellThrough = capacity > 0 ? ((event.ticketsSold / capacity) * 100).round() : 0;

  return EventTicketAnalyticsSnapshot(
    sales: event.ticketsSold,
    revenueMinor: event.revenueMinor,
    capacity: capacity,
    attendance: snapshot.guestCheckedIn,
    tierBreakdown: tiers,
    qrScans: snapshot.guestCheckedIn,
    refunds: event.refundRequests,
    sellThroughPct: sellThrough,
  );
}

EventAiDebrief buildEventAiDebrief({
  required CustomerEvent event,
  required EventCommandCenterSnapshot snapshot,
  required AiPlannerPlan plan,
  required ProgramSnapshot program,
  required List<OpsIncident> incidents,
  required EventFinancialClosureSnapshot financial,
}) {
  final wentWell = <String>[];
  final delays = <String>[];
  final vendorObs = <String>[];
  final guestObs = <String>[];
  final financialObs = <String>[];
  final recs = <String>[];
  final missing = <String>[];
  final improvements = <String>[];

  if (snapshot.guestCheckedIn > 0) {
    wentWell.add('${snapshot.guestCheckedIn} guests checked in successfully.');
  }
  if (snapshot.vendorCompleted > 0) {
    wentWell.add('${snapshot.vendorCompleted} vendors completed their services.');
  }
  if (event.revenueMinor > 0) {
    wentWell.add('Generated ${event.revenueMinor ~/ 100} NGN in ticket revenue.');
  }
  if (plan.readinessScore >= 70) {
    wentWell.add('Planning readiness was ${plan.readinessScore}% before the event.');
  }

  for (final item in program.items.where((i) => i.status == 'delayed')) {
    delays.add('Timeline delay: ${item.title}.');
  }
  for (final inc in incidents.where((i) => i.status != IncidentStatus.resolved)) {
    delays.add('Open incident: ${inc.title}.');
  }

  if (snapshot.vendorAccepted > 0) {
    vendorObs.add('${snapshot.vendorAccepted} vendors confirmed and engaged.');
  }
  if (snapshot.guestCheckedIn > 0) {
    guestObs.add('Check-in flow handled ${snapshot.guestCheckedIn} arrivals.');
  }

  if (financial.profitLossMinor >= 0) {
    financialObs.add('Event closed with a positive margin.');
  } else {
    financialObs.add('Spend exceeded ticket revenue — review vendor allocations.');
  }

  for (final req in plan.missingRequirements.take(3)) {
    missing.add('${req.title}: ${req.description}');
  }

  recs.add('Duplicate this event to carry vendors, budget, and ticket structure forward.');
  for (final item in plan.checklist.where((c) => !c.done).take(3)) {
    improvements.add('Next time: complete "${item.label}" earlier in planning.');
  }

  if (wentWell.isEmpty) wentWell.add('Event completed — review modules for detailed metrics.');

  return EventAiDebrief(
    wentWell: wentWell,
    delays: delays,
    vendorObservations: vendorObs,
    guestObservations: guestObs,
    financialObservations: financialObs,
    recommendations: recs,
    missingOpportunities: missing,
    improvements: improvements,
  );
}

EventMediaSummary buildEventMediaSummary(CustomerEvent event) {
  final photos = <String>[];
  if (event.celebrantImageUrl != null &&
      event.celebrantImageUrl!.isNotEmpty &&
      !event.celebrantImageUrl!.startsWith('data:')) {
    photos.add(event.celebrantImageUrl!);
  }

  return EventMediaSummary(
    photos: photos,
    videos: event.mediaLabels.where((l) => l.toLowerCase().contains('video')).toList(),
    documents: event.mediaLabels
        .where((l) => l.toLowerCase().contains('contract') || l.toLowerCase().contains('invoice'))
        .toList(),
    highlights: [if (event.bannerLabel.isNotEmpty) event.bannerLabel, ...event.tags.take(3)],
  );
}

List<HistoricalSuccessDimension> buildHistoricalSuccessDimensions({
  required EventCommandCenterSnapshot snapshot,
  required AiPlannerPlan plan,
  required ProgramSnapshot program,
  required EventFinancialClosureSnapshot financial,
  required EventGuestIntelligenceSnapshot guestIntel,
  required int openIncidents,
}) {
  final planningScore = (snapshot.progress * 100).round().clamp(0, 100);
  final completedProgram = program.items.where((i) => i.status == 'completed').length;
  final executionScore = program.items.isEmpty
      ? 75
      : ((completedProgram / program.items.length) * 100).round();
  final guestScore = guestIntel.invited > 0
      ? ((guestIntel.checkedIn / guestIntel.invited) * 100).round()
      : 50;
  final vendorScore = snapshot.vendorRequested > 0
      ? ((snapshot.vendorCompleted / snapshot.vendorRequested) * 100).round().clamp(0, 100)
      : 70;
  final financialScore = financial.profitLossMinor >= 0 ? 85 : 45;
  final opsScore = openIncidents == 0 ? 90 : (openIncidents == 1 ? 65 : 40);

  return [
    HistoricalSuccessDimension(
      label: 'Planning quality',
      score: planningScore,
      summary: '${plan.checklist.where((c) => c.done).length}/${plan.checklist.length} checklist',
    ),
    HistoricalSuccessDimension(
      label: 'Execution quality',
      score: executionScore,
      summary: '$completedProgram/${program.items.length} activities',
    ),
    HistoricalSuccessDimension(
      label: 'Guest satisfaction',
      score: guestScore,
      summary: '${guestIntel.checkedIn} attended',
    ),
    HistoricalSuccessDimension(
      label: 'Vendor reliability',
      score: vendorScore,
      summary: '${snapshot.vendorCompleted} completed',
    ),
    HistoricalSuccessDimension(
      label: 'Financial performance',
      score: financialScore,
      summary: financial.profitLossMinor >= 0 ? 'Profitable' : 'Over budget',
    ),
    HistoricalSuccessDimension(
      label: 'Operational efficiency',
      score: opsScore,
      summary: openIncidents == 0 ? 'Clean close' : '$openIncidents open',
    ),
  ];
}

int computeHistoricalSuccessScore(List<HistoricalSuccessDimension> dimensions) {
  if (dimensions.isEmpty) return 0;
  return (dimensions.fold<int>(0, (s, d) => s + d.score) / dimensions.length).round();
}

EventClosingWorkspace buildEventClosingWorkspace({
  required CustomerEvent event,
  required EventCommandCenterSnapshot snapshot,
  required AiPlannerPlan plan,
  required ProgramSnapshot program,
  required List<CustomerGuestView> guests,
  required List<OpsGuest> opsGuests,
  VendorCrmSnapshot? crm,
  BudgetDashboardSnapshot? budget,
  CustomerEventFinanceSummary? finance,
  List<OpsIncident> incidents = const [],
  EventClosingPhase phase = EventClosingPhase.active,
}) {
  final summary = buildEventSummarySnapshot(
    event: event,
    snapshot: snapshot,
    program: program,
    guests: guests,
    opsGuests: opsGuests,
  );
  final financial = buildFinancialClosureSnapshot(
    event: event,
    snapshot: snapshot,
    budget: budget,
    finance: finance,
  );
  final guestIntel = buildGuestIntelligenceSnapshot(guests: guests, snapshot: snapshot);
  final ticketAnalytics = buildTicketAnalyticsSnapshot(event: event, snapshot: snapshot);
  final vendorPerformance = buildVendorPerformanceRows(crm: crm, event: event);
  final debrief = buildEventAiDebrief(
    event: event,
    snapshot: snapshot,
    plan: plan,
    program: program,
    incidents: incidents,
    financial: financial,
  );
  final media = buildEventMediaSummary(event);
  final openIncidents = incidents.where((i) => i.status != IncidentStatus.resolved).length;
  final dimensions = buildHistoricalSuccessDimensions(
    snapshot: snapshot,
    plan: plan,
    program: program,
    financial: financial,
    guestIntel: guestIntel,
    openIncidents: openIncidents,
  );

  return EventClosingWorkspace(
    phase: phase,
    lifecycleStage:
        phase == EventClosingPhase.archived ? EventLifecycleStage.archived : EventLifecycleStage.closing,
    summary: summary,
    financial: financial,
    guestIntel: guestIntel,
    ticketAnalytics: ticketAnalytics,
    vendorPerformance: vendorPerformance,
    debrief: debrief,
    media: media,
    historicalScore: computeHistoricalSuccessScore(dimensions),
    historicalDimensions: dimensions,
    openIncidents: openIncidents,
    feedbackCount: snapshot.feed.length,
    isReadOnly: phase == EventClosingPhase.archived,
  );
}
