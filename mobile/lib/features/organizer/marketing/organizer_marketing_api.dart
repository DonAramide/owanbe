import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/owambe_api_auth.dart';

class OrganizerMarketingApiException implements Exception {
  OrganizerMarketingApiException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => 'OrganizerMarketingApiException($code): $message';
}

class MarketingCampaign {
  const MarketingCampaign({
    required this.id,
    required this.name,
    required this.status,
    required this.channel,
    required this.audienceSegment,
    this.eventId,
    this.eventTitle,
    this.subject,
    this.body = '',
    this.recipientCount = 0,
    this.sentCount = 0,
    this.failedCount = 0,
    this.skippedCount = 0,
    this.lastError,
    this.sentAt,
    this.createdAt,
  });

  final String id;
  final String name;
  final String status;
  final String channel;
  final String audienceSegment;
  final String? eventId;
  final String? eventTitle;
  final String? subject;
  final String body;
  final int recipientCount;
  final int sentCount;
  final int failedCount;
  final int skippedCount;
  final String? lastError;
  final String? sentAt;
  final String? createdAt;

  factory MarketingCampaign.fromJson(Map<String, dynamic> json) => MarketingCampaign(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? ''}',
        status: '${json['status'] ?? ''}',
        channel: '${json['channel'] ?? 'email'}',
        audienceSegment: '${json['audienceSegment'] ?? ''}',
        eventId: json['eventId']?.toString(),
        eventTitle: json['eventTitle']?.toString(),
        subject: json['subject']?.toString(),
        body: '${json['body'] ?? ''}',
        recipientCount: (json['recipientCount'] as num?)?.toInt() ?? 0,
        sentCount: (json['sentCount'] as num?)?.toInt() ?? 0,
        failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
        skippedCount: (json['skippedCount'] as num?)?.toInt() ?? 0,
        lastError: json['lastError']?.toString(),
        sentAt: json['sentAt']?.toString(),
        createdAt: json['createdAt']?.toString(),
      );
}

class OrganizerMarketingApi {
  OrganizerMarketingApi();

  Future<Map<String, dynamic>> channels() async {
    final res = await http.get(
      Uri.parse('${OwambeApiAuth.resolveApiBase()}/organizers/me/marketing/channels'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> segments() async {
    final res = await http.get(
      Uri.parse('${OwambeApiAuth.resolveApiBase()}/organizers/me/marketing/segments'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['items'] as List? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> previewAudience({
    required String eventId,
    required String segment,
    required String channel,
  }) async {
    final q = Uri(
      path: '/organizers/me/marketing/audience/preview',
      queryParameters: {
        'eventId': eventId,
        'segment': segment,
        'channel': channel,
      },
    );
    final res = await http.get(
      Uri.parse('${OwambeApiAuth.resolveApiBase()}${q.path}?${q.query}'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<MarketingCampaign>> listCampaigns({String? eventId}) async {
    final q = eventId == null || eventId.isEmpty ? '' : '?eventId=$eventId';
    final res = await http.get(
      Uri.parse('${OwambeApiAuth.resolveApiBase()}/organizers/me/marketing/campaigns$q'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['items'] as List? ?? const [])
        .map((e) => MarketingCampaign.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getCampaign(String id) async {
    final res = await http.get(
      Uri.parse('${OwambeApiAuth.resolveApiBase()}/organizers/me/marketing/campaigns/$id'),
      headers: await OwambeApiAuth.authorizedHeaders(),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<MarketingCampaign> createCampaign(Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('${OwambeApiAuth.resolveApiBase()}/organizers/me/marketing/campaigns'),
      headers: await OwambeApiAuth.authorizedHeaders(),
      body: jsonEncode(body),
    );
    _ensureOk(res);
    return MarketingCampaign.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> sendCampaign(String id) async {
    final res = await http.post(
      Uri.parse('${OwambeApiAuth.resolveApiBase()}/organizers/me/marketing/campaigns/$id/send'),
      headers: await OwambeApiAuth.authorizedHeaders(),
      body: '{}',
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void _ensureOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      try {
        final body = jsonDecode(res.body);
        if (body is Map) {
          throw OrganizerMarketingApiException(
            code: '${body['code'] ?? res.statusCode}',
            message: '${body['message'] ?? body['reason'] ?? res.body}',
          );
        }
      } catch (e) {
        if (e is OrganizerMarketingApiException) rethrow;
      }
      throw OrganizerMarketingApiException(code: '${res.statusCode}', message: res.body);
    }
  }
}

final organizerMarketingApiProvider = Provider((ref) => OrganizerMarketingApi());

final organizerMarketingCampaignsProvider =
    FutureProvider.autoDispose.family<List<MarketingCampaign>, String?>((ref, eventId) {
  return ref.watch(organizerMarketingApiProvider).listCampaigns(eventId: eventId);
});

final organizerMarketingChannelsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(organizerMarketingApiProvider).channels();
});
