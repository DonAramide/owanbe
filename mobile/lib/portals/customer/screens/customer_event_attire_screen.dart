import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../models/fashion_attire_constants.dart';
import '../models/aso_ebi_models.dart';
import '../providers/aso_ebi_providers.dart';
import '../providers/customer_event_command_providers.dart';
import '../providers/event_attire_providers.dart';
import '../providers/marketplace_providers.dart';
import '../router/customer_routes.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/section_header.dart';

/// Attire Management — Fashion & Attire vertical at `/events/:eventId/attire`.
/// Uses the event-scoped aso-ebi API for packages, reservations, and inventory.
class CustomerEventAttireScreen extends ConsumerStatefulWidget {
  const CustomerEventAttireScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<CustomerEventAttireScreen> createState() => _CustomerEventAttireScreenState();
}

class _CustomerEventAttireScreenState extends ConsumerState<CustomerEventAttireScreen>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  TabController? _tabs;

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      refreshAsoEbi(ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownership = ref.watch(customerEventOwnershipProvider(widget.eventId));
    final isOwner = ownership.valueOrNull == true;

    if (isOwner) {
      final data = ref.watch(asoEbiManageProvider(widget.eventId));
      _tabs ??= TabController(length: 4, vsync: this);
      return _buildScaffold(
        isOwner: true,
        body: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _errorBody(e.toString()),
          data: (snap) => TabBarView(
            controller: _tabs,
            children: [
              _VendorsTab(eventId: widget.eventId),
              _PackagesTab(eventId: widget.eventId, fabrics: snap.fabrics, onRefresh: () => refreshAsoEbi(ref)),
              _OrdersTab(eventId: widget.eventId, reservations: snap.reservations, onAction: _run),
              _DashboardTab(dashboard: snap.dashboard),
            ],
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.storefront_outlined), text: 'Vendors'),
            Tab(icon: Icon(Icons.checkroom_outlined), text: 'Packages'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Orders'),
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Dashboard'),
          ],
        ),
      );
    }

    final data = ref.watch(asoEbiPublicProvider(widget.eventId));
    return _buildScaffold(
      isOwner: false,
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _errorBody(e.toString()),
        data: (snap) => _GuestAttireFlow(
          eventId: widget.eventId,
          fabrics: snap.fabrics,
          onReserve: _run,
        ),
      ),
    );
  }

  Widget _errorBody(String message) {
    return ListView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      children: [
        EmptyStateCard(
          title: 'Could not load attire',
          message: message,
          actionLabel: 'Back to event',
          onAction: () => context.go(CustomerRoutes.eventDetail(widget.eventId)),
        ),
      ],
    );
  }

  Widget _buildScaffold({required bool isOwner, required Widget body, PreferredSizeWidget? bottom}) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(CustomerRoutes.eventDetail(widget.eventId));
            }
          },
        ),
        title: Text(isOwner ? 'Attire management' : 'Event attire'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
        bottom: bottom,
      ),
      body: body,
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.dashboard});

  final AsoEbiDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      children: [
        const SectionHeader(
          title: 'Attire sales',
          subtitle: 'Reservations, payments, and pickup across Fashion & Attire.',
        ),
        GridView.count(
          crossAxisCount: EosResponsive.isMobile(context) ? 2 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: context.eos.spacing.sm,
          mainAxisSpacing: context.eos.spacing.sm,
          childAspectRatio: 1.4,
          children: [
            _StatCard(label: 'Total sales', value: '${dashboard.totalSales}', icon: Icons.shopping_bag_outlined),
            _StatCard(
              label: 'Revenue',
              value: formatRevenue(dashboard.revenueMinor),
              icon: Icons.payments_outlined,
            ),
            _StatCard(
              label: 'Outstanding pickup',
              value: '${dashboard.outstandingPickup}',
              icon: Icons.local_shipping_outlined,
            ),
            _StatCard(
              label: 'Pay later',
              value: '${dashboard.pendingPayment}',
              icon: Icons.schedule_outlined,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: context.eosColors.primary),
          SizedBox(height: context.eos.spacing.xs),
          Text(value, style: context.eosText.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text(label, style: context.eosText.bodySmall),
        ],
      ),
    );
  }
}

