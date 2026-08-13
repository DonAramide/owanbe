import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/auth_notifier.dart';
import '../../../../core/api/persistence_providers.dart';
import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../../../features/public/providers/ticket_commerce_providers.dart';
import '../../data/organizer_persistence.dart';
import '../../models/organizer_models.dart';
import '../../providers/organizer_providers.dart';
import '../../widgets/organizer_ticket_tier_editor.dart';

class TicketsTabV3 extends ConsumerStatefulWidget {
  const TicketsTabV3({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<TicketsTabV3> createState() => _TicketsTabV3State();
}

class _TicketsTabV3State extends ConsumerState<TicketsTabV3> {
  List<Map<String, dynamic>>? _sales;
  List<Map<String, dynamic>>? _orders;
  Map<String, dynamic>? _summary;
  var _loadingSales = false;
  var _loadingOrders = false;
  String? _ordersError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSales();
      _loadOrders();
    });
  }

  Future<void> _loadSales() async {
    setState(() => _loadingSales = true);
    try {
      final items = await ref.read(eventsApiProvider).fetchTierSales(widget.eventId);
      if (mounted) setState(() => _sales = items);
    } catch (_) {
      if (mounted) setState(() => _sales = null);
    } finally {
      if (mounted) setState(() => _loadingSales = false);
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loadingOrders = true;
      _ordersError = null;
    });
    try {
      final session = ref.read(authSessionProvider);
      if (session == null) {
        if (mounted) setState(() => _ordersError = 'Sign in required');
        return;
      }
      final api = ref.read(ticketCommerceApiProvider);
      final body = await api.fetchOrganizerEventOrders(session: session, eventId: widget.eventId);
      final items = (body['items'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final summary = body['summary'] is Map
          ? Map<String, dynamic>.from(body['summary'] as Map)
          : null;
      if (mounted) {
        setState(() {
          _orders = items;
          _summary = summary;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _ordersError = '$e');
    } finally {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadSales(), _loadOrders()]);
    ref.invalidate(organizerEventProvider(widget.eventId));
  }

  Future<void> _openOrderDetail(String orderId) async {
    final session = ref.read(authSessionProvider);
    if (session == null || !mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _OrderDetailDialog(eventId: widget.eventId, orderId: orderId),
    );
  }

  Future<void> _onDelete(OrganizerTicketTier t) async {
    final ok = await confirmDeleteTicketTier(context, t);
    if (!ok || !mounted) return;
    try {
      await deleteTicketTier(ref, t);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ticket "${t.name}" removed')),
      );
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  Future<void> _onArchive(OrganizerTicketTier t) async {
    try {
      await archiveTicketTier(ref, t);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Archived "${t.name}"')));
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Archive failed: $e')));
    }
  }

  Future<void> _onDuplicate(OrganizerTicketTier t) async {
    try {
      await duplicateTicketTier(ref, t);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Duplicated "${t.name}"')));
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Duplicate failed: $e')));
    }
  }

  Future<void> _onReorder(OrganizerEvent event, int oldIndex, int newIndex) async {
    final tiers = List<OrganizerTicketTier>.from(event.ticketTiers);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = tiers.removeAt(oldIndex);
    tiers.insert(newIndex, item);
    try {
      await reorderTicketTiers(ref, event.id, tiers);
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reorder failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(organizerEventProvider(widget.eventId));

    return eventAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: EosSurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load tickets', style: context.eosText.titleSmall),
              Text('$e', style: context.eosText.bodySmall),
              OutlinedButton(
                onPressed: () => ref.invalidate(organizerEventProvider(widget.eventId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (event) {
        if (event == null) {
          return EosSurfaceCard(child: Text('Event not found', style: context.eosText.bodyMedium));
        }
        final active = event.ticketTiers.where((t) => !t.archived).toList();
        final archived = event.ticketTiers.where((t) => t.archived).toList();
        final ordersCount = _summary?['ordersCount'] as num? ?? event.ordersCount;
        final buyersCount = _summary?['buyersCount'] as num? ?? event.buyersCount;
        final ticketsSold = _summary?['ticketsSold'] as num? ?? event.ticketsSold;
        final remaining = _summary?['remainingInventory'] as num? ??
            event.ticketTiers.where((t) => !t.archived).fold<int>(0, (s, t) => s + t.remaining);
        final revenue =
            int.tryParse('${_summary?['revenueMinor'] ?? event.revenueMinor}') ?? event.revenueMinor;

        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(context.eos.spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tickets & Commerce', style: context.eosText.titleLarge),
                          Text(
                            '${event.listingVisibility.replaceAll('_', ' ')} · ${event.status.name}',
                            style: context.eosText.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        await showOrganizerTicketTierEditor(context, ref, eventId: event.id);
                        await _refreshAll();
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create ticket'),
                    ),
                  ],
                ),
                SizedBox(height: context.eos.spacing.md),
                Wrap(
                  spacing: context.eos.spacing.sm,
                  runSpacing: context.eos.spacing.sm,
                  children: [
                    _KpiChip(label: 'Orders', value: '$ordersCount'),
                    _KpiChip(label: 'Buyers', value: '$buyersCount'),
                    _KpiChip(label: 'Tickets sold', value: '$ticketsSold'),
                    _KpiChip(label: 'Remaining', value: '$remaining'),
                    _KpiChip(label: 'Revenue', value: formatRevenue(revenue)),
                  ],
                ),
                SizedBox(height: context.eos.spacing.lg),
                if (_loadingSales)
                  const LinearProgressIndicator()
                else if (_sales != null && _sales!.isNotEmpty) ...[
                  Text('Sales by tier', style: context.eosText.titleSmall),
                  SizedBox(height: context.eos.spacing.sm),
                  EosSurfaceCard(
                    child: Column(
                      children: [
                        for (final s in _sales!)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('${s['name']}', style: context.eosText.bodyMedium),
                            subtitle: Text(
                              s['unlimitedCapacity'] == true
                                  ? '${s['sold']} sold · unlimited'
                                  : '${s['sold']} sold · ${s['remaining']} remaining'
                                      '${s['soldOut'] == true ? ' · SOLD OUT' : ''}',
                              style: context.eosText.bodySmall,
                            ),
                            trailing: Text(
                              formatRevenue(int.tryParse('${s['revenueMinor']}') ?? 0),
                              style: context.eosText.titleSmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.eos.spacing.lg),
                ],
                Text('Orders', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                if (_loadingOrders)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_ordersError != null)
                  EosSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Could not load orders', style: context.eosText.titleSmall),
                        Text(_ordersError!, style: context.eosText.bodySmall),
                        TextButton(onPressed: _loadOrders, child: const Text('Retry')),
                      ],
                    ),
                  )
                else if (_orders == null || _orders!.isEmpty)
                  EosSurfaceCard(
                    child: Text(
                      'No orders yet. When attendees purchase or register, orders appear here.',
                      style: context.eosText.bodyMedium,
                    ),
                  )
                else
                  EosSurfaceCard(
                    child: Column(
                      children: [
                        for (final o in _orders!)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${o['buyerName'] ?? 'Buyer'}',
                              style: context.eosText.titleSmall,
                            ),
                            subtitle: Text(
                              '${o['ticketTypes'] ?? 'Ticket'} · qty ${o['quantity'] ?? 1}\n'
                              '${o['status']} · ${o['paymentStatus'] ?? '—'} · '
                              '${_fmtDate(o['createdAt'])}',
                              style: context.eosText.bodySmall,
                            ),
                            isThreeLine: true,
                            trailing: Text(
                              formatRevenue(int.tryParse('${o['totalMinor']}') ?? 0),
                              style: context.eosText.titleSmall,
                            ),
                            onTap: () => _openOrderDetail('${o['id']}'),
                          ),
                      ],
                    ),
                  ),
                SizedBox(height: context.eos.spacing.lg),
                Text('Ticket types', style: context.eosText.titleSmall),
                SizedBox(height: context.eos.spacing.sm),
                if (active.isEmpty && archived.isEmpty)
                  EosSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No tickets yet', style: context.eosText.titleSmall),
                        SizedBox(height: context.eos.spacing.xs),
                        Text(
                          'Create your first ticket to set price, capacity, sales window, and visibility.',
                          style: context.eosText.bodyMedium,
                        ),
                        SizedBox(height: context.eos.spacing.sm),
                        FilledButton.icon(
                          onPressed: () => showOrganizerTicketTierEditor(context, ref, eventId: event.id),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Create ticket'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: active.length,
                    onReorder: (o, n) => _onReorder(event, o, n),
                    itemBuilder: (context, index) {
                      final t = active[index];
                      return Padding(
                        key: ValueKey(t.id),
                        padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                        child: EosSurfaceCard(
                          elevated: true,
                          child: ListTile(
                            leading: const Icon(Icons.drag_handle),
                            title: Text(t.name, style: context.eosText.titleSmall),
                            subtitle: Text(
                              '${ticketTierTypeLabel(t.tierType)} · '
                              '${t.unlimitedCapacity ? 'unlimited' : '${t.capacity - t.remaining}/${t.capacity} sold'} · '
                              '${t.visibility == TicketVisibility.publicListing ? 'public' : 'hidden'}'
                              '${t.salesPaused ? ' · paused' : ''}'
                              '${t.isSoldOut ? ' · sold out' : ''}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(ngnFromMinor(t.priceMinor.toString()), style: context.eosText.titleSmall),
                                PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    switch (v) {
                                      case 'edit':
                                        await showOrganizerTicketTierEditor(
                                          context,
                                          ref,
                                          eventId: event.id,
                                          existing: t,
                                        );
                                        await _refreshAll();
                                      case 'duplicate':
                                        await _onDuplicate(t);
                                      case 'archive':
                                        await _onArchive(t);
                                      case 'delete':
                                        await _onDelete(t);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                                    PopupMenuItem(value: 'archive', child: Text('Archive')),
                                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () async {
                              await showOrganizerTicketTierEditor(
                                context,
                                ref,
                                eventId: event.id,
                                existing: t,
                              );
                              await _refreshAll();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  if (archived.isNotEmpty) ...[
                    SizedBox(height: context.eos.spacing.lg),
                    Text('Archived', style: context.eosText.titleSmall),
                    SizedBox(height: context.eos.spacing.sm),
                    for (final t in archived)
                      EosSurfaceCard(
                        child: ListTile(
                          title: Text(t.name, style: context.eosText.bodyMedium),
                          subtitle: const Text('Archived — not available for purchase'),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmtDate(Object? raw) {
    final d = raw == null ? null : DateTime.tryParse(raw.toString());
    if (d == null) return '—';
    return '${d.toLocal()}'.split('.').first;
  }
}

class _KpiChip extends StatelessWidget {
  const _KpiChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.eos.spacing.md,
          vertical: context.eos.spacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.eosText.bodySmall),
            Text(value, style: context.eosText.titleSmall),
          ],
        ),
      ),
    );
  }
}

class _OrderDetailDialog extends ConsumerStatefulWidget {
  const _OrderDetailDialog({required this.eventId, required this.orderId});

  final String eventId;
  final String orderId;

  @override
  ConsumerState<_OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends ConsumerState<_OrderDetailDialog> {
  Map<String, dynamic>? _order;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = ref.read(authSessionProvider);
      if (session == null) {
        setState(() => _error = 'Sign in required');
        return;
      }
      final body = await ref.read(ticketCommerceApiProvider).fetchOrganizerOrderDetail(
            session: session,
            eventId: widget.eventId,
            orderId: widget.orderId,
          );
      final order = body['order'];
      if (mounted) {
        setState(() {
          _order = order is Map ? Map<String, dynamic>.from(order) : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Order detail'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? Text(_error!)
                : _order == null
                    ? const Text('Order not found')
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${(_order!['buyer'] as Map?)?['name'] ?? 'Buyer'}',
                              style: context.eosText.titleSmall,
                            ),
                            Text('${(_order!['buyer'] as Map?)?['email'] ?? ''}', style: context.eosText.bodySmall),
                            SizedBox(height: context.eos.spacing.sm),
                            Text('Status: ${_order!['status']}'),
                            Text('Payment: ${_order!['paymentStatus'] ?? '—'}'),
                            Text('Refund: ${_order!['refundStatus'] ?? 'none'}'),
                            Text('Amount: ${formatRevenue(int.tryParse('${_order!['totalMinor']}') ?? 0)}'),
                            Text('Ref: ${_order!['transactionReference'] ?? '—'}'),
                            SizedBox(height: context.eos.spacing.md),
                            Text('Tickets', style: context.eosText.titleSmall),
                            for (final line in (_order!['lines'] as List<dynamic>? ?? []).whereType<Map>())
                              Text(
                                '• ${line['tierName']} × ${line['quantity']} — '
                                '${formatRevenue(int.tryParse('${line['lineSubtotalMinor']}') ?? 0)}',
                              ),
                            if ((_order!['entitlements'] as List?)?.isNotEmpty == true) ...[
                              SizedBox(height: context.eos.spacing.md),
                              Text('Passes', style: context.eosText.titleSmall),
                              for (final e in (_order!['entitlements'] as List).whereType<Map>())
                                Text('• ${e['ticketCode']} (${e['status']})'),
                            ],
                          ],
                        ),
                      ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}
