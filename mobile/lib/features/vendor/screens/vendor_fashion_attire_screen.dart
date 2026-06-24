import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../models/vendor_models.dart';
import '../providers/vendor_providers.dart';
import '../widgets/vendor_shared.dart';

/// Fashion & Attire vendor hub — fabrics, inventory, orders, and collection.
class VendorFashionAttireScreen extends ConsumerStatefulWidget {
  const VendorFashionAttireScreen({super.key});

  @override
  ConsumerState<VendorFashionAttireScreen> createState() => _VendorFashionAttireScreenState();
}

class _VendorFashionAttireScreenState extends ConsumerState<VendorFashionAttireScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(vendorProfileProvider);
    final orders = ref.watch(vendorOrdersProvider);

    return EosPageScaffold(
      title: 'Fashion & Attire',
      subtitle: profile.businessName,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Fabrics'),
              Tab(text: 'Inventory'),
              Tab(text: 'Orders'),
              Tab(text: 'Collection'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _FabricsTab(),
                _InventoryTab(),
                orders.when(
                  data: (items) => _OrdersTab(orders: items),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                ),
                orders.when(
                  data: (items) => _CollectionTab(orders: items),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FabricsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      children: [
        EosSurfaceCard(
          child: ListTile(
            leading: const Icon(Icons.add_photo_alternate_outlined),
            title: const Text('Upload fabrics'),
            subtitle: const Text('Add photos, descriptions, and package pricing for event attire.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fabric upload connects to your service catalog')),
            ),
          ),
        ),
      ],
    );
  }
}

class _InventoryTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      children: const [
        EosSurfaceCard(
          child: ListTile(
            leading: Icon(Icons.inventory_2_outlined),
            title: Text('Manage inventory'),
            subtitle: Text('Track available, reserved, and collected units by size.'),
          ),
        ),
      ],
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.orders});

  final List<VendorOrder> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(child: Text('No attire orders yet'));
    }
    return ListView.builder(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      itemCount: orders.length,
      itemBuilder: (context, i) {
        final o = orders[i];
        return Padding(
          padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
          child: EosSurfaceCard(
            child: ListTile(
              title: Text(o.eventTitle),
              subtitle: Text('${o.itemName} · ${o.statusLabel}'),
              trailing: Text(formatVendorMoney(o.amountMinor)),
            ),
          ),
        );
      },
    );
  }
}

class _CollectionTab extends StatelessWidget {
  const _CollectionTab({required this.orders});

  final List<VendorOrder> orders;

  @override
  Widget build(BuildContext context) {
    final ready = orders.where((o) => o.status == VendorOrderStatus.accepted).toList();
    return ListView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      children: [
        if (ready.isEmpty)
          const EosSurfaceCard(
            child: ListTile(
              leading: Icon(Icons.local_shipping_outlined),
              title: Text('No pickups pending'),
              subtitle: Text('Paid orders ready for collection appear here.'),
            ),
          )
        else
          ...ready.map(
            (o) => EosSurfaceCard(
              child: ListTile(
                leading: const Icon(Icons.checkroom_outlined),
                title: Text(o.eventTitle),
                subtitle: Text('Ready for collection · ${o.itemName}'),
                trailing: FilledButton(
                  onPressed: () {},
                  child: const Text('Mark collected'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
