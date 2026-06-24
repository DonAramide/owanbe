import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../models/rentals_constants.dart';
import '../models/rentals_models.dart';
import '../providers/rentals_providers.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/section_header.dart';

/// Marketplace rentals at `/vendors/rentals`.
class MarketplaceRentalsScreen extends ConsumerStatefulWidget {
  const MarketplaceRentalsScreen({super.key, this.eventId});

  final String? eventId;

  @override
  ConsumerState<MarketplaceRentalsScreen> createState() => _MarketplaceRentalsScreenState();
}

class _MarketplaceRentalsScreenState extends ConsumerState<MarketplaceRentalsScreen> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(rentalsCatalogProvider(_category));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Rentals & equipment'),
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [EmptyStateCard(title: 'Could not load rentals', message: '$e')],
        ),
        data: (items) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            const SectionHeader(
              title: 'Rentals & Event Equipment',
              subtitle: 'Quantity-based bookings with delivery and refundable deposits.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                for (final slug in rentalCategorySlugs.take(10))
                  FilterChip(
                    label: Text(rentalCategoryLabel(slug)),
                    selected: _category == slug,
                    onSelected: (_) => setState(() => _category = slug),
                  ),
              ],
            ),
            SizedBox(height: context.eos.spacing.lg),
            if (items.isEmpty)
              const EmptyStateCard(
                title: 'No rental items yet',
                message: 'Rental vendors can list chairs, tents, sound systems, and more.',
                icon: Icons.inventory_2_outlined,
              )
            else
              ...items.map((item) => _RentalItemCard(item: item, eventId: widget.eventId)),
          ],
        ),
      ),
    );
  }
}

class _RentalItemCard extends ConsumerStatefulWidget {
  const _RentalItemCard({required this.item, this.eventId});

  final RentalCatalogItem item;
  final String? eventId;

  @override
  ConsumerState<_RentalItemCard> createState() => _RentalItemCardState();
}

class _RentalItemCardState extends ConsumerState<_RentalItemCard> {
  final _qtyCtrl = TextEditingController(text: '1');
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    final eventId = widget.eventId;
    if (eventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open rentals from an event to request equipment')),
      );
      return;
    }
    try {
      await ref.read(rentalsApiProvider).createBooking(
            eventId: eventId,
            catalogItemId: widget.item.id,
            quantityRequested: int.tryParse(_qtyCtrl.text.trim()) ?? 1,
            requesterName: _nameCtrl.text.trim().isEmpty ? 'Event organizer' : _nameCtrl.text.trim(),
            deliveryAddress: _addressCtrl.text.trim(),
          );
      refreshRentals(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rental request submitted')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: EosSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.name, style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Text('${rentalCategoryLabel(item.categorySlug)} · ${item.vendorName}'),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatRevenue(item.rentalFeeMinor), style: context.eosText.labelLarge),
                  Text('+ ${formatRevenue(item.depositMinor)} deposit', style: context.eosText.bodySmall),
                ],
              ),
            ),
            Text('${item.availableQuantity} of ${item.totalQuantity} available', style: context.eosText.bodySmall),
            if (widget.eventId != null) ...[
              SizedBox(height: context.eos.spacing.sm),
              TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
              ),
              SizedBox(height: context.eos.spacing.xs),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Contact name', border: OutlineInputBorder()),
              ),
              SizedBox(height: context.eos.spacing.xs),
              TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Delivery address', border: OutlineInputBorder()),
              ),
              SizedBox(height: context.eos.spacing.sm),
              FilledButton(onPressed: _request, child: const Text('Request rental')),
            ],
          ],
        ),
      ),
    );
  }
}
