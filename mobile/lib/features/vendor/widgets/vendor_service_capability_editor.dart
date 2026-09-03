import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/event_config_api.dart';
import '../../../core/providers/silent_refresh.dart';
import '../../../eos/eos.dart';
import '../models/vendor_workspace_profile.dart';
import '../providers/vendor_profile_providers.dart';

class _ServiceDraft {
  _ServiceDraft({required this.status, required this.provided});

  String status;
  Map<String, bool> provided;

  _ServiceDraft copy() => _ServiceDraft(status: status, provided: Map<String, bool>.from(provided));

  bool sameAs(_ServiceDraft other) {
    if (status != other.status) return false;
    final keys = {...provided.keys, ...other.provided.keys};
    for (final key in keys) {
      if ((provided[key] == true) != (other.provided[key] == true)) return false;
    }
    return true;
  }
}

/// Vendor toggles Admin catalogue items only — no Vendor-created catalogue.
class VendorServiceCapabilityEditor extends ConsumerStatefulWidget {
  const VendorServiceCapabilityEditor({
    super.key,
    this.dark = false,
    this.onDirtyChanged,
    this.onAddServices,
  });

  final bool dark;
  final ValueChanged<bool>? onDirtyChanged;
  final VoidCallback? onAddServices;

  @override
  VendorServiceCapabilityEditorState createState() => VendorServiceCapabilityEditorState();
}

class VendorServiceCapabilityEditorState extends ConsumerState<VendorServiceCapabilityEditor> {
  final Map<String, _ServiceDraft> _persisted = {};
  final Map<String, _ServiceDraft> _drafts = {};
  bool _saving = false;
  bool _awaitingRefresh = false;

  bool get hasUnsavedChanges {
    if (_persisted.length != _drafts.length) return true;
    for (final entry in _drafts.entries) {
      final original = _persisted[entry.key];
      if (original == null || !entry.value.sameAs(original)) return true;
    }
    return false;
  }

  void discardLocalChanges() {
    _drafts
      ..clear()
      ..addAll({for (final e in _persisted.entries) e.key: e.value.copy()});
    _notifyDirty();
    if (mounted) setState(() {});
  }

  void _notifyDirty() => widget.onDirtyChanged?.call(hasUnsavedChanges);

  bool _providerMatchesPersisted(List<VendorServiceEntity> services) {
    if (services.length != _persisted.length) return false;
    for (final s in services) {
      final original = _persisted[s.id];
      if (original == null) return false;
      final incoming = _ServiceDraft(
        status: s.status,
        provided: {for (final c in s.capabilities) c.key: c.provided},
      );
      if (!incoming.sameAs(original)) return false;
    }
    return true;
  }

  void _hydrate(List<VendorServiceEntity> services) {
    if (hasUnsavedChanges) return;
    if (_awaitingRefresh) {
      if (_providerMatchesPersisted(services)) {
        _awaitingRefresh = false;
      } else {
        return;
      }
    }
    _persisted
      ..clear()
      ..addAll({
        for (final s in services)
          s.id: _ServiceDraft(
            status: s.status,
            provided: {for (final c in s.capabilities) c.key: c.provided},
          ),
      });
    _drafts
      ..clear()
      ..addAll({for (final e in _persisted.entries) e.key: e.value.copy()});
  }

  _ServiceDraft _draftFor(VendorServiceEntity service) {
    return _drafts.putIfAbsent(
      service.id,
      () => _ServiceDraft(
        status: service.status,
        provided: {for (final c in service.capabilities) c.key: c.provided},
      ),
    );
  }

  List<VendorCategoryCapability> _catalogueFor(
    VendorServiceEntity service,
    List<VendorCategoryConfig> catalogues,
  ) {
    final key = service.serviceKey.toLowerCase();
    final name = service.serviceName.toLowerCase();
    for (final cat in catalogues) {
      if (_categoryMatchesService(cat, key, name)) {
        return [for (final c in cat.capabilities) if (c.enabled) c];
      }
    }
    return const [];
  }

  List<VendorServiceCapability> _orphanedProvided(
    VendorServiceEntity service,
    List<VendorCategoryConfig> catalogues,
  ) {
    final enabledKeys = {for (final c in _catalogueFor(service, catalogues)) c.key};
    return [
      for (final c in service.capabilities)
        if (c.provided && !enabledKeys.contains(c.key)) c,
    ];
  }

