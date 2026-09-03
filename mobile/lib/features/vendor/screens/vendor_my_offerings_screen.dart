import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/event_config_api.dart';
import '../../../core/api/owambe_http_client.dart';
import '../../../core/api/vendor_offerings_api.dart';
import '../../../eos/eos.dart';
import '../providers/vendor_providers.dart';

/// Vendor-owned services (with blueprints) and rental packages.
class VendorMyOfferingsScreen extends ConsumerStatefulWidget {
  const VendorMyOfferingsScreen({super.key});

  @override
  ConsumerState<VendorMyOfferingsScreen> createState() => _VendorMyOfferingsScreenState();
}

class _VendorMyOfferingsScreenState extends ConsumerState<VendorMyOfferingsScreen> {
  Map<String, dynamic>? _config;
  List<VendorResourceCatalogItem> _resources = const [];
  List<VendorCategoryConfig> _serviceCats = const [];
  List<VendorCategoryConfig> _rentalCats = const [];
  List<Map<String, dynamic>> _packages = const [];
  List<Map<String, dynamic>> _services = const [];
  String? _error;
  bool _loading = true;

  bool get _service => (_config?['capabilityKeys'] as List?)?.contains('SERVICE_PROVIDER') == true;
  bool get _rental => (_config?['capabilityKeys'] as List?)?.contains('RENTAL_PROVIDER') == true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<String?> _resolvedVendorId() async {
    try {
      return await ref.read(canonicalVendorIdProvider.future);
    } catch (_) {
      return null;
    }
  }

