import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/event_config_api.dart';
import '../../../core/api/owambe_http_client.dart';
import '../../../core/api/vendor_offerings_api.dart';
import '../../../eos/eos.dart';
import '../models/vendor_legacy_taxonomy_mapping.dart';
import '../models/vendor_offering_category_groups.dart';
import '../models/vendor_workspace_profile.dart';
import '../providers/vendor_profile_providers.dart';
import '../providers/vendor_providers.dart';

enum _OfferingsStep { businessType, services, rentals, review }

class VendorBusinessOfferingsEditor extends ConsumerStatefulWidget {
  const VendorBusinessOfferingsEditor({
    super.key,
    required this.profile,
    this.onDirtyChanged,
  });

  final VendorWorkspaceProfile profile;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  VendorBusinessOfferingsEditorState createState() => VendorBusinessOfferingsEditorState();
}

class VendorBusinessOfferingsEditorState extends ConsumerState<VendorBusinessOfferingsEditor> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _legacyExpanded = false;
  _OfferingsStep _step = _OfferingsStep.businessType;

  List<VendorBusinessCapabilityConfig> _capabilityDefs = const [];
  List<VendorCategoryConfig> _serviceCats = const [];
  List<VendorCategoryConfig> _rentalCats = const [];

  Set<String> _persistedCapabilityKeys = {};
  Set<String> _persistedServiceCategoryIds = {};
  Set<String> _persistedRentalCategoryIds = {};

  Set<String> _draftCapabilityKeys = {};
  Set<String> _draftServiceCategoryIds = {};
  Set<String> _draftRentalCategoryIds = {};

  final Set<String> _dismissedLegacyLabels = {};

  bool get hasUnsavedChanges {
    if (!_setEq(_persistedCapabilityKeys, _draftCapabilityKeys)) return true;
    if (!_setEq(_persistedServiceCategoryIds, _draftServiceCategoryIds)) return true;
    if (!_setEq(_persistedRentalCategoryIds, _draftRentalCategoryIds)) return true;
    return false;
  }

  bool _setEq(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

  void discardLocalChanges() {
    setState(() {
      _draftCapabilityKeys = {..._persistedCapabilityKeys};
      _draftServiceCategoryIds = {..._persistedServiceCategoryIds};
      _draftRentalCategoryIds = {..._persistedRentalCategoryIds};
      _step = _OfferingsStep.businessType;
      _legacyExpanded = false;
    });
    _notifyDirty();
  }

  void _notifyDirty() => widget.onDirtyChanged?.call(hasUnsavedChanges);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant VendorBusinessOfferingsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.vendorId != widget.profile.vendorId) {
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vendorId = await ref.read(canonicalVendorIdProvider.future);
      if (vendorId.isEmpty) throw StateError('Vendor identity is not resolved');

      final http = createOwambeHttpClient();
      final cfgApi = EventConfigApi(http);
      final offApi = VendorOfferingsApi(http);

      final results = await Future.wait([
        cfgApi.listPublicBusinessCapabilities(),
        cfgApi.listPublicOfferingCategories(kind: 'service'),
        cfgApi.listPublicOfferingCategories(kind: 'rental'),
        offApi.getConfig(vendorId),
      ]);

      final caps = results[0] as List<VendorBusinessCapabilityConfig>;
      final services = results[1] as List<VendorCategoryConfig>;
      final rentals = results[2] as List<VendorCategoryConfig>;
      final config = results[3] as Map<String, dynamic>;

      final capabilityKeys = {
        for (final k in (config['capabilityKeys'] as List<dynamic>? ?? const [])) k.toString(),
      };
      final serviceIds = <String>{};
      final rentalIds = <String>{};
      for (final raw in (config['categories'] as List<dynamic>? ?? const [])) {
        if (raw is! Map) continue;
        final id = (raw['id'] ?? raw['categoryId'] ?? '').toString();
        if (id.isEmpty) continue;
        final kind = (raw['offeringKind'] ?? raw['offering_kind'] ?? '').toString().toLowerCase();
        if (kind == 'rental') {
          rentalIds.add(id);
        } else {
          serviceIds.add(id);
        }
      }

      if (!mounted) return;
      setState(() {
        _capabilityDefs = caps.where((c) => c.isActive).toList();
        _serviceCats = services.where((c) => c.isActive).toList();
        _rentalCats = rentals.where((c) => c.isActive).toList();
        _persistedCapabilityKeys = capabilityKeys;
        _persistedServiceCategoryIds = serviceIds;
        _persistedRentalCategoryIds = rentalIds;
        _draftCapabilityKeys = {...capabilityKeys};
        _draftServiceCategoryIds = {...serviceIds};
        _draftRentalCategoryIds = {...rentalIds};
        _loading = false;
        _step = _OfferingsStep.businessType;
      });
      _notifyDirty();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Set<String> get _selectedCategoryIds => {
        ..._draftServiceCategoryIds,
        ..._draftRentalCategoryIds,
      };

  List<LegacyMappingSuggestion> get _legacySuggestions {
    final labels = collectLegacyLabels(
      categoryCsv: widget.profile.category,
      servicesOffered: widget.profile.servicesOffered,
      subcategory: widget.profile.subcategory,
    );
    return suggestLegacyMappings(
      legacyLabels: labels,
      serviceCategories: _serviceCats,
      rentalCategories: _rentalCats,
      alreadySelectedCategoryIds: _selectedCategoryIds,
    ).where((s) => !_dismissedLegacyLabels.contains(s.legacyLabel)).toList();
  }

  Set<String> get _legacyLabels {
    return collectLegacyLabels(
      categoryCsv: widget.profile.category,
      servicesOffered: widget.profile.servicesOffered,
      subcategory: widget.profile.subcategory,
    );
  }

  List<_OfferingsStep> get _visibleSteps {
    return [
      _OfferingsStep.businessType,
      if (_draftCapabilityKeys.contains('SERVICE_PROVIDER')) _OfferingsStep.services,
      if (_draftCapabilityKeys.contains('RENTAL_PROVIDER')) _OfferingsStep.rentals,
      _OfferingsStep.review,
    ];
  }

  String _stepTitle(_OfferingsStep step) => switch (step) {
        _OfferingsStep.businessType => 'Business Type',
        _OfferingsStep.services => 'Choose Services',
        _OfferingsStep.rentals => 'Choose Rentals',
        _OfferingsStep.review => 'Review & Save',
      };

  void _goNext() {
    final steps = _visibleSteps;
    final i = steps.indexOf(_step);
    if (i < 0 || i >= steps.length - 1) return;
    setState(() => _step = steps[i + 1]);
  }

  void _goBack() {
    final steps = _visibleSteps;
    final i = steps.indexOf(_step);
    if (i <= 0) return;
    setState(() => _step = steps[i - 1]);
  }

  void _confirmSuggestion(LegacyMappingSuggestion suggestion) {
    final cat = suggestion.suggestedCategory;
    if (cat == null) return;
    setState(() {
      final cap = capabilityForCategory(cat);
      if (cap != null) _draftCapabilityKeys.add(cap);
      if (cat.offeringKind.toLowerCase() == 'rental') {
        _draftRentalCategoryIds.add(cat.id);
      } else {
        _draftServiceCategoryIds.add(cat.id);
      }
      _dismissedLegacyLabels.add(suggestion.legacyLabel);
    });
    _notifyDirty();
  }

  void _resolveAmbiguousAsRental(LegacyMappingSuggestion suggestion, VendorCategoryConfig category) {
    setState(() {
      _draftCapabilityKeys.add('RENTAL_PROVIDER');
      _draftRentalCategoryIds.add(category.id);
      _dismissedLegacyLabels.add(suggestion.legacyLabel);
    });
    _notifyDirty();
  }

  void _resolveAmbiguousAsService(LegacyMappingSuggestion suggestion, VendorCategoryConfig category) {
    setState(() {
      _draftCapabilityKeys.add('SERVICE_PROVIDER');
      _draftServiceCategoryIds.add(category.id);
      _dismissedLegacyLabels.add(suggestion.legacyLabel);
    });
    _notifyDirty();
  }

  void _dismissLegacyLabel(String label) {
    setState(() => _dismissedLegacyLabels.add(label));
  }

  void _toggleCapability(String key, bool selected) {
    setState(() {
      if (selected) {
        _draftCapabilityKeys.add(key);
      } else {
        _draftCapabilityKeys.remove(key);
        if (key == 'SERVICE_PROVIDER') _draftServiceCategoryIds.clear();
        if (key == 'RENTAL_PROVIDER') _draftRentalCategoryIds.clear();
        if (!(_visibleSteps.contains(_step))) {
          _step = _OfferingsStep.businessType;
        }
      }
    });
    _notifyDirty();
  }

  void _toggleServiceCategory(String id, bool selected) {
    setState(() {
      if (selected) {
        _draftServiceCategoryIds.add(id);
        _draftCapabilityKeys.add('SERVICE_PROVIDER');
      } else {
        _draftServiceCategoryIds.remove(id);
      }
    });
    _notifyDirty();
  }

  void _toggleRentalCategory(String id, bool selected) {
    setState(() {
      if (selected) {
        _draftRentalCategoryIds.add(id);
        _draftCapabilityKeys.add('RENTAL_PROVIDER');
      } else {
        _draftRentalCategoryIds.remove(id);
      }
    });
    _notifyDirty();
  }

  Future<void> saveChanges() async {
    if (!hasUnsavedChanges || _saving) return;
    setState(() => _saving = true);
    try {
      final vendorId = await ref.read(canonicalVendorIdProvider.future);
      final api = VendorOfferingsApi(createOwambeHttpClient());

      final capabilityKeys = _draftCapabilityKeys.toList()..sort();
      final categoryIds = [
        if (_draftCapabilityKeys.contains('SERVICE_PROVIDER')) ..._draftServiceCategoryIds,
        if (_draftCapabilityKeys.contains('RENTAL_PROVIDER')) ..._draftRentalCategoryIds,
      ];

      await api.putCapabilities(vendorId, capabilityKeys);
      await api.putCategories(vendorId, categoryIds.toList());

      ref.invalidate(vendorWorkspaceProfileProvider);

      if (!mounted) return;
      setState(() {
        _persistedCapabilityKeys = {..._draftCapabilityKeys};
        _persistedServiceCategoryIds = {..._draftServiceCategoryIds};
        _persistedRentalCategoryIds = {..._draftRentalCategoryIds};
        _saving = false;
      });
      _notifyDirty();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business type & offerings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save offerings: $e')),
      );
    }
  }

  Widget _stepIndicator(TextStyle? mutedStyle) {
    final steps = _visibleSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step ${steps.indexOf(_step) + 1} of ${steps.length} · ${_stepTitle(_step)}',
          style: mutedStyle?.copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: context.eos.spacing.sm),
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) Expanded(child: Divider(color: EosColors.slate300, height: 1)),
              CircleAvatar(
                radius: 10,
                backgroundColor: steps[i] == _step || steps.indexOf(_step) > i
                    ? EosColors.plum
                    : EosColors.slate300,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _navBar({required bool showSave}) {
    final steps = _visibleSteps;
    final i = steps.indexOf(_step);
    final canBack = i > 0;
    final canNext = i >= 0 && i < steps.length - 1;
    return Padding(
      padding: EdgeInsets.only(top: context.eos.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasUnsavedChanges && showSave)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'You have unsaved changes.',
                style: context.eosText.bodySmall?.copyWith(
                  color: EosColors.plum,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Row(
            children: [
              if (canBack)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _goBack,
                    child: const Text('Back'),
                  ),
                ),
              if (canBack) const SizedBox(width: 12),
              if (canNext)
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : _goNext,
                    child: const Text('Continue'),
                  ),
                ),
              if (showSave) ...[
                if (canBack || canNext) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: !hasUnsavedChanges || _saving ? null : saveChanges,
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
            ],
          ),
          if (hasUnsavedChanges && showSave) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : discardLocalChanges,
              child: const Text('Discard changes'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _businessTypeStep(TextStyle? mutedStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What does your business provide?', style: context.eosText.bodyMedium),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'You may select Service Provider, Rental Provider, or both.',
          style: mutedStyle,
        ),
        SizedBox(height: context.eos.spacing.md),
        for (final cap in _capabilityDefs)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _draftCapabilityKeys.contains(cap.capabilityKey),
            onChanged: _saving
                ? null
                : (v) => _toggleCapability(cap.capabilityKey, v == true),
            title: Text(cap.label, style: context.eosText.bodyMedium),
            subtitle: cap.description.isEmpty
                ? null
                : Text(cap.description, style: mutedStyle),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        _navBar(showSave: false),
      ],
    );
  }

  Widget _groupedCategoryStep({
    required String title,
    required String subtitle,
    required List<VendorCategoryGroup> groups,
    required Set<String> selectedIds,
    required void Function(String id, bool selected) onToggle,
    required TextStyle? mutedStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.eosText.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        SizedBox(height: context.eos.spacing.xs),
        Text(subtitle, style: mutedStyle),
        SizedBox(height: context.eos.spacing.md),
        for (final group in groups) ...[
          Text(
            group.title,
            style: context.eosText.labelMedium?.copyWith(
              color: EosColors.plum,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: context.eos.spacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in group.categories)
                FilterChip(
                  label: Text(c.label),
                  selected: selectedIds.contains(c.id),
                  onSelected: _saving ? null : (v) => onToggle(c.id, v),
                ),
            ],
          ),
          SizedBox(height: context.eos.spacing.md),
        ],
        if (groups.isEmpty) Text('No categories available from Super Admin.', style: mutedStyle),
        _navBar(showSave: false),
      ],
    );
  }

  Widget _legacyBanner(TextStyle? mutedStyle) {
    final labels = _legacyLabels;
    if (labels.isEmpty) return const SizedBox.shrink();
    final pending = _legacySuggestions.where((s) => s.confidence != LegacyMappingConfidence.none).length;
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'We found existing business information',
                  style: context.eosText.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _legacyExpanded = !_legacyExpanded),
                child: Text(_legacyExpanded ? 'Hide' : 'Review'),
              ),
            ],
          ),
          Text(
            pending > 0
                ? '$pending item(s) can be mapped to the catalogue when you are ready. '
                    'Legacy values stay preserved until you save.'
                : 'Legacy values (${labels.join(', ')}) are preserved.',
            style: mutedStyle,
          ),
          if (_legacyExpanded) ...[
            SizedBox(height: context.eos.spacing.sm),
            ..._legacySuggestions
                .where((s) => s.confidence != LegacyMappingConfidence.none)
                .map((s) => _legacyCard(s, mutedStyle)),
            if (_legacySuggestions.every((s) => s.confidence == LegacyMappingConfidence.none))
              Text('No remaining mappings to review.', style: mutedStyle),
          ],
        ],
      ),
    );
  }

  Widget _legacyCard(LegacyMappingSuggestion s, TextStyle? mutedStyle) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 16),
          Text('Existing: ${s.legacyLabel}', style: context.eosText.bodyMedium),
          SizedBox(height: context.eos.spacing.xs),
          if (s.confidence == LegacyMappingConfidence.high && s.suggestedCategory != null) ...[
            Text(
              'Suggested: ${s.suggestedCategory!.offeringKind == 'rental' ? 'Rental' : 'Service'} → ${s.suggestedCategory!.label}',
              style: mutedStyle,
            ),
            SizedBox(height: context.eos.spacing.sm),
            Row(
              children: [
                FilledButton(
                  onPressed: _saving ? null : () => _confirmSuggestion(s),
                  child: const Text('Confirm'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _saving ? null : () => _dismissLegacyLabel(s.legacyLabel),
                  child: const Text('Leave unchanged'),
                ),
              ],
            ),
          ] else ...[
            Text(
              s.legacyLabel.toLowerCase() == 'rentals' ||
                      s.legacyLabel.toLowerCase() == 'rentals & equipment'
                  ? 'Choose how this applies to your business:'
                  : 'Choose a canonical category or leave unchanged:',
              style: mutedStyle,
            ),
            if (s.suggestedCategory != null) ...[
              SizedBox(height: context.eos.spacing.xs),
              Text('Suggested: Service → ${s.suggestedCategory!.label}', style: mutedStyle),
              SizedBox(height: context.eos.spacing.xs),
              FilledButton(
                onPressed: _saving ? null : () => _confirmSuggestion(s),
                child: const Text('Confirm suggestion'),
              ),
            ],
            if (_rentalCats.isNotEmpty) ...[
              SizedBox(height: context.eos.spacing.sm),
              Text('Rental categories', style: context.eosText.labelSmall),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in groupRentalCategories(_rentalCats).expand((g) => g.categories))
                    ActionChip(
                      label: Text(c.label),
                      onPressed: _saving ? null : () => _resolveAmbiguousAsRental(s, c),
                    ),
                ],
              ),
            ],
            if (_serviceCats.isNotEmpty) ...[
              SizedBox(height: context.eos.spacing.sm),
              Text('Service categories', style: context.eosText.labelSmall),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in groupServiceCategories(_serviceCats).expand((g) => g.categories))
                    ActionChip(
                      label: Text(c.label),
                      onPressed: _saving ? null : () => _resolveAmbiguousAsService(s, c),
                    ),
                ],
              ),
            ],
            TextButton(
              onPressed: _saving ? null : () => _dismissLegacyLabel(s.legacyLabel),
              child: const Text('Neither / leave unchanged'),
            ),
          ],
        ],
      ),
    );
  }

  String _capabilityLabel(String key) {
    for (final c in _capabilityDefs) {
      if (c.capabilityKey == key) return c.label;
    }
    return key;
  }

  Widget _reviewStep(TextStyle? mutedStyle) {
    String labelFor(String id, List<VendorCategoryConfig> cats) {
      for (final c in cats) {
        if (c.id == id) return c.label;
      }
      return id;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review your selections', style: context.eosText.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Save applies business type and categories only. Configure availability for each '
          'bookable service in the next section.',
          style: mutedStyle,
        ),
        SizedBox(height: context.eos.spacing.md),
        _legacyBanner(mutedStyle),
        SizedBox(height: context.eos.spacing.md),
        Text('Business type', style: context.eosText.labelMedium),
        SizedBox(height: context.eos.spacing.xs),
        if (_draftCapabilityKeys.isEmpty)
          Text('None selected', style: mutedStyle)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in _draftCapabilityKeys)
                Chip(label: Text(_capabilityLabel(key))),
            ],
          ),
        if (_draftCapabilityKeys.contains('SERVICE_PROVIDER')) ...[
          SizedBox(height: context.eos.spacing.md),
          Text('Service categories (${_draftServiceCategoryIds.length})', style: context.eosText.labelMedium),
          SizedBox(height: context.eos.spacing.xs),
          if (_draftServiceCategoryIds.isEmpty)
            Text('None selected', style: mutedStyle)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in _draftServiceCategoryIds)
                  Chip(label: Text(labelFor(id, _serviceCats))),
              ],
            ),
        ],
        if (_draftCapabilityKeys.contains('RENTAL_PROVIDER')) ...[
          SizedBox(height: context.eos.spacing.md),
          Text('Rental categories (${_draftRentalCategoryIds.length})', style: context.eosText.labelMedium),
          SizedBox(height: context.eos.spacing.xs),
          if (_draftRentalCategoryIds.isEmpty)
            Text('None selected', style: mutedStyle)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in _draftRentalCategoryIds)
                  Chip(label: Text(labelFor(id, _rentalCats))),
              ],
            ),
        ],
        _navBar(showSave: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mutedStyle = context.eosText.bodySmall?.copyWith(color: EosColors.slate500);

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Could not load business offerings: $_error', style: mutedStyle),
          TextButton(onPressed: _reload, child: const Text('Retry')),
        ],
      );
    }

    // Keep step valid when capabilities change.
    if (!_visibleSteps.contains(_step)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _step = _OfferingsStep.businessType);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Business Type & Offerings', style: context.eosText.titleSmall),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Set up what you provide in short steps. Existing profile data is never wiped.',
          style: mutedStyle,
        ),
        SizedBox(height: context.eos.spacing.md),
        _stepIndicator(mutedStyle),
        SizedBox(height: context.eos.spacing.lg),
        switch (_step) {
          _OfferingsStep.businessType => _businessTypeStep(mutedStyle),
          _OfferingsStep.services => _groupedCategoryStep(
              title: 'Choose Services',
              subtitle: 'Select the Super Admin service categories you offer.',
              groups: groupServiceCategories(_serviceCats),
              selectedIds: _draftServiceCategoryIds,
              onToggle: _toggleServiceCategory,
              mutedStyle: mutedStyle,
            ),
          _OfferingsStep.rentals => _groupedCategoryStep(
              title: 'Choose Rentals',
              subtitle: 'Select the Super Admin rental categories you offer.',
              groups: groupRentalCategories(_rentalCats),
              selectedIds: _draftRentalCategoryIds,
              onToggle: _toggleRentalCategory,
              mutedStyle: mutedStyle,
            ),
          _OfferingsStep.review => _reviewStep(mutedStyle),
        },
      ],
    );
  }
}
