import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../providers/customer_event_providers.dart';
import '../navigation/event_navigator.dart';
import '../models/program_constants.dart';
import '../models/program_models.dart';
import '../providers/program_providers.dart';
import '../workspace/event_empty_states.dart';
import '../workspace/event_module_scaffold.dart';
import '../workspace/widgets/event_error_view.dart';
import '../workspace/widgets/event_friendly_errors.dart';
import '../workspace/widgets/event_loading_skeleton.dart';
import '../widgets/program/program_day_widget.dart';
import '../widgets/program/program_status_badge.dart';

/// Program / run sheet at `/events/:eventId/program`.
class CustomerEventProgramScreen extends ConsumerStatefulWidget {
  const CustomerEventProgramScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<CustomerEventProgramScreen> createState() => _CustomerEventProgramScreenState();
}

class _CustomerEventProgramScreenState extends ConsumerState<CustomerEventProgramScreen> {
  bool _saving = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      refreshProgram(ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(EventFriendlyErrors.actionFailedMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _applyTemplate(String template) async {
    await _run(() async {
      await ref.read(programApiProvider).applyTemplate(widget.eventId, template);
    });
  }

  Future<void> _reorder(List<ProgramItem> items, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final reordered = [...items];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    await _run(() async {
      await ref.read(programApiProvider).reorder(
            widget.eventId,
            reordered.map((i) => i.id).toList(),
          );
    });
  }

  Future<void> _setStatus(ProgramItem item, String status, {int? delayMinutes}) async {
    await _run(() async {
      await ref.read(programApiProvider).setStatus(
            widget.eventId,
            item.id,
            status: status,
            delayMinutes: delayMinutes,
          );
    });
  }

  Future<void> _addItem(DateTime eventStart) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _ProgramItemDialog(eventStart: eventStart),
    );
    if (result == null) return;
    await _run(() async {
      await ref.read(programApiProvider).createItem(widget.eventId, result);
    });
  }

  Future<void> _editItem(ProgramItem item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _ProgramItemDialog(item: item),
    );
    if (result == null) return;
    await _run(() async {
      await ref.read(programApiProvider).patchItem(widget.eventId, item.id, result);
    });
  }

  Future<void> _deleteItem(ProgramItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove "${item.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await ref.read(programApiProvider).deleteItem(widget.eventId, item.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final program = ref.watch(eventProgramProvider(widget.eventId));
    final event = ref.watch(customerEventProvider(widget.eventId));

    return EventModuleScaffold(
      eventId: widget.eventId,
      title: 'Program & run sheet',
      subtitle: 'Timeline, owners, and day-of status',
      busy: _saving,
      actions: [
        PopupMenuButton<String>(
          onSelected: _applyTemplate,
          itemBuilder: (context) => [
            const PopupMenuItem(enabled: false, child: Text('Apply template')),
            ...programTemplates.map(
              (t) => PopupMenuItem(value: t.$1, child: Text(t.$2)),
            ),
          ],
        ),
        IconButton(
          tooltip: 'Add activity',
          icon: const Icon(Icons.add),
          onPressed: event.valueOrNull != null ? () => _addItem(event.value!.startsAt) : null,
        ),
      ],
      body: program.when(
        loading: () => const EventLoadingSkeleton(),
        error: (_, _) => ListView(
          padding: EosSpacing.pagePadding,
          children: [
            EventErrorView.module(
              moduleLabel: 'program',
              onRetry: () {
                refreshProgram(ref);
                ref.invalidate(eventProgramProvider(widget.eventId));
              },
              onBackToOverview: () => context.eventNav.backToOverview(widget.eventId),
            ),
          ],
        ),
        data: (snapshot) {
          final items = snapshot.items;
          return EventModuleScrollBody(
            onRefresh: () async {
              refreshProgram(ref);
              await ref.read(eventProgramProvider(widget.eventId).future);
            },
            primaryKpi: ProgramDayWidget(day: snapshot.day),
            content: items.isEmpty
                ? EventEmptyStates.program(
                    onAdd: event.valueOrNull != null
                        ? () => _addItem(event.value!.startsAt)
                        : () {},
                  )
                : ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    onReorder: (old, neu) => _reorder(items, old, neu),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _ProgramTimelineTile(
                        key: ValueKey(item.id),
                        index: index,
                        item: item,
                        onTap: () => _editItem(item),
                        onStatus: (status) async {
                          if (status == 'delayed') {
                            final minutes = await showDialog<int>(
                              context: context,
                              builder: (ctx) => _DelayDialog(title: 'Mark "${item.title}" delayed'),
                            );
                            if (minutes != null && minutes > 0) {
                              await _setStatus(item, 'delayed', delayMinutes: minutes);
                            }
                          } else {
                            await _setStatus(item, status);
                          }
                        },
                        onDelete: () => _deleteItem(item),
                      );
                    },
                  ),
            activity: snapshot.recentActivity.isEmpty
                ? null
                : EosSection(
                    title: 'Activity log',
                    subtitle: 'Program changes and reminders',
                    child: Column(
                      children: snapshot.recentActivity.take(8).map(
                            (a) => ListTile(
                              leading: const Icon(Icons.history, size: 20),
                              title: Text(a.headline),
                              subtitle: Text(a.detail),
                            ),
                          ).toList(),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _ProgramTimelineTile extends StatelessWidget {
  const _ProgramTimelineTile({
    super.key,
    required this.index,
    required this.item,
    required this.onTap,
    required this.onStatus,
    required this.onDelete,
  });

  final int index;
  final ProgramItem item;
  final VoidCallback onTap;
  final ValueChanged<String> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: key,
      margin: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: ListTile(
        onTap: onTap,
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${formatProgramTime(item.startTime)} · ${item.durationMinutes} min · '
          '${programOwnerLabels[item.ownerType] ?? item.ownerName}',
        ),
        trailing: PopupMenuButton<String>(
          icon: ProgramStatusBadge(status: item.status),
          onSelected: onStatus,
          itemBuilder: (context) => programStatuses
              .map((s) => PopupMenuItem(value: s, child: Text(programStatusLabels[s] ?? s)))
              .toList(),
        ),
        isThreeLine: item.description.isNotEmpty,
      ),
    );
  }
}

class _DelayDialog extends StatefulWidget {
  const _DelayDialog({required this.title});

  final String title;

  @override
  State<_DelayDialog> createState() => _DelayDialogState();
}

class _DelayDialogState extends State<_DelayDialog> {
  int _minutes = 15;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Shift this and following activities by:'),
          Slider(
            value: _minutes.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            label: '$_minutes min',
            onChanged: (v) => setState(() => _minutes = v.round()),
          ),
          Text('$_minutes minutes'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _minutes), child: const Text('Shift')),
      ],
    );
  }
}

