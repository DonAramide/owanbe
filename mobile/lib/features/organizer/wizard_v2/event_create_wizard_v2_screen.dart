import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/event_config_api.dart';
import '../../../core/utils/currency_input.dart';
import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../shared/models/event_access_mode.dart';
import '../../../portals/customer/closing/event_closing_actions.dart';
import '../data/organizer_persistence.dart';
import '../models/organizer_models.dart';
import '../providers/event_config_providers.dart';
import '../providers/organizer_providers.dart';
import 'event_publish_readiness.dart';
import 'event_wizard_autosave.dart';
import 'widgets/celebration_type_cards.dart';
import 'widgets/wizard_celebrant_image_picker.dart';
import 'widgets/wizard_service_picker.dart';
import 'widgets/wizard_venue_budget_widgets.dart';

/// Celebration-first event creation wizard (OWANBE EVENT CREATION V2).
class EventCreateWizardV2Screen extends ConsumerStatefulWidget {
  const EventCreateWizardV2Screen({super.key});

  @override
  ConsumerState<EventCreateWizardV2Screen> createState() => _EventCreateWizardV2ScreenState();
}

class _EventCreateWizardV2ScreenState extends ConsumerState<EventCreateWizardV2Screen> {
  int _step = 0;
  EventCategoryConfig? _category;
  EventAccessMode? _accessOverride;
  final _title = TextEditingController();
  final _tagline = TextEditingController();
  final _description = TextEditingController();
  final _venue = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController(text: 'Lagos');
  final _guests = TextEditingController(text: '150');
  final _budget = TextEditingController(text: '5,000,000');
  DateTime _starts = DateTime.now().add(const Duration(days: 60));
  DateTime _ends = DateTime.now().add(const Duration(days: 60, hours: 6));
  int _venueMethod = 0;
  double? _lat;
  double? _lng;
  String? _placeId;
  bool _saving = false;
  bool _venueDeferred = false;
  String _state = 'Lagos';
  String _lga = 'Eti-Osa';
  String? _selectedCenterId;
  final Set<String> _requiredServices = {};
  final Set<String> _selectedTags = {};
  Uint8List? _celebrantImageBytes;
  String? _celebrantImageUrl;
  List<WizardBudgetSlice> _budgetSlices = [];
  bool _budgetSlicesCustomized = false;
  int _lastAutoBudgetMinor = 0;
  String _lastAutoCategorySlug = '';
  List<OrganizerTicketTier> _ticketTiers = [];
  String _language = 'en';
  int _ageMin = 0;
  String _listingVisibility = 'invite_only';
  VenueType _venueType = VenueType.physical;
  bool _registrationEnabled = true;
  bool _checkInEnabled = true;
  final _banner = TextEditingController(text: 'Default banner');
  String _themeColor = '#4B2C6F';
  String _templateSlug = '';
  String? _serverEventId;
  bool _hydrated = false;

  EventAccessMode get _accessMode =>
      _accessOverride ?? _category?.accessMode ?? EventAccessMode.privateInvitation;

  bool get _isPublic => _accessMode == EventAccessMode.publicTicketed;

  List<String> get _stepLabels {
    final steps = ['Celebrate', 'Details', 'Venue', 'Budget', 'Services'];
    if (_isPublic) steps.add('Tickets');
    steps.add('Review');
    return steps;
  }

