import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../data/discover_location.dart';
import '../models/discover_filters.dart';

/// Modern Filters panel for Attendee Discover.
Future<void> showDiscoverFiltersSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<String> categories,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return _DiscoverFiltersSheet(
          scrollController: scrollController,
          categories: categories.where((c) => c != 'all').toList(),
        );
      },
    ),
  );
}

class _DiscoverFiltersSheet extends ConsumerStatefulWidget {
  const _DiscoverFiltersSheet({
    required this.scrollController,
    required this.categories,
  });

  final ScrollController scrollController;
  final List<String> categories;

  @override
  ConsumerState<_DiscoverFiltersSheet> createState() => _DiscoverFiltersSheetState();
}

class _DiscoverFiltersSheetState extends ConsumerState<_DiscoverFiltersSheet> {
  late DiscoverFilters _draft;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(discoverFiltersProvider);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom ? (_draft.dateFrom ?? now) : (_draft.dateTo ?? now.add(const Duration(days: 30)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      _draft = isFrom ? _draft.copyWith(dateFrom: picked) : _draft.copyWith(dateTo: picked);
    });
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final loc = await resolveDiscoverLocation();
      if (!mounted) return;
      if (loc == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location unavailable. Nearby will use geo-tagged events.')),
        );
        return;
      }
      ref.read(discoverUserLocationProvider.notifier).state = loc;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location set for Nearby & Distance filters')),
      );
      setState(() {});
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _apply() {
    ref.read(discoverFiltersProvider.notifier).state = _draft;
    Navigator.of(context).pop();
  }

  void _clear() {
    setState(() => _draft = const DiscoverFilters());
    ref.read(discoverFiltersProvider.notifier).state = const DiscoverFilters();
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(discoverUserLocationProvider);
    final venueOptions = const ['physical', 'virtual', 'hybrid'];

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(
        context.eos.spacing.lg,
        context.eos.spacing.sm,
        context.eos.spacing.lg,
        context.eos.spacing.xl,
      ),
      children: [
        Text('Filters', style: context.eosText.headlineSmall),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Refine the marketplace. Search stays as-is above.',
          style: context.eosText.bodySmall,
        ),
        SizedBox(height: context.eos.spacing.lg),
        Text('Date', style: context.eosText.titleSmall),
        SizedBox(height: context.eos.spacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickDate(isFrom: true),
                child: Text(_draft.dateFrom == null ? 'From' : _fmt(_draft.dateFrom!)),
              ),
            ),
            SizedBox(width: context.eos.spacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickDate(isFrom: false),
                child: Text(_draft.dateTo == null ? 'To' : _fmt(_draft.dateTo!)),
              ),
            ),
            IconButton(
              tooltip: 'Clear dates',
              onPressed: () => setState(() => _draft = _draft.copyWith(clearDates: true)),
              icon: const Icon(Icons.clear),
            ),
          ],
        ),
        SizedBox(height: context.eos.spacing.lg),
        Text('Price', style: context.eosText.titleSmall),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Free only'),
          value: _draft.freeOnly,
          onChanged: (v) => setState(() {
            _draft = _draft.copyWith(freeOnly: v, paidOnly: v ? false : _draft.paidOnly);
          }),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Paid only'),
          value: _draft.paidOnly,
          onChanged: (v) => setState(() {
            _draft = _draft.copyWith(paidOnly: v, freeOnly: v ? false : _draft.freeOnly);
          }),
        ),
        Text(
          _draft.maxPriceMinor <= 0
              ? 'Max price: Any'
              : 'Max price: ${formatRevenue(_draft.maxPriceMinor)}',
          style: context.eosText.bodySmall,
        ),
        Slider(
          value: _draft.maxPriceMinor.clamp(0, 500000).toDouble(),
          max: 500000,
          divisions: 50,
          label: _draft.maxPriceMinor <= 0 ? 'Any' : formatRevenue(_draft.maxPriceMinor),
          onChanged: (v) => setState(() {
            _draft = _draft.copyWith(maxPriceMinor: v.round());
          }),
        ),
        SizedBox(height: context.eos.spacing.md),
        Text('Distance', style: context.eosText.titleSmall),
        Text(
          location == null
              ? 'Set your location to filter by distance.'
              : 'Location set · ${_draft.maxDistanceKm <= 0 ? 'Any distance' : '${_draft.maxDistanceKm.round()} km'}',
          style: context.eosText.bodySmall,
        ),
        Slider(
          value: _draft.maxDistanceKm.clamp(0, 100),
          max: 100,
          divisions: 20,
          label: _draft.maxDistanceKm <= 0 ? 'Any' : '${_draft.maxDistanceKm.round()} km',
          onChanged: (v) => setState(() => _draft = _draft.copyWith(maxDistanceKm: v)),
        ),
        FilledButton.tonalIcon(
          onPressed: _locating ? null : _useMyLocation,
          icon: _locating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location, size: 18),
          label: Text(location == null ? 'Use my location' : 'Refresh location'),
        ),
        SizedBox(height: context.eos.spacing.lg),
        Text('Category', style: context.eosText.titleSmall),
        SizedBox(height: context.eos.spacing.sm),
        Wrap(
          spacing: context.eos.spacing.xs,
          runSpacing: context.eos.spacing.xs,
          children: [
            for (final cat in widget.categories)
              FilterChip(
                label: Text(cat),
                selected: _draft.categories.contains(cat),
                onSelected: (selected) {
                  final next = Set<String>.from(_draft.categories);
                  if (selected) {
                    next.add(cat);
                  } else {
                    next.remove(cat);
                  }
                  setState(() => _draft = _draft.copyWith(categories: next));
                },
              ),
          ],
        ),
        SizedBox(height: context.eos.spacing.lg),
        Text('Event type', style: context.eosText.titleSmall),
        SizedBox(height: context.eos.spacing.sm),
        Wrap(
          spacing: context.eos.spacing.xs,
          runSpacing: context.eos.spacing.xs,
          children: [
            for (final type in venueOptions)
              FilterChip(
                label: Text(type[0].toUpperCase() + type.substring(1)),
                selected: _draft.venueTypes.contains(type),
                onSelected: (selected) {
                  final next = Set<String>.from(_draft.venueTypes);
                  if (selected) {
                    next.add(type);
                  } else {
                    next.remove(type);
                  }
                  setState(() => _draft = _draft.copyWith(venueTypes: next));
                },
              ),
          ],
        ),
        SizedBox(height: context.eos.spacing.xl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: _clear, child: const Text('Clear all')),
            ),
            SizedBox(width: context.eos.spacing.sm),
            Expanded(
              child: FilledButton(onPressed: _apply, child: const Text('Apply filters')),
            ),
          ],
        ),
      ],
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
