import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/event_config_api.dart';
import '../../../core/utils/currency_input.dart';
import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../shared/models/event_access_mode.dart';
import '../data/organizer_persistence.dart';
import '../models/organizer_models.dart';
import '../providers/event_config_providers.dart';
import '../providers/organizer_providers.dart';
import 'widgets/celebration_type_cards.dart';
import 'widgets/wizard_celebrant_image_picker.dart';
import 'widgets/wizard_service_picker.dart';
import 'widgets/wizard_venue_budget_widgets.dart';

const _stepLabels = ['Celebrate', 'Details', 'Venue', 'Budget', 'Services'];

/// Celebration-first event creation wizard (OWANBE EVENT CREATION V2).
class EventCreateWizardV2Screen extends ConsumerStatefulWidget {
  const EventCreateWizardV2Screen({super.key});

  @override
  ConsumerState<EventCreateWizardV2Screen> createState() => _EventCreateWizardV2ScreenState();
}

class _EventCreateWizardV2ScreenState extends ConsumerState<EventCreateWizardV2Screen> {
  int _step = 0;
  EventCategoryConfig? _category;
  final _title = TextEditingController();
  final _tagline = TextEditingController();
  final _venue = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController(text: 'Lagos');
  final _guests = TextEditingController(text: '150');
  final _budget = TextEditingController(text: '5,000,000');
  DateTime _starts = DateTime.now().add(const Duration(days: 60));
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
  Uint8List? _celebrantImageBytes;
  List<WizardBudgetSlice> _budgetSlices = [];
  bool _budgetSlicesCustomized = false;
  int _lastAutoBudgetMinor = 0;
  String _lastAutoCategorySlug = '';

  @override
  void dispose() {
    _title.dispose();
    _tagline.dispose();
    _venue.dispose();
    _address.dispose();
    _city.dispose();
    _guests.dispose();
    _budget.dispose();
    super.dispose();
  }

  int get _guestCount => int.tryParse(_guests.text.replaceAll(',', '')) ?? 0;

  int get _budgetMinor => parseNairaInputToMinor(_budget.text);

