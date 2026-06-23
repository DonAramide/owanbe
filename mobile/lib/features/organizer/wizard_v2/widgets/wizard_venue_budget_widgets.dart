import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';

class VenuePreviewCard extends StatelessWidget {
  const VenuePreviewCard({
    super.key,
    required this.venueName,
    required this.address,
    this.latitude,
    this.longitude,
  });

  final String venueName;
  final String address;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    if (venueName.trim().isEmpty && address.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return EosSurfaceCard(
      elevated: true,
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [EosColors.plum, EosColors.champagne.withValues(alpha: 0.8)],
              ),
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 32),
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
}

class WizardVenueStep extends StatelessWidget {
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
  });

  final TextEditingController venueController;
  final TextEditingController addressController;
  final TextEditingController cityController;
  final double? latitude;
  final double? longitude;
  final VoidCallback onPinDropped;
  final int methodIndex;
  final ValueChanged<int> onMethodChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('Where will you celebrate?', style: context.eosText.headlineSmall),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Choose a registered venue, search a place, or drop a pin on the map.',
          style: context.eosText.bodyMedium?.copyWith(color: EosColors.slate500),
        ),
        SizedBox(height: context.eos.spacing.lg),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Registered'), icon: Icon(Icons.apartment_outlined)),
            ButtonSegment(value: 1, label: Text('Search'), icon: Icon(Icons.search)),
            ButtonSegment(value: 2, label: Text('Map pin'), icon: Icon(Icons.pin_drop_outlined)),
          ],
          selected: {methodIndex},
          onSelectionChanged: (s) => onMethodChanged(s.first),
        ),
        SizedBox(height: context.eos.spacing.lg),
        if (methodIndex == 0) ...[
          EosTextField(controller: venueController, label: 'Registered venue name', hint: 'Eko Hotels & Suites'),
        ] else if (methodIndex == 1) ...[
          EosTextField(
            controller: venueController,
            label: 'Place name',
            hint: 'Search Google Places (manual entry for now)',
          ),
          SizedBox(height: context.eos.spacing.md),
          EosTextField(controller: addressController, label: 'Address', hint: 'Full street address'),
        ] else ...[
          EosSurfaceCard(
            child: Column(
              children: [
                Icon(Icons.map_outlined, size: 48, color: EosColors.plum.withValues(alpha: 0.7)),
                SizedBox(height: context.eos.spacing.sm),
                Text('Tap to drop a pin', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                FilledButton.icon(
                  onPressed: onPinDropped,
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Drop pin at Lagos (demo)'),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: context.eos.spacing.md),
        EosTextField(controller: cityController, label: 'City', hint: 'Lagos'),
        SizedBox(height: context.eos.spacing.lg),
        VenuePreviewCard(
          venueName: venueController.text,
          address: addressController.text.isNotEmpty
              ? '${addressController.text}${cityController.text.isNotEmpty ? ', ${cityController.text}' : ''}'
              : cityController.text,
          latitude: latitude,
          longitude: longitude,
        ),
      ],
    );
  }
}

class WizardBudgetStep extends StatelessWidget {
  const WizardBudgetStep({
    super.key,
    required this.budgetMinor,
    required this.guestCount,
    required this.slices,
    required this.healthLabel,
    required this.warnings,
  });

  final int budgetMinor;
  final int guestCount;
  final List<({String label, int amountMinor, double fraction})> slices;
  final String healthLabel;
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('AI budget planner', style: context.eosText.headlineSmall),
        SizedBox(height: context.eos.spacing.xs),
        Text(
          'Suggested allocation for $guestCount guests · ${formatRevenue(budgetMinor)} total',
          style: context.eosText.bodyMedium?.copyWith(color: EosColors.slate500),
        ),
        SizedBox(height: context.eos.spacing.lg),
        EosSurfaceCard(
          elevated: true,
          child: Row(
            children: [
              Icon(Icons.insights_outlined, color: EosColors.plum),
              SizedBox(width: context.eos.spacing.sm),
              Expanded(child: Text('Budget health: $healthLabel', style: context.eosText.titleSmall)),
            ],
          ),
        ),
        SizedBox(height: context.eos.spacing.md),
        for (final slice in slices) ...[
          EosSurfaceCard(
            child: Row(
              children: [
                Expanded(child: Text(slice.label, style: context.eosText.bodyMedium)),
                Text(formatRevenue(slice.amountMinor), style: context.eosText.labelLarge),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.sm),
        ],
        if (warnings.isNotEmpty) ...[
          SizedBox(height: context.eos.spacing.md),
          Text('Risk warnings', style: context.eosText.titleSmall),
          for (final w in warnings)
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

List<String> vendorCategoriesForSlug(String slug) => switch (slug) {
      'wedding' => ['Venue', 'Decorator', 'Photographer', 'DJ', 'MC', 'Security', 'Cake', 'Drinks', 'Ushers', 'Live Band'],
      'birthday' => ['Cake', 'Decorator', 'DJ', 'Photographer', 'Drinks'],
      'festival' => ['Venue', 'Security', 'DJ', 'Catering', 'Production'],
      'conference' => ['Venue', 'Catering', 'AV Production', 'Photography'],
      _ => ['Catering', 'Decorator', 'Photographer', 'DJ'],
    };
