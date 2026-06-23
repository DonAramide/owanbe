import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../platform/admin_platform_providers.dart';
import '../widgets/admin_async_body.dart';
import '../widgets/admin_error_states.dart';
import '../widgets/admin_page_layout.dart';

class AdminComplianceScreen extends ConsumerWidget {
  const AdminComplianceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminPlatformRevisionProvider);
    final dash = ref.watch(platformDashboardProvider);
    final supervision = ref.watch(adminFinanceSupervisionProvider);
    final vendors = ref.watch(adminVendorsProvider(''));

    return AdminPageLayout(
      title: 'Compliance',
      subtitle: 'Risk posture, disputes, chargebacks, and vendor verification',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminAsyncBody(
            value: dash,
            onRetry: () => ref.invalidate(platformDashboardProvider),
            builder: (d) {
              final health = (d['platformHealth'] ?? 'healthy').toString();
              final openIncidents = (d['openIncidents'] as num? ?? 0).toInt();
              return AdminKpiGrid(
                children: [
                  EosKpiCard(title: 'Risk summary', value: health.toUpperCase(), icon: Icons.shield_outlined, attention: health == 'critical' ? EosKpiAttention.critical : EosKpiAttention.none),
                  EosKpiCard(title: 'Open disputes', value: '$openIncidents', icon: Icons.gavel_outlined, attention: openIncidents > 0 ? EosKpiAttention.warning : EosKpiAttention.none),
                ],
              );
            },
          ),
          SizedBox(height: context.eos.spacing.xl),
          AdminSectionHeader(title: 'Dispute & chargeback statistics'),
          AdminAsyncBody(
            value: supervision,
            onRetry: () => ref.invalidate(adminFinanceSupervisionProvider),
            builder: (d) {
              final ticket = d['ticketRail'] as Map<String, dynamic>? ?? {};
              final recon = d['reconciliation'] as Map<String, dynamic>? ?? {};
              return AdminKpiGrid(
                children: [
                  EosKpiCard(title: 'Open refunds', value: '${ticket['openRefunds'] ?? 0}', icon: Icons.receipt_long_outlined),
                  EosKpiCard(title: 'Reconciliation issues', value: '${recon['openIssues'] ?? 0}', icon: Icons.rule_folder_outlined),
                ],
              );
            },
          ),
          SizedBox(height: context.eos.spacing.xl),
          AdminSectionHeader(title: 'Vendor verification queue', subtitle: 'Pending and suspended vendors'),
          AdminAsyncBody(
            value: vendors,
            onRetry: () => ref.invalidate(adminVendorsProvider('')),
            isEmpty: (items) => items.where((v) => (v['status'] ?? '') != 'active').isEmpty,
            empty: const EmptyStateCard(title: 'Verification queue is clear', message: 'All vendors are verified or no pending reviews.'),
            builder: (items) {
              final queue = items.where((v) {
                final s = (v['status'] ?? '').toString().toLowerCase();
                return s == 'pending' || s == 'suspended' || s == 'invited';
              }).take(12).toList();
              if (queue.isEmpty) {
                return const EmptyStateCard(title: 'Verification queue is clear');
              }
              return EosSurfaceCard(
                elevated: true,
                child: Column(
                  children: [
                    for (final v in queue)
                      ListTile(
                        leading: Icon(Icons.verified_user_outlined, color: context.eosColors.primary),
                        title: Text(v['businessName'] as String? ?? ''),
                        subtitle: Text('${v['category'] ?? ''} · ${v['status'] ?? ''}'),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