class _ProgramItemDialog extends StatefulWidget {
  const _ProgramItemDialog({this.item, this.eventStart});

  final ProgramItem? item;
  final DateTime? eventStart;

  @override
  State<_ProgramItemDialog> createState() => _ProgramItemDialogState();
}

class _ProgramItemDialogState extends State<_ProgramItemDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _ownerName;
  late DateTime _start;
  late int _duration;
  late String _ownerType;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?.title ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    _ownerName = TextEditingController(text: item?.ownerName ?? '');
    _start = item?.startTime ?? widget.eventStart ?? DateTime.now();
    _duration = item?.durationMinutes ?? 15;
    _ownerType = item?.ownerType ?? 'planner';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _ownerName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add activity' : 'Edit activity'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Start: ${formatProgramTime(_start)}'),
              trailing: TextButton(
                child: const Text('Pick time'),
                onPressed: () async {
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
                  if (time != null) {
                    setState(() {
                      _start = DateTime(_start.year, _start.month, _start.day, time.hour, time.minute);
                    });
                  }
                },
              ),
            ),
            DropdownButtonFormField<int>(
              value: _duration,
              decoration: const InputDecoration(labelText: 'Duration (min)'),
              items: [10, 15, 20, 30, 45, 60, 90]
                  .map((m) => DropdownMenuItem(value: m, child: Text('$m minutes')))
                  .toList(),
              onChanged: (v) => setState(() => _duration = v ?? 15),
            ),
            DropdownButtonFormField<String>(
              value: _ownerType,
              decoration: const InputDecoration(labelText: 'Owner'),
              items: programOwnerTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(programOwnerLabels[t] ?? t)))
                  .toList(),
              onChanged: (v) => setState(() => _ownerType = v ?? 'planner'),
            ),
            TextField(
              controller: _ownerName,
              decoration: const InputDecoration(labelText: 'Owner name (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'title': _title.text.trim(),
              'description': _description.text.trim(),
              'startTime': _start.toUtc().toIso8601String(),
              'durationMinutes': _duration,
              'ownerType': _ownerType,
              'ownerName': _ownerName.text.trim().isEmpty
                  ? (programOwnerLabels[_ownerType] ?? _ownerType)
                  : _ownerName.text.trim(),
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