  Future<void> _reload() async {
    final vendorId = await _resolvedVendorId();
    if (vendorId == null || vendorId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Vendor identity is not resolved.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final http = createOwambeHttpClient();
      final cfg = EventConfigApi(http);
      final off = VendorOfferingsApi(http);
      final config = await off.getConfig(vendorId);
      final resources = await cfg.listPublicResourceCatalog();
      final serviceCats = await cfg.listPublicOfferingCategories(kind: 'service');
      final rentalCats = await cfg.listPublicOfferingCategories(kind: 'rental');
      var packages = <Map<String, dynamic>>[];
      var services = <Map<String, dynamic>>[];
      if ((config['capabilityKeys'] as List?)?.contains('SERVICE_PROVIDER') == true) {
        services = await off.listServices(vendorId);
      }
      if ((config['capabilityKeys'] as List?)?.contains('RENTAL_PROVIDER') == true) {
        packages = await off.listPackages(vendorId);
      }
      if (!mounted) return;
      setState(() {
        _config = config;
        _resources = resources;
        _serviceCats = serviceCats;
        _rentalCats = rentalCats;
        _packages = packages;
        _services = services;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EosColors.plumDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('My Services & Rentals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/vendor'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: const TextStyle(color: Colors.white70)),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_service) ...[
                      Text('My Services', style: context.eosText.titleMedium?.copyWith(color: Colors.white)),
                      const SizedBox(height: 8),
                      const Text(
                        'Blueprints list standard resources from the Super Admin catalogue. They are not inventory.',
                        style: TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => _addService(context),
                        child: const Text('Add service'),
                      ),
                      const SizedBox(height: 12),
                      ..._serviceRows(context),
                      const SizedBox(height: 28),
                    ],
                    if (_rental) ...[
                      Text('My Rental Packages', style: context.eosText.titleMedium?.copyWith(color: Colors.white)),
                      const SizedBox(height: 8),
                      const Text(
                        'Buyers rent the package, not arbitrary quantities. Price is stored on the existing rental catalogue.',
                        style: TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => _editPackage(context, null),
                        child: const Text('Create rental package'),
                      ),
                      const SizedBox(height: 12),
                      for (final p in _packages)
                        Card(
                          child: ListTile(
                            title: Text(p['name']?.toString() ?? ''),
                            subtitle: Text(
                              '${p['categorySlug']} · ₦${((p['rentalFeeMinor'] as num?)?.toInt() ?? 0) / 100}',
                            ),
                            onTap: () => _editPackage(context, p),
                          ),
                        ),
                    ],
                    if (!_service && !_rental)
                      const Text(
                        'Select Service Provider and/or Rental Provider during onboarding (or ask support to assign capabilities).',
                        style: TextStyle(color: Colors.white70),
                      ),
                  ],
                ),
    );
  }

  List<Widget> _serviceRows(BuildContext context) {
    if (_services.isEmpty) {
      return const [Text('No services yet. Add one to attach a blueprint.', style: TextStyle(color: Colors.white54))];
    }
    return [
      for (final s in _services)
        Card(
          child: ListTile(
            title: Text(s['serviceName']?.toString() ?? ''),
            subtitle: Text(s['serviceKey']?.toString() ?? ''),
            trailing: const Text('Blueprint'),
            onTap: () => _editBlueprint(
              context,
              s['id']?.toString() ?? '',
              s['serviceName']?.toString() ?? '',
            ),
          ),
        ),
    ];
  }

  Future<void> _addService(BuildContext context) async {
    if (_serviceCats.isEmpty) return;
    final name = TextEditingController();
    String categoryId = _serviceCats.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Service name')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: categoryId,
              items: [
                for (final c in _serviceCats) DropdownMenuItem(value: c.id, child: Text(c.label)),
              ],
              onChanged: (v) => categoryId = v ?? categoryId,
              decoration: const InputDecoration(labelText: 'Service category'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final vendorId = await _resolvedVendorId();
    if (vendorId == null) return;
    try {
      await VendorOfferingsApi(createOwambeHttpClient()).createService(
        vendorId: vendorId,
        serviceName: name.text.trim(),
        categoryId: categoryId,
      );
      await _reload();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editBlueprint(BuildContext context, String serviceId, String title) async {
    if (serviceId.isEmpty) return;
    final vendorId = await _resolvedVendorId();
    if (vendorId == null) return;
    final api = VendorOfferingsApi(createOwambeHttpClient());
    Map<String, dynamic> detail;
    try {
      detail = await api.getBlueprint(vendorId, serviceId);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    final selected = {
      for (final r in (detail['blueprint'] as List? ?? const []))
        (r as Map)['resourceId'].toString(): r['required'] != false,
    };
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text('Blueprint · $title'),
            content: SizedBox(
              width: 420,
              height: 360,
              child: ListView(
                children: [
                  const Text('Required resources (master catalogue). Not inventory.'),
                  for (final r in _resources)
                    CheckboxListTile(
                      title: Text(r.label),
                      value: selected.containsKey(r.id),
                      onChanged: (v) => setLocal(() {
                        if (v == true) {
                          selected[r.id] = true;
                        } else {
                          selected.remove(r.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
            ],
          ),
        );
      },
    );
    if (ok != true) return;
    try {
      await api.putBlueprint(
        vendorId: vendorId,
        serviceId: serviceId,
        resources: [
          for (final e in selected.entries) {'resourceId': e.key, 'required': e.value},
        ],
      );
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editPackage(BuildContext context, Map<String, dynamic>? existing) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final desc = TextEditingController(text: existing?['description']?.toString() ?? '');
    final price = TextEditingController(
      text: existing == null ? '' : (((existing['rentalFeeMinor'] as num?)?.toInt() ?? 0) / 100).toString(),
    );
    String slug = existing?['categorySlug']?.toString() ?? (_rentalCats.isNotEmpty ? _rentalCats.first.slug : '');
    final qty = <String, int>{
      for (final c in (existing?['components'] as List? ?? const []))
        (c as Map)['resourceId'].toString(): (c['quantity'] as num?)?.toInt() ?? 1,
    };
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(existing == null ? 'Create rental package' : 'Edit package'),
            content: SizedBox(
              width: 440,
              height: 420,
              child: ListView(
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Package name')),
                  TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
                  TextField(
                    controller: price,
                    decoration: const InputDecoration(labelText: 'Rental fee (major units)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: slug.isEmpty ? null : slug,
                    items: [
                      for (final c in _rentalCats) DropdownMenuItem(value: c.slug, child: Text(c.label)),
                    ],
                    onChanged: (v) => slug = v ?? slug,
                    decoration: const InputDecoration(labelText: 'Rental category'),
                  ),
                  const SizedBox(height: 8),
                  const Text('Package contents (definition quantities, not a buyer request)'),
                  for (final r in _resources)
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            title: Text(r.label),
                            value: qty.containsKey(r.id),
                            onChanged: (v) => setLocal(() {
                              if (v == true) {
                                qty[r.id] = qty[r.id] ?? 1;
                              } else {
                                qty.remove(r.id);
                              }
                            }),
                          ),
                        ),
                        if (qty.containsKey(r.id))
                          SizedBox(
                            width: 56,
                            child: TextFormField(
                              initialValue: '${qty[r.id]}',
                              keyboardType: TextInputType.number,
                              onChanged: (t) => qty[r.id] = int.tryParse(t) ?? 1,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
            ],
          ),
        );
      },
    );
    if (ok != true || name.text.trim().isEmpty || slug.isEmpty) return;
    final vendorId = await _resolvedVendorId();
    if (vendorId == null) return;
    final major = double.tryParse(price.text.trim()) ?? 0;
    try {
      await VendorOfferingsApi(createOwambeHttpClient()).upsertPackage(
        vendorId: vendorId,
        id: existing?['id']?.toString(),
        name: name.text.trim(),
        description: desc.text.trim(),
        categorySlug: slug,
        rentalFeeMinor: (major * 100).round(),
        components: [
          for (final e in qty.entries) {'resourceId': e.key, 'quantity': e.value < 1 ? 1 : e.value},
        ],
      );
      await _reload();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
