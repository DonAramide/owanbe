import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/event_config_api.dart';
import '../../../core/api/owambe_http_client.dart';
import '../../../eos/eos.dart';
import '../../../shared/widgets/unsaved_changes.dart';
import '../widgets/admin_page_layout.dart';
import 'admin_vendor_categories_screen.dart';

class AdminVendorCapabilityDetailScreen extends ConsumerStatefulWidget {
  const AdminVendorCapabilityDetailScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  ConsumerState<AdminVendorCapabilityDetailScreen> createState() =>
      AdminVendorCapabilityDetailScreenState();
}

class AdminVendorCapabilityDetailScreenState
    extends ConsumerState<AdminVendorCapabilityDetailScreen> {
  List<VendorCategoryCapability> _persisted = const [];
  List<VendorCategoryCapability> _draft = const [];
  bool? _persistedActive;
  bool? _draftActive;
  bool _saving = false;
  bool _awaitingRefresh = false;
  String? _addError;

  @override
  void didUpdateWidget(covariant AdminVendorCapabilityDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) {
      _awaitingRefresh = false;
      _persisted = const [];
      _draft = const [];
      _persistedActive = null;
      _draftActive = null;
    }
  }

  bool get hasUnsavedChanges {
    if (_draftActive != null && _persistedActive != null && _draftActive != _persistedActive) {
      return true;
    }
    return !_capabilityListsEqual(_persisted, _draft);
  }

  @override
  void initState() {
    super.initState();
    UnsavedChangesRegistry.adminCapabilityDetail = UnsavedChangesBinder(
      isDirty: () => hasUnsavedChanges,
      discard: discardLocalChanges,
    );
  }

  @override
  void dispose() {
    if (UnsavedChangesRegistry.adminCapabilityDetail != null) {
      UnsavedChangesRegistry.adminCapabilityDetail = null;
    }
    super.dispose();
  }

  void discardLocalChanges() {
    _draft = List<VendorCategoryCapability>.from(_persisted);
    _draftActive = _persistedActive;
    _addError = null;
    if (mounted) setState(() {});
  }

  void _hydrate(VendorCategoryConfig cat) {
    if (hasUnsavedChanges) return;
    if (_awaitingRefresh) {
      if (_capabilityListsEqual(_persisted, cat.capabilities) &&
          (_persistedActive == null || _persistedActive == cat.isActive)) {
        _awaitingRefresh = false;
      } else {
        return;
      }
    }
    _persisted = List<VendorCategoryCapability>.from(cat.capabilities);
    _draft = List<VendorCategoryCapability>.from(cat.capabilities);
    _persistedActive = cat.isActive;
    _draftActive = cat.isActive;
  }

  Future<bool> _guardLeave() {
    return UnsavedChangesRegistry.confirmLeave(
      context,
      binder: UnsavedChangesRegistry.adminCapabilityDetail,
    );
  }

  Future<void> _save() async {
    if (!hasUnsavedChanges || _saving) return;
    setState(() => _saving = true);
    try {
      await EventConfigApi(createOwambeHttpClient()).adminSaveVendorCategoryCapabilities(
        id: widget.categoryId,
        capabilities: _draft,
        isActive: _draftActive,
      );
      ref.invalidate(adminVendorCategoriesProvider);
      if (!mounted) return;
      setState(() {
        _persisted = List<VendorCategoryCapability>.from(_draft);
        _persistedActive = _draftActive;
        _saving = false;
        _awaitingRefresh = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminVendorCategoriesProvider);
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (cats) {
        VendorCategoryConfig? cat;
        for (final item in cats) {
          if (item.id == widget.categoryId) {
            cat = item;
            break;
          }
        }
        if (cat == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vendor capability')),
            body: const Center(child: Text('Category not found.')),
          );
        }
        _hydrate(cat);
        final dirty = hasUnsavedChanges;
        return PopScope(
          canPop: !dirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final leave = await _guardLeave();
            if (leave && context.mounted) context.pop();
          },
          child: AdminPageLayout(
            title: '${cat.label} · Capability Catalogue',
            subtitle:
                'Marketplace category + Admin-enabled capabilities Vendors may select. '
                'Disabling a capability hides it from new Vendor selection and Marketplace; '
                'historical request snapshots are preserved.',
            actions: [
              TextButton.icon(
                onPressed: () async {
                  final leave = await _guardLeave();
                  if (leave && context.mounted) context.pop();
                },
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
              ),
            ],
            body: EosSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Category active in Marketplace'),
                    subtitle: Text(
                      'Inactive categories are hidden from public Vendor category lists.',
                      style: context.eosText.bodySmall,
                    ),
                    value: _draftActive ?? cat.isActive,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _draftActive = v),
                  ),
                  const Divider(height: 24),
                  Text(
                    'Admin owns this catalogue. Vendors only toggle what they provide.',
                    style: context.eosText.bodySmall?.copyWith(
                      color: context.eosColors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: context.eos.spacing.md),
                  Text(
                    'Core Capabilities',
                    style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: context.eos.spacing.xs),
                  Text(
                    'Basic offerings for this category. Enable/disable for all Vendors.',
                    style: context.eosText.bodySmall?.copyWith(
                      color: context.eosColors.onSurfaceVariant,
                    ),
                  ),
                  ..._capabilityTiles(tier: 'core'),
                  SizedBox(height: context.eos.spacing.md),
                  Text(
                    'Optional / Additional Capabilities',
                    style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: context.eos.spacing.xs),
                  Text(
                    'Still Admin-created. Vendors choose whether they offer each one.',
                    style: context.eosText.bodySmall?.copyWith(
                      color: context.eosColors.onSurfaceVariant,
                    ),
                  ),
                  ..._capabilityTiles(tier: 'optional'),
                  const Divider(height: 24),
                  _AddCapabilityField(
                    enabled: !_saving,
                    errorText: _addError,
                    onAdd: (label, tier) {
                      final key = _capabilityKey(label);
                      if (key.isEmpty) {
                        setState(() => _addError = 'Enter a capability name.');
                        return false;
                      }
                      if (_draft.any((c) => c.key == key)) {
                        setState(() => _addError = 'That capability already exists.');
                        return false;
                      }
                      setState(() {
                        _addError = null;
                        _draft = [
                          ..._draft,
                          VendorCategoryCapability(
                            key: key,
                            label: label.trim(),
                            enabled: true,
                            tier: tier,
                          ),
                        ];
                      });
                      return true;
                    },
                  ),
                ],
              ),
            ),
            footer: Material(
              elevation: 8,
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(EosSpacing.lg, 12, EosSpacing.lg, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (dirty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            'You have unsaved changes.',
                            style: context.eosText.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: EosColors.plum,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          if (dirty) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving ? null : discardLocalChanges,
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: !dirty || _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('SAVE CHANGES'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _capabilityTiles({required String tier}) {
    final indexes = <int>[];
    for (var i = 0; i < _draft.length; i++) {
      if (_draft[i].tier == tier) indexes.add(i);
    }
    if (indexes.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.only(top: context.eos.spacing.xs, bottom: context.eos.spacing.sm),
          child: Text(
            tier == 'core' ? 'No core capabilities yet.' : 'No optional capabilities yet.',
            style: context.eosText.bodyMedium?.copyWith(color: context.eosColors.onSurfaceVariant),
          ),
        ),
      ];
    }
    return [
      for (final i in indexes)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_draft[i].label),
          subtitle: Text(
            '${_draft[i].key} · ${tier == 'core' ? 'Core' : 'Optional'}',
            style: context.eosText.bodySmall,
          ),
          value: _draft[i].enabled,
          secondary: IconButton(
            tooltip: tier == 'core' ? 'Move to Optional' : 'Move to Core',
            icon: Icon(tier == 'core' ? Icons.arrow_downward : Icons.arrow_upward, size: 18),
            onPressed: _saving
                ? null
                : () => setState(() {
                      _draft = [
                        for (var j = 0; j < _draft.length; j++)
                          if (j == i)
                            _draft[j].copyWith(tier: tier == 'core' ? 'optional' : 'core')
                          else
                            _draft[j],
                      ];
                    }),
          ),
          onChanged: _saving
              ? null
              : (v) => setState(() {
                    _draft = [
                      for (var j = 0; j < _draft.length; j++)
                        if (j == i) _draft[j].copyWith(enabled: v ?? false) else _draft[j],
                    ];
                  }),
        ),
    ];
  }
}

