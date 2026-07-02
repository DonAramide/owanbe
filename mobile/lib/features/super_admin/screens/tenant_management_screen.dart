import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../portals/customer/workspace/widgets/event_empty_state.dart';
import '../super_admin_providers.dart';

class TenantManagementScreen extends ConsumerStatefulWidget {
  const TenantManagementScreen({super.key});

  @override
  ConsumerState<TenantManagementScreen> createState() => _TenantManagementScreenState();
}

class _TenantManagementScreenState extends ConsumerState<TenantManagementScreen> {
  String _sortColumn = 'name';
  bool _sortAscending = true;
  String _planFilter = 'all';
  String _statusFilter = 'all';
  final List<String> _selectedTenantIds = [];

  void _toggleSelectAll(List<Map<String, dynamic>> items) {
    setState(() {
      if (_selectedTenantIds.length == items.length) {
        _selectedTenantIds.clear();
      } else {
        _selectedTenantIds.clear();
        _selectedTenantIds.addAll(items.map((i) => i['id'] as String));
      }
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedTenantIds.contains(id)) {
        _selectedTenantIds.remove(id);
      } else {
        _selectedTenantIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(superAdminTenantSearchProvider);
    final list = ref.watch(superAdminTenantsProvider(query));

    return EosPageScaffold(
      title: 'Tenant Intelligence Center',
      subtitle: 'Analyze, audit, and configure Owambe tenant organizations',
      floatingHeader: Row(
        children: [
          Expanded(
            child: EosSearchField(
              hint: 'Search tenants by name or slug…',
              onChanged: (v) => ref.read(superAdminTenantSearchProvider.notifier).state = v,
            ),
          ),
          SizedBox(width: context.eos.spacing.md),
          DropdownButton<String>(
            value: _statusFilter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Statuses')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
          ),
          SizedBox(width: context.eos.spacing.md),
          FilledButton.icon(
            onPressed: () => _createTenant(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Tenant'),
          ),
        ],
      ),
      body: list.when(
        data: (items) {
          // Client-side filtering
          var filtered = items.where((t) {
            if (_statusFilter != 'all' && t['status'] != _statusFilter) return false;
            return true;
          }).toList();

          // Client-side sorting
          filtered.sort((a, b) {
            int comp = 0;
            if (_sortColumn == 'name') {
              comp = (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
            } else if (_sortColumn == 'revenue') {
              final aRev = int.tryParse((a['revenueMinor'] ?? '0').toString()) ?? 0;
              final bRev = int.tryParse((b['revenueMinor'] ?? '0').toString()) ?? 0;
              comp = aRev.compareTo(bRev);
            } else if (_sortColumn == 'events') {
              comp = (a['eventCount'] as num? ?? 0).compareTo(b['eventCount'] as num? ?? 0);
            } else if (_sortColumn == 'organizers') {
              comp = (a['organizerCount'] as num? ?? 0).compareTo(b['organizerCount'] as num? ?? 0);
            }
            return _sortAscending ? comp : -comp;
          });

          if (filtered.isEmpty) {
            return const Center(
              child: EventEmptyState(
                title: 'No Tenants Found',
                description: 'Try adjusting your search query or filter options.',
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedTenantIds.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.md),
                  child: Card(
                    color: context.eosColors.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Text('${_selectedTenantIds.length} tenants selected',
                              style: TextStyle(color: context.eosColors.onSecondaryContainer, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Mock Exporting Selected Tenants to CSV...')),
                              );
                            },
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Export Selected'),
                          ),
                          const SizedBox(width: 12),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _selectedTenantIds.clear());
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear Selection'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: EosDataTable(
                      columns: [
                        DataColumn(
                          label: Row(
                            children: [
                              Checkbox(
                                value: _selectedTenantIds.length == filtered.length,
                                onChanged: (_) => _toggleSelectAll(filtered),
                              ),
                              const Text('Tenant Name'),
                            ],
                          ),
                          onSort: (colIndex, asc) {
                            setState(() {
                              _sortColumn = 'name';
                              _sortAscending = asc;
                            });
                          },
                        ),
                        const DataColumn(label: Text('Plan')),
                        const DataColumn(label: Text('Status')),
                        const DataColumn(label: Text('Health Score')),
                        DataColumn(
                          label: const Text('Total Revenue'),
                          onSort: (colIndex, asc) {
                            setState(() {
                              _sortColumn = 'revenue';
                              _sortAscending = asc;
                            });
                          },
                        ),
                        DataColumn(
                          label: const Text('Events'),
                          onSort: (colIndex, asc) {
                            setState(() {
                              _sortColumn = 'events';
                              _sortAscending = asc;
                            });
                          },
                        ),
                        DataColumn(
                          label: const Text('Organizers'),
                          onSort: (colIndex, asc) {
                            setState(() {
                              _sortColumn = 'organizers';
                              _sortAscending = asc;
                            });
                          },
                        ),
                        const DataColumn(label: Text('Region')),
                      ],
                      rows: filtered.map((t) {
                        final id = t['id'] as String;
                        final name = t['name'] as String? ?? '';
                        final slug = t['slug'] as String? ?? '';
                        final isSuspended = t['status'] == 'suspended';
                        final revenue = int.tryParse((t['revenueMinor'] ?? '0').toString()) ?? 0;

                        // Mock health score computation for dashboard
                        int healthScore = 100 - ((t['eventCount'] as int? ?? 0) > 5 ? 5 : 0);
                        if (isSuspended) healthScore = 0;

                        return DataRow(
                          selected: _selectedTenantIds.contains(id),
                          cells: [
                            DataCell(
                              InkWell(
                                onTap: () => context.go('/super-admin/tenants/$id'),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _selectedTenantIds.contains(id),
                                      onChanged: (_) => _toggleSelect(id),
                                    ),
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: context.eosColors.primaryContainer,
                                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                          style: TextStyle(fontSize: 11, color: context.eosColors.onPrimaryContainer)),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('/$slug', style: context.eosText.bodySmall),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const DataCell(Text('Enterprise')),
                            DataCell(EosFinanceChip(label: t['status'] as String? ?? '', compact: true)),
                            DataCell(
                              Text(
                                '$healthScore%',
                                style: TextStyle(
                                  color: healthScore > 75
                                      ? Colors.green
                                      : (healthScore > 30 ? Colors.orange : Colors.red),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(Text(formatRevenue(revenue))),
                            DataCell(Text('${t['eventCount']}')),
                            DataCell(Text('${t['organizerCount']}')),
                            const DataCell(Text('NG-LAGOS')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EosAttentionBanner(
          headline: 'Error listing tenants',
          message: e.toString(),
          severity: 'CRITICAL',
        ),
      ),
    );
  }

  Future<void> _createTenant(BuildContext context) async {
    final slugCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create tenant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: slugCtrl, decoration: const InputDecoration(labelText: 'Slug (unique subdomain)')),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tenant Organization Name')),
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
