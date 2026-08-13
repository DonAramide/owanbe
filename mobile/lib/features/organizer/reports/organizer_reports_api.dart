import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../auth/auth_notifier.dart';
import '../../../auth/auth_session.dart';
import '../../../core/api/owambe_api_auth.dart';

class OrganizerReportsApiException implements Exception {
  OrganizerReportsApiException({required this.code, required this.message});
  final String code;
  final String message;

  @override
  String toString() => 'OrganizerReportsApiException($code): $message';
}

class ReportCatalogEntry {
  const ReportCatalogEntry({
    required this.id,
    required this.title,
    required this.source,
    required this.status,
    this.reason,
    required this.formats,
  });

  final String id;
  final String title;
  final String source;
  final String status;
  final String? reason;
  final List<String> formats;

  bool get isAvailable => status == 'available';

  factory ReportCatalogEntry.fromJson(Map<String, dynamic> json) => ReportCatalogEntry(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        source: (json['source'] ?? '').toString(),
        status: (json['status'] ?? 'unavailable').toString(),
        reason: json['reason']?.toString(),
        formats: (json['formats'] as List<dynamic>? ?? const ['csv'])
            .map((e) => e.toString())
            .toList(),
      );
}

class ReportExportResult {
  const ReportExportResult({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final List<int> bytes;
  final String filename;
  final String contentType;
}

class OrganizerReportsApi {
  OrganizerReportsApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwambeApiAuth.resolveApiBase();
  String get _tenantId => OwambeApiAuth.resolveTenantId();

  Future<Map<String, String>> _headers([AuthSession? session]) =>
      OwambeApiAuth.authorizedHeaders(tenantId: _tenantId);

  Uri _u(String path, [Map<String, String>? q]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p').replace(queryParameters: q);
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) {
        throw OrganizerReportsApiException(
          code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
          message: (body['message'] ?? body['reason'] ?? 'Request failed').toString(),
        );
      }
    } catch (e) {
      if (e is OrganizerReportsApiException) rethrow;
    }
    throw OrganizerReportsApiException(code: 'HTTP_${res.statusCode}', message: res.body);
  }

  Future<List<ReportCatalogEntry>> fetchEventCatalog({
    required String eventId,
    AuthSession? session,
  }) async {
    final res = await _http.get(
      _u('events/$eventId/reports/catalog'),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .map((e) => ReportCatalogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReportCatalogEntry>> fetchPortfolioCatalog({AuthSession? session}) async {
    final res = await _http.get(
      _u('organizers/me/reports/catalog'),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .map((e) => ReportCatalogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ReportExportResult> exportEventPack({
    required String eventId,
    required String pack,
    String format = 'csv',
    String? from,
    String? to,
    String? ticketType,
    String? vendorId,
    String? vendorStage,
    String? guestStatus,
    AuthSession? session,
  }) async {
    final q = <String, String>{'format': format};
    if (from != null && from.isNotEmpty) q['from'] = from;
    if (to != null && to.isNotEmpty) q['to'] = to;
    if (ticketType != null && ticketType.isNotEmpty) q['ticketType'] = ticketType;
    if (vendorId != null && vendorId.isNotEmpty) q['vendorId'] = vendorId;
    if (vendorStage != null && vendorStage.isNotEmpty) q['vendorStage'] = vendorStage;
    if (guestStatus != null && guestStatus.isNotEmpty) q['guestStatus'] = guestStatus;

    final res = await _http.get(
      _u('events/$eventId/reports/export/$pack', q),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
    final disposition = res.headers['content-disposition'] ?? '';
    final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
    final filename = match?.group(1) ?? 'owanbe-$pack.${format == 'xlsx' ? 'xls' : 'csv'}';
    return ReportExportResult(
      bytes: res.bodyBytes,
      filename: filename,
      contentType: res.headers['content-type'] ?? 'text/csv',
    );
  }

  Future<ReportExportResult> exportPortfolio({
    String format = 'csv',
    AuthSession? session,
  }) async {
    final res = await _http.get(
      _u('organizers/me/reports/export/portfolio', {'format': format}),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
    final disposition = res.headers['content-disposition'] ?? '';
    final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
    final filename = match?.group(1) ?? 'owanbe-portfolio.${format == 'xlsx' ? 'xls' : 'csv'}';
    return ReportExportResult(
      bytes: res.bodyBytes,
      filename: filename,
      contentType: res.headers['content-type'] ?? 'text/csv',
    );
  }
}

final organizerReportsApiProvider = Provider<OrganizerReportsApi>((ref) => OrganizerReportsApi());

final organizerEventReportsCatalogProvider =
    FutureProvider.autoDispose.family<List<ReportCatalogEntry>, String>((ref, eventId) async {
  final session = ref.watch(authSessionProvider);
  return ref.read(organizerReportsApiProvider).fetchEventCatalog(eventId: eventId, session: session);
});
