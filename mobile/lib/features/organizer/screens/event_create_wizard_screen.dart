import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../data/organizer_persistence.dart';
import '../models/organizer_models.dart';
import '../providers/organizer_providers.dart';

const _stepLabels = ['Basics', 'Venue', 'Schedule', 'Media', 'Tickets', 'Publish'];

class EventCreateWizardScreen extends ConsumerStatefulWidget {
  const EventCreateWizardScreen({super.key});

  @override
  ConsumerState<EventCreateWizardScreen> createState() => _EventCreateWizardScreenState();
}

class _EventCreateWizardScreenState extends ConsumerState<EventCreateWizardScreen> {
  static const _stepCount = 6;
  int _step = 0;
  final _title = TextEditingController();
  final _tagline = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  final _venue = TextEditingController();
  final _tagInput = TextEditingController();
  String _category = 'Festival';
  VenueType _venueType = VenueType.physical;
  final List<String> _tags = [];
  String _bannerLabel = 'Hero banner';
  final List<String> _mediaLabels = [];
  DateTime _starts = DateTime.now().add(const Duration(days: 30));
  DateTime _ends = DateTime.now().add(const Duration(days: 30, hours: 5));
  final List<OrganizerTicketTier> _tiers = [];

  @override
  void initState() {
    super.initState();
    _applyPresets();
  }

  void _applyPresets() {
    _tiers.addAll([
      _presetTier('Regular', TicketTierType.regular, 1500000, 500),
      _presetTier('VIP', TicketTierType.vip, 4500000, 100),
      _presetTier('VVIP', TicketTierType.vvip, 12000000, 20),
      _presetTier('Table (10 seats)', TicketTierType.table, 25000000, 15),
    ]);
  }

