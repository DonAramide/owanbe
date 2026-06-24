import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/currency_input.dart';
import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../models/event_center_catalog.dart';
import '../models/nigeria_locations.dart';

class VenuePreviewCard extends StatelessWidget {
  const VenuePreviewCard({
    super.key,
    required this.venueName,
    required this.address,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.deferred = false,
  });

  final String venueName;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final bool deferred;

  @override
  Widget build(BuildContext context) {
    if (deferred) {
      return EosSurfaceCard(
        elevated: true,
        child: Row(
          children: [
            Icon(Icons.schedule_outlined, color: EosColors.plum, size: 32),
            SizedBox(width: context.eos.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Venue — decide later', style: context.eosText.titleSmall),
                  Text(
                    'You can pick a venue when browsing vendors on your event page.',
                    style: context.eosText.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (venueName.trim().isEmpty && address.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return EosSurfaceCard(
      elevated: true,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl != null
                ? Image.network(imageUrl!, width: 72, height: 72, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder())
                : _placeholder(),
          ),
          SizedBox(width: context.eos.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(venueName.isNotEmpty ? venueName : 'Selected venue', style: context.eosText.titleSmall),
                if (address.isNotEmpty)
                  Text(address, style: context.eosText.bodySmall?.copyWith(color: EosColors.slate500)),
                if (latitude != null && longitude != null)
                  Text(
                    '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}',
                    style: context.eosText.labelSmall?.copyWith(color: EosColors.slate500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [EosColors.plum, EosColors.champagne.withValues(alpha: 0.8)]),
      ),
      child: const Icon(Icons.location_on, color: Colors.white, size: 32),
    );
  }
}

class WizardVenueStep extends StatefulWidget {
  const WizardVenueStep({
    super.key,
    required this.venueController,
    required this.addressController,
    required this.cityController,
    required this.latitude,
    required this.longitude,
    required this.onPinDropped,
    required this.methodIndex,
    required this.onMethodChanged,
    required this.state,
    required this.lga,
    required this.onStateChanged,
    required this.onLgaChanged,
    required this.selectedCenterId,
    required this.onCenterSelected,
    required this.venueDeferred,
    required this.onDeferredChanged,
    required this.budgetMinor,
  });

  final TextEditingController venueController;
  final TextEditingController addressController;
  final TextEditingController cityController;
  final double? latitude;
  final double? longitude;
  final VoidCallback onPinDropped;
  final int methodIndex;
  final ValueChanged<int> onMethodChanged;
  final String state;
  final String lga;
  final ValueChanged<String> onStateChanged;
  final ValueChanged<String> onLgaChanged;
  final String? selectedCenterId;
  final ValueChanged<EventCenterOption?> onCenterSelected;
  final bool venueDeferred;
  final ValueChanged<bool> onDeferredChanged;
  final int budgetMinor;

  @override
  State<WizardVenueStep> createState() => _WizardVenueStepState();
}

class _WizardVenueStepState extends State<WizardVenueStep> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<EventCenterOption> get _centers => filterEventCenters(
        state: widget.state,
        lga: widget.lga.isEmpty ? null : widget.lga,
        query: _search.text,
        maxPriceMinor: widget.budgetMinor > 0 ? widget.budgetMinor : 0,
      );

  EventCenterOption? get _selectedCenter {
    if (widget.selectedCenterId == null) return null;
    for (final c in kEventCenterCatalog) {
      if (c.id == widget.selectedCenterId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedCenter;

    return ListView(
      children: [
        Text('Where will you celebrate?', style: context.eosText.headlineSmall),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Browse event centres by state & LGA, enter an address, drop a pin, or decide later.',
          style: context.eosText.bodyMedium?.copyWith(color: EosColors.slate500),
        ),
        SizedBox(height: context.eos.spacing.lg),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Centres'), icon: Icon(Icons.apartment_outlined)),
            ButtonSegment(value: 1, label: Text('Address'), icon: Icon(Icons.home_outlined)),
            ButtonSegment(value: 2, label: Text('Map pin'), icon: Icon(Icons.pin_drop_outlined)),
            ButtonSegment(value: 3, label: Text('Later'), icon: Icon(Icons.schedule_outlined)),
          ],
          selected: {widget.methodIndex},
          onSelectionChanged: (s) {
            final idx = s.first;
            widget.onMethodChanged(idx);
            widget.onDeferredChanged(idx == 3);
          },
        ),
        SizedBox(height: context.eos.spacing.lg),
        if (widget.methodIndex == 0) ...[
          DropdownButtonFormField<String>(
            value: kNigeriaStates.contains(widget.state) ? widget.state : kNigeriaStates.first,
            decoration: const InputDecoration(labelText: 'State'),
            items: [for (final s in kNigeriaStates) DropdownMenuItem(value: s, child: Text(s))],
            onChanged: (v) {
              if (v == null) return;
              widget.onStateChanged(v);
              final lgas = lgasForState(v);
              widget.onLgaChanged(lgas.isNotEmpty ? lgas.first : '');
              widget.onCenterSelected(null);
            },
          ),
          SizedBox(height: context.eos.spacing.md),
          DropdownButtonFormField<String>(
            value: widget.lga.isNotEmpty && lgasForState(widget.state).contains(widget.lga)
                ? widget.lga
                : (lgasForState(widget.state).isNotEmpty ? lgasForState(widget.state).first : null),
            decoration: const InputDecoration(labelText: 'Local government'),
            items: [
              for (final l in lgasForState(widget.state))
                DropdownMenuItem(value: l, child: Text(l)),
            ],
            onChanged: (v) {
              if (v == null) return;
              widget.onLgaChanged(v);
              widget.onCenterSelected(null);
            },
          ),
          SizedBox(height: context.eos.spacing.md),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Search event centres',
              prefixIcon: Icon(Icons.search),
              hintText: 'Name or area',
            ),
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: context.eos.spacing.md),
          Text(
            '${_centers.length} centre${_centers.length == 1 ? '' : 's'} · sorted by price',
            style: context.eosText.labelMedium,
          ),
          SizedBox(height: context.eos.spacing.sm),
          if (_centers.isEmpty)
            EosSurfaceCard(
              child: Text(
                'No centres match your filters. Try another LGA or increase your budget.',
                style: context.eosText.bodySmall,
              ),
            )
          else
            for (final center in _centers)
              Padding(
                padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                child: _EventCenterTile(
                  center: center,
                  selected: widget.selectedCenterId == center.id,
                  onTap: () {
                    widget.onCenterSelected(center);
                    widget.venueController.text = center.name;
                    widget.addressController.text = center.address;
                    widget.cityController.text = center.city;
                  },
                ),
              ),
        ] else if (widget.methodIndex == 1) ...[
          EosTextField(
            controller: widget.addressController,
            label: 'Full address',
            hint: 'House number, street, area',
            maxLines: 2,
          ),
          SizedBox(height: context.eos.spacing.md),
          EosTextField(controller: widget.venueController, label: 'Venue label (optional)', hint: 'My family compound'),
          SizedBox(height: context.eos.spacing.md),
          EosTextField(controller: widget.cityController, label: 'City', hint: 'Lagos'),
        ] else if (widget.methodIndex == 2) ...[
          EosSurfaceCard(
            child: Column(
              children: [
                Icon(Icons.map_outlined, size: 48, color: EosColors.plum.withValues(alpha: 0.7)),
                SizedBox(height: context.eos.spacing.sm),
                Text('Tap to drop a pin on the map', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                FilledButton.icon(
                  onPressed: widget.onPinDropped,
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Drop pin (demo)'),
                ),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          EosTextField(controller: widget.cityController, label: 'City', hint: 'Lagos'),
        ] else ...[
          EosSurfaceCard(
            elevated: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pick a venue later', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.xs),
                Text(
                  'Skip venue selection for now. When your event is created, browse the vendor marketplace to compare venues, images, and pricing.',
                  style: context.eosText.bodySmall,
                ),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          EosTextField(controller: widget.cityController, label: 'Preferred city (optional)', hint: 'Lagos'),
        ],
        SizedBox(height: context.eos.spacing.lg),
        VenuePreviewCard(
          venueName: widget.venueDeferred ? '' : widget.venueController.text,
          address: widget.venueDeferred
              ? ''
              : widget.addressController.text.isNotEmpty
                  ? '${widget.addressController.text}${widget.cityController.text.isNotEmpty ? ', ${widget.cityController.text}' : ''}'
                  : widget.cityController.text,
          latitude: widget.latitude,
          longitude: widget.longitude,
          imageUrl: selected?.coverImageUrl(),
          deferred: widget.venueDeferred,
        ),
      ],
    );
  }
}

class _EventCenterTile extends StatelessWidget {
  const _EventCenterTile({
    required this.center,
    required this.selected,
    required this.onTap,
  });

  final EventCenterOption center;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      elevated: selected,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              center.coverImageUrl(),
              width: 88,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 88,
                height: 72,
                color: EosColors.plum.withValues(alpha: 0.2),
                child: const Icon(Icons.apartment),
              ),
            ),
          ),
          SizedBox(width: context.eos.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(center.name, style: context.eosText.titleSmall),
                    ),
                    if (selected) Icon(Icons.check_circle, color: EosColors.plum, size: 20),
                  ],
                ),
                Text('${center.lga}, ${center.state}', style: context.eosText.bodySmall),
                SizedBox(height: context.eos.spacing.xxs),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: EosColors.champagne),
                    Text(' ${center.rating} · ${center.reviewCount} reviews',
                        style: context.eosText.labelSmall),
                  ],
                ),
                Text(center.priceLabel, style: context.eosText.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Column(
            children: [
              Icon(Icons.play_circle_outline, color: EosColors.plum, size: 22),
              Text('Reel', style: context.eosText.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class WizardBudgetSlice {
  WizardBudgetSlice({
    required this.id,
    required this.label,
    required this.amountMinor,
  });

  final String id;
  String label;
  int amountMinor;

  double fractionOf(int budgetMinor) =>
      budgetMinor <= 0 ? 0 : amountMinor / budgetMinor;

  Map<String, dynamic> toMap(int budgetMinor) => {
        'label': label,
        'amountMinor': amountMinor,
        'fraction': fractionOf(budgetMinor),
      };

  WizardBudgetSlice copyWith({String? label, int? amountMinor}) => WizardBudgetSlice(
        id: id,
        label: label ?? this.label,
        amountMinor: amountMinor ?? this.amountMinor,
      );

  static WizardBudgetSlice fromTuple(({String label, int amountMinor, double fraction}) t, {String? id}) =>
      WizardBudgetSlice(
        id: id ?? '${t.label}_${t.amountMinor}',
        label: t.label,
        amountMinor: t.amountMinor,
      );
}

const kSuggestedBudgetServices = [
  'Transport',
  'Makeup',
  'Cake',
  'Ushers',
  'Security',
  'MC',
  'Drinks',
  'Aso-ebi',
  'Gifts',
  'Live Band',
  'Lighting',
  'Other',
];

class WizardBudgetStep extends StatefulWidget {
  const WizardBudgetStep({
    super.key,
    required this.budgetController,
    required this.onBudgetTotalChanged,
    required this.guestCount,
    required this.slices,
    required this.healthLabel,
    required this.warnings,
    required this.onSlicesChanged,
    required this.onResetToSuggestion,
  });

  final TextEditingController budgetController;
  final VoidCallback onBudgetTotalChanged;
  final int guestCount;
  final List<WizardBudgetSlice> slices;
  final String healthLabel;
  final List<String> warnings;
  final ValueChanged<List<WizardBudgetSlice>> onSlicesChanged;
  final VoidCallback onResetToSuggestion;

  int get budgetMinor => parseNairaInputToMinor(budgetController.text);

  @override
  State<WizardBudgetStep> createState() => _WizardBudgetStepState();
}

class _WizardBudgetStepState extends State<WizardBudgetStep> {
  int get _budgetMinor => widget.budgetMinor;

  int get _allocatedMinor => widget.slices.fold<int>(0, (s, e) => s + e.amountMinor);

  int get _remainingMinor => _budgetMinor - _allocatedMinor;

  void _updateSlice(int index, WizardBudgetSlice slice) {
    final next = [...widget.slices];
    next[index] = slice;
    widget.onSlicesChanged(next);
  }

  void _removeSlice(int index) {
    if (widget.slices.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep at least one budget line')),
      );
      return;
    }
    final next = [...widget.slices]..removeAt(index);
    widget.onSlicesChanged(next);
  }

  Future<void> _addService() async {
    final existing = widget.slices.map((s) => s.label.toLowerCase()).toSet();
    final suggestions = kSuggestedBudgetServices.where((s) => !existing.contains(s.toLowerCase())).toList();

    final result = await showDialog<({String label, int amountMinor})>(
      context: context,
      builder: (ctx) => _AddBudgetServiceDialog(suggestions: suggestions),
    );
    if (result == null) return;
    widget.onSlicesChanged([
      ...widget.slices,
      WizardBudgetSlice(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        label: result.label,
        amountMinor: result.amountMinor,
      ),
    ]);
  }

  void _distributeRemaining() {
    if (_remainingMinor <= 0) return;
    final reserveIdx = widget.slices.indexWhere((s) => s.label.toLowerCase() == 'reserve');
    if (reserveIdx >= 0) {
      final slice = widget.slices[reserveIdx];
      _updateSlice(reserveIdx, slice.copyWith(amountMinor: slice.amountMinor + _remainingMinor));
      return;
    }
    widget.onSlicesChanged([
      ...widget.slices,
      WizardBudgetSlice(
        id: 'reserve_${DateTime.now().millisecondsSinceEpoch}',
        label: 'Reserve',
        amountMinor: _remainingMinor,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final overBudget = _remainingMinor < 0;
    final unallocated = _remainingMinor > 0;

    return ListView(
      children: [
        Text('AI budget planner', style: context.eosText.headlineSmall),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Drag sliders or type amounts · ${widget.guestCount} guests',
          style: context.eosText.bodyMedium?.copyWith(color: EosColors.slate500),
        ),
        SizedBox(height: context.eos.spacing.md),
        TextFormField(
          controller: widget.budgetController,
          keyboardType: TextInputType.number,
          inputFormatters: [NairaInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Total celebration budget',
            prefixText: '₦ ',
            helperText: 'Change the total and adjust each line below',
          ),
          onChanged: (_) => widget.onBudgetTotalChanged(),
        ),
        SizedBox(height: context.eos.spacing.lg),
        EosSurfaceCard(
          elevated: true,
          child: Row(
            children: [
              Icon(Icons.insights_outlined, color: EosColors.plum),
              SizedBox(width: context.eos.spacing.sm),
              Expanded(child: Text('Budget health: ${widget.healthLabel}', style: context.eosText.titleSmall)),
              TextButton(onPressed: widget.onResetToSuggestion, child: const Text('Reset AI')),
            ],
          ),
        ),
        SizedBox(height: context.eos.spacing.md),
        EosSurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Allocated', style: context.eosText.labelSmall),
                    Text(formatRevenue(_allocatedMinor), style: context.eosText.titleSmall),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(overBudget ? 'Over budget' : 'Remaining', style: context.eosText.labelSmall),
                    Text(
                      formatRevenue(_remainingMinor.abs()),
                      style: context.eosText.titleSmall?.copyWith(
                        color: overBudget ? EosColors.critical : (unallocated ? EosColors.warning : EosColors.plum),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.eos.spacing.md),
        for (var i = 0; i < widget.slices.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
            child: _BudgetSliceEditor(
              key: ValueKey(widget.slices[i].id),
              slice: widget.slices[i],
              budgetMinor: _budgetMinor,
              onChanged: (s) => _updateSlice(i, s),
              onRemove: () => _removeSlice(i),
            ),
          ),
        if (unallocated)
          Padding(
            padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _distributeRemaining,
                icon: const Icon(Icons.savings_outlined, size: 18),
                label: Text('Add ${formatRevenue(_remainingMinor)} to reserve'),
              ),
            ),
          ),
        FilledButton.tonalIcon(
          onPressed: _addService,
          icon: const Icon(Icons.add),
          label: const Text('Add service'),
        ),
        if (overBudget)
          Padding(
            padding: EdgeInsets.only(top: context.eos.spacing.sm),
            child: Text(
              'Allocated amount exceeds your total budget — reduce a line or increase budget on the Details step.',
              style: context.eosText.bodySmall?.copyWith(color: EosColors.critical),
            ),
          ),
        if (widget.warnings.isNotEmpty) ...[
          SizedBox(height: context.eos.spacing.md),
          Text('Risk warnings', style: context.eosText.titleSmall),
          for (final w in widget.warnings)
            Padding(
              padding: EdgeInsets.only(top: context.eos.spacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: EosColors.warning),
                  SizedBox(width: context.eos.spacing.xs),
                  Expanded(child: Text(w, style: context.eosText.bodySmall)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _BudgetSliceEditor extends StatefulWidget {
  const _BudgetSliceEditor({
    super.key,
    required this.slice,
    required this.budgetMinor,
    required this.onChanged,
    required this.onRemove,
  });

  final WizardBudgetSlice slice;
  final int budgetMinor;
  final ValueChanged<WizardBudgetSlice> onChanged;
  final VoidCallback onRemove;

  @override
  State<_BudgetSliceEditor> createState() => _BudgetSliceEditorState();
}

class _BudgetSliceEditorState extends State<_BudgetSliceEditor> {
  late final TextEditingController _amount;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: nairaInputFromMinor(widget.slice.amountMinor));
  }

  @override
  void didUpdateWidget(covariant _BudgetSliceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slice.amountMinor != widget.slice.amountMinor) {
      final text = nairaInputFromMinor(widget.slice.amountMinor);
      if (_amount.text != text) _amount.text = text;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _renameLabel() async {
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController(text: widget.slice.label);
        return AlertDialog(
          title: const Text('Rename service'),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Service name'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (next == null || next.isEmpty || next == widget.slice.label) return;
    widget.onChanged(widget.slice.copyWith(label: next));
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.budgetMinor <= 0 ? 0.0 : widget.slice.amountMinor / widget.budgetMinor;

    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.slice.label, style: context.eosText.bodyMedium)),
              IconButton(
                tooltip: 'Rename',
                onPressed: _renameLabel,
                icon: Icon(Icons.edit_outlined, size: 18, color: context.eosColors.onSurfaceVariant),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: widget.onRemove,
                icon: Icon(Icons.close, size: 18, color: context.eosColors.onSurfaceVariant),
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.xs),
          TextFormField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [NairaInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₦ ',
              isDense: true,
            ),
            onChanged: (v) {
              widget.onChanged(widget.slice.copyWith(amountMinor: parseNairaInputToMinor(v)));
            },
          ),
          SizedBox(height: context.eos.spacing.sm),
          Slider(
            value: pct.clamp(0.0, 1.0),
            onChanged: widget.budgetMinor <= 0
                ? null
                : (v) {
                    final amount = (widget.budgetMinor * v).round();
                    widget.onChanged(widget.slice.copyWith(amountMinor: amount));
                  },
            activeColor: EosColors.plum,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(pct * 100).round()}% of total budget',
              style: context.eosText.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddBudgetServiceDialog extends StatefulWidget {
  const _AddBudgetServiceDialog({required this.suggestions});

  final List<String> suggestions;

  @override
  State<_AddBudgetServiceDialog> createState() => _AddBudgetServiceDialogState();
}

class _AddBudgetServiceDialogState extends State<_AddBudgetServiceDialog> {
  final _customName = TextEditingController();
  final _amount = TextEditingController();
  String? _picked;

  @override
  void dispose() {
    _customName.dispose();
    _amount.dispose();
    super.dispose();
  }

  String get _label {
    if (_picked != null && _picked != 'Other') return _picked!;
    return _customName.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add service'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.suggestions.isNotEmpty) ...[
              Text('Suggested', style: context.eosText.labelMedium),
              SizedBox(height: context.eos.spacing.sm),
              Wrap(
                spacing: context.eos.spacing.xs,
                runSpacing: context.eos.spacing.xs,
                children: [
                  for (final s in widget.suggestions)
                    FilterChip(
                      label: Text(s),
                      selected: _picked == s,
                      onSelected: (on) => setState(() => _picked = on ? s : null),
                    ),
                  FilterChip(
                    label: const Text('Custom…'),
                    selected: _picked == 'Other',
                    onSelected: (on) => setState(() => _picked = on ? 'Other' : null),
                  ),
                ],
              ),
              SizedBox(height: context.eos.spacing.md),
            ],
            if (_picked == 'Other' || widget.suggestions.isEmpty)
              TextField(
                controller: _customName,
                decoration: const InputDecoration(labelText: 'Service name'),
              ),
            SizedBox(height: context.eos.spacing.md),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [NairaInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Budget amount (optional)',
                prefixText: '₦ ',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _label.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    (label: _label, amountMinor: parseNairaInputToMinor(_amount.text)),
                  ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

List<({String label, int amountMinor, double fraction})> buildWizardBudgetSlices({
  required int budgetMinor,
  required String categorySlug,
}) {
  final weights = switch (categorySlug) {
    'wedding' => <String, double>{
        'Venue': 0.35,
        'Food': 0.30,
        'Decoration': 0.10,
        'Photography': 0.08,
        'Music': 0.05,
        'Reserve': 0.12,
      },
    'festival' || 'conference' => <String, double>{
        'Venue': 0.25,
        'Production': 0.30,
        'Marketing': 0.15,
        'Staff': 0.12,
        'Reserve': 0.18,
      },
    _ => <String, double>{
        'Venue': 0.30,
        'Food': 0.28,
        'Decoration': 0.12,
        'Photography': 0.10,
        'Music': 0.08,
        'Reserve': 0.12,
      },
  };
  return weights.entries
      .map((e) => (label: e.key, amountMinor: (budgetMinor * e.value).round(), fraction: e.value))
      .toList();
}

List<WizardBudgetSlice> buildWizardBudgetSliceModels({
  required int budgetMinor,
  required String categorySlug,
}) {
  return buildWizardBudgetSlices(budgetMinor: budgetMinor, categorySlug: categorySlug)
      .asMap()
      .entries
      .map((e) => WizardBudgetSlice.fromTuple(e.value, id: '${e.value.label}_${e.key}'))
      .toList();
}

List<String> vendorCategoriesForSlug(String slug) => switch (slug) {
      'wedding' => ['Venue', 'Catering', 'Decorator', 'Photographer', 'DJ', 'MC', 'Security', 'Cake', 'Drinks', 'Ushers', 'Live Band', 'Fashion & Attire', 'Aso-Ebi', 'Tailoring'],
      'birthday' => ['Cake', 'Decorator', 'DJ', 'Photographer', 'Drinks', 'Catering'],
      'festival' => ['Venue', 'Security', 'DJ', 'Catering', 'Production'],
      'conference' => ['Venue', 'Catering', 'AV Production', 'Photography'],
      _ => ['Catering', 'Decorator', 'Photographer', 'DJ'],
    };

/// Maps budget line labels to vendor service names on the Services step.
String? budgetSliceToServiceName(String label) {
  final key = label.trim().toLowerCase();
  return switch (key) {
    'food' || 'catering' => 'Catering',
    'decoration' || 'decor' || 'décor' => 'Decorator',
    'photography' || 'photo' || 'media' => 'Photographer',
    'music' || 'dj' => 'DJ',
    'venue' => 'Venue',
    'cake' => 'Cake',
    'drinks' => 'Drinks',
    'transport' => 'Transport',
    'makeup' => 'Makeup',
    'ushers' => 'Ushers',
    'security' => 'Security',
    'mc' => 'MC',
    'live band' => 'Live Band',
    'lighting' => 'Lighting',
    'production' => 'Production',
    'marketing' => 'Marketing',
    'staff' => 'Staff',
    'reserve' || 'other' => null,
    _ => label.trim().isEmpty ? null : label.trim(),
  };
}

List<String> serviceNamesFromBudgetSlices(List<WizardBudgetSlice> slices, String categorySlug) {
  final available = vendorCategoriesForSlug(categorySlug).toSet();
  final picked = <String>{};
  for (final slice in slices) {
    final mapped = budgetSliceToServiceName(slice.label);
    if (mapped != null && available.contains(mapped)) picked.add(mapped);
    if (available.contains(slice.label)) picked.add(slice.label);
  }
  return picked.toList();
}
