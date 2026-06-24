import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../portals/customer/models/rentals_constants.dart';
import '../../../portals/customer/models/rentals_models.dart';
import '../../../portals/customer/providers/rentals_providers.dart';
import '../providers/vendor_providers.dart';

/// Rental vendor portal — inventory, orders, delivery, returns, damage claims.
class VendorRentalsScreen extends ConsumerStatefulWidget {
  const VendorRentalsScreen({super.key});

  @override
  ConsumerState<VendorRentalsScreen> createState() => _VendorRentalsScreenState();
}

class _VendorRentalsScreenState extends ConsumerState<VendorRentalsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);
  String get _vendorId => ref.read(vendorProfileProvider).id;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      refreshRentals(ref);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(vendorRentalsInventoryProvider(_vendorId));
    final bookings = ref.watch(vendorRentalsBookingsProvider(_vendorId));

    return EosPageScaffold(
      title: 'Rentals & equipment',
      subtitle: 'Inventory and rental orders',
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Inventory'),
              Tab(text: 'Orders'),
              Tab(text: 'Delivery'),
              Tab(text: 'Returns'),
              Tab(text: 'Claims'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                inventory.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (data) => _InventoryTab(vendorId: _vendorId, items: data.items, onRefresh: () => refreshRentals(ref)),
                ),
                bookings.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (list) => _OrdersTab(vendorId: _vendorId, bookings: list, onAction: _run),
                ),
                bookings.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (list) => _DeliveryTab(bookings: list.where((b) => b.isApproved || b.isDelivered).toList()),
                ),
                bookings.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (list) => _ReturnsTab(
                    vendorId: _vendorId,
                    bookings: list.where((b) => b.isDelivered).toList(),
                    onAction: _run,
                  ),
                ),
                bookings.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (list) => _ClaimsTab(bookings: list.where((b) => b.damageNotes != null).toList()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryTab extends ConsumerWidget {
  const _InventoryTab({required this.vendorId, required this.items, required this.onRefresh});

  final String vendorId;
  final List<RentalCatalogItem> items;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      children: [
        FilledButton.icon(
          onPressed: () async {
            try {
              await ref.read(rentalsApiProvider).createInventoryItem(vendorId, {
                'name': 'Chiavari chairs',
                'categorySlug': 'chairs',
                'description': 'Gold chiavari chairs for owambes',
                'totalQuantity': 200,
                'rentalFeeMinor': 250000,
                'depositMinor': 100000,
              });
              onRefresh();
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Add rental item'),
        ),
        SizedBox(height: context.eos.spacing.md),
        for (final item in items)
          EosSurfaceCard(
            child: ListTile(
              title: Text(item.name),
              subtitle: Text(
                '${rentalCategoryLabel(item.categorySlug)} · ${item.availableQuantity}/${item.totalQuantity} avail · ${item.reservedQuantity} reserved',
              ),
              trailing: Text(formatRevenue(item.rentalFeeMinor)),
            ),
          ),
      ],
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab({required this.vendorId, required this.bookings, required this.onAction});

  final String vendorId;
  final List<RentalBooking> bookings;
  final Future<void> Function(Future<void> Function()) onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bookings.isEmpty) return const Center(child: Text('No rental orders'));
    return ListView.builder(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      itemCount: bookings.length,
      itemBuilder: (context, i) {
        final b = bookings[i];
        return EosSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${b.itemName} · ${b.eventTitle}', style: context.eosText.titleSmall),
              Text('Requested ${b.quantityRequested} · ${b.status}'),
              if (b.isPending || b.isCountered)
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => onAction(() => ref.read(rentalsApiProvider).vendorAction(vendorId, b.id, 'approve')),
                      child: const Text('Approve'),
                    ),
                    OutlinedButton(
                      onPressed: () => onAction(() => ref.read(rentalsApiProvider).vendorAction(
                            vendorId,
                            b.id,
                            'counter',
                            {'counterQuantity': (b.quantityRequested / 2).ceil().clamp(1, b.quantityRequested)},
                          )),
                      child: const Text('Counter'),
                    ),
                    TextButton(
                      onPressed: () => onAction(() => ref.read(rentalsApiProvider).vendorAction(vendorId, b.id, 'decline')),
                      child: const Text('Decline'),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DeliveryTab extends StatelessWidget {
  const _DeliveryTab({required this.bookings});

  final List<RentalBooking> bookings;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return const Center(child: Text('No scheduled deliveries'));
    return ListView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      children: [
        for (final b in bookings)
          ListTile(
            title: Text(b.itemName),
            subtitle: Text('${b.deliveryDate ?? 'TBD'} · ${b.deliveryAddress ?? 'Venue'}'),
          ),
      ],
    );
  }
}

class _ReturnsTab extends ConsumerWidget {
  const _ReturnsTab({required this.vendorId, required this.bookings, required this.onAction});

  final String vendorId;
  final List<RentalBooking> bookings;
  final Future<void> Function(Future<void> Function()) onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bookings.isEmpty) return const Center(child: Text('No returns pending'));
    return ListView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      children: [
        for (final b in bookings)
          EosSurfaceCard(
            child: ListTile(
              title: Text(b.itemName),
              subtitle: Text('Pickup ${b.pickupDate ?? 'TBD'}'),
              trailing: FilledButton(
                onPressed: () => onAction(() => ref.read(rentalsApiProvider).vendorAction(vendorId, b.id, 'return')),
                child: const Text('Mark returned'),
              ),
            ),
          ),
      ],
    );
  }
}

class _ClaimsTab extends StatelessWidget {
  const _ClaimsTab({required this.bookings});

  final List<RentalBooking> bookings;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const Center(child: Text('No damage claims'));
    }
    return ListView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      children: [
        for (final b in bookings)
          ListTile(
            title: Text(b.itemName),
            subtitle: Text(b.damageNotes ?? ''),
          ),
      ],
    );
  }
}