  /// Select celebration type and advance from the Celebrate step.
  void _onCelebrationTypeSelected(EventCategoryConfig c) {
    _category = c;
    _accessOverride = null;
    _listingVisibility =
        c.accessMode == EventAccessMode.publicTicketed ? 'public' : 'invite_only';
    _autosaveLocal();
    final labels = _stepLabels;
    final stepSafe = _step.clamp(0, labels.length - 1);
    if (labels[stepSafe] == 'Celebrate') {
      _next(labels);
    } else {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _hydrate();
    });
  }

  Future<void> _hydrate() async {
    final seed = ref.read(eventDuplicateSeedProvider);
    if (seed != null) {
      _applySeed(seed);
      clearDuplicateSeed(ref);
    } else {
      final local = await ref.read(wizardAutosaveProvider.notifier).loadLocal();
      if (local != null && local.draft.title.isNotEmpty && mounted) {
        final resume = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Resume draft?'),
            content: Text('Continue editing "${local.draft.title}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Discard')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Resume')),
            ],
          ),
        );
        if (resume == true) {
          _applySeed(local.draft);
          _serverEventId = local.serverEventId;
          _step = local.wizardStep;
          if (local.serverEventId != null) {
            ref.read(wizardAutosaveProvider.notifier).bindServerEvent(local.serverEventId!);
          }
          ref.read(wizardAutosaveProvider.notifier).setWizardStep(local.wizardStep);
        } else {
          // Discard local + soft-cancel server draft if linked.
          final serverId = local.serverEventId;
          ref.read(wizardAutosaveProvider.notifier).clear();
          if (serverId != null && serverId.isNotEmpty) {
            try {
              await discardServerDraft(ref, serverId);
            } catch (_) {
              // Local cleared; server discard best-effort on resume-decline.
            }
          }
        }
      }
    }
    _hydrated = true;
    if (mounted) setState(() {});
  }

  void _applySeed(EventWizardV2Draft seed) {
    _title.text = seed.title;
    _tagline.text = seed.tagline;
    _description.text = seed.description;
    _city.text = seed.city.isNotEmpty ? seed.city : _city.text;
    _venue.text = seed.venueName;
    _address.text = seed.venueAddress;
    _guests.text = '${seed.expectedGuests}';
    _budget.text = nairaInputFromMinor(seed.budgetMinor);
    _starts = seed.startsAt;
    _ends = seed.endsAt.isAfter(seed.startsAt) ? seed.endsAt : seed.startsAt.add(const Duration(hours: 6));
    _venueDeferred = seed.venueDeferred;
    _state = seed.state.isNotEmpty ? seed.state : _state;
    _lga = seed.lga.isNotEmpty ? seed.lga : _lga;
    _lat = seed.venueLatitude;
    _lng = seed.venueLongitude;
    _placeId = seed.googlePlaceId;
    _celebrantImageUrl = seed.celebrantImageUrl;
    _language = seed.language;
    _ageMin = seed.ageRestrictionMin;
    _listingVisibility = seed.listingVisibility;
    _venueType = seed.venueType;
    _registrationEnabled = seed.registrationEnabled;
    _checkInEnabled = seed.checkInEnabled;
    _banner.text = seed.bannerLabel;
    _themeColor = seed.themeColor;
    _templateSlug = seed.selectedTemplateSlug;
    _accessOverride = seed.eventAccessMode;
    _requiredServices
      ..clear()
      ..addAll(seed.requiredServices);
    _selectedTags
      ..clear()
      ..addAll(seed.tags);
    _ticketTiers = List.of(seed.ticketTiers);
    if (seed.categorySlug.isNotEmpty) {
      _category = EventCategoryConfig(
        id: seed.categorySlug,
        slug: seed.categorySlug,
        label: seed.categoryLabel.isNotEmpty ? seed.categoryLabel : seed.categorySlug,
        iconKey: 'event',
        accessMode: seed.eventAccessMode,
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _tagline.dispose();
    _description.dispose();
    _venue.dispose();
    _address.dispose();
    _city.dispose();
    _guests.dispose();
    _budget.dispose();
    _banner.dispose();
    super.dispose();
  }

  int get _guestCount => int.tryParse(_guests.text.replaceAll(',', '')) ?? 0;
  int get _budgetMinor => parseNairaInputToMinor(_budget.text);

  EventWizardV2Draft _buildDraft() {
    final slug = _category?.slug ?? '';
    return EventWizardV2Draft(
      categorySlug: slug,
      categoryLabel: _category?.label ?? '',
      eventAccessMode: _accessMode,
      title: _title.text.trim(),
      tagline: _tagline.text.trim(),
      description: _description.text.trim(),
      city: _city.text.trim(),
      venueName: _venueDeferred ? '' : _venue.text.trim(),
      venueAddress: _venueDeferred ? '' : _address.text.trim(),
      venueLatitude: _venueDeferred ? null : _lat,
      venueLongitude: _venueDeferred ? null : _lng,
      googlePlaceId: _venueDeferred ? null : _placeId,
      budgetMinor: _budgetMinor,
      expectedGuests: _guestCount,
      tags: _selectedTags.toList(),
      startsAt: _starts,
      endsAt: _ends,
      budgetAllocation: _budgetSlices.map((s) => s.toMap(_budgetMinor)).toList(),
      requiredServices: _requiredServices.toList(),
      venueDeferred: _venueDeferred,
      state: _state,
      lga: _lga,
      celebrantImageUrl: _celebrantImageUrl,
      ticketTiers: _ticketTiers,
      language: _language,
      ageRestrictionMin: _ageMin,
      listingVisibility: _listingVisibility,
      venueType: _venueType,
      registrationEnabled: _registrationEnabled,
      checkInEnabled: _checkInEnabled,
      bannerLabel: _banner.text.trim().isEmpty ? 'Default banner' : _banner.text.trim(),
      themeColor: _themeColor,
      selectedTemplateSlug: _templateSlug,
    );
  }

  void _autosaveLocal() {
    if (!_hydrated) return;
    ref.read(wizardAutosaveProvider.notifier).persistLocal(
          _buildDraft(),
          serverEventId: _serverEventId,
          wizardStep: _step,
        );
  }

  Future<void> _discard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard draft?'),
        content: const Text('Your unsaved celebration details will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final serverId = _serverEventId;
    ref.read(wizardAutosaveProvider.notifier).clear();
    if (serverId != null && serverId.isNotEmpty) {
      try {
        await discardServerDraft(ref, serverId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Draft closed locally. Server discard failed: $e')),
          );
        }
      }
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/organizer');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(eventCategoriesProvider);
    final autosave = ref.watch(wizardAutosaveProvider);
    final labels = _stepLabels;
    final stepSafe = _step.clamp(0, labels.length - 1);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _discard();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: context.eosCanvas,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _discard),
          title: Text('Create celebration · ${labels[stepSafe]}'),
          actions: [
            if (autosave.lastSavedAt != null)
              Padding(
                padding: EdgeInsets.only(right: context.eos.spacing.sm),
                child: Center(
                  child: Text(
                    autosave.dirty ? 'Saving…' : 'Draft saved',
                    style: context.eosText.labelSmall,
                  ),
                ),
              ),
            TextButton(onPressed: _saving ? null : _saveDraftOnly, child: const Text('Save draft')),
          ],
        ),
        body: Column(
          children: [
            _progressBar(labels, stepSafe),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.eos.spacing.lg),
                child: categoriesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => CelebrationTypeCards(
                    categories: EventCategoryConfig.fallbackDefaults,
                    selectedSlug: _category?.slug,
                    onSelected: _onCelebrationTypeSelected,
                  ),
                  data: (cats) => _stepBody(cats, labels, stepSafe),
                ),
              ),
            ),
            _footer(labels, stepSafe),
          ],
        ),
      ),
    );
  }

  Widget _progressBar(List<String> labels, int step) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.eos.spacing.lg, 0, context.eos.spacing.lg, context.eos.spacing.md),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (step + 1) / labels.length,
              minHeight: 6,
              backgroundColor: EosColors.champagne.withValues(alpha: 0.4),
              color: EosColors.plum,
            ),
          ),
          SizedBox(height: context.eos.spacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Padding(
                    padding: EdgeInsets.only(right: context.eos.spacing.xs),
                    child: FilterChip(
                      label: Text(labels[i]),
                      selected: i == step,
                      onSelected: i <= step
                          ? (_) => setState(() {
                                if (labels[i] == 'Budget') _syncBudgetSlicesIfNeeded();
                                _step = i;
                              })
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBody(List<EventCategoryConfig> categories, List<String> labels, int step) {
    final name = labels[step];
    return switch (name) {
      'Celebrate' => _celebrateStep(categories),
      'Details' => _detailsStep(),
      'Venue' => _venueStep(),
      'Budget' => _budgetStep(),
      'Services' => _servicesStep(),
      'Tickets' => _ticketsStep(),
      _ => _reviewStep(),
    };
  }

  Widget _celebrateStep(List<EventCategoryConfig> categories) {
    return ListView(
      children: [
        Text('What are you celebrating?', style: context.eosText.headlineMedium),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Pick a celebration type — we tailor guests, vendors, and access mode.',
          style: context.eosText.bodyMedium?.copyWith(color: EosColors.slate500),
        ),
        SizedBox(height: context.eos.spacing.lg),
        CelebrationTypeCards(
          categories: categories,
          selectedSlug: _category?.slug,
          onSelected: _onCelebrationTypeSelected,
        ),
      ],
    );
  }

  Widget _detailsStep() {
    final isPrivate = !_isPublic;
    final tagsAsync = ref.watch(eventTagsProvider);
    return ListView(
      children: [
        Text('Tell us about your celebration', style: context.eosText.headlineSmall),
        SizedBox(height: context.eos.spacing.md),
        WizardCelebrantImagePicker(
          imageBytes: _celebrantImageBytes,
          imageUrl: _celebrantImageUrl,
          onPicked: (bytes) => setState(() {
            _celebrantImageBytes = bytes;
            _autosaveLocal();
          }),
          onClear: () => setState(() {
            _celebrantImageBytes = null;
            _celebrantImageUrl = null;
            _autosaveLocal();
          }),
        ),
        SizedBox(height: context.eos.spacing.md),
        EosTextField(
          controller: _title,
          label: 'Event name',
          hint: 'Ada & Emeka\'s Wedding',
          onChanged: (_) => _autosaveLocal(),
        ),
        SizedBox(height: context.eos.spacing.md),
        EosTextField(
          controller: _tagline,
          label: 'Tagline',
          hint: 'Love, laughter, and jollof',
          onChanged: (_) => _autosaveLocal(),
        ),
        SizedBox(height: context.eos.spacing.md),
        EosTextField(
          controller: _description,
          label: 'Description',
          hint: 'Share what makes this celebration special…',
          maxLines: 4,
          onChanged: (_) => _autosaveLocal(),
        ),
        SizedBox(height: context.eos.spacing.md),
        Text('Event type / visibility', style: context.eosText.titleSmall),
        SizedBox(height: context.eos.spacing.xs),
        Wrap(
          spacing: context.eos.spacing.xs,
          children: [
            ChoiceChip(
              label: const Text('Invite only'),
              selected: _listingVisibility == 'invite_only',
              onSelected: (_) => setState(() {
                _listingVisibility = 'invite_only';
                _accessOverride = EventAccessMode.privateInvitation;
                _autosaveLocal();
              }),
            ),
            ChoiceChip(
              label: const Text('Public tickets'),
              selected: _listingVisibility == 'public',
              onSelected: (_) => setState(() {
                _listingVisibility = 'public';
                _accessOverride = EventAccessMode.publicTicketed;
                _autosaveLocal();
              }),
            ),
            ChoiceChip(
              label: const Text('Hidden'),
              selected: _listingVisibility == 'hidden',
              onSelected: (_) => setState(() {
                _listingVisibility = 'hidden';
                _accessOverride = EventAccessMode.privateInvitation;
                _autosaveLocal();
              }),
            ),
          ],
        ),
        SizedBox(height: context.eos.spacing.sm),
        Text(
          'Scheduled publish is not available yet — publish remains a manual action from the Event Workspace.',
          style: context.eosText.bodySmall?.copyWith(color: EosColors.slate500),
        ),
        SizedBox(height: context.eos.spacing.md),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Starts'),
          subtitle: Text(_fmt(_starts)),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: () => _pickDateTime(isEnd: false),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ends'),
          subtitle: Text(_fmt(_ends)),
          trailing: const Icon(Icons.event_outlined),
          onTap: () => _pickDateTime(isEnd: true),
        ),
        if (!_ends.isAfter(_starts))
          Text('End must be after start.', style: context.eosText.bodySmall?.copyWith(color: Colors.red)),
        SizedBox(height: context.eos.spacing.md),
        EosSelectField<String>(
          label: 'Language',
          value: _language,
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'yo', child: Text('Yoruba')),
            DropdownMenuItem(value: 'ig', child: Text('Igbo')),
            DropdownMenuItem(value: 'ha', child: Text('Hausa')),
            DropdownMenuItem(value: 'pcm', child: Text('Pidgin')),
          ],
          onChanged: (v) => setState(() {
            _language = v ?? 'en';
            _autosaveLocal();
          }),
        ),
        SizedBox(height: context.eos.spacing.sm),
        EosSelectField<int>(
          label: 'Age restriction',
          value: _ageMin,
          items: const [
            DropdownMenuItem(value: 0, child: Text('All ages')),
            DropdownMenuItem(value: 18, child: Text('18+')),
            DropdownMenuItem(value: 21, child: Text('21+')),
          ],
          onChanged: (v) => setState(() {
            _ageMin = v ?? 0;
            _autosaveLocal();
          }),
        ),
        SizedBox(height: context.eos.spacing.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Registration enabled'),
          value: _registrationEnabled,
          onChanged: (v) => setState(() {
            _registrationEnabled = v;
            _autosaveLocal();
          }),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Check-in enabled'),
          value: _checkInEnabled,
          onChanged: (v) => setState(() {
            _checkInEnabled = v;
            _autosaveLocal();
          }),
        ),
        SizedBox(height: context.eos.spacing.md),
        Text('Tags', style: context.eosText.titleSmall),
        tagsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const SizedBox.shrink(),
          data: (tags) => Wrap(
            spacing: context.eos.spacing.xs,
            children: [
              for (final t in tags)
                FilterChip(
                  label: Text(t.label),
                  selected: _selectedTags.contains(t.label),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _selectedTags.add(t.label);
                    } else {
                      _selectedTags.remove(t.label);
                    }
                    _autosaveLocal();
                  }),
                ),
            ],
          ),
        ),
        SizedBox(height: context.eos.spacing.md),
        Text('Branding', style: context.eosText.titleSmall),
        EosTextField(
          controller: _banner,
          label: 'Banner label',
          onChanged: (_) => _autosaveLocal(),
        ),
        SizedBox(height: context.eos.spacing.sm),
        EosSelectField<String>(
          label: 'Theme colour',
          value: _themeColor,
          items: const [
            DropdownMenuItem(value: '#4B2C6F', child: Text('Plum')),
            DropdownMenuItem(value: '#D4A853', child: Text('Gold')),
            DropdownMenuItem(value: '#1F4E5F', child: Text('Teal')),
            DropdownMenuItem(value: '#8B2942', child: Text('Wine')),
          ],
          onChanged: (v) => setState(() {
            _themeColor = v ?? '#4B2C6F';
            _autosaveLocal();
          }),
        ),
        SizedBox(height: context.eos.spacing.md),
        EosTextField(
          controller: _guests,
          label: isPrivate ? 'Expected guests' : 'Expected attendance',
          hint: '500',
          keyboardType: TextInputType.number,
          onChanged: (_) => _autosaveLocal(),
        ),
        SizedBox(height: context.eos.spacing.md),
        TextFormField(
          controller: _budget,
          keyboardType: TextInputType.number,
          inputFormatters: [NairaInputFormatter()],
          onChanged: (_) {
            setState(() {});
            _autosaveLocal();
          },
          decoration: const InputDecoration(
            labelText: 'Total budget',
            prefixText: '₦ ',
            hintText: '5,000,000',
          ),
        ),
      ],
    );
  }

  Widget _venueStep() {
    // WizardVenueStep is itself a ListView — nest it under Expanded, not another ListView,
    // or the venue body gets zero height (blank step / "render box with no size").
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Venue mode', style: context.eosText.titleSmall),
        Wrap(
          spacing: context.eos.spacing.xs,
          children: [
            for (final v in VenueType.values)
              ChoiceChip(
                label: Text(v.name),
                selected: _venueType == v,
                onSelected: (_) => setState(() {
                  _venueType = v;
                  _autosaveLocal();
                }),
              ),
          ],
        ),
        SizedBox(height: context.eos.spacing.sm),
        Text(
          'Map pin uses a demo Lagos coordinate until Places/Maps credentials are configured.',
          style: context.eosText.bodySmall?.copyWith(color: EosColors.slate500),
        ),
        SizedBox(height: context.eos.spacing.md),
        Expanded(
          child: WizardVenueStep(
            venueController: _venue,
            addressController: _address,
            cityController: _city,
            latitude: _lat,
            longitude: _lng,
            methodIndex: _venueMethod,
            state: _state,
            lga: _lga,
            selectedCenterId: _selectedCenterId,
            venueDeferred: _venueDeferred,
            budgetMinor: _budgetMinor,
            onStateChanged: (v) => setState(() {
              _state = v;
              _autosaveLocal();
            }),
            onLgaChanged: (v) => setState(() {
              _lga = v;
              _autosaveLocal();
            }),
            onCenterSelected: (c) => setState(() {
              _selectedCenterId = c?.id;
              _autosaveLocal();
            }),
            onDeferredChanged: (v) => setState(() {
              _venueDeferred = v;
              _autosaveLocal();
            }),
            onMethodChanged: (v) => setState(() {
              _venueMethod = v;
              _venueDeferred = v == 3;
              _autosaveLocal();
            }),
            onPinDropped: () => setState(() {
              _lat = 6.4281;
              _lng = 3.4219;
              _placeId = 'demo_lagos_pin';
              if (_venue.text.isEmpty) _venue.text = 'Pinned location';
              if (_address.text.isEmpty) _address.text = 'Victoria Island, Lagos';
              _autosaveLocal();
            }),
          ),
        ),
      ],
    );
  }

  Widget _budgetStep() {
    if (_budgetSlices.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _budgetSlices.isNotEmpty) return;
        setState(_syncBudgetSlicesIfNeeded);
      });
      return const Center(child: CircularProgressIndicator());
    }
    final slug = _category?.slug ?? 'other';
    final perGuest = _guestCount > 0 ? _budgetMinor / _guestCount : 0;
    final health = perGuest >= 8000000
        ? 'Healthy'
        : perGuest >= 5000000
            ? 'Tight'
            : 'At risk';
    final warnings = <String>[];
    if (perGuest < 5000000) {
      warnings.add('Budget per guest looks low for a ${_category?.label ?? 'celebration'}.');
    }
    return WizardBudgetStep(
      budgetController: _budget,
      onBudgetTotalChanged: () => setState(() {
        if (!_budgetSlicesCustomized) _syncBudgetSlicesIfNeeded();
        _autosaveLocal();
      }),
      guestCount: _guestCount,
      slices: _budgetSlices,
      healthLabel: health,
      warnings: warnings,
      onSlicesChanged: (slices) => setState(() {
        _budgetSlices = slices;
        _budgetSlicesCustomized = true;
        _autosaveLocal();
      }),
      onResetToSuggestion: () => setState(() {
        _budgetSlices = buildWizardBudgetSliceModels(budgetMinor: _budgetMinor, categorySlug: slug);
        _budgetSlicesCustomized = false;
        _lastAutoBudgetMinor = _budgetMinor;
        _lastAutoCategorySlug = slug;
        _autosaveLocal();
      }),
    );
  }

  void _syncBudgetSlicesIfNeeded() {
    final slug = _category?.slug ?? 'other';
    final shouldRegenerate = _budgetSlices.isEmpty ||
        (!_budgetSlicesCustomized &&
            (_lastAutoBudgetMinor != _budgetMinor || _lastAutoCategorySlug != slug));
    if (!shouldRegenerate) return;
    _budgetSlices = buildWizardBudgetSliceModels(budgetMinor: _budgetMinor, categorySlug: slug);
    _lastAutoBudgetMinor = _budgetMinor;
    _lastAutoCategorySlug = slug;
  }

  Widget _servicesStep() {
    final slug = _category?.slug ?? 'other';
    final services = vendorCategoriesForSlug(slug);
    return ListView(
      children: [
        Text('Services you will need', style: context.eosText.headlineSmall),
        SizedBox(height: context.eos.spacing.lg),
        WizardServicePicker(
          services: services,
          selected: _requiredServices,
          onToggle: (service, on) => setState(() {
            if (on) {
              _requiredServices.add(service);
            } else {
              _requiredServices.remove(service);
            }
            _autosaveLocal();
          }),
        ),
      ],
    );
  }

  Widget _ticketsStep() {
    return ListView(
      children: [
        Text('Ticket preparation', style: context.eosText.headlineSmall),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Public events need at least one ticket before publish. You can refine pricing later in the Event Workspace.',
          style: context.eosText.bodyMedium?.copyWith(color: EosColors.slate500),
        ),
        SizedBox(height: context.eos.spacing.lg),
        if (_ticketTiers.isEmpty)
          EosSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No tickets yet', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                FilledButton.icon(
                  onPressed: _addDefaultTicket,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Regular ticket'),
                ),
              ],
            ),
          )
        else
          for (final t in _ticketTiers)
            Padding(
              padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
              child: EosSurfaceCard(
                child: ListTile(
                  title: Text(t.name),
                  subtitle: Text(
                    '${formatRevenue(t.priceMinor)} · ${t.capacity} capacity · ${t.visibility == TicketVisibility.publicListing ? 'public' : 'hidden'}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() {
                      _ticketTiers.removeWhere((x) => x.id == t.id);
                      _autosaveLocal();
                    }),
                  ),
                ),
              ),
            ),
        SizedBox(height: context.eos.spacing.sm),
        OutlinedButton.icon(
          onPressed: _addDefaultTicket,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add another ticket'),
        ),
      ],
    );
  }

  void _addDefaultTicket() {
    setState(() {
      _ticketTiers.add(
        OrganizerTicketTier(
          id: 'tier_${DateTime.now().millisecondsSinceEpoch}',
          name: _ticketTiers.isEmpty ? 'Regular' : 'VIP',
          description: _ticketTiers.isEmpty ? 'General admission' : 'Premium access',
          priceMinor: _ticketTiers.isEmpty ? 1500000 : 3500000,
          currency: 'NGN',
          capacity: _guestCount > 0 ? _guestCount : 100,
          remaining: _guestCount > 0 ? _guestCount : 100,
          tierType: _ticketTiers.isEmpty ? TicketTierType.regular : TicketTierType.vip,
        ),
      );
      _autosaveLocal();
    });
  }

  Widget _reviewStep() {
    final readiness = evaluateEventPublishReadiness(
      title: _title.text,
      startsAt: _starts,
      endsAt: _ends,
      accessMode: _accessMode,
      venueDeferred: _venueDeferred,
      venueName: _venue.text,
      city: _city.text,
      ticketTiers: _ticketTiers,
      description: _description.text,
      celebrantImageUrl: _celebrantImageUrl,
      hasCelebrantBytes: _celebrantImageBytes != null,
    );
    return ListView(
      children: [
        Text('Preview & readiness', style: context.eosText.headlineSmall),
        SizedBox(height: context.eos.spacing.md),
        EosSurfaceCard(
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title.text.trim().isEmpty ? 'Your celebration' : _title.text.trim(),
                  style: context.eosText.titleLarge),
              if (_tagline.text.trim().isNotEmpty) Text(_tagline.text.trim()),
              if (_description.text.trim().isNotEmpty) ...[
                SizedBox(height: context.eos.spacing.sm),
                Text(_description.text.trim(), style: context.eosText.bodyMedium),
              ],
              SizedBox(height: context.eos.spacing.sm),
              Text(
                '${_category?.label ?? 'Event'} · ${_listingVisibility.replaceAll('_', ' ')} · ${_fmt(_starts)} → ${_fmt(_ends)}',
                style: context.eosText.bodySmall,
              ),
              Text('Budget ${formatRevenue(_budgetMinor)} · Theme $_themeColor', style: context.eosText.bodySmall),
              if (_ticketTiers.isNotEmpty)
                Text('Tickets: ${_ticketTiers.map((t) => t.name).join(', ')}', style: context.eosText.bodySmall),
            ],
          ),
        ),
        SizedBox(height: context.eos.spacing.lg),
        Text('Validation', style: context.eosText.titleSmall),
        SizedBox(height: context.eos.spacing.sm),
        for (final item in readiness.items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              item.done ? Icons.check_circle : Icons.error_outline,
              color: item.done
                  ? Colors.green
                  : (item.severity == 'blocking' ? Colors.red : EosColors.warning),
            ),
            title: Text(item.label),
            subtitle: item.done ? null : Text(item.severity),
          ),
        SizedBox(height: context.eos.spacing.md),
        EosSurfaceCard(
          child: Text(
            readiness.readyToPublish
                ? 'Ready to create — after open, use the readiness checklist to publish when you are set.'
                : 'Fix blocking items above, then create. The Event Workspace will guide your next best action.',
            style: context.eosText.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _footer(List<String> labels, int step) {
    final isLast = step == labels.length - 1;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        child: Row(
          children: [
            if (step > 0)
              OutlinedButton(onPressed: () => setState(() => _step--), child: const Text('Back')),
            const Spacer(),
            FilledButton(
              onPressed: _saving ? null : (isLast ? _saveAndOpen : () => _next(labels)),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isLast ? 'Create & open workspace' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }

  void _next(List<String> labels) {
    final name = labels[_step];
    if (name == 'Celebrate' && _category == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a celebration type')));
      return;
    }
    if (name == 'Details') {
      if (_title.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add an event name')));
        return;
      }
      if (!_ends.isAfter(_starts)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End must be after start')));
        return;
      }
    }
    if (name == 'Venue' && !_venueDeferred) {
      if (_venueMethod == 0 && _selectedCenterId == null && _venue.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a venue or Later')));
        return;
      }
      if (_venueMethod == 1 && _address.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter venue address')));
        return;
      }
      if (_city.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a city')));
        return;
      }
    }
    if (name == 'Services' && _requiredServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one service')));
      return;
    }
    if (name == 'Tickets' && _isPublic && _ticketTiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one ticket for public events')));
      return;
    }
    setState(() {
      if (name == 'Venue') _syncBudgetSlicesIfNeeded();
      if (name == 'Budget') {
        final slug = _category?.slug ?? 'other';
        for (final s in serviceNamesFromBudgetSlices(_budgetSlices, slug)) {
          _requiredServices.add(s);
        }
      }
      _step++;
      _autosaveLocal();
    });
    ref.read(wizardAutosaveProvider.notifier).setWizardStep(_step);
    _maybeAutosaveServer();
  }

  Future<void> _maybeAutosaveServer() async {
    final draft = _buildDraft();
    if (draft.title.isEmpty) return;
    try {
      if (_serverEventId == null) {
        final event = await createEventFromV2Draft(ref, draft, celebrantImageBytes: _celebrantImageBytes);
        _serverEventId = event.id;
        _celebrantImageBytes = null;
        if (event.celebrantImageUrl != null) _celebrantImageUrl = event.celebrantImageUrl;
        ref.read(wizardAutosaveProvider.notifier).bindServerEvent(event.id);
        _autosaveLocal();
      } else {
        await patchEventFromV2Draft(ref, _serverEventId!, draft);
        ref.read(wizardAutosaveProvider.notifier).bindServerEvent(_serverEventId!);
        _autosaveLocal();
      }
    } catch (_) {
      // Local autosave remains; server sync is best-effort while stepping.
    }
  }

  Future<void> _saveDraftOnly() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add an event name before saving')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _maybeAutosaveServer();
      _autosaveLocal();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAndOpen() async {
    if (_category == null || _title.text.trim().isEmpty) return;
    if (_requiredServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one service')));
      return;
    }
    if (_isPublic && _ticketTiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add tickets before creating a public event')));
      return;
    }
    if (!_ends.isAfter(_starts)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End must be after start')));
      return;
    }
    setState(() => _saving = true);
    _syncBudgetSlicesIfNeeded();
    final draft = _buildDraft();
    try {
      late OrganizerEvent event;
      if (_serverEventId != null) {
        event = await patchEventFromV2Draft(ref, _serverEventId!, draft);
      } else {
        event = await createEventFromV2Draft(ref, draft, celebrantImageBytes: _celebrantImageBytes);
      }
      ref.read(selectedOrganizerEventIdProvider.notifier).state = event.id;
      ref.read(wizardAutosaveProvider.notifier).clear();
      if (!mounted) return;
      context.go('/events/${event.id}?focus=readiness');
    } on EventCreationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), action: SnackBarAction(label: 'Retry', onPressed: _saveAndOpen)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create event: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDateTime({required bool isEnd}) async {
    final initial = isEnd ? _ends : _starts;
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2035),
      initialDate: initial,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (t == null) return;
    final next = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    setState(() {
      if (isEnd) {
        _ends = next;
      } else {
        _starts = next;
        if (!_ends.isAfter(_starts)) {
          _ends = _starts.add(const Duration(hours: 6));
        }
      }
      _autosaveLocal();
    });
  }
}
