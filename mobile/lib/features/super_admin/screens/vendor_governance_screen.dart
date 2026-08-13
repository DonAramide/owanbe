import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/control_plane_api.dart';
import '../../../eos/eos.dart';

/// Phase 28 — Nest-backed Vendor Governance (canonical vendors.status).
class VendorGovernanceScreen extends ConsumerStatefulWidget {
  const VendorGovernanceScreen({super.key});

  @override
  ConsumerState<VendorGovernanceScreen> createState() => _VendorGovernanceScreenState();
}

class _VendorGovernanceScreenState extends ConsumerState<VendorGovernanceScreen> {
  String _query = '';
  String _status = 'all';

  Future<void> _refresh() async {
    ref.invalidate(controlPlaneVendorsProvider(_query));
    ref.invalidate(controlPlaneDashboardProvider);
    ref.invalidate(controlPlaneActivityProvider);
  }

  Future<void> _snack(String msg, {bool error = false}) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade800 : null),
    );
  }

  Future<void> _transition(Map<String, dynamic> v, String action) async {
    String? reason;
    if (action == 'suspend' || action == 'reject') {
      reason = await _prompt('Reason for $action');
      if (reason == null) return;
    }
    try {
      await ref.read(controlPlaneApiProvider).transitionVendor(
            tenantId: v['tenantId'].toString(),
            vendorId: v['id'].toString(),
            action: action,
            reason: reason,
          );
      await _refresh();
      await _snack('Vendor $action completed');
    } catch (e) {
      await _snack(e.toString(), error: true);
    }
  }

  Future<String?> _prompt(String title) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(controlPlaneVendorsProvider(_query));
    final dash = ref.watch(controlPlaneDashboardProvider);
    final activity = ref.watch(controlPlaneActivityProvider);

    return EosPageScaffold(
      title: 'Vendor Governance',
      subtitle: 'Canonical vendor standing from Nest — not mock engines',
      floatingHeader: Row(
        children: [
          Expanded(
            child: EosSearchField(
              hint: 'Search vendors…',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _status,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All statuses')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'pending_review', child: Text('Pending')),
              DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
              DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'all'),
          ),
          const SizedBox(width: 12),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        children: [
          dash.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Dashboard unavailable: $e'),
            data: (d) {
              final by = d['vendorsByStatus'] as Map<String, dynamic>? ?? {};
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final e in by.entries)
                    Chip(label: Text('${e.key}: ${e.value}')),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Vendors', style: context.eosText.titleMedium),
          const SizedBox(height: 8),
          vendors.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EosSurfaceCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Vendor governance unavailable: $e'),
              ),
            ),
            data: (items) {
              final filtered = _status == 'all'
                  ? items
                  : items.where((v) => v['status'] == _status).toList();
              if (filtered.isEmpty) {
                return const EosSurfaceCard(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No vendors match this filter.'),
                  ),
                );
              }
              return EosSurfaceCard(
                elevated: true,
                child: Column(
                  children: [
                    for (final v in filtered)
                      ListTile(
                        title: Text('${v['businessName'] ?? ''}'),
                        subtitle: Text(
                          '${v['tenantSlug'] ?? ''} · ${v['status']} · ${v['complianceState'] ?? ''}'
                          '${v['suspendedReason'] != null ? '\n${v['suspendedReason']}' : ''}',
                        ),
                        isThreeLine: v['suspendedReason'] != null,
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            if (v['status'] == 'pending_review' || v['status'] == 'draft')
                              TextButton(
                                onPressed: () => _transition(v, 'approve'),
                                child: const Text('Approve'),
                              ),
                            if (v['status'] != 'suspended')
                              TextButton(
                                onPressed: () => _transition(v, 'suspend'),
                                child: const Text('Suspend'),
                              ),
                            if (v['status'] == 'suspended')
                              TextButton(
                                onPressed: () => _transition(v, 'reactivate'),
                                child: const Text('Reactivate'),
                              ),
                            if (v['status'] != 'rejected')
                              TextButton(
                                onPressed: () => _transition(v, 'reject'),
                                child: const Text('Reject'),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Governance activity', style: context.eosText.titleMedium),
          const SizedBox(height: 8),
          activity.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (items) {
              final vendorActs = items
                  .where((a) => (a['action']?.toString() ?? '').contains('vendor'))
                  .take(20)
                  .toList();
              if (vendorActs.isEmpty) {
                return const Text('No control_plane.vendor_* audit events yet');
              }
              return EosSurfaceCard(
                child: Column(
                  children: [
                    for (final a in vendorActs)
                      ListTile(
                        dense: true,
                        title: Text('${a['action']}'),
                        subtitle: Text('${a['resourceId']} · ${a['createdAt'] ?? ''}'),
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