class _VendorsTab extends ConsumerStatefulWidget {
  const _VendorsTab({required this.eventId});

  final String eventId;

  @override
  ConsumerState<_VendorsTab> createState() => _VendorsTabState();
}

class _VendorsTabState extends ConsumerState<_VendorsTab> {
  String _subcategory = fashionAttireVertical;

  @override
  Widget build(BuildContext context) {
    final preferred = ref.watch(preferredAttireVendorProvider(widget.eventId));
    final vendorsAsync = ref.watch(marketplaceVendorsProvider);
    final categories = [fashionAttireVertical, ...fashionAttireSubcategories];

    return vendorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: [EmptyStateCard(title: 'Could not load vendors', message: '$e')],
      ),
      data: (vendors) {
        final fashionVendors = vendors.where((v) => v.isFashionAttireVendor).toList();
        final filtered = _subcategory == fashionAttireVertical
            ? fashionVendors
            : fashionVendors.where((v) => v.fashionSubcategory == _subcategory || v.matchesService(_subcategory)).toList();

        return ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            const SectionHeader(
              title: 'Fashion & Attire vendors',
              subtitle: 'Browse marketplace tailors and fabric houses for this event.',
            ),
            preferred.when(
              data: (p) => p.id != null
                  ? EosSurfaceCard(
                      child: ListTile(
                        leading: const Icon(Icons.verified_outlined, color: EosColors.plum),
                        title: Text('Preferred vendor: ${p.name ?? 'Selected'}'),
                        subtitle: const Text('Packages you publish are linked to this partner'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            await clearPreferredAttireVendor(widget.eventId);
                            ref.invalidate(preferredAttireVendorProvider(widget.eventId));
                          },
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            SizedBox(height: context.eos.spacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final cat in categories)
                  FilterChip(
                    label: Text(cat),
                    selected: _subcategory == cat,
                    onSelected: (_) => setState(() => _subcategory = cat),
                  ),
              ],
            ),
            SizedBox(height: context.eos.spacing.md),
            OutlinedButton.icon(
              onPressed: () => context.push(
                '${CustomerRoutes.vendors}?category=${Uri.encodeComponent(_subcategory)}',
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open marketplace'),
            ),
            SizedBox(height: context.eos.spacing.lg),
            if (filtered.isEmpty)
              const EmptyStateCard(
                title: 'No fashion vendors yet',
                message: 'Invite tailors and fabric vendors from the marketplace, or add vendors with fashion-related slugs.',
                icon: Icons.storefront_outlined,
              )
            else
              ...filtered.map(
                (v) => Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                  child: EosSurfaceCard(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: v.imageUrl != null ? NetworkImage(v.imageUrl!) : null,
                        child: v.imageUrl == null ? const Icon(Icons.checkroom_outlined) : null,
                      ),
                      title: Text(v.businessName),
                      subtitle: Text('${v.fashionSubcategory ?? v.categoryLabel} · ${v.city ?? 'Nigeria'}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'select') {
                            await setPreferredAttireVendor(
                              eventId: widget.eventId,
                              vendorId: v.id,
                              vendorName: v.businessName,
                            );
                            ref.invalidate(preferredAttireVendorProvider(widget.eventId));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${v.businessName} set as preferred vendor')),
                              );
                            }
                          } else if (action == 'sample') {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Sample request sent to ${v.businessName}')),
                              );
                            }
                            context.push(CustomerRoutes.vendorDetail(v.id));
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'select', child: Text('Select preferred vendor')),
                          PopupMenuItem(value: 'sample', child: Text('Request fabric sample')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PackagesTab extends StatelessWidget {
  const _PackagesTab({required this.eventId, required this.fabrics, required this.onRefresh});

  final String eventId;
  final List<AsoEbiFabric> fabrics;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      children: [
        FilledButton.icon(
          onPressed: () => _showAddFabric(context),
          icon: const Icon(Icons.add),
          label: const Text('Add fabric'),
        ),
        SizedBox(height: context.eos.spacing.lg),
        if (fabrics.isEmpty)
          const EmptyStateCard(
            title: 'No packages yet',
            message: 'Publish attire packages for guests after selecting a Fashion & Attire vendor.',
            icon: Icons.checkroom_outlined,
          )
        else
          ...fabrics.map((f) => _OrganizerFabricCard(eventId: eventId, fabric: f, onRefresh: onRefresh)),
      ],
    );
  }

