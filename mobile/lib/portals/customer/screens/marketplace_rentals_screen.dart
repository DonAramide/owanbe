import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/event_config_api.dart';
import '../../../core/api/owambe_http_client.dart';
import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../features/vendor/providers/vendor_providers.dart';
import '../models/marketplace_offering_context.dart';
import '../models/rentals_constants.dart';
import '../models/rentals_models.dart';
import '../providers/rentals_providers.dart';
import '../workspace/widgets/event_friendly_errors.dart';
import '../workspace/widgets/event_loading_skeleton.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/section_header.dart';

/// Marketplace rentals at `/vendors/rentals`.
class MarketplaceRentalsScreen extends ConsumerStatefulWidget {
  const MarketplaceRentalsScreen({
    super.key,
    this.eventId,
    this.vendorBuyerMode = false,
    this.buyerVendorId,
    this.embedded = false,
  });

  final String? eventId;
  final bool vendorBuyerMode;
  final String? buyerVendorId;
  final bool embedded;

  @override
  ConsumerState<MarketplaceRentalsScreen> createState() => _MarketplaceRentalsScreenState();
}

class _MarketplaceRentalsScreenState extends ConsumerState<MarketplaceRentalsScreen> {
  String? _category;
  List<VendorCategoryConfig> _rentalCats = const [];

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  Future<void> _loadCats() async {
    try {
      final cats = await EventConfigApi(createOwambeHttpClient()).listPublicOfferingCategories(kind: 'rental');
      if (!mounted) return;
      setState(() => _rentalCats = cats);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final currentVendorId = widget.vendorBuyerMode
        ? (ref.watch(canonicalVendorIdProvider).valueOrNull ?? widget.buyerVendorId)
        : widget.buyerVendorId;
    final catalog = ref.watch(rentalsCatalogProvider(_category));
    final body = catalog.when(
        loading: () => const EventLoadingSkeleton(variant: EventLoadingVariant.list),
        error: (_, _) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            EmptyStateCard(
              title: EventFriendlyErrors.headlineFor('rentals'),
              message: EventFriendlyErrors.genericMessage,
            ),
          ],
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
                if (_rentalCats.isEmpty)
                  for (final slug in rentalCategorySlugs.take(10))
                    FilterChip(
                      label: Text(rentalCategoryLabel(slug)),
                      selected: _category == slug,
                      onSelected: (_) => setState(() => _category = slug),
                    )
                else
                  for (final cat in _rentalCats)
                    FilterChip(
                      label: Text(cat.label),
                      selected: _category == cat.slug,
                      onSelected: (_) => setState(() => _category = cat.slug),
                    ),
              ],
            ),
            SizedBox(height: context.eos.spacing.lg),
            if (items.isEmpty)
              const EmptyStateCard(
                title: 'No rental items yet',
                message: 'Rental vendors can list packages and equipment.',
                icon: Icons.inventory_2_outlined,
              )
            else
              ...items.map(
                    (item) => _RentalItemCard(
                      item: item,
                      eventId: widget.eventId,
                      vendorBuyerMode: widget.vendorBuyerMode,
                      isOwnOffering: isMarketplaceOwnOffering(
                        offeringVendorId: item.vendorId,
                        currentVendorId: currentVendorId,
                      ),
                    ),
                  ),
          ],
        ),
      );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Rentals & equipment'),
      ),
      body: body,
    );
  }
}

class _RentalItemCard extends ConsumerStatefulWidget {
  const _RentalItemCard({
    required this.item,
    this.eventId,
    this.vendorBuyerMode = false,
    this.isOwnOffering = false,
  });

  final RentalCatalogItem item;
  final String? eventId;
  final bool vendorBuyerMode;
  final bool isOwnOffering;

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
      if (widget.vendorBuyerMode) {
        await ref.read(rentalsApiProvider).createVendorBuyerBooking(
              eventId: eventId,
              catalogItemId: widget.item.id,
              requesterName: _nameCtrl.text.trim().isEmpty ? 'Vendor buyer' : _nameCtrl.text.trim(),
              deliveryAddress: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
            );
      } else {
        await ref.read(rentalsApiProvider).createBooking(
              eventId: eventId,
              catalogItemId: widget.item.id,
              quantityRequested: widget.item.isPackage ? 1 : (int.tryParse(_qtyCtrl.text.trim()) ?? 1),
              requesterName: _nameCtrl.text.trim().isEmpty ? 'Event organizer' : _nameCtrl.text.trim(),
              deliveryAddress: _addressCtrl.text.trim(),
            );
      }
      refreshRentals(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rental request submitted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(EventFriendlyErrors.actionFailedMessage)),
        );
      }
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
            Text(
              item.availableQuantity < 1
                  ? 'Unavailable'
                  : '${item.availableQuantity} of ${item.totalQuantity} available',
              style: context.eosText.bodySmall,
            ),
            if (item.isPackage && item.components.isNotEmpty) ...[
              SizedBox(height: context.eos.spacing.xs),
              Text(
                item.components.map((c) => '${c.label} × ${c.quantity}').join(' · '),
                style: context.eosText.bodySmall,
              ),
            ],
            if (widget.isOwnOffering) ...[
              SizedBox(height: context.eos.spacing.sm),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('View'),
                  ),
                  SizedBox(width: context.eos.spacing.sm),
                  FilledButton(
                    onPressed: () => context.push('/vendor/offerings'),
                    child: const Text('Manage'),
                  ),
                ],
              ),
            ] else if (widget.eventId != null) ...[
              SizedBox(height: context.eos.spacing.sm),
              if (!item.isPackage)
                TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                ),
              if (!item.isPackage) SizedBox(height: context.eos.spacing.xs),
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
              FilledButton(
                onPressed: item.availableQuantity < 1 ? null : _request,
                child: Text(item.availableQuantity < 1 ? 'Unavailable' : 'Request rental'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
