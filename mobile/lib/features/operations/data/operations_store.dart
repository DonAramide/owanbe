import '../../organizer/data/organizer_event_store.dart';
import '../../organizer/models/organizer_models.dart';
import '../models/operations_models.dart';

class OperationsStore {
  OperationsStore._();
  static final OperationsStore instance = OperationsStore._();

  final Map<String, _EventOpsState> _states = {};

  _EventOpsState _state(String eventId) {
    return _states.putIfAbsent(eventId, () => _EventOpsState.bootstrap(eventId));
  }

  bool hasState(String eventId) => _states.containsKey(eventId);

  void ensureLive(String eventId) => _state(eventId);

  List<OpsGuest> guests(String eventId) => List.unmodifiable(_state(eventId).guests);

  List<OpsFeedEvent> feed(String eventId) => List.unmodifiable(_state(eventId).feed);

  List<OpsIncident> incidents(String eventId) => List.unmodifiable(_state(eventId).incidents);

  List<VendorOpsSnapshot> vendors(String eventId) => List.unmodifiable(_state(eventId).vendors);

  LiveEventKpis kpis(String eventId) => _state(eventId).kpis();

  EventHealthSnapshot health(String eventId) => _state(eventId).health();

  OpsGuest? guestByTicket(String eventId, String ticketId) {
    final normalized = ticketId.trim().toLowerCase();
    try {
      return _state(eventId).guests.firstWhere((g) => g.ticketId.toLowerCase() == normalized);
    } catch (_) {
      return null;
    }
  }

  QrScanResponse scanTicket(String eventId, String ticketId) {
    final guest = guestByTicket(eventId, ticketId);
    if (guest == null) {
      return const QrScanResponse(result: QrScanResult.invalid, message: 'Ticket not recognized');
    }
    if (guest.ticketExpired) {
      return QrScanResponse(result: QrScanResult.expired, message: 'Ticket expired', guest: guest);
    }
    if (!guest.qrValid) {
      return QrScanResponse(result: QrScanResult.invalid, message: 'Invalid QR signature', guest: guest);
    }
    if (guest.checkedIn) {
      return QrScanResponse(result: QrScanResult.alreadyUsed, message: 'Already checked in', guest: guest);
    }
    if (guest.tier == GuestTier.vvip) {
      checkInGuest(eventId, guest.id, manual: false);
      return QrScanResponse(result: QrScanResult.vvip, message: 'VVIP — fast lane cleared', guest: guest);
    }
    if (guest.tier == GuestTier.vip) {
      checkInGuest(eventId, guest.id, manual: false);
      return QrScanResponse(result: QrScanResult.vip, message: 'VIP — lounge access granted', guest: guest);
    }
    checkInGuest(eventId, guest.id, manual: false);
    return QrScanResponse(result: QrScanResult.valid, message: 'Check-in successful', guest: guest);
  }

  OpsGuest checkInGuest(String eventId, String guestId, {bool manual = true}) {
    final state = _state(eventId);
    final idx = state.guests.indexWhere((g) => g.id == guestId);
    if (idx < 0) throw StateError('guest not found');
    final guest = state.guests[idx];
    if (guest.checkedIn) return guest;
    final now = DateTime.now();
    final updated = guest.copyWith(checkedIn: true, checkedInAt: now);
    state.guests[idx] = updated;
    state._syncOrganizerAttendee(eventId, updated);
    state._prependFeed(
      OpsFeedEvent(
        id: 'feed_${now.millisecondsSinceEpoch}',
        type: FeedEventType.guestCheckedIn,
        headline: '${updated.name} checked in',
        detail: '${updated.tierName} · ${manual ? 'Manual' : 'QR scan'}',
        timestamp: now,
      ),
    );
    state.ordersToday += updated.tier == GuestTier.general ? 0 : 1;
    return updated;
  }