  Future<void> _showAddFabric(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final photoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add fabric'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
              TextField(controller: photoCtrl, decoration: const InputDecoration(labelText: 'Photo URL')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final container = ProviderScope.containerOf(context);
    try {
      await container.read(asoEbiApiProvider).createFabric(eventId, {
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'photoUrl': photoCtrl.text.trim(),
      });
      onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _OrganizerFabricCard extends ConsumerStatefulWidget {
  const _OrganizerFabricCard({required this.eventId, required this.fabric, required this.onRefresh});

  final String eventId;
  final AsoEbiFabric fabric;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_OrganizerFabricCard> createState() => _OrganizerFabricCardState();
}

class _OrganizerFabricCardState extends ConsumerState<_OrganizerFabricCard> {
  bool _expanded = false;

  Future<void> _savePackages() async {
    final controllers = <String, TextEditingController>{};
    for (final type in asoEbiPackageTypes) {
      final pkg = widget.fabric.packageOf(type);
      final naira = ((pkg?.priceMinor ?? 0) / 100).round();
      controllers[type] = TextEditingController(text: naira > 0 ? '$naira' : '');
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Package prices (₦)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final type in asoEbiPackageTypes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: controllers[type],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: asoEbiPackageLabels[type],
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(asoEbiApiProvider).upsertPackages(
            widget.eventId,
            widget.fabric.id,
            asoEbiPackageTypes.map((type) {
              final naira = int.tryParse(controllers[type]!.text.trim()) ?? 0;
              return {'packageType': type, 'priceMinor': naira * 100};
            }).toList(),
          );
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _saveInventory() async {
    final packageType = ValueNotifier(asoEbiPackageTypes.first);
    final sizeCtrls = {for (final s in asoEbiDefaultSizes) s: TextEditingController()};
    for (final item in widget.fabric.inventory) {
      if (sizeCtrls.containsKey(item.size)) {
        sizeCtrls[item.size]!.text = '${item.available}';
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inventory by size'),
        content: StatefulBuilder(
          builder: (context, setLocal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: packageType.value,
                  decoration: const InputDecoration(labelText: 'Package'),
                  items: asoEbiPackageTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(asoEbiPackageLabels[t]!)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setLocal(() => packageType.value = v);
                  },
                ),
                const SizedBox(height: 8),
                for (final size in asoEbiDefaultSizes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: sizeCtrls[size],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Size $size — available',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(asoEbiApiProvider).upsertInventory(
            widget.eventId,
            widget.fabric.id,
            asoEbiDefaultSizes.map((size) {
              return {
                'packageType': packageType.value,
                'size': size,
                'available': int.tryParse(sizeCtrls[size]!.text.trim()) ?? 0,
              };
            }).toList(),
          );
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fabric;
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: EosSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  if (f.photoUrl != null && f.photoUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(f.photoUrl!, width: 56, height: 56, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported)),
                    )
                  else
                    const CircleAvatar(child: Icon(Icons.checkroom_outlined)),
                  SizedBox(width: context.eos.spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.name, style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        if (f.description.isNotEmpty)
                          Text(f.description, style: context.eosText.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            if (_expanded) ...[
              SizedBox(height: context.eos.spacing.sm),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in f.packages)
                    Chip(label: Text('${p.label}: ${formatRevenue(p.priceMinor)}')),
                ],
              ),
              if (f.inventory.isNotEmpty) ...[
                SizedBox(height: context.eos.spacing.xs),
                Text('Inventory', style: context.eosText.labelMedium),
                for (final i in f.inventory.take(8))
                  Text(
                    '${asoEbiPackageLabels[i.packageType]} · ${i.size}: ${i.available} avail · ${i.reserved} reserved · ${i.collected} collected',
                    style: context.eosText.bodySmall,
                  ),
              ],
              Row(
                children: [
                  TextButton(onPressed: _savePackages, child: const Text('Edit prices')),
                  TextButton(onPressed: _saveInventory, child: const Text('Edit inventory')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({
    required this.eventId,
    required this.reservations,
    required this.onAction,
  });

  final String eventId;
  final List<AsoEbiReservation> reservations;
  final Future<void> Function(Future<void> Function()) onAction;

  @override
  Widget build(BuildContext context) {
    final active = reservations.where((r) => !r.isCancelled).toList();
    return ListView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      children: [
        if (active.isEmpty)
          const EmptyStateCard(
            title: 'No orders yet',
            message: 'Guest attire reservations and payments will appear here.',
            icon: Icons.inventory_2_outlined,
          )
        else
          ...active.map(
            (r) => Padding(
              padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
              child: EosSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.guestName, style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text('${r.fabricName} · ${r.packageLabel} · Size ${r.size}'),
                    Text(formatRevenue(r.priceMinor), style: context.eosText.bodyMedium),
                    Text(
                      '${r.isPaid ? 'Paid' : 'Pay later'} · ${r.isCollected ? 'Collected' : 'Reserved'}',
                      style: context.eosText.bodySmall,
                    ),
                    if (!r.isCollected && r.fulfillmentStatus == 'reserved') ...[
                      SizedBox(height: context.eos.spacing.xs),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (!r.isPaid)
                            OutlinedButton(
                              onPressed: () => onAction(() async {
                                final api = ProviderScope.containerOf(context).read(asoEbiApiProvider);
                                await api.pay(eventId, r.id);
                              }),
                              child: const Text('Mark paid'),
                            ),
                          FilledButton(
                            onPressed: () => onAction(() async {
                              final api = ProviderScope.containerOf(context).read(asoEbiApiProvider);
                              await api.collect(eventId, r.id);
                            }),
                            child: const Text('Mark collected'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GuestAttireFlow extends ConsumerStatefulWidget {
  const _GuestAttireFlow({required this.eventId, required this.fabrics, required this.onReserve});

  final String eventId;
  final List<AsoEbiFabric> fabrics;
  final Future<void> Function(Future<void> Function()) onReserve;

  @override
  ConsumerState<_GuestAttireFlow> createState() => _GuestAttireFlowState();
}

class _GuestAttireFlowState extends ConsumerState<_GuestAttireFlow> {
  AsoEbiFabric? _selected;
  String? _packageType;
  String? _size;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final List<AsoEbiReservation> _myOrders = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _reserve() async {
    final fabric = _selected;
    if (fabric == null || _packageType == null || _size == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select fabric, package, and size')));
      return;
    }
    await widget.onReserve(() async {
      final reservation = await ref.read(asoEbiApiProvider).reserve(
            eventId: widget.eventId,
            fabricId: fabric.id,
            packageType: _packageType!,
            size: _size!,
            guestName: _nameCtrl.text.trim(),
            guestEmail: _emailCtrl.text.trim(),
          );
      if (mounted) {
        setState(() {
          _myOrders.insert(0, reservation);
          _size = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reserved — ${formatRevenue(reservation.priceMinor)}')),
        );
      }
    });
  }

  Future<void> _pay(AsoEbiReservation order) async {
    await widget.onReserve(() async {
      final updated = await ref.read(asoEbiApiProvider).pay(widget.eventId, order.id);
      if (mounted) {
        setState(() {
          final idx = _myOrders.indexWhere((o) => o.id == order.id);
          if (idx >= 0) _myOrders[idx] = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fabrics.isEmpty) {
      return ListView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: const [
          EmptyStateCard(
            title: 'Attire not published yet',
            message: 'The organizer has not published event attire packages yet.',
            icon: Icons.checkroom_outlined,
          ),
        ],
      );
    }

    final fabric = _selected ?? widget.fabrics.first;
    final sizes = _packageType != null ? fabric.availableSizes(_packageType!) : <String>[];

    return ListView(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      children: [
        const SectionHeader(title: 'Event attire', subtitle: 'Select a package and reserve your size'),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.fabrics.length,
            separatorBuilder: (_, __) => SizedBox(width: context.eos.spacing.sm),
            itemBuilder: (context, i) {
              final f = widget.fabrics[i];
              final selected = fabric.id == f.id;
              return SizedBox(
                width: 140,
                child: EosSurfaceCard(
                  onTap: () => setState(() {
                    _selected = f;
                    _packageType = null;
                    _size = null;
                  }),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (f.photoUrl != null && f.photoUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(f.photoUrl!, height: 72, width: double.infinity, fit: BoxFit.cover),
                        )
                      else
                        const Icon(Icons.checkroom_outlined, size: 48),
                      Text(
                        f.name,
                        style: context.eosText.labelLarge?.copyWith(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? context.eosColors.primary : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (fabric.description.isNotEmpty) ...[
          SizedBox(height: context.eos.spacing.sm),
          Text(fabric.description, style: context.eosText.bodyMedium),
        ],
        SizedBox(height: context.eos.spacing.lg),
        const SectionHeader(title: 'Package', subtitle: 'Fabric only, with cap, or premium'),
        Wrap(
          spacing: 8,
          children: [
            for (final type in asoEbiPackageTypes)
              ChoiceChip(
                label: Text('${asoEbiPackageLabels[type]} · ${formatRevenue(fabric.packageOf(type)?.priceMinor ?? 0)}'),
                selected: _packageType == type,
                onSelected: (_) => setState(() {
                  _packageType = type;
                  _size = null;
                }),
              ),
          ],
        ),
        if (_packageType != null) ...[
          SizedBox(height: context.eos.spacing.lg),
          const SectionHeader(title: 'Size', subtitle: 'Pick an available size'),
          Wrap(
            spacing: 8,
            children: [
              for (final size in sizes)
                ChoiceChip(
                  label: Text(size),
                  selected: _size == size,
                  onSelected: (_) => setState(() => _size = size),
                ),
              if (sizes.isEmpty)
                Text('No sizes in stock for this package', style: context.eosText.bodySmall),
            ],
          ),
        ],
        SizedBox(height: context.eos.spacing.lg),
        const SectionHeader(title: 'Your details', subtitle: 'Reserve now — pay when ready'),
        EosSurfaceCard(
          child: Column(
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder()),
              ),
              SizedBox(height: context.eos.spacing.sm),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email (optional)', border: OutlineInputBorder()),
              ),
              SizedBox(height: context.eos.spacing.md),
              FilledButton.icon(
                onPressed: _reserve,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Reserve'),
              ),
            ],
          ),
        ),
        if (_myOrders.isNotEmpty) ...[
          SizedBox(height: context.eos.spacing.lg),
          const SectionHeader(title: 'Your orders', subtitle: 'Pay and track collection'),
          for (final order in _myOrders)
            Padding(
              padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
              child: EosSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${order.packageLabel} · Size ${order.size}', style: context.eosText.titleSmall),
                    Text(formatRevenue(order.priceMinor), style: context.eosText.bodyMedium),
                    Text(
                      order.isCollected
                          ? 'Collected'
                          : order.isPaid
                              ? 'Paid — awaiting pickup'
                              : 'Reserved — payment pending',
                      style: context.eosText.bodySmall,
                    ),
                    if (!order.isPaid && !order.isCollected) ...[
                      SizedBox(height: context.eos.spacing.xs),
                      FilledButton(onPressed: () => _pay(order), child: const Text('Pay now')),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
