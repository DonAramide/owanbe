import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/auth_session.dart';
import 'owambe_api_auth.dart';

class PostEventApiException implements Exception {
  PostEventApiException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => message;
}

class AttendeeEventFeedback {
  AttendeeEventFeedback({
    required this.eventId,
    required this.rating,
    required this.submittedAt,
    required this.updatedAt,
    required this.editable,
    this.comment,
    this.editableUntil,
  });

  final String eventId;
  final int rating;
  final String? comment;
  final DateTime submittedAt;
  final DateTime updatedAt;
  final bool editable;
  final DateTime? editableUntil;

  factory AttendeeEventFeedback.fromJson(Map<String, dynamic> json) {
    return AttendeeEventFeedback(
      eventId: (json['eventId'] ?? '').toString(),
      rating: int.tryParse('${json['rating']}') ?? 0,
      comment: json['comment']?.toString(),
      submittedAt: DateTime.tryParse((json['submittedAt'] ?? '').toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? DateTime.now(),
      editable: json['editable'] == true,
      editableUntil: DateTime.tryParse((json['editableUntil'] ?? '').toString()),
    );
  }
}

class AttendeeFeedbackEnvelope {
  AttendeeFeedbackEnvelope({
    required this.canSubmit,
    this.feedback,
    this.editableUntil,
  });

  final AttendeeEventFeedback? feedback;
  final DateTime? editableUntil;
  final bool canSubmit;

  factory AttendeeFeedbackEnvelope.fromJson(Map<String, dynamic> json) {
    final raw = json['feedback'];
    return AttendeeFeedbackEnvelope(
      feedback: raw is Map
          ? AttendeeEventFeedback.fromJson(Map<String, dynamic>.from(raw))
          : null,
      editableUntil: DateTime.tryParse((json['editableUntil'] ?? '').toString()),
      canSubmit: json['canSubmit'] == true,
    );
  }
}

class PostEventApi {
  PostEventApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  Uri _u(String path) => Uri.parse('${OwambeApiAuth.resolveApiBase()}/$path');

  Future<Map<String, String>> _headers(AuthSession session) =>
      OwambeApiAuth.authorizedHeaders(tenantId: OwambeApiAuth.resolveTenantId());

  void _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        throw PostEventApiException(
          code: (body['code'] ?? 'ERROR').toString(),
          message: (body['message'] ?? res.body).toString(),
        );
      }
    } catch (e) {
      if (e is PostEventApiException) rethrow;
    }
    throw PostEventApiException(code: 'HTTP_${res.statusCode}', message: res.body);
  }

  Future<AttendeeFeedbackEnvelope> fetchFeedback({
    required AuthSession session,
    required String eventId,
  }) async {
    final res = await _http.get(
      _u('events/$eventId/feedback'),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
    return AttendeeFeedbackEnvelope.fromJson(
      Map<String, dynamic>.from(jsonDecode(res.body) as Map),
    );
  }

  Future<AttendeeEventFeedback> upsertFeedback({
    required AuthSession session,
    required String eventId,
    required int rating,
    String? comment,
  }) async {
    final res = await _http.put(
      _u('events/$eventId/feedback'),
      headers: await _headers(session),
      body: jsonEncode({
        'rating': rating,
        if (comment != null) 'comment': comment,
      }),
    );
    if (res.statusCode >= 400) _throw(res);
    return AttendeeEventFeedback.fromJson(
      Map<String, dynamic>.from(jsonDecode(res.body) as Map),
    );
  }
}
