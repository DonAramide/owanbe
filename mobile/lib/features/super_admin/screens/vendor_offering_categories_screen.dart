import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/event_config_api.dart';
import '../../../core/api/owambe_http_client.dart';
import '../../../eos/eos.dart';
import '../../admin/widgets/admin_page_layout.dart';

final vendorOfferingCategoriesProvider =
    FutureProvider.autoDispose.family<List<VendorCategoryConfig>, String>((ref, kind) async {
  return EventConfigApi(createOwambeHttpClient()).adminListOfferingCategories(kind: kind);
});

class VendorOfferingCategoriesScreen extends ConsumerWidget {
  const VendorOfferingCategoriesScreen({super.key, required this.offeringKind});

  /// `service` or `rental`
  final String offeringKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isService = offeringKind == 'service';
    final title = isService ? 'Service Categories' : 'Rental Categories';
    final items = ref.watch(vendorOfferingCategoriesProvider(offeringKind));

    return AdminPageLayout(
      title: title,
      subtitle: isService
          ? 'Categories for services a vendor performs. Deactivate instead of deleting referenced rows.'
          : 'Categories for rental packages/sets. Deactivate instead of deleting. Not inventory quantities.',
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
        error: (e, _) => Text('Could not load categories: $e'),
        data: (list) {
          if (list.isEmpty) {
            return Text('No $offeringKind categories yet. Create one to start.');
          }
          return Column(
            children: [
              for (final cat in list)
                Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                  child: EosSurfaceCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(cat.label),
                      subtitle: Text(
                        [
                          cat.slug,
                          cat.isActive ? 'Active' : 'Inactive',
                          cat.offeringKind,
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _openEditor(context, ref, cat),
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
    VendorCategoryConfig? existing,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CategoryEditorDialog(
        offeringKind: offeringKind,
        existing: existing,
      ),
    );
    if (saved == true) {
      ref.invalidate(vendorOfferingCategoriesProvider(offeringKind));
    }
  }
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({required this.offeringKind, this.existing});

  final String offeringKind;
  final VendorCategoryConfig? existing;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late final TextEditingController _label;
  late final TextEditingController _slug;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.existing?.label ?? '');
    _slug = TextEditingController(text: widget.existing?.slug ?? '');
    _active = widget.existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _label.dispose();
    _slug.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await EventConfigApi(createOwambeHttpClient()).adminUpsertOfferingCategory(
        id: widget.existing?.id,
        label: _label.text.trim(),
        slug: _slug.text.trim().isEmpty ? null : _slug.text.trim(),
        offeringKind: widget.offeringKind,
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
      title: Text(widget.existing == null ? 'Create category' : 'Edit category'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _label,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _slug,
              decoration: const InputDecoration(
                labelText: 'Slug (optional on create)',
                helperText: 'Leave blank to generate from the label.',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text('Inactive categories stay in the database (no hard delete).'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}
