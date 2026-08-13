import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/control_plane_api.dart';
import '../../../eos/eos.dart';

/// Phase 28 — Nest-backed MDM dictionary workspace (039 mdm_*).
/// Device inventory is Unavailable (no enrollment schema).
class MdmWorkspaceScreen extends ConsumerStatefulWidget {
  const MdmWorkspaceScreen({super.key});

  @override
  ConsumerState<MdmWorkspaceScreen> createState() => _MdmWorkspaceScreenState();
}

class _MdmWorkspaceScreenState extends ConsumerState<MdmWorkspaceScreen> {
  String? _domainKey;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final domains = ref.watch(controlPlaneMdmDomainsProvider);
    final devices = ref.watch(controlPlaneDevicesProvider);
    final activity = ref.watch(controlPlaneActivityProvider);
    final selected = _domainKey;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Master Data Management', style: context.eosText.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Nest-backed dictionary domains (mdm_*). Not an in-memory engine.',
          style: context.eosText.bodySmall?.copyWith(color: context.eosColors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        devices.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (d) => EosSurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.devices_other_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      d['available'] == true
                          ? 'Devices online'
                          : 'Devices: Unavailable — ${d['reason'] ?? 'no enrollment schema'}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        domains.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EosSurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('MDM unavailable: $e\nApply infra/db/039_enterprise_mdm.sql and 061_control_plane.sql.'),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Text('No MDM domains. Apply migration 039.');
            }
            final key = selected ?? items.first['domainKey']?.toString();
            if (_domainKey == null && key != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _domainKey = key);
              });
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in items)
                      ChoiceChip(
                        label: Text('${d['label']} (${d['entityCount'] ?? 0})'),
                        selected: (_domainKey ?? key) == d['domainKey'],
                        onSelected: (_) => setState(() => _domainKey = d['domainKey']?.toString()),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search entities…',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: key == null ? null : () => _createEntity(key),
                      icon: const Icon(Icons.add),
                      label: const Text('New entity'),
                    ),
                    IconButton(
                      onPressed: () {
                        ref.invalidate(controlPlaneMdmDomainsProvider);
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (key != null) _EntityList(domainKey: key, search: _search),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text('MDM / control-plane activity', style: context.eosText.titleMedium),
        const SizedBox(height: 8),
        activity.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (items) {
            final mdm = items.where((a) => (a['action']?.toString() ?? '').startsWith('mdm.')).take(20);
            if (mdm.isEmpty) return const Text('No mdm.* audit events yet');
            return EosSurfaceCard(
              child: Column(
                children: [
                  for (final a in mdm)
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
    );
  }

  Future<void> _createEntity(String domainKey) async {
    final slug = TextEditingController();
    final label = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create MDM entity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug')),
            TextField(controller: label, decoration: const InputDecoration(labelText: 'Label')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(controlPlaneApiProvider).createMdmEntity(domainKey, {
        'slug': slug.text.trim(),
        'label': label.text.trim(),
        'status': 'draft',
      });
      ref.invalidate(controlPlaneMdmDomainsProvider);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entity created')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _EntityList extends ConsumerWidget {
  const _EntityList({required this.domainKey, required this.search});
  final String domainKey;
  final String search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_mdmEntitiesProvider('$domainKey|$search'));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('$e'),
      data: (items) {
        if (items.isEmpty) {
          return const EosSurfaceCard(
            child: Padding(padding: EdgeInsets.all(16), child: Text('No entities in this domain.')),
          );
        }
        return EosSurfaceCard(
          elevated: true,
          child: Column(
            children: [
              for (final e in items)
                ListTile(
                  title: Text('${e['label']}'),
                  subtitle: Text('${e['slug']} · ${e['status']}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      try {
                        await ref.read(controlPlaneApiProvider).updateMdmEntity(
                              e['id'].toString(),
                              {'status': action},
                            );
                        ref.invalidate(_mdmEntitiesProvider('$domainKey|$search'));
                        ref.invalidate(controlPlaneMdmDomainsProvider);
                      } catch (err) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err')));
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'draft', child: Text('Set draft')),
                      PopupMenuItem(value: 'published', child: Text('Publish')),
                      PopupMenuItem(value: 'archived', child: Text('Archive')),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

final _mdmEntitiesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, key) async {
  final parts = key.split('|');
  return ref.read(controlPlaneApiProvider).mdmEntities(
        parts[0],
        q: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
      );
});
