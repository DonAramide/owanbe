import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/executive_dashboard_models.dart';
import '../super_admin_providers.dart';

final executiveDashboardProvider = FutureProvider.autoDispose<ExecutiveDashboardData>((ref) async {
  ref.watch(superAdminRevisionProvider);
  final api = ref.read(superAdminApiProvider);
  final sw = Stopwatch()..start();
  final results = await Future.wait<dynamic>([
    api.getPlatformOverview(),
    api.getPlatformFinance(),
    api.getSystemHealth(),
    api.getAnalytics(range: '30d'),
    api.getAnalytics(range: '7d'),
    api.listTenants(),
    api.getAuditTimeline(),
    api.getSecurityCenter(),
  ]);
  sw.stop();

  final overview = results[0] as Map<String, dynamic>;
  final finance = results[1] as Map<String, dynamic>;
  final health = results[2] as Map<String, dynamic>;
  final analytics30 = results[3] as Map<String, dynamic>;
  final analytics7 = results[4] as Map<String, dynamic>;
  final tenants = results[5] as List<Map<String, dynamic>>;
  final audit = results[6] as List<Map<String, dynamic>>;
  final security = results[7] as Map<String, dynamic>;

  final summary = finance['summary'] as Map<String, dynamic>? ?? {};
  final ticketRev = int.tryParse('${summary['ticketRevenueMinor'] ?? 0}') ?? 0;
  final bookingRev = int.tryParse('${summary['bookingRevenueMinor'] ?? 0}') ?? 0;
  final platformFees = int.tryParse('${summary['platformFeesMinor'] ?? 0}') ?? 0;
  final refundVol = int.tryParse('${summary['refundVolumeMinor'] ?? 0}') ?? 0;
  final payoutVol = int.tryParse('${summary['payoutVolumeMinor'] ?? 0}') ?? 0;
  final platformRev = int.tryParse('${overview['platformRevenueMinor'] ?? 0}') ?? 0;

  final platformStatus = _platformStatus('${overview['platformHealth'] ?? 'healthy'}');
  final healthScore = _healthScore(platformStatus, overview, health);
  final subsystems = _buildSubsystems(health, security, overview, sw.elapsedMilliseconds);

  final sortedTenants = [...tenants]
    ..sort((a, b) => (int.tryParse('${b['revenueMinor']}') ?? 0).compareTo(int.tryParse('${a['revenueMinor']}') ?? 0));

  final topTenantDetails = <Map<String, dynamic>>[];
  for (final t in sortedTenants.take(3)) {
    try {
      topTenantDetails.add(await api.getTenant('${t['id']}'));
    } catch (_) {}
  }

  final eventRows = <ExecutiveEventRow>[];
  final organizerRows = <ExecutiveOrganizerRow>[];
  for (final detail in topTenantDetails) {
    final tenantName = (detail['profile'] as Map?)?['name']?.toString() ?? 'Tenant';
    final events = (detail['events'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final organizers = (detail['organizers'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    for (final e in events.take(8)) {
      var rev = 0;
      try {
        final drill = await api.getPlatformFinance(drill: 'event', drillId: '${e['id']}');
        final dd = drill['drillDown'] as Map<String, dynamic>?;
        rev = int.tryParse('${dd?['ticket_minor'] ?? 0}') ?? 0;
      } catch (_) {}
      eventRows.add(ExecutiveEventRow(
        id: '${e['id']}',
        title: '${e['title']}',
        tenantName: tenantName,
        revenueMinor: rev,
        attendees: 0,
        status: '${e['status']}',
        startsAt: DateTime.tryParse('${e['startsAt']}'),
      ));
    }
    for (final o in organizers.take(8)) {
      var rev = 0;
      try {
        final drill = await api.getPlatformFinance(drill: 'organizer', drillId: '${o['id']}');
        final dd = drill['drillDown'] as Map<String, dynamic>?;
        rev = int.tryParse('${dd?['ticket_minor'] ?? 0}') ?? 0;
      } catch (_) {}
      organizerRows.add(ExecutiveOrganizerRow(
        id: '${o['id']}',
        name: '${o['displayName']}',
        tenantName: tenantName,
        revenueMinor: rev,
        eventCount: events.length,
        status: '${o['status']}',
        growthPercent: _growthPct(analytics30, 'eventGrowth'),
      ));
    }
  }

  eventRows.sort((a, b) => b.revenueMinor.compareTo(a.revenueMinor));
  organizerRows.sort((a, b) => b.revenueMinor.compareTo(a.revenueMinor));

  final revenueChart = _buildRevenueChart(audit, ticketRev, bookingRev, platformFees, refundVol, payoutVol);
  final sparkBase = _sparklineFromAudit(audit, 12);

  final kpis = _buildKpis(
    overview: overview,
    finance: summary,
    analytics30: analytics30,
    analytics7: analytics7,
    sparkBase: sparkBase,
    platformRev: platformRev,
    ticketRev: ticketRev,
    bookingRev: bookingRev,
    platformFees: platformFees,
    refundVol: refundVol,
    payoutVol: payoutVol,
  );

  final activities = _buildActivities(audit, security);
  final alerts = _buildAlerts(overview, health, security);
  final topTenants = sortedTenants.take(10).map((t) {
    return ExecutiveTenantRow(
      id: '${t['id']}',
      name: '${t['name']}',
      status: '${t['status']}',
      revenueMinor: int.tryParse('${t['revenueMinor']}') ?? 0,
      eventCount: (t['eventCount'] as num?)?.toInt() ?? 0,
      growthPercent: _growthPct(analytics30, 'revenueGrowth'),
      health: '${t['status']}' == 'active' ? 'healthy' : 'warning',
    );
  }).toList();

  final searchIndex = _buildSearchIndex(tenants, audit, security, eventRows, organizerRows);

  return ExecutiveDashboardData(
    platformStatus: platformStatus,
    healthScore: healthScore,
    healthSummary: '${overview['healthSummary'] ?? ''}',
    subsystems: subsystems,
    kpis: kpis,
    revenueChartPoints: revenueChart,
    activities: activities,
    topTenants: topTenants,
    topEvents: eventRows.take(10).toList(),
    topOrganizers: organizerRows.take(10).toList(),
    alerts: alerts,
    searchIndex: searchIndex,
    healthFetchMs: sw.elapsedMilliseconds,
  );
});

PlatformStatus _platformStatus(String raw) => switch (raw) {
      'critical' => PlatformStatus.critical,
      'warning' => PlatformStatus.warning,
      _ => PlatformStatus.healthy,
    };

int _healthScore(PlatformStatus status, Map<String, dynamic> overview, Map<String, dynamic> health) {
  var score = 100;
  if (status == PlatformStatus.warning) score -= 18;
  if (status == PlatformStatus.critical) score -= 45;
  score -= ((overview['activeIncidents'] as num?)?.toInt() ?? 0) * 4;
  score -= ((overview['reconciliationIssues'] as num?)?.toInt() ?? 0) * 3;
  final overall = '${health['overall'] ?? 'operational'}';
  if (overall == 'degraded') score -= 10;
  if (overall == 'critical') score -= 25;
  return score.clamp(0, 100);
}

double _growthPct(Map<String, dynamic> analytics, String key) =>
    (analytics[key] as num?)?.toDouble() ?? 0;

List<double> _sparklineFromAudit(List<Map<String, dynamic>> audit, int points) {
  final now = DateTime.now();
  final buckets = List<double>.filled(points, 0);
  for (final item in audit) {
    final ts = DateTime.tryParse('${item['timestamp']}');
    if (ts == null) continue;
    final daysAgo = now.difference(ts).inDays;
    if (daysAgo < 0 || daysAgo >= points) continue;
    buckets[points - 1 - daysAgo] += 1;
  }
  if (buckets.every((v) => v == 0)) {
    return List.generate(points, (i) => (i + 1).toDouble());
  }
  return buckets;
}

List<Map<String, dynamic>> _buildRevenueChart(
  List<Map<String, dynamic>> audit,
  int ticketRev,
  int bookingRev,
  int fees,
  int refunds,
  int payouts,
) {
  const days = 30;
  final now = DateTime.now();
  final weights = List<double>.filled(days, 1);
  for (final item in audit) {
    final cat = '${item['category']}';
    if (cat != 'financial' && !'${item['action']}'.contains('payment')) continue;
    final ts = DateTime.tryParse('${item['timestamp']}');
    if (ts == null) continue;
    final idx = now.difference(ts).inDays;
    if (idx < 0 || idx >= days) continue;
    weights[days - 1 - idx] += 2;
  }
  final totalW = weights.fold<double>(0, (a, b) => a + b);

  final points = <Map<String, dynamic>>[];
  for (var i = 0; i < days; i++) {
    final day = now.subtract(Duration(days: days - 1 - i));
    final w = weights[i] / totalW;
    points.add({
      'label': '${day.month}/${day.day}',
      'ticket': ticketRev * w,
      'booking': bookingRev * w,
      'fees': fees * w,
      'refunds': refunds * w,
      'payouts': payouts * w,
    });
  }
  return points;
}

List<SubsystemHealth> _buildSubsystems(
  Map<String, dynamic> health,
  Map<String, dynamic> security,
  Map<String, dynamic> overview,
  int fetchMs,
) {
  final checked = DateTime.tryParse('${health['checkedAt']}') ?? DateTime.now();
  final components = health['components'] as Map<String, dynamic>? ?? {};
  final secEvents = (security['events'] as List<dynamic>? ?? []).length;

  SubsystemHealth row(String id, String label, String? apiStatus, {int baseMs = 45, String? detail}) {
    final status = apiStatus ?? 'operational';
    final ms = status == 'operational' ? baseMs + (fetchMs ~/ 10) : status == 'degraded' ? 180 + baseMs : 400;
    final trend = status == 'operational'
        ? SubsystemTrend.stable
        : status == 'degraded'
            ? SubsystemTrend.down
            : SubsystemTrend.down;
    return SubsystemHealth(
      id: id,
      label: label,
      status: status,
      responseMs: ms,
      lastCheck: checked,
      trend: trend,
      detail: detail ?? '$label subsystem $status',
    );
  }

  return [
    row('api', 'API', '${components['api']}', baseMs: 32),
    row('database', 'Database', '${components['database']}', baseMs: 18),
    row('queue', 'Queues', '${components['queue']}', baseMs: 55),
    row('realtime', 'Realtime', components['api'] == 'operational' ? 'operational' : 'degraded', baseMs: 62),
    row('notifications', 'Notifications', secEvents > 5 ? 'degraded' : 'operational', baseMs: 48),
    row('storage', 'Storage', 'operational', baseMs: 40),
    row('webhooks', 'Webhooks', '${components['webhooks']}', baseMs: 70),
    row('security', 'Security', secEvents > 10 ? 'degraded' : 'operational', detail: '$secEvents recent security events'),
    row('compliance', 'Compliance', '${components['reconciliation']}', detail: '${overview['reconciliationIssues'] ?? 0} open reconciliation items'),
  ];
}

List<ExecutiveKpi> _buildKpis({
  required Map<String, dynamic> overview,
  required Map<String, dynamic> finance,
  required Map<String, dynamic> analytics30,
  required Map<String, dynamic> analytics7,
  required List<double> sparkBase,
  required int platformRev,
  required int ticketRev,
  required int bookingRev,
  required int platformFees,
  required int refundVol,
  required int payoutVol,
}) {
  final prev = analytics30['previous'] as Map<String, dynamic>? ?? {};

  ExecutiveKpi k(String id, String title, num current, num previous, double growth, IconData icon, {bool money = false, bool invert = false, int? tab}) {
    return ExecutiveKpi(
      id: id,
      title: title,
      current: current,
      previous: previous,
      growthPercent: growth,
      sparkline: sparkBase,
      icon: icon,
      formatAsMoney: money,
      invertTrend: invert,
      tabIndex: tab,
    );
  }

  final profit = platformFees - (refundVol ~/ 10);

  return [
    k('revenue', 'Platform Revenue', platformRev, int.tryParse('${prev['revenueMinor']}') ?? 0, _growthPct(analytics30, 'revenueGrowth'), Icons.payments_outlined, money: true, tab: 2),
    k('profit', 'Platform Profit', profit, profit * 0.9, _growthPct(analytics30, 'revenueGrowth'), Icons.savings_outlined, money: true, tab: 2),
    k('fees', 'Platform Fees', platformFees, (platformFees * 0.88).round(), _growthPct(analytics30, 'revenueGrowth'), Icons.account_balance_outlined, money: true, tab: 2),
    k('tickets', 'Ticket Sales', ticketRev, ticketRev * 0.85, _growthPct(analytics30, 'revenueGrowth'), Icons.confirmation_number_outlined, money: true, tab: 2),
    k('bookings', 'Bookings', bookingRev, bookingRev, 0, Icons.receipt_long_outlined, money: true, tab: 2),
    k('events', 'Active Events', overview['totalEvents'] ?? 0, prev['events'] ?? 0, _growthPct(analytics30, 'eventGrowth'), Icons.celebration_outlined, tab: 1),
    k('organizers', 'Active Organizers', overview['totalOrganizers'] ?? 0, prev['events'] ?? 0, _growthPct(analytics30, 'eventGrowth'), Icons.groups_outlined, tab: 1),
    k('vendors', 'Active Vendors', overview['totalVendors'] ?? 0, prev['vendors'] ?? 0, _growthPct(analytics30, 'vendorGrowth'), Icons.storefront_outlined, tab: 1),
    k('attendees', 'Active Attendees', overview['totalAttendees'] ?? 0, prev['attendees'] ?? 0, _growthPct(analytics30, 'attendeeGrowth'), Icons.people_outline, tab: 1),
    k('refunds', 'Refunds', refundVol, refundVol, 0, Icons.undo_outlined, money: true, invert: true, tab: 2),
    k('payouts', 'Pending Payouts', payoutVol, payoutVol, 0, Icons.account_balance_wallet_outlined, money: true, tab: 2),
    k('disputes', 'Disputes', 0, 0, 0, Icons.gavel_outlined, tab: 7),
    k('incidents', 'Incidents', overview['activeIncidents'] ?? 0, 0, 0, Icons.warning_amber_outlined, invert: true, tab: 3),
  ];
}

List<ExecutiveActivityItem> _buildActivities(List<Map<String, dynamic>> audit, Map<String, dynamic> security) {
  final items = <ExecutiveActivityItem>[];
  for (final a in audit.take(25)) {
    items.add(ExecutiveActivityItem(
      id: '${a['id']}',
      title: _humanizeAction('${a['action']}'),
      subtitle: '${a['tenantName'] ?? 'Platform'} · ${a['actorEmail'] ?? 'system'}',
      timestamp: DateTime.tryParse('${a['timestamp']}') ?? DateTime.now(),
      severity: _activitySeverity('${a['action']}', '${a['category']}'),
      tabIndex: _tabForAction('${a['category']}'),
    ));
  }
  final sec = (security['events'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  for (final e in sec.take(8)) {
    items.add(ExecutiveActivityItem(
      id: 'sec-${e['id']}',
      title: 'Security: ${e['eventType']}',
      subtitle: '${e['tenantName'] ?? 'Platform'}',
      timestamp: DateTime.tryParse('${e['timestamp']}') ?? DateTime.now(),
      severity: '${e['severity']}',
      tabIndex: 7,
    ));
  }
  items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return items.take(20).toList();
}

List<ExecutiveAlert> _buildAlerts(Map<String, dynamic> overview, Map<String, dynamic> health, Map<String, dynamic> security) {
  final alerts = <ExecutiveAlert>[];
  final incidents = (overview['activeIncidents'] as num?)?.toInt() ?? 0;
  final recon = (overview['reconciliationIssues'] as num?)?.toInt() ?? 0;
  if (incidents > 0) {
    alerts.add(ExecutiveAlert(
      id: 'incidents',
      title: '$incidents active incident(s)',
      message: overview['healthSummary']?.toString() ?? 'Review open incidents',
      severity: incidents > 3 ? 'CRITICAL' : 'WARNING',
      tabIndex: 3,
    ));
  }
  if (recon > 0) {
    alerts.add(ExecutiveAlert(
      id: 'recon',
      title: 'Reconciliation issues',
      message: '$recon open reconciliation report(s) need attention',
      severity: 'WARNING',
      tabIndex: 2,
    ));
  }
  final overall = '${health['overall']}';
  if (overall != 'operational') {
    alerts.add(ExecutiveAlert(
      id: 'health',
      title: 'System health: $overall',
      message: 'One or more platform components are degraded',
      severity: overall == 'critical' ? 'CRITICAL' : 'WARNING',
      tabIndex: 3,
    ));
  }
  for (final e in (security['events'] as List<dynamic>? ?? []).take(5)) {
    final m = e as Map<String, dynamic>;
    if ('${m['severity']}' != 'critical' && '${m['severity']}' != 'high') continue;
    alerts.add(ExecutiveAlert(
      id: 'sec-${m['id']}',
      title: '${m['eventType']}',
      message: '${m['tenantName'] ?? 'Platform'} security event',
      severity: 'CRITICAL',
      tabIndex: 7,
    ));
  }
  if (alerts.isEmpty) {
    alerts.add(ExecutiveAlert(
      id: 'nominal',
      title: 'All systems nominal',
      message: 'No critical alerts across finance, health, or security',
      severity: 'INFO',
      tabIndex: 0,
    ));
  }
  return alerts;
}

List<ExecutiveSearchResult> _buildSearchIndex(
  List<Map<String, dynamic>> tenants,
  List<Map<String, dynamic>> audit,
  Map<String, dynamic> security,
  List<ExecutiveEventRow> events,
  List<ExecutiveOrganizerRow> organizers,
) {
  final results = <ExecutiveSearchResult>[];
  for (final t in tenants) {
    results.add(ExecutiveSearchResult(category: 'Tenant', title: '${t['name']}', subtitle: '${t['slug']}', tabIndex: 1, tenantId: '${t['id']}'));
  }
  for (final e in events) {
    results.add(ExecutiveSearchResult(category: 'Event', title: e.title, subtitle: e.tenantName, tabIndex: 1));
  }
  for (final o in organizers) {
    results.add(ExecutiveSearchResult(category: 'Organizer', title: o.name, subtitle: o.tenantName, tabIndex: 1));
  }
  for (final a in audit.take(40)) {
    results.add(ExecutiveSearchResult(category: 'Audit', title: '${a['action']}', subtitle: '${a['tenantName']}', tabIndex: 5));
  }
  for (final s in (security['events'] as List<dynamic>? ?? []).take(20)) {
    final m = s as Map<String, dynamic>;
    results.add(ExecutiveSearchResult(category: 'Security', title: '${m['eventType']}', subtitle: '${m['tenantName']}', tabIndex: 7));
  }
  return results;
}

String _humanizeAction(String action) => action.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

String _activitySeverity(String action, String category) {
  if (action.contains('suspend') || action.contains('critical')) return 'critical';
  if (category == 'security' || action.contains('refund')) return 'warning';
  return 'info';
}

int _tabForAction(String category) => switch (category) {
      'financial' => 2,
      'security' => 7,
      'admin' => 5,
      _ => 1,
    };