bool _capabilityListsEqual(List<VendorCategoryCapability> a, List<VendorCategoryCapability> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].key != b[i].key ||
        a[i].label != b[i].label ||
        a[i].enabled != b[i].enabled ||
        a[i].tier != b[i].tier) {
      return false;
    }
  }
  return true;
}

String _capabilityKey(String label) {
  return label
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

class _AddCapabilityField extends StatefulWidget {
  const _AddCapabilityField({
    required this.onAdd,
    required this.enabled,
    this.errorText,
  });

  final bool Function(String label, String tier) onAdd;
  final bool enabled;
  final String? errorText;

  @override
  State<_AddCapabilityField> createState() => _AddCapabilityFieldState();
}

class _AddCapabilityFieldState extends State<_AddCapabilityField> {
  final _controller = TextEditingController();
  String _tier = 'core';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.onAdd(_controller.text, _tier)) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Add capability', style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        SizedBox(height: context.eos.spacing.sm),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'core', label: Text('Core')),
            ButtonSegment(value: 'optional', label: Text('Optional')),
          ],
          selected: {_tier},
          onSelectionChanged: widget.enabled
              ? (s) => setState(() => _tier = s.first)
              : null,
        ),
        SizedBox(height: context.eos.spacing.sm),
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: 'Capability name',
            hintText: _tier == 'core' ? 'e.g. Sound System' : 'e.g. LED Screen',
            errorText: widget.errorText,
          ),
          onSubmitted: widget.enabled ? (_) => _submit() : null,
        ),
        SizedBox(height: context.eos.spacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: widget.enabled ? _submit : null,
            icon: const Icon(Icons.add),
            label: Text(_tier == 'core' ? 'Add Core' : 'Add Optional'),
          ),
        ),
      ],
    );
  }
}