  OpsIncident logIncident({
    required String eventId,
    required String title,
    required IncidentCategory category,
    required IncidentPriority priority,
    required String reporter,
    String description = '',
  }) {
    final state = _state(eventId);
    final now = DateTime.now();
    final incident = OpsIncident(
      id: 'inc_${now.millisecondsSinceEpoch}',
      title: title,
      category: category,
      priority: priority,
      status: IncidentStatus.open,
      reporter: reporter,
      reportedAt: now,
      description: description,
      timeline: [OpsIncidentEvent(label: 'Reported', at: now)],
    );
    state.incidents.insert(0, incident);
    state._prependFeed(
      OpsFeedEvent(
        id: 'feed_${now.millisecondsSinceEpoch}',
        type: FeedEventType.incidentLogged,
        headline: title,
        detail: '${_categoryLabel(category)} · ${_priorityLabel(priority)} priority',
        timestamp: now,
      ),
    );
    return incident;
  }

  OpsIncident updateIncidentStatus(String eventId, String incidentId, IncidentStatus status) {
    final state = _state(eventId);
    final idx = state.incidents.indexWhere((i) => i.id == incidentId);
    if (idx < 0) throw StateError('incident not found');
    final current = state.incidents[idx];
    final now = DateTime.now();
    final timeline = [
      ...current.timeline,
      OpsIncidentEvent(label: _statusLabel(status), at: now),
    ];
    state.incidents[idx] = current.copyWith(status: status, timeline: timeline);
    return state.incidents[idx];
  }

  static String _categoryLabel(IncidentCategory c) => switch (c) {
        IncidentCategory.security => 'Security',
        IncidentCategory.medical => 'Medical',
        IncidentCategory.access => 'Access',
        IncidentCategory.technical => 'Technical',
        IncidentCategory.vendor => 'Vendor',
      };

  static String _priorityLabel(IncidentPriority p) => p.name;

  static String _statusLabel(IncidentStatus s) => switch (s) {
        IncidentStatus.open => 'Opened',
        IncidentStatus.investigating => 'Investigating',
        IncidentStatus.resolved => 'Resolved',
      };
}

class _EventOpsState {
  _EventOpsState({
    required this.guests,
    required this.feed,
    required this.incidents,
    required this.vendors,
    required this.ordersToday,
    required this.revenueTodayMinor,
  });

  List<OpsGuest> guests;
  List<OpsFeedEvent> feed;
  List<OpsIncident> incidents;
  List<VendorOpsSnapshot> vendors;
  int ordersToday;
  int revenueTodayMinor;

  static _EventOpsState bootstrap(String eventId) {
    final org = OrganizerEventStore.instance.byId(eventId);
    final guests = _seedGuests(org);
    final vendors = _seedVendors(org);
    final feed = _seedFeed(guests);
    final incidents = _seedIncidents();
    return _EventOpsState(
      guests: guests,
      feed: feed,
      incidents: incidents,
      vendors: vendors,
      ordersToday: 47,
      revenueTodayMinor: 285000000,
    );
  }

  LiveEventKpis kpis() {
    final checkedIn = guests.where((g) => g.checkedIn).length;
    return LiveEventKpis(
      checkedIn: checkedIn,
      remainingGuests: guests.length - checkedIn,
      vendorsActive: vendors.where((v) => v.status == VendorOpsStatus.active).length,
      ordersToday: ordersToday,
      revenueTodayMinor: revenueTodayMinor,
      openIncidents: incidents.where((i) => i.status != IncidentStatus.resolved).length,
      totalRegistered: guests.length,
    );
  }

  EventHealthSnapshot health() {
    final k = kpis();
    final checkInRate = k.totalRegistered == 0 ? 0.0 : k.checkedIn / k.totalRegistered;
    final attendanceRate = checkInRate * 0.92;
    final vendorActivityRate =
        vendors.isEmpty ? 0.0 : vendors.where((v) => v.status == VendorOpsStatus.active).length / vendors.length;
    final incidentRate = incidents.isEmpty
        ? 0.0
        : incidents.where((i) => i.status != IncidentStatus.resolved).length / incidents.length;
    final level = _healthLevel(checkInRate, vendorActivityRate, incidentRate);
    return EventHealthSnapshot(
      level: level,
      attendanceRate: attendanceRate,
      checkInRate: checkInRate,
      vendorActivityRate: vendorActivityRate,
      incidentRate: incidentRate,
      revenueVelocityMinor: revenueTodayMinor ~/ 8,
      summary: _healthSummary(level),
    );
  }

