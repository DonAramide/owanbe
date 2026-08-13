enum EventHealthLevel { healthy, warning, critical }

enum IncidentCategory { security, medical, access, technical, vendor }

enum IncidentPriority { low, medium, high, critical }

enum IncidentStatus { open, investigating, resolved }

enum FeedEventType {
  guestCheckedIn,
  invitationArrival,
  checkInDuplicate,
  checkInInvalid,
  vendorJoined,
  orderPlaced,
  refundRequested,
  incidentLogged,
  incidentUpdated,
  wallPost,
  wallPinned,
}

enum QrScanResult { valid, alreadyUsed, expired, invalid, cancelled, offline, vip, vvip }

enum CheckInFilter { all, checkedIn, notCheckedIn, vip, vvip }

enum VendorOpsStatus { active, idle, offline }

enum GuestTier { general, vip, vvip }

/// Door lifecycle derived from entitlements + event_check_ins.
enum DoorAttendeeStatus { registered, checkedIn, inside, completed }

class OpsGuest {
  const OpsGuest({
    required this.id,
    required this.name,
    required this.email,
    required this.ticketId,
    required this.tierName,
    required this.tier,
    this.checkedIn = false,
    this.checkedInAt,
    this.qrValid = true,
    this.ticketExpired = false,
    this.doorStatus = DoorAttendeeStatus.registered,
    this.source,
  });

  final String id;
  final String name;
  final String email;
  final String ticketId;
  final String tierName;
  final GuestTier tier;
  final bool checkedIn;
  final DateTime? checkedInAt;
  final bool qrValid;
  final bool ticketExpired;
  final DoorAttendeeStatus doorStatus;
  final String? source;

  String get doorStatusLabel => switch (doorStatus) {
        DoorAttendeeStatus.registered => 'Registered',
        DoorAttendeeStatus.checkedIn => 'Checked In',
        DoorAttendeeStatus.inside => 'Inside Event',
        DoorAttendeeStatus.completed => 'Completed',
      };

  OpsGuest copyWith({
    bool? checkedIn,
    DateTime? checkedInAt,
    bool? qrValid,
    bool? ticketExpired,
    DoorAttendeeStatus? doorStatus,
    String? source,
  }) =>
      OpsGuest(
        id: id,
        name: name,
        email: email,
        ticketId: ticketId,
        tierName: tierName,
        tier: tier,
        checkedIn: checkedIn ?? this.checkedIn,
        checkedInAt: checkedInAt ?? this.checkedInAt,
        qrValid: qrValid ?? this.qrValid,
        ticketExpired: ticketExpired ?? this.ticketExpired,
        doorStatus: doorStatus ?? this.doorStatus,
        source: source ?? this.source,
      );
}

class OpsIncident {
  const OpsIncident({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    required this.status,
    required this.reporter,
    required this.reportedAt,
    required this.timeline,
    this.description = '',
  });

  final String id;
  final String title;
  final IncidentCategory category;
  final IncidentPriority priority;
  final IncidentStatus status;
  final String reporter;
  final DateTime reportedAt;
  final List<OpsIncidentEvent> timeline;
  final String description;

  OpsIncident copyWith({
    IncidentStatus? status,
    List<OpsIncidentEvent>? timeline,
  }) =>
      OpsIncident(
        id: id,
        title: title,
        category: category,
        priority: priority,
        status: status ?? this.status,
        reporter: reporter,
        reportedAt: reportedAt,
        timeline: timeline ?? this.timeline,
        description: description,
      );
}

class OpsIncidentEvent {
  const OpsIncidentEvent({required this.label, required this.at});

  final String label;
  final DateTime at;
}

class OpsFeedEvent {
  const OpsFeedEvent({
    required this.id,
    required this.type,
    required this.headline,
    required this.detail,
    required this.timestamp,
  });

  final String id;
  final FeedEventType type;
  final String headline;
  final String detail;
  final DateTime timestamp;
}

class VendorOpsSnapshot {
  const VendorOpsSnapshot({
    required this.vendorId,
    required this.businessName,
    required this.category,
    required this.status,
    required this.ordersToday,
    required this.revenueTodayMinor,
    required this.lastActivity,
  });

  final String vendorId;
  final String businessName;
  final String category;
  final VendorOpsStatus status;
  final int ordersToday;
  final int revenueTodayMinor;
  final DateTime lastActivity;
}

class DoorArrival {
  const DoorArrival({
    required this.ticketCode,
    required this.name,
    required this.tierName,
    required this.source,
    required this.checkedInAt,
  });

  final String ticketCode;
  final String name;
  final String tierName;
  final String source;
  final DateTime checkedInAt;
}

class LiveEventKpis {
  const LiveEventKpis({
    required this.checkedIn,
    required this.remainingGuests,
    required this.capacity,
    required this.noShows,
    required this.attendancePct,
    required this.capacityPct,
    required this.vendorsActive,
    required this.ordersToday,
    required this.revenueTodayMinor,
    required this.openIncidents,
    required this.totalRegistered,
    this.checkInsLast15m = 0,
    this.checkInsLast60m = 0,
    this.queueState = 'quiet',
    this.eventStatus = 'published',
    this.recentArrivals = const [],
  });

  final int checkedIn;
  final int remainingGuests;
  final int capacity;
  final int noShows;
  final double attendancePct;
  final double capacityPct;
  final int vendorsActive;
  final int ordersToday;
  final int revenueTodayMinor;
  final int openIncidents;
  final int totalRegistered;
  final int checkInsLast15m;
  final int checkInsLast60m;
  final String queueState;
  final String eventStatus;
  final List<DoorArrival> recentArrivals;
}

class EventHealthSnapshot {
  const EventHealthSnapshot({
    required this.level,
    required this.attendanceRate,
    required this.checkInRate,
    required this.capacityRate,
    required this.vendorActivityRate,
    required this.incidentRate,
    required this.revenueVelocityMinor,
    required this.summary,
    this.queueState = 'quiet',
    this.checkInThroughputPerHour = 0,
  });

  final EventHealthLevel level;
  final double attendanceRate;
  final double checkInRate;
  final double capacityRate;
  final double vendorActivityRate;
  final double incidentRate;
  final int revenueVelocityMinor;
  final String summary;
  final String queueState;
  final int checkInThroughputPerHour;
}

class QrScanResponse {
  const QrScanResponse({
    required this.result,
    required this.message,
    this.guest,
  });

  final QrScanResult result;
  final String message;
  final OpsGuest? guest;
}

/// Normalize QR / pasted ticket input to a door ticket code when possible.
String resolveDoorTicketInput(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return value;
  if (value.toUpperCase().startsWith('OWANBE:')) {
    final parts = value.split(':').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 4) return parts.last;
    if (parts.length == 3) return parts[2];
  }
  return value;
}
