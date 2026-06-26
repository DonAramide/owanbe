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
    required this.createdAt,
    required this.updatedAt,
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
  final DateTime createdAt;
  final DateTime updatedAt;

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
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      );
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

class VendorCrmSnapshot {
  const VendorCrmSnapshot({required this.items, required this.stats});

  final List<VendorRequest> items;
  final VendorPipelineStats stats;

  factory VendorCrmSnapshot.fromJson(Map<String, dynamic> json) => VendorCrmSnapshot(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => VendorRequest.fromJson(e as Map<String, dynamic>))
            .toList(),
        stats: VendorPipelineStats.fromJson(json['stats'] as Map<String, dynamic>? ?? const {}),
      );
}

const vendorCrmStageLabels = {
  'new': 'New Request',
  'negotiating': 'Negotiating',
  'accepted': 'Accepted',
  'scheduled': 'Scheduled',
  'arrived': 'Arrived',
  'completed': 'Completed',
  'declined': 'Declined',
  'cancelled': 'Cancelled',
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
  });

  final String id;
  final String kind;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool allDay;
  final String? reason;

  factory VendorCalendarBlock.fromJson(Map<String, dynamic> json) => VendorCalendarBlock(
        id: json['id'] as String,
        kind: json['kind'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
        endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
        allDay: json['allDay'] as bool? ?? false,
        reason: json['reason'] as String?,
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
