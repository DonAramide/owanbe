import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../super_admin_providers.dart';

class TenantManagementScreen extends ConsumerWidget {
  const TenantManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(superAdminTenantSearchProvider);
    final list = ref.watch(superAdminTenantsProvider(query));
    final selected = ref.watch(selectedSuperAdminTenantIdProvider);
    final detail = selected == null ? null : ref.watch(superAdminTenantDetailProvider(selected));

    return EosPageScaffold(
      title: 'Tenant management',
      subtitle: 'Create, suspend, and inspect tenant health',
      floatingHeader: Row(
        children: [
          Expanded(child: EosSearchField(hint: 'Search tenants…', onChanged: (v) => ref.read(superAdminTenantSearchProvider.notifier).state = v)),
          SizedBox(width: context.eos.spacing.sm),
          FilledButton.icon(
            onPressed: () => _createTenant(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Create'),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: list.when(
              data: (items) => EosDataTable(
                columns: const [
                  DataColumn(label: Text('Tenant')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Events')),
                  DataColumn(label: Text('Revenue')),
                ],
                rows: items.map((t) {
                  final id = t['id'] as String;
                  return DataRow(
                    selected: selected == id,
                    onSelectChanged: (_) => ref.read(selectedSuperAdminTenantIdProvider.notifier).state = id,
                    cells: [
                      DataCell(Text(t['name'] as String? ?? '')),
                      DataCell(EosFinanceChip(label: t['status'] as String? ?? '', compact: true)),
                      DataCell(Text('${t['eventCount']}')),
                      DataCell(Text(formatRevenue(int.tryParse((t['revenueMinor'] ?? '0').toString()) ?? 0))),
                    ],
                  );
                }).toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
            ),
          ),
          if (selected != null) ...[
            SizedBox(width: context.eos.spacing.lg),
            Expanded(child: detail == null ? const SizedBox.shrink() : detail.when(
              data: (d) => _TenantDetail(d: d, tenantId: selected, onAction: () => bumpSuperAdminRevision(ref)),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
            )),
          ],
        ],
      ),
    );
  }

  Future<void> _createTenant(BuildContext context, WidgetRef ref) async {
    final slugCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create tenant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: slugCtrl, decoration: const InputDecoration(labelText: 'Slug')),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true && slugCtrl.text.isNotEmpty && nameCtrl.text.isNotEmpty) {
      await ref.read(superAdminApiProvider).createTenant(slug: slugCtrl.text, name: nameCtrl.text);
      bumpSuperAdminRevision(ref);
    }
  }
}

class _TenantDetail extends ConsumerWidget {
  const _TenantDetail({required this.d, required this.tenantId, required this.onAction});
  final Map<String, dynamic> d;
  final String tenantId;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = d['profile'] as Map<String, dynamic>? ?? {};
    final finance = d['finance'] as Map<String, dynamic>? ?? {};
    final health = d['health'] as Map<String, dynamic>? ?? {};
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(profile['name'] as String? ?? '', style: context.eosText.titleMedium),
          Text('${profile['slug']} · ${profile['status']}', style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.sm),
          EosAttentionBanner(headline: 'Health: ${health['level']}', message: '${health['summary']}', severity: health['level'] == 'critical' ? 'CRITICAL' : 'WARNING'),
          Text('Revenue: ${formatRevenue(int.tryParse((finance['totalRevenueMinor'] ?? '0').toString()) ?? 0)}', style: context.eosText.bodyMedium),
          Text('Events: ${(d['events'] as List?)?.length ?? 0}', style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.md),
          Wrap(
            spacing: context.eos.spacing.sm,
            children: [
              FilledButton(
                onPressed: () async {
                  await ref.read(superAdminApiProvider).suspendTenant(tenantId);
                  onAction();
                },
                child: const Text('Suspend'),
              ),
              OutlinedButton(
                onPressed: () async {
                  await ref.read(superAdminApiProvider).reactivateTenant(tenantId);
                  onAction();
                },
                child: const Text('Reactivate'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
