class DisputeItem {
  const DisputeItem({
    required this.id,
    required this.bookingId,
    required this.paymentId,
    required this.reason,
    required this.status,
    required this.outcome,
    required this.amountClaimedMinor,
    required this.createdAt,
  });
  final String id;
  final String bookingId;
  final String paymentId;
  final String reason;
  final String status;
  final String outcome;
  final String amountClaimedMinor;
  final DateTime createdAt;

  factory DisputeItem.fromJson(Map<String, dynamic> json) => DisputeItem(
        id: (json['id'] ?? '').toString(),
        bookingId: (json['booking_id'] ?? '').toString(),
        paymentId: (json['payment_id'] ?? '').toString(),
        reason: (json['reason'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        outcome: (json['outcome'] ?? '').toString(),
        amountClaimedMinor: (json['amount_claimed_minor'] ?? '0').toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
      );
}

class DisputeMessage {
  const DisputeMessage({
    required this.id,
    required this.senderType,
    required this.senderUserId,
    required this.message,
    required this.createdAt,
  });
  final String id;
  final String senderType;
  final String senderUserId;
  final String message;
  final DateTime createdAt;

  factory DisputeMessage.fromJson(Map<String, dynamic> json) => DisputeMessage(
        id: (json['id'] ?? '').toString(),
        senderType: (json['sender_type'] ?? '').toString(),
        senderUserId: (json['sender_user_id'] ?? '').toString(),
        message: (json['message'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
      );
}

class DisputeEvidence {
  const DisputeEvidence({
    required this.id,
    required this.type,
    required this.url,
    required this.createdAt,
  });
  final String id;
  final String type;
  final String url;
  final DateTime createdAt;

  factory DisputeEvidence.fromJson(Map<String, dynamic> json) => DisputeEvidence(
        id: (json['id'] ?? '').toString(),
        type: (json['type'] ?? '').toString(),
        url: (json['url'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
      );
}

class DisputeDetail {
  const DisputeDetail({
    required this.item,
    required this.messages,
    required this.evidence,
  });
  final DisputeItem item;
  final List<DisputeMessage> messages;
  final List<DisputeEvidence> evidence;

  factory DisputeDetail.fromJson(Map<String, dynamic> json) => DisputeDetail(
        item: DisputeItem.fromJson(json),
        messages: (json['messages'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DisputeMessage.fromJson)
            .toList(),
        evidence: (json['evidence'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DisputeEvidence.fromJson)
            .toList(),
      );
}
