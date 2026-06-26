import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../data/vendor_store.dart';
import '../models/vendor_models.dart';
import '../providers/vendor_providers.dart';
import '../widgets/vendor_shared.dart';

class ServiceCatalogScreen extends ConsumerStatefulWidget {
  const ServiceCatalogScreen({super.key});

  @override
  ConsumerState<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends ConsumerState<ServiceCatalogScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  VendorCatalogType _category = VendorCatalogType.catering;
  VendorCatalogType? _filter;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(vendorCatalogProvider);
    final profile = ref.watch(vendorProfileProvider);

    return EosPageScaffold(
      title: 'Service catalog',
      subtitle: '${profile.vendorType.label} packages and services',
      actions: [
        FilledButton.icon(
          onPressed: () => _showAddSheet(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add item'),
        ),
      ],
      floatingHeader: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(right: context.eos.spacing.xs),
              child: FilterChip(
                label: const Text('All types'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
            ),
            for (final type in VendorCatalogType.values)
              Padding(
                padding: EdgeInsets.only(right: context.eos.spacing.xs),
                child: FilterChip(
                  avatar: Icon(catalogTypeIcon(type), size: 16),
                  label: Text(type.label),
                  selected: _filter == type,
                  onSelected: (_) => setState(() => _filter = type),
                ),
              ),
          ],
        ),
      ),
      body: catalog.when(
        data: (items) {
          final filtered = _filter == null
              ? items
              : items.where((i) => i.category.toLowerCase() == _filter!.label.toLowerCase()).toList();
          if (filtered.isEmpty) {
            return EosSurfaceCard(
              child: Padding(
                padding: EdgeInsets.all(context.eos.spacing.lg),
                child: Column(
                  children: [
                    Text('No ${_filter?.label ?? ''} packages yet', style: context.eosText.titleMedium),
                    SizedBox(height: context.eos.spacing.sm),
                    Text(
                      'Add services across Catering, Photography, Decoration, Entertainment, Security, Rentals, Beauty, and Logistics.',
                      style: context.eosText.bodyMedium,
                    ),
                    SizedBox(height: context.eos.spacing.md),
                    FilledButton(onPressed: () => _showAddSheet(context), child: const Text('Add item')),
                  ],
                ),
              ),
            );
          }
          return Wrap(
            spacing: context.eos.spacing.md,
            runSpacing: context.eos.spacing.md,
            children: filtered
                .map(
                  (item) => SizedBox(
                    width: 320,
                    child: VendorCatalogCard(
                      item: item,
                      onToggle: () => _toggleActive(item),
                    ),
                  ),
                )
                .toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }

  Future<void> _toggleActive(VendorCatalogItem item) async {
    final next = item.status != VendorCatalogStatus.active;
    try {
      await ref.read(vendorCatalogApiProvider).setActive(item.id, next);
      bumpVendorRevision(ref);
    } catch (e) {
      if (!allowMockPersistenceFallback()) rethrow;
      VendorStore.instance.toggleCatalogStatus(item.id);
      bumpVendorRevision(ref);
    }
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: context.eos.spacing.lg,
          right: context.eos.spacing.lg,
          top: context.eos.spacing.lg,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + context.eos.spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New catalog item', style: context.eosText.titleLarge),
            SizedBox(height: context.eos.spacing.md),
            EosTextField(controller: _name, label: 'Name', hint: 'Party Jollof Package'),
            SizedBox(height: context.eos.spacing.sm),
            EosTextField(controller: _description, label: 'Description', hint: 'What is included', maxLines: 2),
            SizedBox(height: context.eos.spacing.sm),
            EosSelectField<VendorCatalogType>(
              label: 'Vendor type',
              value: _category,
              items: VendorCatalogType.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            SizedBox(height: context.eos.spacing.sm),
            EosTextField(
              controller: _price,
              label: 'Price (minor units)',
              hint: '45000000',
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: context.eos.spacing.lg),
            FilledButton(
              onPressed: () async {
                final price = int.tryParse(_price.text.trim()) ?? 0;
                if (_name.text.trim().isEmpty || price <= 0) return;
                try {
                  await ref.read(vendorCatalogApiProvider).createPackage(
                        name: _name.text.trim(),
                        description: _description.text.trim(),
                        category: _category.label,
                        priceMinor: price,
                      );
                  bumpVendorRevision(ref);
                } catch (e) {
                  if (!allowMockPersistenceFallback()) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                    }
                    return;
                  }
                  VendorStore.instance.addCatalogItem(
                    name: _name.text.trim(),
                    description: _description.text.trim(),
                    category: _category.label,
                    priceMinor: price,
                  );
                  bumpVendorRevision(ref);
                }
                _name.clear();
                _description.clear();
                _price.clear();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save item'),
            ),
          ],
        ),
      ),
    );
  }
}
