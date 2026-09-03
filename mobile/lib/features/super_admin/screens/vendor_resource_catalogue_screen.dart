import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/event_config_api.dart';
import '../../../core/api/owambe_http_client.dart';
import '../../../eos/eos.dart';
import '../../admin/widgets/admin_page_layout.dart';

final vendorResourceCatalogProvider =
    FutureProvider.autoDispose<List<VendorResourceCatalogItem>>((ref) async {
  return EventConfigApi(createOwambeHttpClient()).adminListResourceCatalog();
});

class VendorResourceCatalogueScreen extends ConsumerWidget {
  const VendorResourceCatalogueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(vendorResourceCatalogProvider);
    return AdminPageLayout(
      title: 'Resource Catalogue',
      subtitle:
          'Master resource kinds for future service requirements and rental package contents. '
          'This is not vendor inventory, stock quantity, bookings, or finance.',
      actions: [
        TextButton.icon(
          onPressed: () => context.canPop() ? context.pop() : context.go('/super-admin'),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back'),
        ),
        FilledButton.icon(
          onPressed: () => _openEditor(context, ref, null),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Create'),
        ),
      ],
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Could not load resources: $e'),
        data: (list) {
          if (list.isEmpty) {
            return const Text('No resources yet. Apply migration 071 or create a definition.');
          }
          return Column(
            children: [
              for (final item in list)
                Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                  child: EosSurfaceCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.label),
                      subtitle: Text(
                        [
                          item.slug,
                          item.isActive ? 'Active' : 'Inactive',
                          if (item.description.isNotEmpty) item.description,
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _openEditor(context, ref, item),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    VendorResourceCatalogItem? existing,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ResourceEditorDialog(existing: existing),
    );
    if (saved == true) ref.invalidate(vendorResourceCatalogProvider);
  }
}

class _ResourceEditorDialog extends StatefulWidget {
  const _ResourceEditorDialog({this.existing});
  final VendorResourceCatalogItem? existing;

  @override
  State<_ResourceEditorDialog> createState() => _ResourceEditorDialogState();
}

class _ResourceEditorDialogState extends State<_ResourceEditorDialog> {
  late final TextEditingController _label;
  late final TextEditingController _slug;
  late final TextEditingController _description;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.existing?.label ?? '');
    _slug = TextEditingController(text: widget.existing?.slug ?? '');
    _description = TextEditingController(text: widget.existing?.description ?? '');
    _active = widget.existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _label.dispose();
    _slug.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await EventConfigApi(createOwambeHttpClient()).adminUpsertResource(
        id: widget.existing?.id,
        label: _label.text.trim(),
        slug: _slug.text.trim().isEmpty ? null : _slug.text.trim(),
        description: _description.text.trim(),
        isActive: _active,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Create resource' : 'Edit resource'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _label, decoration: const InputDecoration(labelText: 'Label')),
            const SizedBox(height: 12),
            TextField(
              controller: _slug,
              decoration: const InputDecoration(labelText: 'Slug (optional on create)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
