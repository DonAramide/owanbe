import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../super_admin_providers.dart';

class SecurityCenterScreen extends ConsumerWidget {
  const SecurityCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final security = ref.watch(superAdminSecurityProvider);
    return EosPageScaffold(
      title: 'Security center',
      subtitle: 'Failed logins, escalations, suspicious activity, finance exceptions',
      body: security.when(
        data: (d) {
          final summary = d['summary'] as Map<String, dynamic>? ?? {};
          final events = (d['events'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: context.eos.spacing.md,
                runSpacing: context.eos.spacing.md,
                children: [
                  _kpi(context, 'Failed logins', '${summary['failedLogins']}', Icons.lock_outline),
                  _kpi(context, 'Permission escalations', '${summary['permissionEscalations']}', Icons.admin_panel_settings_outlined),
                  _kpi(context, 'Suspicious activity', '${summary['suspiciousActivity']}', Icons.shield_outlined),
                  _kpi(context, 'Finance exceptions', '${summary['financeExceptions']}', Icons.warning_amber_outlined),
                ],
              ),
              SizedBox(height: context.eos.spacing.xl),
              EosSection(
                title: 'Recent security events',
                child: events.isEmpty
                    ? EosSurfaceCard(child: Text('No security events', style: context.eosText.bodyMedium))
                    : Column(
                        children: events.take(20).map((e) => Padding(
                          padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                          child: EosAttentionBanner(
                            headline: e['eventType'] as String? ?? '',
                            message: '${e['tenantName'] ?? 'platform'} · ${e['severity']}',
                            severity: e['severity'] == 'critical' ? 'CRITICAL' : 'WARNING',
                          ),
                        )).toList(),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }

  Widget _kpi(BuildContext context, String title, String value, IconData icon) {
    return SizedBox(width: 220, child: EosKpiCard(title: title, value: value, icon: icon));
  }
}
