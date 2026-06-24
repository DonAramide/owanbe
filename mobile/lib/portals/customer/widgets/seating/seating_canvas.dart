import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';
import '../../models/customer_guest_models.dart';
import '../../models/seating_models.dart';

typedef TableMoveCallback = Future<void> Function(SeatingTable table, double x, double y);
typedef TableDeleteCallback = Future<void> Function(SeatingTable table);
typedef GuestDropCallback = Future<void> Function(SeatingTable table, CustomerGuestView guest);
typedef GuestRemoveCallback = Future<void> Function(String assignmentId);

class SeatingCanvas extends StatefulWidget {
  const SeatingCanvas({
    super.key,
    required this.layout,
    required this.onTableMoved,
    required this.onTableDeleted,
    required this.onGuestDropped,
    required this.onGuestRemoved,
  });

  final SeatingLayout layout;
  final TableMoveCallback onTableMoved;
  final TableDeleteCallback onTableDeleted;
  final GuestDropCallback onGuestDropped;
  final GuestRemoveCallback onGuestRemoved;

  @override
  State<SeatingCanvas> createState() => _SeatingCanvasState();
}

class _SeatingCanvasState extends State<SeatingCanvas> {
  late Map<String, Offset> _positions;

  @override
  void initState() {
    super.initState();
    _positions = _buildPositions(widget.layout);
  }

  @override
  void didUpdateWidget(covariant SeatingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layout.id != widget.layout.id ||
        oldWidget.layout.tables.length != widget.layout.tables.length) {
      _positions = _buildPositions(widget.layout);
    }
  }

  Map<String, Offset> _buildPositions(SeatingLayout layout) {
    return {
      for (final t in layout.tables) t.id: Offset(t.positionX, t.positionY),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.layout.tables.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.table_restaurant_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
              SizedBox(height: context.eos.spacing.md),
              Text(
                'No tables yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text('Add tables or run auto-layout from the menu.'),
            ],
          ),
        ),
      );
    }

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(80),
      minScale: 0.5,
      maxScale: 2.5,
      child: SizedBox(
        width: widget.layout.canvasWidth.toDouble(),
        height: widget.layout.canvasHeight.toDouble(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final table in widget.layout.tables)
                _SeatingTableWidget(
                  table: table,
                  position: _positions[table.id] ?? Offset(table.positionX, table.positionY),
                  onMoved: (offset) {
                    setState(() => _positions[table.id] = offset);
                  },
                  onMoveEnd: (offset) => widget.onTableMoved(table, offset.dx, offset.dy),
                  onDelete: () => widget.onTableDeleted(table),
                  onGuestDropped: (guest) => widget.onGuestDropped(table, guest),
                  onGuestRemoved: widget.onGuestRemoved,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatingTableWidget extends StatefulWidget {
  const _SeatingTableWidget({
    required this.table,
    required this.position,
    required this.onMoved,
    required this.onMoveEnd,
    required this.onDelete,
    required this.onGuestDropped,
    required this.onGuestRemoved,
  });

  final SeatingTable table;
  final Offset position;
  final ValueChanged<Offset> onMoved;
  final ValueChanged<Offset> onMoveEnd;
  final VoidCallback onDelete;
  final ValueChanged<CustomerGuestView> onGuestDropped;
  final GuestRemoveCallback onGuestRemoved;

  @override
  State<_SeatingTableWidget> createState() => _SeatingTableWidgetState();
}

class _SeatingTableWidgetState extends State<_SeatingTableWidget> {
  Offset _dragDelta = Offset.zero;

  Offset get _current => widget.position + _dragDelta;

  @override
  void didUpdateWidget(covariant _SeatingTableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) _dragDelta = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    final vip = table.isVip || table.tableKind == 'vip';
    final borderColor = vip ? EosColors.champagne : EosColors.plum;
    final width = table.tableKind == 'rectangular' || table.tableKind == 'head' ? 120.0 : 96.0;
    final height = table.tableKind == 'rectangular' || table.tableKind == 'head' ? 72.0 : 96.0;
    final isRect = table.tableKind == 'rectangular' || table.tableKind == 'head';

    return Positioned(
      left: _current.dx,
      top: _current.dy,
      child: DragTarget<CustomerGuestView>(
        onWillAcceptWithDetails: (_) => table.hasSpace,
        onAcceptWithDetails: (details) => widget.onGuestDropped(details.data),
        builder: (context, candidate, rejected) {
          final highlight = candidate.isNotEmpty;
          return GestureDetector(
            onPanUpdate: (d) => setState(() => _dragDelta += d.delta),
            onPanEnd: (_) {
              final finalPos = _current;
              widget.onMoved(finalPos);
              widget.onMoveEnd(finalPos);
              setState(() => _dragDelta = Offset.zero);
            },
            onLongPress: () => _showTableMenu(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: width,
              height: height + 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isRect ? 8 : 48),
                border: Border.all(
                  color: highlight ? Theme.of(context).colorScheme.primary : borderColor,
                  width: highlight ? 3 : 2,
                ),
                color: vip
                    ? EosColors.champagne.withValues(alpha: 0.12)
                    : Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (vip)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: Icon(Icons.star, size: 14, color: EosColors.champagne),
                    ),
                  Text(
                    table.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${table.assignedCount}/${table.capacity}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (table.assignments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 2,
                        runSpacing: 2,
                        children: table.assignments.take(3).map((a) {
                          return InputChip(
                            label: Text(a.guestName, style: const TextStyle(fontSize: 10)),
                            visualDensity: VisualDensity.compact,
                            onDeleted: () => widget.onGuestRemoved(a.id),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTableMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text('Remove ${widget.table.label}'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
