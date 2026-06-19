import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../data/vendor_store.dart';
import '../models/vendor_models.dart';
import '../providers/vendor_providers.dart';
import '../widgets/vendor_shared.dart';

class OrdersBookingsScreen extends ConsumerWidget {
  const OrdersBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventId = ref.watch(selectedVendorEventIdProvider);
    final orders = ref.watch(vendorOrdersProvider);
    final viewMode = ref.watch(vendorOrdersViewModeProvider);

    return EosPageScaffold(
      title: 'Orders & bookings',
      subtitle: 'Customer requests across your events',
      actions: [
        SegmentedButton<VendorOrdersViewMode>(
          segments: const [
            ButtonSegment(value: VendorOrdersViewMode.cards, icon: Icon(Icons.view_agenda_outlined, size: 18)),
            ButtonSegment(value: VendorOrdersViewMode.table, icon: Icon(Icons.table_rows_outlined, size: 18)),
          ],
          selected: {viewMode},
          onSelectionChanged: (s) => ref.read(vendorOrdersViewModeProvider.notifier).state = s.first,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VendorEventPicker(),
          SizedBox(height: context.eos.spacing.lg),
          orders.when(
            data: (list) {
              final filtered = eventId == null ? list : list.where((o) => o.eventId == eventId).toList();
              if (filtered.isEmpty) {
                return EosSurfaceCard(
                  child: Padding(
                    padding: EdgeInsets.all(context.eos.spacing.lg),
                    child: Text('No bookings for this event yet', style: context.eosText.bodyMedium),
                  ),
                );
              }
              if (viewMode == VendorOrdersViewMode.table) {
                return _OrdersTable(orders: filtered, ref: ref);
              }
              return _OrdersCards(orders: filtered, ref: ref);
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
        ],
      ),
    );
  }
}

class _OrdersCards extends StatelessWidget {
  const _OrdersCards({required this.orders, required this.ref});

  final List<VendorOrder> orders;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByStatus(orders);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in grouped.entries) ...[
          EosSection(
            title: _groupTitle(entry.key),
            child: Column(
              children: [
                for (final o in entry.value)
                  Padding(
                    padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                    child: VendorOrderCard(
                      order: o,
                      onAccept: o.status == VendorOrderStatus.newOrder
                          ? () => _update(ref, o.id, VendorOrderStatus.accepted)
                          : null,
                      onFulfill: o.status == VendorOrderStatus.inProgress
                          ? () => _update(ref, o.id, VendorOrderStatus.fulfilled)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OrdersTable extends StatelessWidget {
  const _OrdersTable({required this.orders, required this.ref});

  final List<VendorOrder> orders;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return EosDataTable(
      columns: const [
        DataColumn(label: Text('Customer')),
        DataColumn(label: Text('Event')),
        DataColumn(label: Text('Package')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Amount')),
        DataColumn(label: Text('')),
      ],
      rows: orders.map((o) {
        return DataRow(
          cells: [
            DataCell(Text(o.customerName, style: context.eosText.titleSmall)),
            DataCell(Text(o.eventTitle, style: context.eosText.bodySmall)),
            DataCell(Text(o.itemName, style: context.eosText.bodySmall)),
            DataCell(EosFinanceChip(label: o.statusLabel, compact: true)),
            DataCell(VendorMoneyText(minor: o.amountMinor, compact: true)),
            DataCell(
              o.status == VendorOrderStatus.newOrder
                  ? TextButton(
                      onPressed: () => _update(ref, o.id, VendorOrderStatus.accepted),
                      child: const Text('Accept'),
                    )
                  : o.status == VendorOrderStatus.inProgress
                      ? TextButton(
                          onPressed: () => _update(ref, o.id, VendorOrderStatus.fulfilled),
                          child: const Text('Fulfill'),
                        )
                      : const SizedBox.shrink(),
            ),
          ],
        );
      }).toList(),
    );
  }
}

void _update(WidgetRef ref, String id, VendorOrderStatus status) {
  VendorStore.instance.updateOrderStatus(id, status);
  bumpVendorRevision(ref);
}

Map<VendorOrderStatus, List<VendorOrder>> _groupByStatus(List<VendorOrder> orders) {
  final map = <VendorOrderStatus, List<VendorOrder>>{};
  for (final o in orders) {
    map.putIfAbsent(o.status, () => []).add(o);
  }
  const order = [
    VendorOrderStatus.newOrder,
    VendorOrderStatus.accepted,
    VendorOrderStatus.inProgress,
    VendorOrderStatus.fulfilled,
    VendorOrderStatus.cancelled,
  ];
  return {for (final s in order) if (map.containsKey(s)) s: map[s]!};
}

String _groupTitle(VendorOrderStatus status) => switch (status) {
      VendorOrderStatus.newOrder => 'New',
      VendorOrderStatus.accepted => 'Accepted',
      VendorOrderStatus.inProgress => 'In progress',
      VendorOrderStatus.fulfilled => 'Fulfilled',
      VendorOrderStatus.cancelled => 'Cancelled',
    };
