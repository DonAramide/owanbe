import '../../../features/operations/models/operations_models.dart';
import '../models/command_center_models.dart';
import '../models/customer_event_models.dart';
import '../models/customer_guest_models.dart';
import '../models/program_models.dart';
import '../models/vendor_crm_models.dart';
import '../planning/event_planning_models.dart';

/// Event Desktop primary surface — adapts by lifecycle (Phase 4).
enum EventDesktopMode {
  planning,
  execution,
  closing,
  archived,
}

extension EventDesktopModeX on EventDesktopMode {
  String get label => switch (this) {
        EventDesktopMode.planning => 'Planning Workspace',
        EventDesktopMode.execution => 'Operations Center',
        EventDesktopMode.closing => 'Closing & Intelligence',
        EventDesktopMode.archived => 'Event Archive',
      };
}

/// Command actions — each maps to an existing module or ops screen.
enum OperationsCommandAction {
  openCheckIn,
  broadcastAnnouncement,
  contactVendor,
  contactStaff,
  emergencyMode,
  logIncident,
}

extension OperationsCommandActionX on OperationsCommandAction {
  String get label => switch (this) {
        OperationsCommandAction.openCheckIn => 'Open Check-In',
        OperationsCommandAction.broadcastAnnouncement => 'Broadcast',
        OperationsCommandAction.contactVendor => 'Contact Vendor',
        OperationsCommandAction.contactStaff => 'Contact Staff',
        OperationsCommandAction.emergencyMode => 'Emergency',
        OperationsCommandAction.logIncident => 'Log Incident',
      };
}

class LiveGuestOpsSummary {
  const LiveGuestOpsSummary({
    required this.checkedIn,
    required this.pending,
    required this.vipArrived,
    required this.plusOnes,
    required this.walkIns,
    required this.capacity,
    required this.total,
  });

  final int checkedIn;
  final int pending;
  final int vipArrived;
  final int plusOnes;
  final int walkIns;
  final int capacity;
  final int total;
}

class LiveVendorOpsSummary {
  const LiveVendorOpsSummary({
    required this.expected,
    required this.arrived,
    required this.settingUp,
    required this.working,
    required this.completed,
    required this.paid,
    required this.total,
  });

  final int expected;
  final int arrived;
  final int settingUp;
  final int working;
  final int completed;
  final int paid;
  final int total;
}

class OperationalHealthDimension {
  const OperationalHealthDimension({
    required this.label,
    required this.score,
    required this.statusLabel,
  });

  final String label;
  final int score;
  final String statusLabel;
}

class LiveTimelineSection {
  const LiveTimelineSection({
    required this.current,
    required this.next,
    required this.delayed,
    required this.completed,
    required this.day,
  });

  final ProgramItem? current;
  final ProgramItem? next;
  final List<ProgramItem> delayed;
  final List<ProgramItem> completed;
  final ProgramDaySnapshot day;
}

class EventOperationsWorkspace {
  const EventOperationsWorkspace({
    required this.mode,
    required this.lifecycleStage,
    required this.operationalHealthScore,
    required this.healthLevel,
    required this.healthSummary,
    required this.healthDimensions,
    required this.guestOps,
    required this.vendorOps,
    required this.timeline,
    required this.commandFeed,
    required this.openIncidents,
    required this.kpis,
  });

  final EventDesktopMode mode;
  final EventLifecycleStage lifecycleStage;
  final int operationalHealthScore;
  final EventHealthLevel healthLevel;
  final String healthSummary;
  final List<OperationalHealthDimension> healthDimensions;
  final LiveGuestOpsSummary guestOps;
  final LiveVendorOpsSummary vendorOps;
  final LiveTimelineSection timeline;
  final List<OpsFeedEvent> commandFeed;
  final int openIncidents;
  final LiveEventKpis? kpis;
}

