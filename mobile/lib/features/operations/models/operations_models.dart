enum EventHealthLevel { healthy, warning, critical }

enum IncidentCategory { security, medical, access, technical, vendor }

enum IncidentPriority { low, medium, high, critical }

enum IncidentStatus { open, investigating, resolved }

enum FeedEventType {
  guestCheckedIn,
  vendorJoined,
  orderPlaced,
  refundRequested,
  incidentLogged,
  wallPost,
  wallPinned,
}

enum QrScanResult { valid, alreadyUsed, expired, invalid, vip, vvip }

enum CheckInFilter { all, checkedIn, notCheckedIn, vip, vvip }

enum VendorOpsStatus { active, idle, offline }

enum GuestTier { general, vip, vvip }

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

  OpsGuest copyWith({
    bool? checkedIn,
    DateTime? checkedInAt,
    bool? qrValid,
    bool? ticketExpired,
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

class LiveEventKpis {
  const LiveEventKpis({
    required this.checkedIn,
    required this.remainingGuests,
    required this.vendorsActive,
    required this.ordersToday,
    required this.revenueTodayMinor,
    required this.openIncidents,
    required this.totalRegistered,
  });

  final int checkedIn;
  final int remainingGuests;
  final int vendorsActive;
  final int ordersToday;
  final int revenueTodayMinor;
  final int openIncidents;
  final int totalRegistered;
}

class EventHealthSnapshot {
  const EventHealthSnapshot({
    required this.level,
    required this.attendanceRate,
    required this.checkInRate,
    required this.vendorActivityRate,
    required this.incidentRate,
    required this.revenueVelocityMinor,
    required this.summary,
  });

  final EventHealthLevel level;
  final double attendanceRate;
  final double checkInRate;
  final double vendorActivityRate;
  final double incidentRate;
  final int revenueVelocityMinor;
  final String summary;
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
