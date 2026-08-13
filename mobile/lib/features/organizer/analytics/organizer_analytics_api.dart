import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../auth/auth_session.dart';
import '../../../core/api/owambe_api_auth.dart';
import '../models/organizer_models.dart';

class OrganizerAnalyticsApiException implements Exception {
  OrganizerAnalyticsApiException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => message;
}

class AnalyticsSeriesPoint {
  const AnalyticsSeriesPoint({required this.label, required this.value});
  final String label;
  final double value;

  factory AnalyticsSeriesPoint.fromJson(Map<String, dynamic> json) => AnalyticsSeriesPoint(
        label: (json['label'] ?? '').toString(),
        value: (json['value'] as num?)?.toDouble() ?? 0,
      );
}

class EventAnalyticsSnapshot {
  const EventAnalyticsSnapshot({
    required this.eventId,
    this.eventTitle = '',
    this.pageViewsAvailable = false,
    this.trafficSourcesAvailable = false,
    required this.ticketsSold,
    required this.revenueMinor,
    required this.checkInRate,
    required this.registrations,
    required this.checkIns,
    required this.noShows,
    required this.attendancePct,
    required this.noShowPct,
    required this.ordersCount,
    required this.paidTickets,
    required this.complimentaryTickets,
    required this.dailySales,
    required this.weeklySales,
    required this.monthlySales,
    required this.revenueDaily,
    required this.checkInsDaily,
    required this.checkInsHourly,
    required this.tierBreakdown,
    required this.tierTypeBreakdown,
    this.invitationsSent = 0,
    this.invitationsPending = 0,
    this.invitationsAccepted = 0,
    this.invitationsDeclined = 0,
    this.rsvpConversionPct = 0,
    this.invitationsAvailable = false,
    this.grossCollectedMinor = '0',
    this.netEarningsMinor = '0',
    this.platformFeeMinor = '0',
    this.refundedTotalMinor = '0',
    this.heldInEscrowMinor = '0',
    this.pendingPayoutMinor = '0',
    this.settlementStatus = 'none',
    this.bestSellingTier,
    this.peakAttendanceHour,
    this.peakAttendanceCount = 0,
    this.engagementSummary = '',
    this.sellThroughPct,
  });

  final String eventId;
  final String eventTitle;
  final bool pageViewsAvailable;
  final bool trafficSourcesAvailable;
  final int ticketsSold;
  final int revenueMinor;
  final double checkInRate;
  final int registrations;
  final int checkIns;
  final int noShows;
  final double attendancePct;
  final double noShowPct;
  final int ordersCount;
  final int paidTickets;
  final int complimentaryTickets;
  final List<double> dailySales;
  final List<double> weeklySales;
  final List<double> monthlySales;
  final List<double> revenueDaily;
  final List<double> checkInsDaily;
  final List<AnalyticsSeriesPoint> checkInsHourly;
  final Map<String, int> tierBreakdown;
  final Map<TicketTierType, int> tierTypeBreakdown;
  final int invitationsSent;
  final int invitationsPending;
  final int invitationsAccepted;
  final int invitationsDeclined;
  final double rsvpConversionPct;
  final bool invitationsAvailable;
  final String grossCollectedMinor;
  final String netEarningsMinor;
  final String platformFeeMinor;
  final String refundedTotalMinor;
  final String heldInEscrowMinor;
  final String pendingPayoutMinor;
  final String settlementStatus;
  final String? bestSellingTier;
  final String? peakAttendanceHour;
  final int peakAttendanceCount;
  final String engagementSummary;
  final double? sellThroughPct;

  /// Deprecated synthetic field — always null/unavailable.
  int get pageViews => 0;

  List<double> get salesTrend => dailySales;

