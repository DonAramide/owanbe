import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import 'admin_platform_providers.dart';

class VendorOversightScreen extends ConsumerWidget {
  const VendorOversightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminPlatformRevisionProvider);
    final query = ref.watch(adminVendorSearchProvider);
    final list = ref.watch(adminVendorsProvider(query));
    final selected = ref.watch(selectedAdminVendorIdProvider);
    final detail = selected == null ? null : ref.watch(adminVendorDetailProvider(selected));

    return EosPageScaffold(
      title: 'Vendor oversight',
      subtitle: 'Approve, suspend, and review vendor participation',
      floatingHeader: EosSearchField(
        hint: 'Search vendors…',
        onChanged: (v) => ref.read(adminVendorSearchProvider.notifier).state = v,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: list.when(
              data: (items) => EosDataTable(
                columns: const [
                  DataColumn(label: Text('Vendor')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Events')),
                  DataColumn(label: Text('Revenue')),
                ],
                rows: items.map((v) {
                  final id = v['id'] as String;
                  return DataRow(
                    selected: selected == id,
                    onSelectChanged: (_) => ref.read(selectedAdminVendorIdProvider.notifier).state = id,
                    cells: [
                      DataCell(Text(v['businessName'] as String? ?? '')),
                      DataCell(EosFinanceChip(label: v['status'] as String? ?? '', compact: true)),
                      DataCell(Text('${v['participationCount']}')),
                      DataCell(Text(formatRevenue(int.tryParse((v['revenueMinor'] ?? '0').toString()) ?? 0))),
                    ],
                  );
                }).toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
          ),
          SizedBox(width: context.eos.spacing.lg),
          Expanded(
            child: selected == null
                ? EosSurfaceCard(child: Text('Select a vendor', style: context.eosText.bodyMedium))
                : detail!.when(
                    data: (d) => _VendorDetailPanel(vendorId: selected, data: d),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('$e'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _VendorDetailPanel extends ConsumerWidget {
  const _VendorDetailPanel({required this.vendorId, required this.data});
  final String vendorId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = data['profile'] as Map<String, dynamic>? ?? {};
    final parts = (data['participations'] as List<dynamic>? ?? []).length;
    final wallet = data['wallet'] as Map<String, dynamic>? ?? {};
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(profile['businessName'] as String? ?? '', style: context.eosText.titleLarge),
          EosFinanceChip(label: profile['status'] as String? ?? '', compact: true),
          SizedBox(height: context.eos.spacing.sm),
          Text('Participations: $parts', style: context.eosText.bodySmall),
          Text('Wallet available: ${formatRevenue(int.tryParse((wallet['availableMinor'] ?? '0').toString()) ?? 0)}', style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.md),
          Wrap(
            spacing: context.eos.spacing.xs,
            children: [
              if (profile['status'] != 'active')
                FilledButton(
                  onPressed: () async {
                    await ref.read(adminPlatformApiProvider).approveVendor(vendorId);
                    bumpAdminPlatformRevision(ref);
                  },
                  child: const Text('Approve'),
                ),
              if (profile['status'] == 'active')
                FilledButton(
                  onPressed: () async {
                    await ref.read(adminPlatformApiProvider).suspendVendor(vendorId);
                    bumpAdminPlatformRevision(ref);
                  },
                  child: const Text('Suspend'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