  static EventHealthLevel _healthLevel(double checkIn, double vendor, double incident) {
    if (incident > 0.5 || checkIn < 0.25) return EventHealthLevel.critical;
    if (incident > 0.25 || checkIn < 0.45 || vendor < 0.5) return EventHealthLevel.warning;
    return EventHealthLevel.healthy;
  }

  static String _healthSummary(EventHealthLevel level) => switch (level) {
        EventHealthLevel.healthy => 'Event operating within normal parameters',
        EventHealthLevel.warning => 'Monitor check-in flow and open incidents',
        EventHealthLevel.critical => 'Immediate attention required on the floor',
      };

  void _prependFeed(OpsFeedEvent event) {
    feed.insert(0, event);
    if (feed.length > 50) feed.removeLast();
  }

  void _syncOrganizerAttendee(String eventId, OpsGuest guest) {
    try {
      OrganizerEventStore.instance.update(eventId, (e) {
        final attendees = e.attendees.map((a) {
          if (a.ticketId != guest.ticketId) return a;
          return a.copyWith(checkedIn: true);
        }).toList();
        return e.copyWith(attendees: attendees);
      });
    } catch (_) {}
  }

  static List<OpsGuest> _seedGuests(OrganizerEvent? org) {
    final fromOrg = org?.attendees.map(_guestFromOrganizer).toList() ?? [];
    final extras = <OpsGuest>[
      const OpsGuest(
        id: 'att_vvip_1',
        name: 'Chief Adaeze N.',
        email: 'adaeze@example.com',
        ticketId: 'tkt_vvip_1',
        tierName: 'VVIP Royal Box',
        tier: GuestTier.vvip,
        checkedIn: true,
        qrValid: true,
      ),
      const OpsGuest(
        id: 'att_vvip_2',
        name: 'Mr. Kunle Adeyemi',
        email: 'kunle@example.com',
        ticketId: 'tkt_vvip_2',
        tierName: 'VVIP Royal Box',
        tier: GuestTier.vvip,
        qrValid: true,
      ),
      ...List.generate(
        12,
        (i) => OpsGuest(
          id: 'att_gen_$i',
          name: 'Guest ${i + 10}',
          email: 'guest${i + 10}@example.com',
          ticketId: 'tkt_gen_$i',
          tierName: 'General Admission',
          tier: GuestTier.general,
          checkedIn: i < 4,
          checkedInAt: i < 4 ? DateTime.now().subtract(Duration(minutes: i * 8)) : null,
        ),
      ),
      ...List.generate(
        6,
        (i) => OpsGuest(
          id: 'att_vip_$i',
          name: 'VIP Guest ${i + 1}',
          email: 'vip$i@example.com',
          ticketId: 'tkt_vip_$i',
          tierName: 'VIP Lounge',
          tier: GuestTier.vip,
          checkedIn: i < 2,
          checkedInAt: i < 2 ? DateTime.now().subtract(Duration(minutes: 15 + i * 5)) : null,
        ),
      ),
    ];
    for (final g in fromOrg) {
      if (!extras.any((e) => e.ticketId == g.ticketId)) extras.add(g);
    }
    for (var i = 0; i < extras.length; i++) {
      final g = extras[i];
      if (g.checkedIn && g.checkedInAt == null) {
        extras[i] = g.copyWith(checkedInAt: DateTime.now().subtract(Duration(minutes: 30 - i)));
      }
    }
    return extras;
  }

  static OpsGuest _guestFromOrganizer(OrganizerAttendee a) {
    final tier = a.tierName.toLowerCase().contains('vvip')
        ? GuestTier.vvip
        : a.tierName.toLowerCase().contains('vip')
            ? GuestTier.vip
            : GuestTier.general;
    return OpsGuest(
      id: a.id,
      name: a.name,
      email: a.email,
      ticketId: a.ticketId,
      tierName: a.tierName,
      tier: tier,
      checkedIn: a.checkedIn,
      checkedInAt: a.checkedIn ? DateTime.now().subtract(const Duration(minutes: 20)) : null,
    );
  }

