import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/admin_vendor_pricing_api.dart';
import '../../../eos/eos.dart';
import '../widgets/admin_page_layout.dart';

final adminVendorPricingApiProvider = Provider<AdminVendorPricingApi>(
  (ref) => AdminVendorPricingApi(),
);

final adminVendorPricingRulesProvider =
    FutureProvider.autoDispose<VendorPricingRulesSnapshot>((ref) async {
  return ref.read(adminVendorPricingApiProvider).listRules();
});

/// Platform Admin → Settings → Vendor Pricing Rules (single editor).
/// Configures platform markup for organizer-facing vendor service prices.
/// Internal only — never shown to organizers or vendors.
class AdminVendorPricingScreen extends ConsumerWidget {
  const AdminVendorPricingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(adminVendorPricingRulesProvider);

    return AdminPageLayout(
      title: 'Vendor Pricing Rules',
      subtitle:
          'Platform markup applied when calculating organizer-facing service prices. '
          'Changes apply to future bookings only — historical prices stay frozen.',
      actions: [
        TextButton.icon(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/super-admin');
            }
          },
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back'),
        ),
      ],
      body: rules.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EosSurfaceCard(
          child: Text(
            'Could not load pricing rules: $e',
            style: context.eosText.bodyMedium,
          ),
        ),
        data: (snap) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EosSurfaceCard(
              elevated: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Global Default Markup',
                    style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: context.eos.spacing.sm),
                  Text(
                    snap.defaultRule == null
                        ? 'Not configured (API will seed 40%)'
                        : '${_formatPercent(snap.defaultRule!.markupPercent)}%',
                    style: context.eosText.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: EosColors.plum,
                    ),
                  ),
                  SizedBox(height: context.eos.spacing.xs),
                  Text(
                    'Example: ₦50,000 vendor payout + ${_formatPercent(snap.defaultRule?.markupPercent ?? 40)}% '
                    '→ ₦${_exampleCustomerPrice(snap.defaultRule?.markupPercent ?? 40).toStringAsFixed(0)} organizer price',
                    style: context.eosText.bodySmall?.copyWith(color: EosColors.slate500),
                  ),
                  SizedBox(height: context.eos.spacing.md),
                  FilledButton.icon(
                    onPressed: () => _editDefault(context, ref, snap.defaultRule?.markupPercent ?? 40),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.eos.spacing.lg),
            _rulesCard(
              context,
              title: '2. Service Category Rules',
              hint:
                  'Applies when no vendor override matches (catering, photography, dj, decor, …).',
              empty: 'No service category rules. Falls through to global default.',
              onAdd: () => _editService(context, ref),
              rules: snap.serviceRules,
              titleOf: (r) => r.serviceKey ?? '—',
              onEdit: (r) => _editService(
                context,
                ref,
                serviceKey: r.serviceKey,
                markupPercent: r.markupPercent,
              ),
              onDelete: (r) => _deleteService(context, ref, r.serviceKey!),
            ),
            SizedBox(height: context.eos.spacing.lg),
            _rulesCard(
              context,
              title: '3. Vendor Overrides',
              hint:
                  'Vendor-wide markup for a specific vendors.id. Beats service category & default.',
              empty: 'No vendor-wide overrides.',
              onAdd: () => _editVendor(context, ref),
              rules: snap.vendorRules,
              titleOf: (r) => r.vendorName?.isNotEmpty == true
                  ? '${r.vendorName} (${_shortId(r.vendorId!)})'
                  : (r.vendorId ?? '—'),
              onEdit: (r) => _editVendor(
                context,
                ref,
                vendorId: r.vendorId,
                markupPercent: r.markupPercent,
              ),
              onDelete: (r) => _deleteVendor(context, ref, vendorId: r.vendorId!),
            ),
            SizedBox(height: context.eos.spacing.lg),
            _rulesCard(
              context,
              title: '4. Vendor + Service Overrides',
              hint: 'Highest priority. Example: Jollof & Co + catering @ 20%.',
              empty: 'No vendor+service overrides.',
              onAdd: () => _editVendor(context, ref, requireService: true),
              rules: snap.vendorServiceRules,
              titleOf: (r) {
                final name = r.vendorName?.isNotEmpty == true
                    ? r.vendorName!
                    : _shortId(r.vendorId ?? '');
                return '$name · ${r.serviceKey}';
              },
              onEdit: (r) => _editVendor(
                context,
                ref,
                vendorId: r.vendorId,
                serviceKey: r.serviceKey,
                markupPercent: r.markupPercent,
                requireService: true,
              ),
              onDelete: (r) => _deleteVendor(
                context,
                ref,
                vendorId: r.vendorId!,
                serviceKey: r.serviceKey,
              ),
            ),
            SizedBox(height: context.eos.spacing.lg),
            EosSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resolution order (deterministic)',
                    style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: context.eos.spacing.sm),
                  Text(
                    '1. Vendor + service override\n'
                    '2. Vendor override\n'
                    '3. Service category rule\n'
                    '4. Global default\n'
                    '5. Hardcoded fallback (40% / 4000 bps)\n\n'
                    'Organizers see Service Price only. Vendors see Agreed Vendor Payout only. '
                    'Markup is never exposed outside Admin. '
                    'Rule edits never recalculate historical requests, negotiations, or funding.',
                    style: context.eosText.bodySmall?.copyWith(color: EosColors.slate500),
                  ),
                  if (snap.resolutionOrder.isNotEmpty) ...[
                    SizedBox(height: context.eos.spacing.sm),
                    Text(
                      'API: ${snap.resolutionOrder.join(' → ')}',
                      style: context.eosText.labelSmall?.copyWith(color: EosColors.slate500),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _rulesCard(
    BuildContext context, {
    required String title,
    required String hint,
    required String empty,
    required VoidCallback onAdd,
    required List<VendorPricingRule> rules,
    required String Function(VendorPricingRule) titleOf,
    required void Function(VendorPricingRule) onEdit,
    required void Function(VendorPricingRule) onDelete,
  }) {
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          Text(hint, style: context.eosText.bodySmall?.copyWith(color: EosColors.slate500)),
          SizedBox(height: context.eos.spacing.md),
          if (rules.isEmpty)
            Text(empty, style: context.eosText.bodyMedium)
          else
            ...rules.map(
              (rule) => Padding(
                padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(titleOf(rule), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${_formatPercent(rule.markupPercent)}% markup'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () => onEdit(rule),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () => onDelete(rule),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatPercent(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  static String _shortId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}…';
  }

  static double _exampleCustomerPrice(double markupPercent) {
    return 50000 * (1 + markupPercent / 100);
  }

  Future<void> _editDefault(BuildContext context, WidgetRef ref, double current) async {
    final value = await _promptPercent(
      context,
      title: 'Default Platform Markup',
      initial: current,
      hint: 'e.g. 40, 45, 50',
    );
    if (value == null || !context.mounted) return;
    try {
      await ref.read(adminVendorPricingApiProvider).upsertDefault(value);
      ref.invalidate(adminVendorPricingRulesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Default markup set to ${_formatPercent(value)}%')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _editService(
    BuildContext context,
    WidgetRef ref, {
    String? serviceKey,
    double? markupPercent,
  }) async {
    final result = await _promptServiceRule(
      context,
      initialKey: serviceKey,
      initialPercent: markupPercent ?? 40,
      lockKey: serviceKey != null,
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(adminVendorPricingApiProvider).upsertServiceRule(
            serviceKey: result.$1,
            markupPercent: result.$2,
          );
      ref.invalidate(adminVendorPricingRulesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.$1}: ${_formatPercent(result.$2)}% saved')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteService(BuildContext context, WidgetRef ref, String serviceKey) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove service rule?'),
        content: Text(
          '“$serviceKey” will fall back to vendor override / default for future bookings only.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(adminVendorPricingApiProvider).deleteServiceRule(serviceKey);
      ref.invalidate(adminVendorPricingRulesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<void> _editVendor(
    BuildContext context,
    WidgetRef ref, {
    String? vendorId,
    String? serviceKey,
    double? markupPercent,
    bool requireService = false,
  }) async {
    final result = await _promptVendorRule(
      context,
      initialVendorId: vendorId,
      initialServiceKey: serviceKey,
      initialPercent: markupPercent ?? 25,
      lockVendor: vendorId != null,
      requireService: requireService || serviceKey != null,
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(adminVendorPricingApiProvider).upsertVendorRule(
            vendorId: result.$1,
            serviceKey: result.$2,
            markupPercent: result.$3,
          );
      ref.invalidate(adminVendorPricingRulesProvider);
      if (context.mounted) {
        final label = result.$2 == null || result.$2!.isEmpty
            ? result.$1
            : '${result.$1} / ${result.$2}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label: ${_formatPercent(result.$3)}% saved')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteVendor(
    BuildContext context,
    WidgetRef ref, {
    required String vendorId,
    String? serviceKey,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(serviceKey == null ? 'Remove vendor override?' : 'Remove vendor+service override?'),
        content: Text(
          serviceKey == null
              ? 'Vendor $vendorId will fall back to service / default for future bookings only.'
              : 'Vendor $vendorId / $serviceKey will fall back for future bookings only.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(adminVendorPricingApiProvider).deleteVendorRule(
            vendorId: vendorId,
            serviceKey: serviceKey,
          );
      ref.invalidate(adminVendorPricingRulesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<double?> _promptPercent(
    BuildContext context, {
    required String title,
    required double initial,
    required String hint,
  }) async {
    final controller = TextEditingController(text: _formatPercent(initial));
    return showDialog<double>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: 'Markup %',
                hintText: hint,
                suffixText: '%',
                errorText: error,
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final parsed = double.tryParse(controller.text.trim());
                  if (parsed == null || parsed < 0 || parsed > 90) {
                    setState(() => error = 'Enter a percentage from 0 to 90');
                    return;
                  }
                  Navigator.pop(ctx, parsed);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<(String, double)?> _promptServiceRule(
    BuildContext context, {
    String? initialKey,
    required double initialPercent,
    required bool lockKey,
  }) async {
    final keyController = TextEditingController(text: initialKey ?? '');
    final pctController = TextEditingController(text: _formatPercent(initialPercent));
    return showDialog<(String, double)>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(lockKey ? 'Edit service markup' : 'Add service markup'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyController,
                  enabled: !lockKey,
                  decoration: const InputDecoration(
                    labelText: 'Service key',
                    hintText: 'catering, decor, photography, dj',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pctController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Markup %',
                    suffixText: '%',
                    errorText: error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final key = keyController.text.trim().toLowerCase();
                  final parsed = double.tryParse(pctController.text.trim());
                  if (key.isEmpty) {
                    setState(() => error = 'Service key is required');
                    return;
                  }
                  if (parsed == null || parsed < 0 || parsed > 90) {
                    setState(() => error = 'Enter a percentage from 0 to 90');
                    return;
                  }
                  Navigator.pop(ctx, (key, parsed));
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<(String, String?, double)?> _promptVendorRule(
    BuildContext context, {
    String? initialVendorId,
    String? initialServiceKey,
    required double initialPercent,
    required bool lockVendor,
    required bool requireService,
  }) async {
    final vendorController = TextEditingController(text: initialVendorId ?? '');
    final serviceController = TextEditingController(text: initialServiceKey ?? '');
    final pctController = TextEditingController(text: _formatPercent(initialPercent));
    return showDialog<(String, String?, double)>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(
              requireService
                  ? (lockVendor ? 'Edit vendor + service markup' : 'Add vendor + service markup')
                  : (lockVendor ? 'Edit vendor markup' : 'Add vendor markup'),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: vendorController,
                  enabled: !lockVendor,
                  decoration: const InputDecoration(
                    labelText: 'Vendor ID (vendors.id)',
                    hintText: 'UUID from vendors table — not user id',
                  ),
                ),
                if (requireService) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: serviceController,
                    enabled: initialServiceKey == null,
                    decoration: const InputDecoration(
                      labelText: 'Service key',
                      hintText: 'catering, photography, …',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: pctController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Markup %',
                    suffixText: '%',
                    errorText: error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final vendorId = vendorController.text.trim();
                  final service = serviceController.text.trim().toLowerCase();
                  final parsed = double.tryParse(pctController.text.trim());
                  if (vendorId.isEmpty) {
                    setState(() => error = 'vendors.id is required');
                    return;
                  }
                  if (requireService && service.isEmpty) {
                    setState(() => error = 'Service key is required');
                    return;
                  }
                  if (parsed == null || parsed < 0 || parsed > 90) {
                    setState(() => error = 'Enter a percentage from 0 to 90');
                    return;
                  }
                  Navigator.pop(
                    ctx,
                    (vendorId, requireService ? service : null, parsed),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }
}