EventDesktopMode resolveEventDesktopMode({
  required CustomerEvent event,
  required EventLifecycleStage lifecycleStage,
  bool isArchived = false,
}) {
  if (isArchived) {
    return EventDesktopMode.archived;
  }
  if (event.status == CustomerEventStatus.completed) {
    return EventDesktopMode.closing;
  }
  if (event.status == CustomerEventStatus.cancelled) {
    return EventDesktopMode.closing;
  }
  if (event.status == CustomerEventStatus.live || lifecycleStage == EventLifecycleStage.liveEvent) {
    return EventDesktopMode.execution;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final eventDay = DateTime(event.startsAt.year, event.startsAt.month, event.startsAt.day);
  final daysUntil = eventDay.difference(today).inDays;

  if (daysUntil <= 0 && event.status != CustomerEventStatus.draft) {
    return EventDesktopMode.execution;
  }
  if (lifecycleStage == EventLifecycleStage.readyForEvent && daysUntil <= 1) {
    return EventDesktopMode.execution;
  }

  return EventDesktopMode.planning;
}

LiveGuestOpsSummary buildLiveGuestOpsSummary({
  required List<CustomerGuestView> guests,
  required List<OpsGuest> opsGuests,
  required CustomerEvent event,
}) {
  final capacity = event.totalCapacity > 0 ? event.totalCapacity : event.expectedGuests;
  final checkedIn = opsGuests.isNotEmpty
      ? opsGuests.where((g) => g.checkedIn).length
      : guests.where((g) => g.checkedIn).length;
  final pending = guests.where((g) => g.rsvpStatus == GuestRsvpStatus.pending && !g.checkedIn).length;
  final vipArrived = opsGuests.isNotEmpty
      ? opsGuests.where((g) => g.checkedIn && (g.tier == GuestTier.vip || g.tier == GuestTier.vvip)).length
      : guests.where((g) => g.checkedIn && (g.tier == GuestTier.vip || g.tier == GuestTier.vvip)).length;
  final total = opsGuests.isNotEmpty ? opsGuests.length : guests.length;

  return LiveGuestOpsSummary(
    checkedIn: checkedIn,
    pending: pending,
    vipArrived: vipArrived,
    plusOnes: guests.where((g) => g.ticketId.isNotEmpty && g.name.contains('+')).length,
    walkIns: 0,
    capacity: capacity,
    total: total,
  );
}

LiveVendorOpsSummary buildLiveVendorOpsSummary({
  VendorCrmSnapshot? crm,
  required CustomerEvent event,
  List<VendorOpsSnapshot> vendorOps = const [],
}) {
  if (crm != null) {
    final s = crm.stats;
    return LiveVendorOpsSummary(
      expected: s.accepted + s.scheduled,
      arrived: s.arrived,
      settingUp: s.arrived,
      working: s.arrived > 0 ? s.arrived : s.scheduled,
      completed: s.completed,
      paid: s.completed,
      total: s.total,
    );
  }

  final active = vendorOps.where((v) => v.status == VendorOpsStatus.active).length;
  final approved = event.vendors.where((v) => v.status == CustomerVendorSlotStatus.approved).length;

  return LiveVendorOpsSummary(
    expected: approved,
    arrived: active,
    settingUp: active,
    working: active,
    completed: event.vendors.where((v) => v.ordersCount > 0).length,
    paid: event.vendors.where((v) => v.revenueMinor > 0).length,
    total: event.vendors.length,
  );
}

LiveTimelineSection buildLiveTimelineSection(ProgramSnapshot program) {
  final items = program.items;
  return LiveTimelineSection(
    current: program.day.current,
    next: program.day.next,
    delayed: items.where((i) => i.status == 'delayed').toList(),
    completed: items.where((i) => i.status == 'completed' || i.status == 'skipped').toList(),
    day: program.day,
  );
}

List<OperationalHealthDimension> buildOperationalHealthDimensions({
  required EventHealthSnapshot? health,
  required LiveGuestOpsSummary guestOps,
  required LiveVendorOpsSummary vendorOps,
  required LiveTimelineSection timeline,
  required int openIncidents,
  required CustomerEvent event,
}) {
  final guestScore = guestOps.capacity > 0
      ? ((guestOps.checkedIn / guestOps.capacity).clamp(0.0, 1.0) * 100).round()
      : guestOps.total > 0
          ? ((guestOps.checkedIn / guestOps.total).clamp(0.0, 1.0) * 100).round()
          : 0;

  final vendorDenom = vendorOps.total > 0 ? vendorOps.total : 1;
  final vendorScore =
      (((vendorOps.arrived + vendorOps.completed) / vendorDenom).clamp(0.0, 1.0) * 100).round();

  final timelineTotal = timeline.completed.length +
      timeline.delayed.length +
      (timeline.current != null ? 1 : 0) +
      (timeline.next != null ? 1 : 0);
  final timelineDone = timeline.completed.length;
  final timelineScore = timelineTotal > 0 ? ((timelineDone / timelineTotal) * 100).round() : 50;

  final incidentScore = openIncidents == 0 ? 100 : (openIncidents == 1 ? 60 : 30);
  final venueScore = event.venue.trim().isNotEmpty ? 100 : 40;
  final networkScore = 100;
  final staffScore = timeline.current?.ownerType == 'coordinator' ? 90 : 75;

  return [
    OperationalHealthDimension(
      label: 'Guest flow',
      score: guestScore,
      statusLabel: '${guestOps.checkedIn} checked in',
    ),
    OperationalHealthDimension(
      label: 'Vendor readiness',
      score: vendorScore,
      statusLabel: '${vendorOps.arrived} on site',
    ),
    OperationalHealthDimension(
      label: 'Timeline',
      score: timelineScore,
      statusLabel: timeline.current?.title ?? 'Awaiting start',
    ),
    OperationalHealthDimension(
      label: 'Incidents',
      score: incidentScore,
      statusLabel: openIncidents == 0 ? 'Clear' : '$openIncidents open',
    ),
    OperationalHealthDimension(
      label: 'Venue',
      score: venueScore,
      statusLabel: event.venue.isNotEmpty ? event.venue : 'Not set',
    ),
    OperationalHealthDimension(
      label: 'Network',
      score: networkScore,
      statusLabel: 'Connected',
    ),
    OperationalHealthDimension(
      label: 'Staff',
      score: staffScore,
      statusLabel: timeline.current?.ownerName ?? 'Standby',
    ),
  ];
}

int computeOperationalHealthScore(List<OperationalHealthDimension> dimensions) {
  if (dimensions.isEmpty) return 0;
  return (dimensions.fold<int>(0, (s, d) => s + d.score) / dimensions.length).round();
}

List<OpsFeedEvent> mergeCommandFeed({
  required List<OpsFeedEvent> opsFeed,
  required List<OpsFeedEvent> commandFeed,
}) {
  final merged = [...opsFeed, ...commandFeed];
  merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  final seen = <String>{};
  return [
    for (final item in merged)
      if (seen.add(item.id)) item,
  ].take(12).toList();
}

EventOperationsWorkspace buildEventOperationsWorkspace({
  required CustomerEvent event,
  required EventLifecycleStage lifecycleStage,
  required EventCommandCenterSnapshot snapshot,
  required List<CustomerGuestView> guests,
  required List<OpsGuest> opsGuests,
  required ProgramSnapshot program,
  VendorCrmSnapshot? crm,
  List<VendorOpsSnapshot> vendorOps = const [],
  EventHealthSnapshot? health,
  LiveEventKpis? kpis,
  List<OpsFeedEvent> opsFeed = const [],
  List<OpsIncident> incidents = const [],
}) {
  final mode = resolveEventDesktopMode(event: event, lifecycleStage: lifecycleStage);
  final guestOps = buildLiveGuestOpsSummary(guests: guests, opsGuests: opsGuests, event: event);
  final vendorOpsSummary = buildLiveVendorOpsSummary(crm: crm, event: event, vendorOps: vendorOps);
  final timeline = buildLiveTimelineSection(program);
  final openIncidents = incidents.where((i) => i.status != IncidentStatus.resolved).length;

  final dimensions = buildOperationalHealthDimensions(
    health: health,
    guestOps: guestOps,
    vendorOps: vendorOpsSummary,
    timeline: timeline,
    openIncidents: openIncidents,
    event: event,
  );

  final operationalScore = health != null
      ? ((health.checkInRate * 40 + (1 - health.incidentRate.clamp(0, 1)) * 30 + health.attendanceRate * 30))
          .round()
          .clamp(0, 100)
      : computeOperationalHealthScore(dimensions);

  return EventOperationsWorkspace(
    mode: mode,
    lifecycleStage: lifecycleStage,
    operationalHealthScore: operationalScore,
    healthLevel: health?.level ?? EventHealthLevel.healthy,
    healthSummary: health?.summary ?? 'Operations monitoring active',
    healthDimensions: dimensions,
    guestOps: guestOps,
    vendorOps: vendorOpsSummary,
    timeline: timeline,
    commandFeed: mergeCommandFeed(opsFeed: opsFeed, commandFeed: snapshot.feed),
    openIncidents: openIncidents,
    kpis: kpis,
  );
}