  static List<VendorOpsSnapshot> _seedVendors(OrganizerEvent? org) {
    final now = DateTime.now();
    if (org == null || org.vendors.isEmpty) {
      return [
        VendorOpsSnapshot(
          vendorId: 'v1',
          businessName: 'Jollof & Co',
          category: 'Catering',
          status: VendorOpsStatus.active,
          ordersToday: 18,
          revenueTodayMinor: 124000000,
          lastActivity: now.subtract(const Duration(minutes: 2)),
        ),
      ];
    }
    return org.vendors.asMap().entries.map((e) {
      final v = e.value;
      final status = switch (e.key % 3) {
        0 => VendorOpsStatus.active,
        1 => VendorOpsStatus.idle,
        _ => VendorOpsStatus.offline,
      };
      return VendorOpsSnapshot(
        vendorId: v.id,
        businessName: v.businessName,
        category: v.category,
        status: status,
        ordersToday: status == VendorOpsStatus.active ? 12 + e.key * 3 : 0,
        revenueTodayMinor: status == VendorOpsStatus.active ? 85000000 + e.key * 20000000 : 0,
        lastActivity: now.subtract(Duration(minutes: e.key * 7 + 1)),
      );
    }).toList();
  }

  static List<OpsFeedEvent> _seedFeed(List<OpsGuest> guests) {
    final now = DateTime.now();
    final checkedIn = guests.where((g) => g.checkedIn).take(3).toList();
    return [
      OpsFeedEvent(
        id: 'feed_seed_1',
        type: FeedEventType.vendorJoined,
        headline: 'Jollof & Co went active',
        detail: 'Zone B · Premium catering online',
        timestamp: now.subtract(const Duration(minutes: 3)),
      ),
      OpsFeedEvent(
        id: 'feed_seed_2',
        type: FeedEventType.orderPlaced,
        headline: 'Order placed · Party Jollof Package',
        detail: 'Jollof & Co · ₦450,000',
        timestamp: now.subtract(const Duration(minutes: 8)),
      ),
      for (var i = 0; i < checkedIn.length; i++)
        OpsFeedEvent(
          id: 'feed_seed_ci_$i',
          type: FeedEventType.guestCheckedIn,
          headline: '${checkedIn[i].name} checked in',
          detail: checkedIn[i].tierName,
          timestamp: now.subtract(Duration(minutes: 15 + i * 4)),
        ),
      OpsFeedEvent(
        id: 'feed_seed_3',
        type: FeedEventType.refundRequested,
        headline: 'Refund requested',
        detail: 'Guest inquiry · General Admission',
        timestamp: now.subtract(const Duration(minutes: 22)),
      ),
    ];
  }

  static List<OpsIncident> _seedIncidents() {
    final now = DateTime.now();
    return [
      OpsIncident(
        id: 'inc_seed_1',
        title: 'Queue surge at Gate A',
        category: IncidentCategory.access,
        priority: IncidentPriority.medium,
        status: IncidentStatus.investigating,
        reporter: 'Security Lead',
        reportedAt: now.subtract(const Duration(minutes: 18)),
        description: 'Wait time exceeding 12 minutes',
        timeline: [
          OpsIncidentEvent(label: 'Reported', at: now.subtract(const Duration(minutes: 18))),
          OpsIncidentEvent(label: 'Investigating', at: now.subtract(const Duration(minutes: 10))),
        ],
      ),
      OpsIncident(
        id: 'inc_seed_2',
        title: 'AV mic feedback Zone C',
        category: IncidentCategory.technical,
        priority: IncidentPriority.low,
        status: IncidentStatus.open,
        reporter: 'Stage Manager',
        reportedAt: now.subtract(const Duration(minutes: 35)),
        timeline: [OpsIncidentEvent(label: 'Reported', at: now.subtract(const Duration(minutes: 35)))],
      ),
    ];
  }
}