  String? get _celebrantImageUrl {
    if (_celebrantImageBytes == null) return null;
    final b64 = base64Encode(_celebrantImageBytes!);
    return 'data:image/jpeg;base64,$b64';
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(eventCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.eosCanvas,
        elevation: 0,
        title: Text('Create celebration · ${_stepLabels[_step]}'),
      ),
      body: Column(
        children: [
          _progressBar(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.eos.spacing.lg),
              child: categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => CelebrationTypeCards(
                  categories: EventCategoryConfig.fallbackDefaults,
                  selectedSlug: _category?.slug,
                  onSelected: (c) => setState(() => _category = c),
                ),
                data: (cats) => _stepBody(cats),
              ),
            ),
          ),
          _footer(),
        ],
      ),
    );
  }

  Widget _progressBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.eos.spacing.lg, 0, context.eos.spacing.lg, context.eos.spacing.md),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_step + 1) / _stepLabels.length,
              minHeight: 6,
              backgroundColor: EosColors.champagne.withValues(alpha: 0.4),
              color: EosColors.plum,
            ),
          ),
          SizedBox(height: context.eos.spacing.sm),
          Wrap(
            spacing: context.eos.spacing.xs,
            children: [
              for (var i = 0; i < _stepLabels.length; i++)
                FilterChip(
                  label: Text(_stepLabels[i]),
                  selected: i == _step,
                  onSelected: i <= _step
                      ? (_) => setState(() {
                            if (i == 3) _syncBudgetSlicesIfNeeded();
                            _step = i;
                          })
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepBody(List<EventCategoryConfig> categories) {
    return switch (_step) {
      0 => _celebrateStep(categories),
      1 => _detailsStep(),
      2 => _venueStep(),
      3 => _budgetStep(),
      _ => _servicesStep(),
    };
  }

  Widget _celebrateStep(List<EventCategoryConfig> categories) {
    return ListView(
      children: [
        Text('What are you celebrating?', style: context.eosText.headlineMedium),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Pick a celebration type — we will tailor guests, vendors, and budget for you.',
          style: context.eosText.bodyMedium?.copyWith(color: EosColors.slate500),
        ),
        SizedBox(height: context.eos.spacing.lg),
        CelebrationTypeCards(
          categories: categories,
          selectedSlug: _category?.slug,
          onSelected: (c) => setState(() => _category = c),
        ),
      ],
    );
  }

  Widget _detailsStep() {
    final isPrivate = _category?.accessMode != EventAccessMode.publicTicketed;
    return ListView(
      children: [
        Text('Tell us about your celebration', style: context.eosText.headlineSmall),
        SizedBox(height: context.eos.spacing.md),
        WizardCelebrantImagePicker(
          imageBytes: _celebrantImageBytes,
          onPicked: (bytes) => setState(() => _celebrantImageBytes = bytes),
          onClear: () => setState(() => _celebrantImageBytes = null),
        ),
        SizedBox(height: context.eos.spacing.md),
        EosTextField(controller: _title, label: 'Event name', hint: 'Ada & Emeka\'s Wedding'),
        SizedBox(height: context.eos.spacing.md),
        EosTextField(controller: _tagline, label: 'Tagline', hint: 'Love, laughter, and jollof'),
        SizedBox(height: context.eos.spacing.md),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Date & time'),
          subtitle: Text(_starts.toString().substring(0, 16)),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: _pickDateTime,
        ),
        SizedBox(height: context.eos.spacing.md),
        EosTextField(
          controller: _guests,
          label: isPrivate ? 'Expected guests' : 'Expected attendance',
          hint: '500',
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: context.eos.spacing.md),
        TextFormField(
          controller: _budget,
          keyboardType: TextInputType.number,
          inputFormatters: [NairaInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Total budget',
            prefixText: '₦ ',
            hintText: '5,000,000',
          ),
        ),
        if (_budgetMinor > 0)
          Padding(
            padding: EdgeInsets.only(top: context.eos.spacing.xs),
            child: Text(
              'Budget: ${formatRevenue(_budgetMinor)}',
              style: context.eosText.bodySmall?.copyWith(color: EosColors.plum),
            ),
          ),
      ],
    );
  }

  Widget _venueStep() {
    return WizardVenueStep(
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
      onStateChanged: (v) => setState(() => _state = v),
      onLgaChanged: (v) => setState(() => _lga = v),
      onCenterSelected: (c) => setState(() => _selectedCenterId = c?.id),
      onDeferredChanged: (v) => setState(() => _venueDeferred = v),
      onMethodChanged: (v) => setState(() {
        _venueMethod = v;
        _venueDeferred = v == 3;
      }),
      onPinDropped: () => setState(() {
        _lat = 6.4281;
        _lng = 3.4219;
        _placeId = 'demo_lagos_pin';
        if (_venue.text.isEmpty) _venue.text = 'Pinned location';
        if (_address.text.isEmpty) _address.text = 'Victoria Island, Lagos';
      }),
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
      warnings.add('Budget per guest is low for a ${_category?.label ?? 'celebration'} — consider trimming the guest list or increasing budget.');
    }
    if (_budgetMinor < 5000000000 && slug == 'wedding' && _guestCount > 300) {
      warnings.add('Large weddings often need ₦50M+ — venue and catering may exceed this plan.');
    }
    return WizardBudgetStep(
      budgetController: _budget,
      onBudgetTotalChanged: () => setState(() {
        if (!_budgetSlicesCustomized) _syncBudgetSlicesIfNeeded();
      }),
      guestCount: _guestCount,
      slices: _budgetSlices,
      healthLabel: health,
      warnings: warnings,
      onSlicesChanged: (slices) => setState(() {
        _budgetSlices = slices;
        _budgetSlicesCustomized = true;
      }),
      onResetToSuggestion: () => setState(() {
        _budgetSlices = buildWizardBudgetSliceModels(budgetMinor: _budgetMinor, categorySlug: slug);
        _budgetSlicesCustomized = false;
        _lastAutoBudgetMinor = _budgetMinor;
        _lastAutoCategorySlug = slug;
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
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Select the types of vendors your ${_category?.label ?? 'event'} needs. You will choose and negotiate with specific vendors on your event page.',
          style: context.eosText.bodyMedium?.copyWith(color: EosColors.slate500),
        ),
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
          }),
        ),
        SizedBox(height: context.eos.spacing.lg),
        EosSurfaceCard(
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title.text.trim().isEmpty ? 'Your celebration' : _title.text.trim(),
                  style: context.eosText.titleLarge),
              if (_tagline.text.trim().isNotEmpty)
                Text(_tagline.text.trim(), style: context.eosText.bodyMedium),
              SizedBox(height: context.eos.spacing.sm),
              Text(
                '${_category?.label ?? 'Event'} · ${_city.text.trim()} · $_guestCount guests',
                style: context.eosText.bodySmall,
              ),
              Text('Budget ${formatRevenue(_budgetMinor)}', style: context.eosText.bodySmall),
              if (_budgetSlices.isNotEmpty)
                Text(
                  'Allocation: ${_budgetSlices.map((s) => '${s.label} ${formatRevenue(s.amountMinor)}').join(' · ')}',
                  style: context.eosText.bodySmall,
                ),
              if (_venueDeferred)
                Text('Venue: Decide later', style: context.eosText.bodySmall)
              else if (_venue.text.trim().isNotEmpty)
                Text('Venue: ${_venue.text.trim()}', style: context.eosText.bodySmall),
              if (_requiredServices.isNotEmpty)
                Text('Services: ${_requiredServices.join(', ')}', style: context.eosText.bodySmall),
            ],
          ),
        ),
        SizedBox(height: context.eos.spacing.md),
        Text(
          'Saved as a draft — open the command center to invite guests, shop vendors, and publish when ready.',
          style: context.eosText.bodySmall?.copyWith(color: EosColors.slate500),
        ),
      ],
    );
  }

  Widget _footer() {
    final isLast = _step == _stepLabels.length - 1;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        child: Row(
          children: [
            if (_step > 0)
              OutlinedButton(onPressed: () => setState(() => _step--), child: const Text('Back')),
            const Spacer(),
            FilledButton(
              onPressed: _saving ? null : (isLast ? _save : _next),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isLast ? 'Create celebration' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }

  void _next() {
    if (_step == 0 && _category == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a celebration type')));
      return;
    }
    if (_step == 1 && _title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add an event name')));
      return;
    }
    if (_step == 2) {
      if (_venueDeferred) {
        setState(() {
          _syncBudgetSlicesIfNeeded();
          _step++;
        });
        return;
      }
      if (_venueMethod == 0 && _selectedCenterId == null && _venue.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an event centre or choose Later')));
        return;
      }
      if (_venueMethod == 1 && _address.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your venue address')));
        return;
      }
      if (_city.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a city')));
        return;
      }
    }
    setState(() {
      if (_step == 2) _syncBudgetSlicesIfNeeded();
      if (_step == 3) _prefillServicesFromBudget();
      _step++;
    });
  }

  void _prefillServicesFromBudget() {
    final slug = _category?.slug ?? 'other';
    for (final name in serviceNamesFromBudgetSlices(_budgetSlices, slug)) {
      _requiredServices.add(name);
    }
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2032),
      initialDate: _starts,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_starts));
    if (t == null) return;
    setState(() => _starts = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (_category == null || _title.text.trim().isEmpty) return;
    if (_requiredServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one service')));
      return;
    }
    setState(() => _saving = true);
    final slug = _category!.slug;
    _syncBudgetSlicesIfNeeded();
    final draft = EventWizardV2Draft(
      categorySlug: slug,
      categoryLabel: _category!.label,
      eventAccessMode: _category!.accessMode,
      title: _title.text.trim(),
      tagline: _tagline.text.trim(),
      city: _city.text.trim(),
      venueName: _venueDeferred ? '' : _venue.text.trim(),
      venueAddress: _venueDeferred ? '' : _address.text.trim(),
      venueLatitude: _venueDeferred ? null : _lat,
      venueLongitude: _venueDeferred ? null : _lng,
      googlePlaceId: _venueDeferred ? null : _placeId,
      budgetMinor: _budgetMinor,
      expectedGuests: _guestCount,
      startsAt: _starts,
      endsAt: _starts.add(const Duration(hours: 6)),
      budgetAllocation: _budgetSlices.map((s) => s.toMap(_budgetMinor)).toList(),
      requiredServices: _requiredServices.toList(),
      venueDeferred: _venueDeferred,
      state: _state,
      lga: _lga,
      celebrantImageUrl: _celebrantImageUrl,
    );
    try {
      final event = await createEventFromV2Draft(ref, draft);
      ref.read(selectedOrganizerEventIdProvider.notifier).state = event.id;
      if (!mounted) return;
      context.go('/events/${event.id}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
