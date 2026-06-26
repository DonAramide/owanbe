import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../widgets/admin_async_body.dart';
import '../widgets/admin_page_layout.dart';
import 'admin_platform_providers.dart';

/// Phase 41 — internal launch operations dashboard (admin only, not customer-facing).
class LaunchOpsDashboardScreen extends ConsumerWidget {
  const LaunchOpsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminPlatformRevisionProvider);
    final dash = ref.watch(launchOpsDashboardProvider);

    return AdminPageLayout(
      title: 'Launch operations',
      subtitle: 'Platform health, metrics, and beta readiness (internal)',
      body: AdminAsyncBody(
        value: dash,
        onRetry: () => ref.invalidate(launchOpsDashboardProvider),
        skeletonCount: 8,
        builder: (d) {
          final health = (d['platformHealth'] ?? 'healthy').toString();
          final subsystems = (d['subsystems'] as Map<String, dynamic>?) ?? {};
          final today = (d['todayMetrics'] as Map<String, dynamic>?) ?? {};
          final prom = (d['prometheus'] as Map<String, dynamic>?) ?? {};
          final alerts = (d['alerts'] as Map<String, dynamic>?) ?? {};
          final revenue = (d['revenue'] as Map<String, dynamic>?) ?? {};

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EosAttentionBanner(
                headline: 'Platform · ${health.toUpperCase()}',
                message: (d['healthSummary'] ?? 'Monitoring active').toString(),
                severity: health == 'critical' ? 'CRITICAL' : health == 'warning' ? 'WARNING' : 'INFO',
              ),
              SizedBox(height: context.eos.spacing.lg),
              AdminSectionHeader(title: 'Platform health', subtitle: 'Subsystem status'),
              _statusGrid(context, subsystems),
              SizedBox(height: context.eos.spacing.xl),
              AdminSectionHeader(title: "Today's metrics", subtitle: 'Since midnight UTC'),
              AdminKpiGrid(
                children: [
                  _kpi(context, 'Events today', '${today['eventsToday'] ?? 0}', Icons.celebration_outlined),
                  _kpi(context, 'Invitations sent', '${today['invitationsSentToday'] ?? 0}', Icons.mail_outline),
                  _kpi(context, 'RSVP rate', '${today['rsvpRate'] ?? 0}%', Icons.how_to_reg_outlined),
                  _kpi(context, 'Ticket revenue', formatRevenue((today['ticketRevenueMinor'] as num?)?.toInt() ?? 0), Icons.confirmation_number_outlined),
                  _kpi(context, 'Rental revenue', formatRevenue((today['rentalRevenueMinor'] as num?)?.toInt() ?? 0), Icons.chair_outlined),
                  _kpi(context, 'Aso-Ebi revenue', formatRevenue((today['asoEbiRevenueMinor'] as num?)?.toInt() ?? 0), Icons.checkroom_outlined),
                ],
              ),
              SizedBox(height: context.eos.spacing.xl),
              AdminSectionHeader(title: 'Prometheus counters', subtitle: 'In-process metrics snapshot'),
              AdminKpiGrid(
                children: [
                  _kpi(context, 'API errors', '${prom['apiErrors'] ?? 0}', Icons.error_outline, warn: ((prom['apiErrors'] as num?) ?? 0) > 0),
                  _kpi(context, 'Payments captured', '${prom['paymentsCaptured'] ?? 0}', Icons.payments_outlined),
                  _kpi(context, 'Invitations sent', '${prom['invitationsSent'] ?? 0}', Icons.send_outlined),
                  _kpi(context, 'Invitations failed', '${prom['invitationsFailed'] ?? 0}', Icons.mark_email_unread_outlined, warn: ((prom['invitationsFailed'] as num?) ?? 0) > 0),
                  _kpi(context, 'Notifications failed', '${prom['notificationsFailed'] ?? 0}', Icons.notifications_off_outlined),
                  _kpi(context, 'Storage uploads', '${prom['storageUploads'] ?? 0}', Icons.cloud_upload_outlined),
                ],
              ),
              SizedBox(height: context.eos.spacing.xl),
              AdminSectionHeader(title: 'System alerts', subtitle: 'Requires attention'),
              AdminKpiGrid(
                children: [
                  _kpi(context, 'Failed payments', '${alerts['failedPayments'] ?? 0}', Icons.money_off_outlined, warn: true),
                  _kpi(context, 'Open disputes', '${alerts['openDisputes'] ?? 0}', Icons.gavel_outlined),
                  _kpi(context, 'Pending vendors', '${alerts['pendingVendorApprovals'] ?? 0}', Icons.pending_actions_outlined),
                  _kpi(context, 'Recon issues', '${alerts['reconciliationIssues'] ?? 0}', Icons.sync_problem_outlined),
                  _kpi(context, 'Total revenue today', formatRevenue((revenue['totalMinor'] as num?)?.toInt() ?? 0), Icons.account_balance_wallet_outlined),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusGrid(BuildContext context, Map<String, dynamic> subsystems) {
    final entries = subsystems.entries.toList();
    return Wrap(
      spacing: context.eos.spacing.sm,
      runSpacing: context.eos.spacing.sm,
      children: entries.map((e) {
        final ok = e.value == 'ok' || e.value == 'configured' || e.value == 'production';
        return Chip(
          avatar: Icon(ok ? Icons.check_circle : Icons.warning_amber, size: 18, color: ok ? Colors.green : Colors.orange),
          label: Text('${e.key}: ${e.value}'),
        );
      }).toList(),
    );
  }

  Widget _kpi(BuildContext context, String label, String value, IconData icon, {bool warn = false}) {
    return EosKpiCard(
      title: label,
      value: value,
      icon: icon,
      attention: warn ? EosKpiAttention.warning : EosKpiAttention.none,
    );
  }
}
