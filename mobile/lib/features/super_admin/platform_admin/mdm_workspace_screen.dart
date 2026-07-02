import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/master_data_engine.dart';
import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';

class MdmWorkspaceScreen extends ConsumerStatefulWidget {
  const MdmWorkspaceScreen({super.key});

  @override
  ConsumerState<MdmWorkspaceScreen> createState() => _MdmWorkspaceScreenState();
}

class _MdmWorkspaceScreenState extends ConsumerState<MdmWorkspaceScreen> with SingleTickerProviderStateMixin {
  String _selectedDomainKey = 'marketplace';
  String? _selectedParentId;
  String _searchQuery = '';
  MdmEntity? _selectedEntity;

  // Search/Filters Controller
  final _searchController = TextEditingController();

  // Import simulation controllers
  final _importController = TextEditingController();

  late TabController _tabs360Controller;

  @override
  void initState() {
    super.initState();
    _tabs360Controller = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _importController.dispose();
    _tabs360Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(masterDataEngineProvider);
    final currentDomain = engine.domains.firstWhere(
      (d) => d.key == _selectedDomainKey,
      orElse: () => engine.domains.first,
    );

    // Resolve top-level or hierarchical list
    final list = engine.resolve(
      domainKey: _selectedDomainKey,
      parentId: _selectedParentId,
      searchQuery: _searchQuery,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Executive Header Metrics
        _buildExecutiveHeader(engine),
        const SizedBox(height: 24),

        // Extensible Domains Horizontal Strip
        _buildDomainsStrip(engine),
        const SizedBox(height: 16),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Dictionary Entity List
            Expanded(
              flex: 2,
              child: EosSurfaceCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${currentDomain.label} Dictionaries', style: context.eosText.titleMedium),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () => _showImportWizard(context, engine),
                                icon: const Icon(Icons.file_upload, size: 16),
                                label: const Text('Sync/Import'),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.blue),
                                onPressed: () => _showUpsertDialog(context, engine, null),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search dictionaries...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedParentId != null)
                        TextButton.icon(
                          onPressed: () => setState(() => _selectedParentId = null),
                          icon: const Icon(Icons.arrow_back, size: 14),
                          label: const Text('Back to parent level'),
                        ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: list.length,
                        itemBuilder: (context, idx) {
                          final ent = list[idx];
                          final active = _selectedEntity?.id == ent.id;
                          return ListTile(
                            selected: active,
                            title: Text(ent.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Slug: ${ent.slug} | Order: ${ent.sortOrder}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                EosFinanceChip(
                                  label: ent.status.toUpperCase(),
                                  compact: true,
                                ),
                                const Icon(Icons.chevron_right, size: 16),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                _selectedEntity = ent;
                              });
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),

            // Right Column: Entity 360 Workspace
            Expanded(
              flex: 3,
              child: _selectedEntity == null
                  ? EosSurfaceCard(
                      child: Container(
                        height: 400,
                        alignment: Alignment.center,
                        child: const Text('Select a dictionary item to explore Workspace 360'),
                      ),
                    )
                  : _buildWorkspace360(engine, _selectedEntity!),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExecutiveHeader(MasterDataEngine engine) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enterprise Master Data Control Platform', style: context.eosText.headlineMedium),
                    const SizedBox(height: 4),
                    Text('System-wide single source of truth (SSOT) configuration cache and dependencies dashboard', style: context.eosText.bodySmall),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showRegisterDomainDialog(context, engine),
                  icon: const Icon(Icons.domain_add),
                  label: const Text('Register Extension Domain'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildHeaderStat('Total Active Domains', '${engine.domains.length}', Icons.category, Colors.purple),
                _buildHeaderStat('Active Lookup Items', '${engine.entities.length}', Icons.dns, Colors.blue),
                _buildHeaderStat('Recent Changes', '${engine.auditLogs.length}', Icons.history, Colors.orange),
                _buildHeaderStat('Cache State', 'Optimal (99.8%)', Icons.bolt, Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: context.eosColors.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: context.eosText.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(label, style: context.eosText.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDomainsStrip(MasterDataEngine engine) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: engine.domains.map((dom) {
          final isSelected = _selectedDomainKey == dom.key;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              avatar: Icon(dom.icon, size: 16, color: isSelected ? Colors.white : Colors.blueGrey),
              label: Text(dom.label),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _selectedDomainKey = dom.key;
                    _selectedParentId = null;
                    _selectedEntity = null;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWorkspace360(MasterDataEngine engine, MdmEntity entity) {
    final auditHistory = engine.auditLogs.where((a) => a.affectedTarget == entity.label).toList();
    final versions = engine.getVersionHistory(entity.id);
    final dep = engine.checkDependencies(entity.id);
    final aiInsights = engine.generateAiInsights(entity.id);

    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of Entity Workspace
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entity.label, style: context.eosText.titleLarge),
                    Text('Dictionary URI: /${entity.domainKey}/${entity.slug}', style: context.eosText.bodySmall),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showUpsertDialog(context, engine, entity),
                    ),
                    IconButton(
                      icon: const Icon(Icons.archive, color: Colors.orange),
                      onPressed: () => _showArchiveDialog(context, engine, entity),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteDialog(context, engine, entity, dep),
                    ),
                  ],
                ),
              ],
            ),
          ),

          TabBar(
            controller: _tabs360Controller,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Overview & Properties'),
              Tab(text: 'Where Used'),
              Tab(text: 'Hierarchy & Drilldown'),
              Tab(text: 'Version History'),
              Tab(text: 'Audit Log'),
              Tab(text: 'AI Governance'),
            ],
          ),

          Container(
            height: 400,
            padding: const EdgeInsets.all(16),
            child: TabBarView(
              controller: _tabs360Controller,
              children: [
                // Overview & Properties Tab
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Description:', style: context.eosText.titleSmall),
                      Text(entity.description.isNotEmpty ? entity.description : 'No description provided.'),
                      const SizedBox(height: 16),
                      Text('Effective Range:', style: context.eosText.titleSmall),
                      Text('Effective: ${entity.effectiveDate.toLocal().toString().split('.').first}'),
                      Text('Expiry: ${entity.expiryDate != null ? entity.expiryDate!.toLocal().toString().split('.').first : 'Never (Indefinite)'}'),
                      const SizedBox(height: 16),
                      Text('System Properties (JSON):', style: context.eosText.titleSmall),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          const JsonEncoder.withIndent('  ').convert(entity.properties),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.greenAccent),
                        ),
                      ),
                    ],
                  ),
                ),

                // Where Used Tab
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Impact Assessment Metric Dashboard', style: context.eosText.titleMedium),
                    const SizedBox(height: 12),
                    _buildUsedIndicator('Vendors actively offering service', '${dep.count} Vendors', Icons.people, Colors.blue),
                    _buildUsedIndicator('Total Platform Revenue Influence', '₦${(dep.financialImpact / 1000000).toStringAsFixed(1)}M NGN', Icons.payments, Colors.green),
                    _buildUsedIndicator('Operational Link Path', dep.consumerType, Icons.lan, Colors.purple),
                    _buildUsedIndicator('Status Blockers', dep.status, Icons.warning_amber, dep.count > 0 ? Colors.red : Colors.grey),
                  ],
                ),

                // Hierarchy Tab
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parent / Child Hierarchy Resolution', style: context.eosText.titleMedium),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.arrow_upward, color: Colors.blue),
                      title: const Text('Parent Entity Path'),
                      subtitle: Text(entity.parentId ?? 'None (Root Entity)'),
                    ),
                    const Divider(),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedParentId = entity.id;
                          _selectedEntity = null;
                        });
                      },
                      icon: const Icon(Icons.zoom_in),
                      label: const Text('Drill down into Child Services'),
                    ),
                  ],
                ),

                // Version History Tab
                ListView.builder(
                  itemCount: versions.length,
                  itemBuilder: (context, idx) {
                    final ver = versions[idx];
                    return ListTile(
                      leading: CircleAvatar(child: Text('v${ver.versionNumber}')),
                      title: Text('Status: ${ver.status.toUpperCase()}'),
                      subtitle: Text('Saved By: ${ver.createdBy}\nTime: ${ver.createdAt.toString().split('.').first}'),
                      trailing: TextButton(
                        onPressed: () {
                          engine.rollback(entity.id, ver.versionNumber);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Rolled back ${entity.label} to version ${ver.versionNumber}')),
                          );
                        },
                        child: const Text('Rollback'),
                      ),
                    );
                  },
                ),

                // Audit Log Tab
                ListView.builder(
                  itemCount: auditHistory.length,
                  itemBuilder: (context, idx) {
                    final aud = auditHistory[idx];
                    return ListTile(
                      leading: const Icon(Icons.history_edu, color: Colors.orange),
                      title: Text('${aud.actionType} - ${aud.operator}'),
                      subtitle: Text('Change: ${aud.prevVal ?? "NEW"} -> ${aud.newVal ?? "NONE"}\nReason: ${aud.reason ?? "N/A"}'),
                      trailing: Text(aud.createdAt.toString().split(' ').last.split('.').first),
                    );
                  },
                ),

                // AI Governance Tab
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                        const SizedBox(width: 8),
                        Text('AI-Copilot Governance Insights', style: context.eosText.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Classification Recommendation: ${aiInsights['classification']}'),
                    Text('Estimated Obsolescence Risk Score: ${(aiInsights['obsoleteScore'] * 100).toStringAsFixed(1)}%'),
                    const SizedBox(height: 16),
                    Text('Recommendations Summary:', style: context.eosText.titleSmall),
                    for (final rec in aiInsights['recommendations'] as List<String>)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 14, color: Colors.purple),
                            const SizedBox(width: 8),
                            Expanded(child: Text(rec)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsedIndicator(String label, String value, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(label),
    );
  }

  void _showUpsertDialog(BuildContext context, MasterDataEngine engine, MdmEntity? existing) {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final sortCtrl = TextEditingController(text: (existing?.sortOrder ?? 0).toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Create Dictionary Node' : 'Edit Dictionary Node'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Display Label'),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: sortCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Display Sort Order'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final label = labelCtrl.text.trim();
                final desc = descCtrl.text.trim();
                final order = int.tryParse(sortCtrl.text) ?? 0;
                if (label.isEmpty) return;

                if (existing == null) {
                  final created = MdmEntity(
                    id: 'ent_${DateTime.now().millisecondsSinceEpoch}',
                    domainKey: _selectedDomainKey,
                    parentId: _selectedParentId,
                    slug: label.toLowerCase().replaceAll(' ', '_'),
                    label: label,
                    description: desc,
                    status: 'published',
                    sortOrder: order,
                    effectiveDate: DateTime.now(),
                    properties: {},
                  );
                  engine.createEntity(created);
                } else {
                  final updated = existing.copyWith(
                    label: label,
                    description: desc,
                    sortOrder: order,
                  );
                  engine.updateEntity(updated);
                  setState(() {
                    _selectedEntity = updated;
                  });
                }
                Navigator.of(context).pop();
              },
              child: const Text('Save Node'),
            ),
          ],
        );
      },
    );
  }

  void _showArchiveDialog(BuildContext context, MasterDataEngine engine, MdmEntity entity) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Archive Master Data Entity?'),
          content: Text('Archiving "${entity.label}" keeps it in historical records but prevents future selections in forms and event registration wizards.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                engine.archiveEntity(entity.id);
                setState(() {
                  _selectedEntity = null;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Confirm Archival'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, MasterDataEngine engine, MdmEntity entity, MdmDependency dep) {
    final canDelete = dep.count == 0;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(canDelete ? 'Delete Entity?' : 'Deletion Blocked!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!canDelete) ...[
                const Text(
                  'This dictionary item is actively referenced in the Owambe Ecosystem.',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('• Consumer References: ${dep.count} entries'),
                Text('• Estimated Revenue Exposure: ₦${(dep.financialImpact / 1000000).toStringAsFixed(1)}M NGN'),
                const SizedBox(height: 12),
                const Text('To prevent data corruption, direct deletion is blocked. Please use the "Archive" action instead.'),
              ] else ...[
                Text('Are you sure you want to permanently delete "${entity.label}"? This action is irreversible.'),
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if (canDelete)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  engine.deleteEntity(entity.id);
                  setState(() {
                    _selectedEntity = null;
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Delete Node'),
              ),
            if (!canDelete)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  engine.archiveEntity(entity.id);
                  setState(() {
                    _selectedEntity = null;
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Fallback to Archive'),
              ),
          ],
        );
      },
    );
  }

  void _showRegisterDomainDialog(BuildContext context, MasterDataEngine engine) {
    final keyCtrl = TextEditingController();
    final labelCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Register Extension Domain'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyCtrl,
                decoration: const InputDecoration(labelText: 'Domain Key (e.g. crm)'),
              ),
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(labelText: 'Display Label (e.g. Customer Relations)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final key = keyCtrl.text.trim();
                final label = labelCtrl.text.trim();
                if (key.isEmpty || label.isEmpty) return;

                engine.registerDomain(MdmDomain(
                  key: key,
                  label: label,
                  icon: Icons.extension,
                  metadataSchema: {},
                ));
                Navigator.of(context).pop();
              },
              child: const Text('Register'),
            ),
          ],
        );
      },
    );
  }

  void _showImportWizard(BuildContext context, MasterDataEngine engine) {
    _importController.text = '[\n  {"slug": "imported_node_1", "label": "Imported Category Value"}\n]';
    List<Map<String, dynamic>> validatedList = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('CSV/JSON Bulk Integration Utility'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _importController,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Paste JSON Array payload',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.health_and_safety),
                      label: const Text('Run Dry Run Validation'),
                      onPressed: () async {
                        try {
                          final results = await engine.dryRunImport(_selectedDomainKey, _importController.text);
                          validatedList = results.map((r) => {
                            'slug': r['slug'],
                            'label': r['label'],
                            'description': 'Imported node via sync tool',
                          }).toList();

                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Validation Run Summary'),
                              content: Text('Dry Run completed successfully. Found ${results.length} valid entities.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Dismiss'),
                                )
                              ],
                            ),
                          );
                        } catch (err) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Validation Format Error'),
                              content: Text('Payload parsing failed: $err'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: validatedList.isEmpty
                      ? null
                      : () {
                          engine.executeImport(_selectedDomainKey, validatedList);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bulk synchronization applied successfully.')),
                          );
                        },
                  child: const Text('Sync & Execute Import'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