  factory EventAnalyticsSnapshot.fromApi(Map<String, dynamic> json) {
    final sales = json['sales'] as Map<String, dynamic>? ?? {};
    final attendance = json['attendance'] as Map<String, dynamic>? ?? {};
    final invitations = json['invitations'] as Map<String, dynamic>? ?? {};
    final finance = json['finance'] as Map<String, dynamic>? ?? {};
    final series = json['series'] as Map<String, dynamic>? ?? {};
    final intelligence = json['intelligence'] as Map<String, dynamic>? ?? {};
    final tiers = (json['tiers'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();

    List<double> seriesValues(String key) {
      final list = series[key] as List<dynamic>? ?? [];
      return list
          .map((e) => ((e as Map<String, dynamic>)['value'] as num?)?.toDouble() ?? 0)
          .toList();
    }

    final tierBreakdown = <String, int>{
      for (final t in tiers) (t['name'] ?? 'General').toString(): (t['sold'] as num?)?.toInt() ?? 0,
    };

    return EventAnalyticsSnapshot(
      eventId: (json['eventId'] ?? '').toString(),
      eventTitle: (json['eventTitle'] ?? '').toString(),
      pageViewsAvailable: json['pageViewsAvailable'] == true,
      trafficSourcesAvailable: json['trafficSourcesAvailable'] == true,
      ticketsSold: (sales['ticketsSold'] as num?)?.toInt() ?? 0,
      revenueMinor: int.tryParse((sales['revenueMinor'] ?? '0').toString()) ?? 0,
      checkInRate: (attendance['checkInRate'] as num?)?.toDouble() ?? 0,
      registrations: (attendance['registered'] as num?)?.toInt() ?? 0,
      checkIns: (attendance['checkedIn'] as num?)?.toInt() ?? 0,
      noShows: (attendance['noShows'] as num?)?.toInt() ?? 0,
      attendancePct: (attendance['attendancePct'] as num?)?.toDouble() ?? 0,
      noShowPct: (attendance['noShowPct'] as num?)?.toDouble() ?? 0,
      ordersCount: (sales['ordersCount'] as num?)?.toInt() ?? 0,
      paidTickets: (sales['paidTickets'] as num?)?.toInt() ?? 0,
      complimentaryTickets: (sales['complimentaryTickets'] as num?)?.toInt() ?? 0,
      dailySales: seriesValues('salesDaily'),
      weeklySales: seriesValues('salesWeekly'),
      monthlySales: seriesValues('salesMonthly'),
      revenueDaily: seriesValues('revenueDaily'),
      checkInsDaily: seriesValues('checkInsDaily'),
      checkInsHourly: (series['checkInsHourly'] as List<dynamic>? ?? [])
          .map((e) => AnalyticsSeriesPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      tierBreakdown: tierBreakdown,
      tierTypeBreakdown: const {},
      invitationsSent: (invitations['sent'] as num?)?.toInt() ?? 0,
      invitationsPending: (invitations['pending'] as num?)?.toInt() ?? 0,
      invitationsAccepted: (invitations['accepted'] as num?)?.toInt() ?? 0,
      invitationsDeclined: (invitations['declined'] as num?)?.toInt() ?? 0,
      rsvpConversionPct: (invitations['rsvpConversionPct'] as num?)?.toDouble() ?? 0,
      invitationsAvailable: invitations['available'] == true,
      grossCollectedMinor: (finance['grossCollectedMinor'] ?? '0').toString(),
      netEarningsMinor: (finance['netEarningsMinor'] ?? '0').toString(),
      platformFeeMinor: (finance['platformFeeMinor'] ?? '0').toString(),
      refundedTotalMinor: (finance['refundedTotalMinor'] ?? '0').toString(),
      heldInEscrowMinor: (finance['heldInEscrowMinor'] ?? '0').toString(),
      pendingPayoutMinor: (finance['pendingPayoutMinor'] ?? '0').toString(),
      settlementStatus: (finance['settlementStatus'] ?? 'none').toString(),
      bestSellingTier: intelligence['bestSellingTier'] as String?,
      peakAttendanceHour: intelligence['peakAttendanceHour'] as String?,
      peakAttendanceCount: (intelligence['peakAttendanceCount'] as num?)?.toInt() ?? 0,
      engagementSummary: (intelligence['engagementSummary'] ?? '').toString(),
    );
  }

  static EventAnalyticsSnapshot empty(String eventId) => EventAnalyticsSnapshot(
        eventId: eventId,
        ticketsSold: 0,
        revenueMinor: 0,
        checkInRate: 0,
        registrations: 0,
        checkIns: 0,
        noShows: 0,
        attendancePct: 0,
        noShowPct: 0,
        ordersCount: 0,
        paidTickets: 0,
        complimentaryTickets: 0,
        dailySales: const [],
        weeklySales: const [],
        monthlySales: const [],
        revenueDaily: const [],
        checkInsDaily: const [],
        checkInsHourly: const [],
        tierBreakdown: const {},
        tierTypeBreakdown: const {},
      );
}

class PortfolioAnalyticsItem {
  const PortfolioAnalyticsItem({
    required this.eventId,
    required this.title,
    required this.status,
    required this.ticketsSold,
    required this.revenueMinor,
    required this.checkedIn,
    required this.attendancePct,
  });

  final String eventId;
  final String title;
  final String status;
  final int ticketsSold;
  final int revenueMinor;
  final int checkedIn;
  final double attendancePct;

  factory PortfolioAnalyticsItem.fromJson(Map<String, dynamic> json) => PortfolioAnalyticsItem(
        eventId: (json['eventId'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        ticketsSold: (json['ticketsSold'] as num?)?.toInt() ?? 0,
        revenueMinor: int.tryParse((json['revenueMinor'] ?? '0').toString()) ?? 0,
        checkedIn: (json['checkedIn'] as num?)?.toInt() ?? 0,
        attendancePct: (json['attendancePct'] as num?)?.toDouble() ?? 0,
      );
}

class OrganizerAnalyticsApi {
  OrganizerAnalyticsApi({http.Client? client}) : _http = client ?? http.Client();
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
        throw OrganizerAnalyticsApiException(
          code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
          message: (body['message'] ?? 'Request failed').toString(),
        );
      }
    } catch (e) {
      if (e is OrganizerAnalyticsApiException) rethrow;
    }
    throw OrganizerAnalyticsApiException(code: 'HTTP_${res.statusCode}', message: res.body);
  }

  Future<EventAnalyticsSnapshot> fetchEventIntelligence({
    required String eventId,
    int days = 30,
    AuthSession? session,
  }) async {
    final res = await _http.get(
      _u('events/$eventId/analytics', {'days': '$days'}),
      headers: await _headers(session),
    );
    if (res.statusCode >= 400) _throw(res);
    return EventAnalyticsSnapshot.fromApi(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<PortfolioAnalyticsItem>> fetchPortfolio({AuthSession? session}) async {
    final res = await _http.get(_u('organizers/me/analytics/portfolio'), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .map((e) => PortfolioAnalyticsItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<int>> exportEventCsvBytes({required String eventId, AuthSession? session}) async {
    final res = await _http.get(_u('events/$eventId/analytics/export'), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    return res.bodyBytes;
  }
}
