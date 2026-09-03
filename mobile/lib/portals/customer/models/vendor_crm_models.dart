class SelectedCapability {
  const SelectedCapability({required this.key, required this.label});

  final String key;
  final String label;

  factory SelectedCapability.fromJson(Map<String, dynamic> json) => SelectedCapability(
        key: (json['key'] ?? json['id'] ?? '').toString(),
        label: (json['label'] ?? json['name'] ?? json['key'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'key': key, 'label': label};
}

class VendorRequest {
  const VendorRequest({
    required this.id,
    required this.eventId,
    required this.vendorId,
    required this.stage,
    required this.serviceLabel,
    required this.message,
    this.negotiationId,
    this.scheduledAt,
    this.scheduledEnd,
    this.vendorName,
    this.eventTitle,
    this.organizerName,
    required this.createdAt,
    required this.updatedAt,
    this.contractStatus = 'draft',
    this.assignmentStatus = 'unassigned',
    this.latestOfferMinor,
    this.servicePriceMinor,
    this.vendorPayoutMinor,
    this.escrowStatus = 'unfunded',
    this.eventExternalRef,
    this.serviceKey,
    this.vendorServiceId,
    this.serviceCode,
    this.unreadCount = 0,
    this.fundingStatus = 'unfunded',
    this.pricingMarkupBps,
    this.eventStartsAt,
    this.eventEndsAt,
    this.eventType,
    this.eventLocation,
    this.expectedAttendees,
    this.eventDescription,
    this.requiredServices,
    this.venueName,
    this.venueAddress,
    this.selectedCapabilities = const [],
    this.buyerKind = 'organizer',
    this.buyerVendorId,
    this.buyerVendorName,
  });

  final String id;
  final String eventId;
  final String vendorId;
  final String stage;
  final String? serviceLabel;
  final String message;
  final String? negotiationId;
  final DateTime? scheduledAt;
  final DateTime? scheduledEnd;
  final String? vendorName;
  final String? eventTitle;
  final String? organizerName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String contractStatus;
  final String assignmentStatus;
  final int? latestOfferMinor;
  /// Organizer-facing commercial amount (never show vendor payout / margin).
  final int? servicePriceMinor;
  /// Vendor-facing agreed payout (never show customer price / margin).
  final int? vendorPayoutMinor;
  final String escrowStatus;
  /// events.external_ref — bridges Event Ops evt_* keys to CRM UUID eventId.
  final String? eventExternalRef;
  final String? serviceKey;
  /// First-class vendor_services.id when present (additive).
  final String? vendorServiceId;
  final String? serviceCode;
  final int unreadCount;
  final String fundingStatus;
  /// Snapshotted markup bps at request creation.
  final int? pricingMarkupBps;
  final DateTime? eventStartsAt;
  final DateTime? eventEndsAt;
  final String? eventType;
  final String? eventLocation;
  final int? expectedAttendees;
  final String? eventDescription;
  final List<String>? requiredServices;
  final String? venueName;
  final String? venueAddress;
  /// Frozen organizer selection from request metadata (never live-edited).
  final List<SelectedCapability> selectedCapabilities;
  final String buyerKind;
  final String? buyerVendorId;
  final String? buyerVendorName;

  String get displayBuyerName =>
      buyerKind == 'vendor' ? (buyerVendorName ?? 'Vendor') : (organizerName ?? 'Organizer');

  /// Party-appropriate amount for display.
  int? get displayAmountMinor => servicePriceMinor ?? vendorPayoutMinor ?? latestOfferMinor;

  /// Pending vendor decision (organizer waits; no conversation yet).
  bool get isAwaitingVendor => stage == 'new' || stage == 'negotiating';

  /// Confirmed booking stages — matches VendorAvailabilityService.loadBookedRanges.
  bool get isConfirmedBooking =>
      stage == 'accepted' || stage == 'scheduled' || stage == 'arrived' || stage == 'completed';

  DateTime get scheduleStartsAt => eventStartsAt ?? scheduledAt ?? updatedAt;

  DateTime? get scheduleEndsAt => eventEndsAt ?? scheduledEnd;

  /// Active service relationship after vendor accept (messaging allowed).
  bool get canMessage =>
      stage == 'accepted' || stage == 'scheduled' || stage == 'arrived';

  bool get isClosed => stage == 'declined' || stage == 'cancelled' || stage == 'completed';

  bool get canWithdraw => stage == 'new' || stage == 'negotiating';

  factory VendorRequest.fromJson(Map<String, dynamic> json) => VendorRequest(
        id: json['id'] as String,
        eventId: json['eventId'] as String,
        vendorId: json['vendorId'] as String,
        stage: json['stage'] as String? ?? 'new',
        serviceLabel: json['serviceLabel'] as String?,
        message: json['message'] as String? ?? '',
        negotiationId: json['negotiationId'] as String?,
        scheduledAt: json['scheduledAt'] != null ? DateTime.parse(json['scheduledAt'] as String).toLocal() : null,
        scheduledEnd: json['scheduledEnd'] != null ? DateTime.parse(json['scheduledEnd'] as String).toLocal() : null,
        vendorName: json['vendorName'] as String?,
        eventTitle: json['eventTitle'] as String?,
        organizerName: json['organizerName'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
        contractStatus: json['contractStatus'] as String? ?? _fallbackContract(json['stage'] as String? ?? 'new'),
        assignmentStatus: json['assignmentStatus'] as String? ?? _fallbackAssignment(json['stage'] as String? ?? 'new'),
        latestOfferMinor: int.tryParse((json['latestOfferMinor'] ?? '').toString()),
        servicePriceMinor: int.tryParse((json['servicePriceMinor'] ?? '').toString()),
        vendorPayoutMinor: int.tryParse((json['vendorPayoutMinor'] ?? '').toString()),
        escrowStatus: json['escrowStatus'] as String? ?? _fallbackEscrow(json['stage'] as String? ?? 'new'),
        eventExternalRef: json['eventExternalRef'] as String?,
        serviceKey: json['serviceKey'] as String?,
        vendorServiceId: json['vendorServiceId'] as String?,
        serviceCode: json['serviceCode'] as String?,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
        fundingStatus: json['fundingStatus'] as String? ?? 'unfunded',
        pricingMarkupBps: (json['pricingMarkupBps'] as num?)?.toInt(),
        eventStartsAt: json['eventStartsAt'] != null
            ? DateTime.parse(json['eventStartsAt'] as String).toLocal()
            : null,
        eventEndsAt: json['eventEndsAt'] != null
            ? DateTime.parse(json['eventEndsAt'] as String).toLocal()
            : null,
        eventType: json['eventType'] as String?,
        eventLocation: json['eventLocation'] as String?,
        expectedAttendees: (json['expectedAttendees'] as num?)?.toInt(),
        eventDescription: json['eventDescription'] as String?,
        requiredServices: (json['requiredServices'] as List?)?.map((e) => e.toString()).toList(),
        venueName: json['venueName'] as String?,
        venueAddress: json['venueAddress'] as String?,
        selectedCapabilities: (json['selectedCapabilities'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => SelectedCapability.fromJson(Map<String, dynamic>.from(e)))
            .where((c) => c.key.isNotEmpty)
            .toList(),
        buyerKind: (json['buyerKind'] as String?) ?? 'organizer',
        buyerVendorId: json['buyerVendorId'] as String?,
        buyerVendorName: json['buyerVendorName'] as String?,
      );

  static String _fallbackContract(String stage) => switch (stage) {
        'new' => 'draft',
        'negotiating' => 'pending',
        'accepted' || 'scheduled' || 'arrived' => 'accepted',
        'declined' || 'cancelled' => 'rejected',
        'completed' => 'completed',
        _ => 'draft',
      };

  static String _fallbackAssignment(String stage) => switch (stage) {
        'accepted' => 'assigned',
        'scheduled' || 'arrived' => 'in_progress',
        'completed' => 'done',
        'declined' || 'cancelled' => 'closed',
        _ => 'unassigned',
      };

  static String _fallbackEscrow(String stage) => switch (stage) {
        'new' || 'negotiating' => 'unfunded',
        'accepted' => 'pending',
        'scheduled' || 'arrived' => 'funded',
        'completed' => 'released',
        'declined' || 'cancelled' => 'cancelled',
        _ => 'unfunded',
      };
}

class VendorPipelineStats {
  const VendorPipelineStats({
    this.newCount = 0,
    this.negotiating = 0,
    this.accepted = 0,
    this.scheduled = 0,
    this.arrived = 0,
    this.completed = 0,
    this.declined = 0,
    this.cancelled = 0,
    this.total = 0,
  });

  final int newCount;
  final int negotiating;
  final int accepted;
  final int scheduled;
  final int arrived;
  final int completed;
  final int declined;
  final int cancelled;
  final int total;

  factory VendorPipelineStats.fromJson(Map<String, dynamic> json) => VendorPipelineStats(
        newCount: json['new'] as int? ?? 0,
        negotiating: json['negotiating'] as int? ?? 0,
        accepted: json['accepted'] as int? ?? 0,
        scheduled: json['scheduled'] as int? ?? 0,
        arrived: json['arrived'] as int? ?? 0,
        completed: json['completed'] as int? ?? 0,
        declined: json['declined'] as int? ?? 0,
        cancelled: json['cancelled'] as int? ?? 0,
        total: json['total'] as int? ?? 0,
      );

  int countForStage(String stage) => switch (stage) {
        'new' => newCount,
        'negotiating' => negotiating,
        'accepted' => accepted,
        'scheduled' => scheduled,
        'arrived' => arrived,
        'completed' => completed,
        _ => 0,
      };
}

class VendorCrmInsights {
  const VendorCrmInsights({
    this.attachedVendors = 0,
    this.vendorSpendMinor = 0,
    this.completedCount = 0,
    this.completionPct = 0,
    this.negotiatingCount = 0,
  });

  final int attachedVendors;
  final int vendorSpendMinor;
  final int completedCount;
  final double completionPct;
  final int negotiatingCount;

  factory VendorCrmInsights.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VendorCrmInsights();
    return VendorCrmInsights(
      attachedVendors: json['attachedVendors'] as int? ?? 0,
      vendorSpendMinor: int.tryParse((json['vendorSpendMinor'] ?? '0').toString()) ?? 0,
      completedCount: json['completedCount'] as int? ?? 0,
      completionPct: (json['completionPct'] as num?)?.toDouble() ?? 0,
      negotiatingCount: json['negotiatingCount'] as int? ?? 0,
    );
  }
}

class VendorCrmSnapshot {
  const VendorCrmSnapshot({
    required this.items,
    required this.stats,
    this.insights = const VendorCrmInsights(),
  });

  final List<VendorRequest> items;
  final VendorPipelineStats stats;
  final VendorCrmInsights insights;

  factory VendorCrmSnapshot.fromJson(Map<String, dynamic> json) => VendorCrmSnapshot(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => VendorRequest.fromJson(e as Map<String, dynamic>))
            .toList(),
        stats: VendorPipelineStats.fromJson(json['stats'] as Map<String, dynamic>? ?? const {}),
        insights: VendorCrmInsights.fromJson(json['insights'] as Map<String, dynamic>?),
      );
}

class VendorTimelineEvent {
  const VendorTimelineEvent({
    required this.id,
    this.fromStage,
    required this.toStage,
    required this.actorType,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String? fromStage;
  final String toStage;
  final String actorType;
  final String? note;
  final DateTime createdAt;

  factory VendorTimelineEvent.fromJson(Map<String, dynamic> json) => VendorTimelineEvent(
        id: json['id'] as String,
        fromStage: json['fromStage'] as String?,
        toStage: json['toStage'] as String,
        actorType: json['actorType'] as String? ?? 'organizer',
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}

class VendorNegotiationOffer {
  const VendorNegotiationOffer({
    required this.id,
    required this.actorType,
    required this.amountMinor,
    this.message,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String actorType;
  final int amountMinor;
  final String? message;
  final String status;
  final DateTime createdAt;

  factory VendorNegotiationOffer.fromJson(Map<String, dynamic> json) => VendorNegotiationOffer(
        id: json['id'] as String,
        actorType: json['actorType'] as String,
        amountMinor: int.tryParse((json['amountMinor'] ?? '0').toString()) ?? 0,
        message: json['message'] as String?,
        status: json['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}

class VendorRequestTimeline {
  const VendorRequestTimeline({
    required this.request,
    required this.history,
    required this.offers,
    required this.contractStatus,
    required this.assignmentStatus,
    this.escrowStatus = 'unfunded',
  });

  final VendorRequest request;
  final List<VendorTimelineEvent> history;
  final List<VendorNegotiationOffer> offers;
  final String contractStatus;
  final String assignmentStatus;
  final String escrowStatus;

  /// Same-stage history notes = shared conversation messages.
  List<VendorTimelineEvent> get conversationMessages => history
      .where((h) => h.fromStage == h.toStage && (h.note?.trim().isNotEmpty ?? false))
      .toList();

  factory VendorRequestTimeline.fromJson(Map<String, dynamic> json) => VendorRequestTimeline(
        request: VendorRequest.fromJson(json['request'] as Map<String, dynamic>),
        history: (json['history'] as List<dynamic>? ?? const [])
            .map((e) => VendorTimelineEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        offers: (json['offers'] as List<dynamic>? ?? const [])
            .map((e) => VendorNegotiationOffer.fromJson(e as Map<String, dynamic>))
            .toList(),
        contractStatus: json['contractStatus'] as String? ?? 'draft',
        assignmentStatus: json['assignmentStatus'] as String? ?? 'unassigned',
        escrowStatus: json['escrowStatus'] as String? ??
            (json['request'] is Map
                ? (json['request'] as Map)['escrowStatus'] as String?
                : null) ??
            'unfunded',
      );
}

const vendorCrmStageLabels = {
  'new': 'Pending Vendor Response',
  'negotiating': 'Pending Vendor Response',
  'accepted': 'Accepted',
  'scheduled': 'Scheduled',
  'arrived': 'Arrived',
  'completed': 'Completed',
  'declined': 'Declined',
  'cancelled': 'Cancelled',
};

const vendorCrmVendorStageLabels = {
  'new': 'NEW',
  'negotiating': 'NEW',
  'accepted': 'Accepted',
  'scheduled': 'Scheduled',
  'arrived': 'Arrived',
  'completed': 'Completed',
  'declined': 'Declined',
  'cancelled': 'Cancelled',
};

const vendorCrmContractLabels = {
  'draft': 'Draft',
  'pending': 'Pending',
  'accepted': 'Accepted',
  'rejected': 'Rejected',
  'completed': 'Completed',
};

const vendorCrmAssignmentLabels = {
  'unassigned': 'Unassigned',
  'assigned': 'Assigned',
  'in_progress': 'In progress',
  'done': 'Done',
  'closed': 'Closed',
};

const vendorCrmEscrowLabels = {
  'unfunded': 'UNFUNDED',
  'pending': 'PENDING',
  'funded': 'FUNDED',
  'released': 'RELEASED',
  'cancelled': 'CANCELLED',
};

const vendorCrmPipelineStages = [
  'new',
  'negotiating',
  'accepted',
  'scheduled',
  'arrived',
  'completed',
];

class VendorCalendarBlock {
  const VendorCalendarBlock({
    required this.id,
    required this.kind,
    required this.startsAt,
    required this.endsAt,
    required this.allDay,
    this.reason,
    this.sourceType,
    this.sourceId,
  });

  final String id;
  final String kind;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool allDay;
  final String? reason;
  final String? sourceType;
  final String? sourceId;

  /// Manual Block Dates rows. Vacation and CRM/rental-sourced rows stay read-only.
  bool get isManualBlackout {
    if (kind != 'blackout') return false;
    final source = sourceType?.trim();
    final sourceKey = sourceId?.trim();
    return (source == null || source.isEmpty) && (sourceKey == null || sourceKey.isEmpty);
  }

  factory VendorCalendarBlock.fromJson(Map<String, dynamic> json) => VendorCalendarBlock(
        id: json['id'] as String,
        kind: json['kind'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
        endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
        allDay: json['allDay'] as bool? ?? false,
        reason: json['reason'] as String?,
        sourceType: json['sourceType']?.toString(),
        sourceId: json['sourceId']?.toString(),
      );
}

class VendorCalendarSnapshot {
  const VendorCalendarSnapshot({
    required this.vacationMode,
    this.vacationUntil,
    required this.blocks,
  });

  final bool vacationMode;
  final String? vacationUntil;
  final List<VendorCalendarBlock> blocks;

  factory VendorCalendarSnapshot.fromJson(Map<String, dynamic> json) => VendorCalendarSnapshot(
        vacationMode: json['vacationMode'] as bool? ?? false,
        vacationUntil: json['vacationUntil'] as String?,
        blocks: (json['blocks'] as List<dynamic>? ?? const [])
            .map((e) => VendorCalendarBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
