/// Phase 3C/3D structured change-request view models (REST-backed).
class VendorChangeRequest {
  const VendorChangeRequest({
    required this.id,
    required this.vendorRequestId,
    required this.eventId,
    required this.vendorId,
    required this.type,
    required this.status,
    required this.originalSnapshot,
    required this.requestedPayload,
    required this.responsePayload,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.requestedByUserId,
    this.respondedByUserId,
  });

  final String id;
  final String vendorRequestId;
  final String eventId;
  final String vendorId;
  final String type;
  final String status;
  final Map<String, dynamic> originalSnapshot;
  final Map<String, dynamic> requestedPayload;
  final Map<String, dynamic> responsePayload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final String? requestedByUserId;
  final String? respondedByUserId;

  bool get isPending => status == 'pending';

  String get typeLabel {
    switch (type) {
      case 'ADD_CAPABILITY':
        return 'Add capability';
      case 'REMOVE_CAPABILITY':
        return 'Remove capability';
      case 'CHANGE_DATE':
        return 'Change date';
      case 'CHANGE_TIME':
        return 'Change time';
      case 'CHANGE_VENUE':
        return 'Change venue';
      case 'SPECIAL_REQUIREMENT':
        return 'Special requirement';
      default:
        return type;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'declined':
        return 'Declined';
      case 'cancelled':
        return 'Cancelled';
      case 'expired':
        return 'Expired';
      default:
        return status;
    }
  }

  /// Human-readable CURRENT summary from original snapshot.
  String get currentSummary {
    final caps = originalSnapshot['selectedCapabilities'];
    final capLabels = <String>[];
    if (caps is List) {
      for (final c in caps) {
        if (c is Map) {
          final label = (c['label'] ?? c['key'] ?? '').toString();
          if (label.isNotEmpty) capLabels.add(label);
        }
      }
    }
    final parts = <String>[
      if ((originalSnapshot['serviceLabel'] ?? '').toString().isNotEmpty)
        originalSnapshot['serviceLabel'].toString(),
      if ((originalSnapshot['eventStartsAt'] ?? '').toString().isNotEmpty)
        _shortIso(originalSnapshot['eventStartsAt'].toString()),
      if ((originalSnapshot['eventEndsAt'] ?? '').toString().isNotEmpty)
        '– ${_shortIso(originalSnapshot['eventEndsAt'].toString())}',
      if ((originalSnapshot['venueName'] ?? originalSnapshot['venue'] ?? '')
          .toString()
          .isNotEmpty)
        (originalSnapshot['venueName'] ?? originalSnapshot['venue']).toString(),
      if (capLabels.isNotEmpty) 'Capabilities: ${capLabels.join(', ')}',
    ];
    return parts.isEmpty ? 'Current booking' : parts.join('\n');
  }

  /// Human-readable REQUESTED summary from payload + type.
  String get requestedSummary {
    switch (type) {
      case 'ADD_CAPABILITY':
        return 'Add: ${requestedPayload['capabilityLabel'] ?? requestedPayload['capabilityKey'] ?? 'capability'}';
      case 'REMOVE_CAPABILITY':
        return 'Remove: ${requestedPayload['capabilityLabel'] ?? requestedPayload['capabilityKey'] ?? 'capability'}';
      case 'CHANGE_DATE':
      case 'CHANGE_TIME':
        final start = requestedPayload['startsAt']?.toString();
        final end = requestedPayload['endsAt']?.toString();
        return [
          if (start != null && start.isNotEmpty) _shortIso(start),
          if (end != null && end.isNotEmpty) '– ${_shortIso(end)}',
        ].join(' ');
      case 'CHANGE_VENUE':
        return [
          requestedPayload['venueName'] ?? requestedPayload['venue'],
          if ((requestedPayload['venueAddress'] ?? '').toString().isNotEmpty)
            requestedPayload['venueAddress'],
        ].whereType<Object>().map((e) => e.toString()).where((s) => s.isNotEmpty).join('\n');
      case 'SPECIAL_REQUIREMENT':
        return (requestedPayload['requirement'] ?? '').toString();
      default:
        return requestedPayload.toString();
    }
  }

  static String _shortIso(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  factory VendorChangeRequest.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> mapOf(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return <String, dynamic>{};
    }

    return VendorChangeRequest(
      id: (json['id'] ?? '').toString(),
      vendorRequestId: (json['vendorRequestId'] ?? '').toString(),
      eventId: (json['eventId'] ?? '').toString(),
      vendorId: (json['vendorId'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      originalSnapshot: mapOf(json['originalSnapshot']),
      requestedPayload: mapOf(json['requestedPayload']),
      responsePayload: mapOf(json['responsePayload']),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? DateTime.now().toUtc(),
      resolvedAt: DateTime.tryParse((json['resolvedAt'] ?? '').toString()),
      requestedByUserId: json['requestedByUserId']?.toString(),
      respondedByUserId: json['respondedByUserId']?.toString(),
    );
  }
}

bool vendorRequestAllowsChangeRequests(String stage) =>
    stage == 'accepted' || stage == 'scheduled' || stage == 'arrived';