  bool _categoryMatchesService(VendorCategoryConfig cat, String serviceKey, String serviceName) {
    final slug = cat.slug.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final labelKey = cat.label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final nameKey = serviceName.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    if (slug.isNotEmpty && slug == serviceKey) return true;
    if (labelKey.isNotEmpty && labelKey == serviceKey) return true;
    if (nameKey.isNotEmpty && (nameKey == slug || nameKey == labelKey)) return true;
    final label = cat.label.toLowerCase();
    if (serviceName.isNotEmpty &&
        label.isNotEmpty &&
        (serviceName.contains(label) || label.contains(serviceName))) {
      return true;
    }
    return _stemsMatch(slug, serviceKey) ||
        _stemsMatch(labelKey, serviceKey) ||
        _stemsMatch(slug, nameKey);
  }

  bool _stemsMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty || a == 'general' || b == 'general') return false;
    if (a == b) return true;
    final min = a.length < b.length ? a.length : b.length;
    if (min < 4) return false;
    final stem = min < 6 ? min : 6;
    return a.startsWith(b.substring(0, stem)) || b.startsWith(a.substring(0, stem));
  }

  List<Map<String, dynamic>> _capabilityPayload(
    VendorServiceEntity service,
    List<VendorCategoryConfig> catalogues,
  ) {
    final draft = _draftFor(service);
    final labels = <String, String>{
      for (final c in service.capabilities) c.key: c.label,
      for (final c in _catalogueFor(service, catalogues)) c.key: c.label,
    };
    final keys = {
      ..._catalogueFor(service, catalogues).map((c) => c.key),
      ...draft.provided.keys.where((k) => labels.containsKey(k)),
    };
    return [
      for (final key in keys)
        {
          'key': key,
          'label': labels[key] ?? key,
          'provided': draft.provided[key] == true,
        },
    ];
  }

  Future<void> _save(
    List<VendorServiceEntity> services,
    List<VendorCategoryConfig> catalogues,
  ) async {
    if (!hasUnsavedChanges || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(vendorProfileRepositoryProvider);
      for (final service in services) {
        final draft = _drafts[service.id];
        final original = _persisted[service.id];
        if (draft == null || original == null || draft.sameAs(original)) continue;
        await repo.patchService(
          service.id,
          status: draft.status,
          capabilities: _capabilityPayload(service, catalogues),
        );
      }
      ref.invalidate(vendorWorkspaceProfileProvider);
      if (!mounted) return;
      setState(() {
        _persisted
          ..clear()
          ..addAll({for (final e in _drafts.entries) e.key: e.value.copy()});
        _saving = false;
        _awaitingRefresh = true;
      });
      _notifyDirty();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _saveBar({required bool dirty, required VoidCallback? onSave}) {
    final unsavedStyle = widget.dark
        ? const TextStyle(color: EosColors.champagne, fontWeight: FontWeight.w600)
        : null;
    return Padding(
      padding: EdgeInsets.only(top: context.eos.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dirty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('You have unsaved changes.', style: unsavedStyle),
            ),
          Row(
            children: [
              if (dirty) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : discardLocalChanges,
                    child: Text(
                      'Cancel',
                      style: widget.dark ? const TextStyle(color: Colors.white) : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: !dirty || _saving ? null : onSave,
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
    );
  }

  List<Widget> _sectionHeader({
    required String title,
    required String subtitle,
    required TextStyle? titleStyle,
    required TextStyle? mutedStyle,
  }) {
    final headingStyle = widget.dark
        ? const TextStyle(
            color: EosColors.champagne,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.6,
          )
        : context.eosText.labelMedium?.copyWith(
            color: EosColors.plum,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          );
    return [
      const Divider(height: 24),
      Text(title.toUpperCase(), style: headingStyle ?? titleStyle),
      SizedBox(height: context.eos.spacing.xs),
      Text(subtitle, style: mutedStyle),
      SizedBox(height: context.eos.spacing.xs),
    ];
  }

  List<Widget> _includedServices({
    required VendorServiceEntity service,
    required List<VendorCategoryCapability> caps,
    required String emptyMessage,
    required TextStyle? titleStyle,
    required TextStyle? mutedStyle,
  }) {
    if (caps.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.only(top: context.eos.spacing.xs, bottom: context.eos.spacing.sm),
          child: Text(emptyMessage, style: mutedStyle),
        ),
      ];
    }
    return [
      for (final cap in caps)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          secondary: Icon(
            _draftFor(service).provided[cap.key] == true
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            size: 18,
            color: _draftFor(service).provided[cap.key] == true
                ? (widget.dark ? EosColors.champagne : EosColors.plum)
                : EosColors.slate500,
          ),
          title: Text(
            cap.label,
            style: titleStyle?.copyWith(
              fontWeight: _draftFor(service).provided[cap.key] == true
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
          subtitle: Text(
            _draftFor(service).provided[cap.key] == true ? 'Enabled' : 'Disabled',
            style: mutedStyle,
          ),
          value: _draftFor(service).provided[cap.key] == true,
          onChanged: _saving
              ? null
              : (v) {
                  setState(() {
                    _draftFor(service).provided[cap.key] = v == true;
                  });
                  _notifyDirty();
                },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final catalogues =
        ref.watch(vendorCapabilityCatalogueProvider).valueOrNull ?? const <VendorCategoryConfig>[];
    final profile = ref.watch(vendorWorkspaceProfileProvider);
    return profile.whenStable(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Could not load services: $e'),
      data: (data) {
        final services = data.services;
        _hydrate(services);
        final dirty = hasUnsavedChanges;
        final titleStyle = widget.dark
            ? const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)
            : null;
        final mutedStyle = widget.dark
            ? const TextStyle(color: Colors.white54, fontSize: 12)
            : context.eosText.labelSmall;
        if (services.isEmpty) {
          return EosSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No bookable services yet. Add service labels in Edit Profile and save — '
                  'they become bookable services here so you can toggle Admin catalogue items.',
                  style: widget.dark ? const TextStyle(color: Colors.white70) : context.eosText.bodyMedium,
                ),
                if (widget.onAddServices != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: widget.onAddServices,
                    child: Text(
                      'Open Edit Profile',
                      style: widget.dark ? const TextStyle(color: EosColors.champagne) : null,
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final service in services)
              Padding(
                padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                child: EosSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(service.serviceName, style: titleStyle ?? context.eosText.titleSmall),
                      if (service.serviceCode != null) ...[
                        SizedBox(height: context.eos.spacing.xs),
                        Text(service.serviceCode!, style: mutedStyle),
                      ],
                      SizedBox(height: context.eos.spacing.sm),
                      Text(
                        'Availability',
                        style: (titleStyle ?? context.eosText.labelMedium)?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Available for Requests', style: titleStyle),
                        subtitle: Text(
                          _draftFor(service).status == 'active'
                              ? 'Visible for new organizer requests'
                              : 'Hidden from new requests — not deleted',
                          style: mutedStyle,
                        ),
                        value: _draftFor(service).status == 'active',
                        onChanged: _saving
                            ? null
                            : (v) {
                                setState(() {
                                  _draftFor(service).status = v ? 'active' : 'inactive';
                                });
                                _notifyDirty();
                              },
                      ),
                      ...() {
                        final catalogue = _catalogueFor(service, catalogues);
                        final core = vendorCapabilitiesForTier(catalogue, 'core');
                        final additional = vendorCapabilitiesForTier(catalogue, 'optional');
                        return [
                          ..._sectionHeader(
                            title: 'Included Services',
                            subtitle: 'Admin-defined core items for this category.',
                            titleStyle: titleStyle,
                            mutedStyle: mutedStyle,
                          ),
                          ..._includedServices(
                            service: service,
                            caps: core,
                            emptyMessage:
                                'No core services have been configured for this category yet.',
                            titleStyle: titleStyle,
                            mutedStyle: mutedStyle,
                          ),
                          ..._sectionHeader(
                            title: 'Additional Services',
                            subtitle: 'Admin-defined optional items.',
                            titleStyle: titleStyle,
                            mutedStyle: mutedStyle,
                          ),
                          ..._includedServices(
                            service: service,
                            caps: additional,
                            emptyMessage:
                                'No additional services have been configured for this category yet.',
                            titleStyle: titleStyle,
                            mutedStyle: mutedStyle,
                          ),
                        ];
                      }(),
                      for (final cap in _orphanedProvided(service, catalogues))
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(cap.label, style: titleStyle),
                          subtitle: Text(
                            'Admin disabled — kept on your profile; not shown on Marketplace.',
                            style: mutedStyle,
                          ),
                          value: true,
                          onChanged: null,
                        ),
                    ],
                  ),
                ),
              ),
            _saveBar(dirty: dirty, onSave: () => _save(services, catalogues)),
          ],
        );
      },
    );
  }
}

/// Presentation helper — groups Admin catalogue by [tier] without reordering within a tier.
@visibleForTesting
List<VendorCategoryCapability> vendorCapabilitiesForTier(
  List<VendorCategoryCapability> catalogue,
  String tier,
) {
  if (tier == 'optional') {
    return [for (final c in catalogue) if (c.tier == 'optional') c];
  }
  return [for (final c in catalogue) if (c.tier != 'optional') c];
}
