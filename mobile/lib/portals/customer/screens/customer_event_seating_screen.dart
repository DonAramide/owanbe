import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../features/organizer/providers/organizer_providers.dart';
import '../../../features/operations/models/operations_models.dart';
import '../models/customer_guest_models.dart';
import '../models/seating_models.dart';
import '../providers/customer_guest_providers.dart';
import '../providers/seating_providers.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/section_header.dart';
import '../widgets/seating/seating_canvas.dart';

/// Seating planner at `/events/:eventId/seating`.
class CustomerEventSeatingScreen extends ConsumerStatefulWidget {
  const CustomerEventSeatingScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<CustomerEventSeatingScreen> createState() => _CustomerEventSeatingScreenState();
}

class _CustomerEventSeatingScreenState extends ConsumerState<CustomerEventSeatingScreen> {
  bool _saving = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      refreshSeating(ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addTable() async {
    await _run(() async {
      await ref.read(seatingApiProvider).createTable(widget.eventId, {'label': 'New table'});
    });
  }

  Future<void> _addVipTable() async {
    await _run(() async {
      await ref.read(seatingApiProvider).createTable(widget.eventId, {
        'label': 'VIP table',
        'tableKind': 'vip',
        'capacity': 6,
        'isVip': true,
      });
    });
  }

  Future<void> _autoLayout(int guestCount) async {
    await _run(() async {
      await ref.read(seatingApiProvider).initialize(
            widget.eventId,
            guestCount: guestCount,
            vipTableCount: 1,
          );
    });
  }

  Future<void> _exportLayout(SeatingLayout layout) async {
    final csv = seatingLayoutToCsv(layout);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seating export'),
        content: SingleChildScrollView(
          child: SelectableText(csv, style: Theme.of(ctx).textTheme.bodySmall),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seating layout copied to clipboard')),
    );
  }

  Future<void> _assignGuest(SeatingTable table, CustomerGuestView guest) async {
    await _run(() async {
      await ref.read(seatingApiProvider).assignGuest(
            eventId: widget.eventId,
            tableId: table.id,
            guestRef: guest.id,
            guestName: guest.name,
          );
    });
  }

  Future<void> _unassignGuest(String assignmentId) async {
    await _run(() async {
      await ref.read(seatingApiProvider).unassignGuest(widget.eventId, assignmentId);
    });
  }

  Future<void> _patchTablePosition(SeatingTable table, double x, double y) async {
    await _run(() async {
      await ref.read(seatingApiProvider).patchTable(widget.eventId, table.id, {
        'positionX': x,
        'positionY': y,
      });
    });
  }

  Future<void> _deleteTable(SeatingTable table) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${table.label}?'),
        content: const Text('Guests at this table will be unassigned.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await ref.read(seatingApiProvider).deleteTable(widget.eventId, table.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final seating = ref.watch(eventSeatingProvider(widget.eventId));
    final guests = ref.watch(customerEventGuestsProvider(widget.eventId));
    final event = ref.watch(organizerEventProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Seating planner'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          IconButton(
            tooltip: 'Export layout',
            icon: const Icon(Icons.download_outlined),
            onPressed: seating.maybeWhen(
              data: (layout) => () => _exportLayout(layout),
              orElse: () => null,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final guestCount = event.valueOrNull?.expectedGuests ?? 150;
              switch (value) {
                case 'table':
                  await _addTable();
                case 'vip':
                  await _addVipTable();
                case 'auto':
                  await _autoLayout(guestCount);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'table', child: Text('Add table')),
              PopupMenuItem(value: 'vip', child: Text('Add VIP table')),
              PopupMenuItem(value: 'auto', child: Text('Auto-layout from guest count')),
            ],
          ),
        ],
      ),
      body: seating.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [EmptyStateCard(title: 'Could not load seating', message: '$e')],
        ),
        data: (layout) {
          return guests.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(
              padding: EdgeInsets.all(context.eos.spacing.lg),
              children: [EmptyStateCard(title: 'Could not load guests', message: '$e')],
            ),
            data: (guestList) {
              final assigned = layout.assignedGuestRefs;
              final unassigned = guestList.where((g) => !assigned.contains(g.id)).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.eos.spacing.lg,
                      context.eos.spacing.md,
                      context.eos.spacing.lg,
                      0,
                    ),
                    child: _StatsRow(stats: layout.stats, unassigned: unassigned.length),
                  ),
                  Expanded(
                    child: SeatingCanvas(
                      layout: layout,
                      onTableMoved: _patchTablePosition,
                      onTableDeleted: _deleteTable,
                      onGuestDropped: _assignGuest,
                      onGuestRemoved: _unassignGuest,
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.all(context.eos.spacing.md),
                    child: const SectionHeader(
                      title: 'Unassigned guests',
                      subtitle: 'Drag guests onto a table.',
                    ),
                  ),
                  SizedBox(
                    height: 120,
                    child: unassigned.isEmpty
                        ? Center(
                            child: Text(
                              'All guests are seated',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: context.eos.spacing.md),
                            itemCount: unassigned.length,
                            separatorBuilder: (_, __) => SizedBox(width: context.eos.spacing.sm),
                            itemBuilder: (context, index) {
                              final guest = unassigned[index];
                              return _DraggableGuestChip(guest: guest);
                            },
                          ),
                  ),
                  SizedBox(height: context.eos.spacing.md),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.unassigned});

  final SeatingStats stats;
  final int unassigned;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.eos.spacing.sm,
      runSpacing: context.eos.spacing.sm,
      children: [
        _StatChip(label: 'Tables', value: '${stats.tableCount}'),
        _StatChip(label: 'Capacity', value: '${stats.totalCapacity}'),
        _StatChip(label: 'Seated', value: '${stats.assignedGuests}'),
        _StatChip(label: 'VIP tables', value: '${stats.vipTableCount}'),
        _StatChip(label: 'Unassigned', value: '$unassigned'),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _DraggableGuestChip extends StatelessWidget {
  const _DraggableGuestChip({required this.guest});

  final CustomerGuestView guest;

  @override
  Widget build(BuildContext context) {
    return Draggable<CustomerGuestView>(
      data: guest,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(guest.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _GuestChip(guest: guest),
      ),
      child: _GuestChip(guest: guest),
    );
  }
}

class _GuestChip extends StatelessWidget {
  const _GuestChip({required this.guest});

  final CustomerGuestView guest;

  @override
  Widget build(BuildContext context) {
    final isVip = guest.tier == GuestTier.vip || guest.tier == GuestTier.vvip;
    return Chip(
      avatar: Icon(
        isVip ? Icons.star : Icons.person_outline,
        size: 18,
        color: isVip ? EosColors.champagne : null,
      ),
      label: Text(guest.name),
    );
  }
}