  OrganizerTicketTier _presetTier(String name, TicketTierType type, int price, int cap) {
    return OrganizerTicketTier(
      id: 'tier_${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: ticketTierTypeLabel(type),
      priceMinor: price,
      currency: 'NGN',
      capacity: cap,
      remaining: cap,
      tierType: type,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _tagline.dispose();
    _description.dispose();
    _city.dispose();
    _venue.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create event · ${_stepLabels[_step]}'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/organizer')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _stepHeader(context),
                SizedBox(height: context.eos.spacing.lg),
                Expanded(child: _stepBody()),
                SizedBox(height: context.eos.spacing.md),
                Row(
                  children: [
                    if (_step > 0)
                      OutlinedButton(onPressed: () => setState(() => _step--), child: const Text('Back')),
                    const Spacer(),
                    FilledButton(
                      onPressed: _step < _stepCount - 1 ? _next : _save,
                      child: Text(_step < _stepCount - 1 ? 'Continue' : 'Save draft'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: (_step + 1) / _stepCount),
        SizedBox(height: context.eos.spacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _stepCount; i++) ...[
                if (i > 0) SizedBox(width: context.eos.spacing.xs),
                FilterChip(
                  label: Text(_stepLabels[i]),
                  selected: i == _step,
                  onSelected: i <= _step ? (_) => setState(() => _step = i) : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepBody() {
    return switch (_step) {
      0 => _basicsStep(),
      1 => _venueTypeStep(),
      2 => _scheduleStep(),
      3 => _mediaStep(),
      4 => _ticketsStep(),
      _ => _reviewStep(),
    };
  }

  Widget _basicsStep() {
    return ListView(
      children: [
        Text('Event basics', style: context.eosText.headlineSmall),
        SizedBox(height: context.eos.spacing.md),
        EosTextField(controller: _title, label: 'Event title', hint: 'Lagos Sunset Owanbe'),
        SizedBox(height: context.eos.spacing.md),
        EosTextField(controller: _tagline, label: 'Tagline', hint: 'Short hook for discovery'),
        SizedBox(height: context.eos.spacing.md),
        EosSelectField<String>(
          label: 'Category',
          value: _category,
          items: ['Festival', 'Expo', 'Concert', 'Workshop', 'Wedding']
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _category = v ?? _category),
        ),
        SizedBox(height: context.eos.spacing.md),
        Row(
          children: [
            Expanded(
              child: EosTextField(
                controller: _tagInput,
                label: 'Tags',
                hint: 'afrobeats, outdoor',
              ),
            ),
            SizedBox(width: context.eos.spacing.sm),
            FilledButton(
              onPressed: () {
                final t = _tagInput.text.trim();
                if (t.isNotEmpty && !_tags.contains(t)) setState(() => _tags.add(t));
                _tagInput.clear();
              },
              child: const Text('Add'),
            ),
          ],
        ),
        Wrap(
          spacing: context.eos.spacing.xs,
          children: [
            for (final t in _tags)
              Chip(label: Text(t), onDeleted: () => setState(() => _tags.remove(t))),
          ],
        ),
      ],
    );
  }

  Widget _venueTypeStep() {
    return ListView(
      children: [
        Text('Venue type', style: context.eosText.headlineSmall),
        SizedBox(height: context.eos.spacing.md),
        SegmentedButton<VenueType>(
          segments: const [
            ButtonSegment(value: VenueType.physical, label: Text('Physical'), icon: Icon(Icons.location_on_outlined)),
            ButtonSegment(value: VenueType.virtual, label: Text('Virtual'), icon: Icon(Icons.videocam_outlined)),
            ButtonSegment(value: VenueType.hybrid, label: Text('Hybrid'), icon: Icon(Icons.hub_outlined)),
          ],
          selected: {_venueType},
          onSelectionChanged: (s) => setState(() => _venueType = s.first),
        ),
        SizedBox(height: context.eos.spacing.lg),
        EosTextField(controller: _city, label: 'City', hint: 'Lagos'),
        SizedBox(height: context.eos.spacing.md),
        EosTextField(
          controller: _venue,
          label: _venueType == VenueType.virtual ? 'Stream URL / platform' : 'Venue',
          hint: _venueType == VenueType.virtual ? 'https://stream.owanbe.live/...' : 'Eko Atlantic Waterfront',
        ),
        SizedBox(height: context.eos.spacing.md),
        EosTextField(
          controller: _description,
          label: 'Description',
          hint: 'What attendees should expect…',
          maxLines: 5,
        ),
      ],
    );
  }

  Widget _scheduleStep() {
    return ListView(
      children: [
        Text('Date & time', style: context.eosText.headlineSmall),
        SizedBox(height: context.eos.spacing.md),
        ListTile(
          title: const Text('Starts'),
          subtitle: Text(_starts.toString()),
          trailing: const Icon(Icons.calendar_today),
          onTap: () => _pickDateTime(isStart: true),
        ),
        ListTile(
          title: const Text('Ends'),
          subtitle: Text(_ends.toString()),
          trailing: const Icon(Icons.schedule),
          onTap: () => _pickDateTime(isStart: false),
        ),
      ],
    );
  }

  Widget _mediaStep() {
    return ListView(
      children: [
        Text('Banner & gallery', style: context.eosText.headlineSmall),
        SizedBox(height: context.eos.spacing.md),
        EosSelectField<String>(
          label: 'Banner preset',
          value: _bannerLabel,
          items: ['Hero banner', 'Sunset gradient', 'Brand collage', 'Video loop']
              .map((b) => DropdownMenuItem(value: b, child: Text(b)))
              .toList(),
          onChanged: (v) => setState(() => _bannerLabel = v ?? _bannerLabel),
        ),
        SizedBox(height: context.eos.spacing.md),
        EosSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gallery assets (mock)', style: context.eosText.titleSmall),
              SizedBox(height: context.eos.spacing.sm),
              Wrap(
                spacing: context.eos.spacing.xs,
                children: [
                  for (final label in ['Venue render', 'Lineup teaser', 'Recap video', 'Sponsor strip'])
                    FilterChip(
                      label: Text(label),
                      selected: _mediaLabels.contains(label),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _mediaLabels.add(label);
                        } else {
                          _mediaLabels.remove(label);
                        }
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ticketsStep() {
    return ListView(
      children: [
        Row(
          children: [
            Expanded(child: Text('Ticket presets', style: context.eosText.headlineSmall)),
            TextButton.icon(onPressed: _addTier, icon: const Icon(Icons.add), label: const Text('Add tier')),
          ],
        ),
        SizedBox(height: context.eos.spacing.sm),
        Text(
          'Regular, VIP, VVIP, and Table tiers are pre-loaded. Adjust pricing and capacity before saving.',
          style: context.eosText.bodySmall,
        ),
        SizedBox(height: context.eos.spacing.md),
        for (final t in _tiers)
          Padding(
            padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
            child: EosSurfaceCard(
              child: ListTile(
                title: Text('${t.name} · ${ticketTierTypeLabel(t.tierType)}'),
                subtitle: Text('${ngnFromMinor(t.priceMinor.toString())} · cap ${t.capacity}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _tiers.remove(t)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _reviewStep() {
    return ListView(
      children: [
        Text('Review & publish', style: context.eosText.headlineSmall),
        SizedBox(height: context.eos.spacing.md),
        EosSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title.text, style: context.eosText.titleLarge),
              Text(_tagline.text, style: context.eosText.bodyMedium),
              SizedBox(height: context.eos.spacing.sm),
              Text('${_venueType.name} · $_city · $_venue', style: context.eosText.bodySmall),
              Text('Category: $_category', style: context.eosText.bodySmall),
              Text('${_tiers.length} ticket tier(s)', style: context.eosText.bodySmall),
              if (_tags.isNotEmpty) Text('Tags: ${_tags.join(', ')}', style: context.eosText.bodySmall),
            ],
          ),
        ),
        SizedBox(height: context.eos.spacing.md),
        Text(
          'Saved as draft — publish from the event workspace when ready.',
          style: context.eosText.bodySmall,
        ),
      ],
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _starts : _ends;
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: initial,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (t == null) return;
    final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    setState(() {
      if (isStart) {
        _starts = dt;
      } else {
        _ends = dt;
      }
    });
  }

  void _addTier() {
    setState(() {
      _tiers.add(_presetTier('Custom tier', TicketTierType.regular, 1000000, 50));
    });
  }

  void _next() {
    if (_step == 0 && _title.text.trim().isEmpty) return;
    if (_step == 1 && _city.text.trim().isEmpty) return;
    setState(() => _step++);
  }

  Future<void> _save() async {
    final draft = EventWizardDraft(
      title: _title.text.trim(),
      tagline: _tagline.text.trim(),
      description: _description.text.trim(),
      city: _city.text.trim(),
      venue: _venue.text.trim(),
      category: _category,
      venueType: _venueType,
      tags: _tags,
      bannerLabel: _bannerLabel,
      mediaLabels: _mediaLabels,
      startsAt: _starts,
      endsAt: _ends,
      ticketTiers: _tiers,
    );
    final event = await createEventFromDraft(ref, draft);
    ref.read(selectedOrganizerEventIdProvider.notifier).state = event.id;
    if (mounted) context.go('/organizer/events/${event.id}');
  }
}
