import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../data/operations_store.dart';
import '../models/operations_models.dart';
import '../providers/operations_providers.dart';
import '../widgets/operations_shared.dart';

class IncidentCenterScreen extends ConsumerStatefulWidget {
  const IncidentCenterScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<IncidentCenterScreen> createState() => _IncidentCenterScreenState();
}

class _IncidentCenterScreenState extends ConsumerState<IncidentCenterScreen> {
  final _title = TextEditingController();
  final _reporter = TextEditingController(text: 'Ops Lead');
  IncidentCategory _category = IncidentCategory.access;
  IncidentPriority _priority = IncidentPriority.medium;

  @override
  void dispose() {
    _title.dispose();
    _reporter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incidents = ref.watch(operationsIncidentsProvider(widget.eventId));

    return EosPageScaffold(
      title: 'Incident center',
      subtitle: 'Track and resolve operational issues',
      actions: [
        FilledButton.icon(
          onPressed: _showLogSheet,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Log incident'),
        ),
      ],
      body: incidents.when(
        data: (list) {
          if (list.isEmpty) {
            return EosSurfaceCard(
              child: Text('No incidents — floor is clear', style: context.eosText.bodyMedium),
            );
          }
          return Column(
            children: [
              for (final inc in list)
                Padding(
                  padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                  child: OpsIncidentCard(
                    incident: inc,
                    onInvestigate: inc.status == IncidentStatus.open
                        ? () => _update(inc.id, IncidentStatus.investigating)
                        : null,
                    onResolve: inc.status == IncidentStatus.investigating
                        ? () => _update(inc.id, IncidentStatus.resolved)
                        : null,
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }

  void _update(String id, IncidentStatus status) {
    OperationsStore.instance.updateIncidentStatus(widget.eventId, id, status);
    bumpOperationsRevision(ref);
  }

  void _showLogSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: context.eos.spacing.lg,
          right: context.eos.spacing.lg,
          top: context.eos.spacing.lg,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + context.eos.spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log incident', style: context.eosText.titleLarge),
            SizedBox(height: context.eos.spacing.md),
            EosTextField(controller: _title, label: 'Title', hint: 'Brief description'),
            SizedBox(height: context.eos.spacing.sm),
            EosTextField(controller: _reporter, label: 'Reporter'),
            SizedBox(height: context.eos.spacing.sm),
            EosSelectField<IncidentCategory>(
              label: 'Category',
              value: _category,
              items: IncidentCategory.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            SizedBox(height: context.eos.spacing.sm),
            EosSelectField<IncidentPriority>(
              label: 'Priority',
              value: _priority,
              items: IncidentPriority.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v ?? _priority),
            ),
            SizedBox(height: context.eos.spacing.lg),
            FilledButton(
              onPressed: () {
                if (_title.text.trim().isEmpty) return;
                OperationsStore.instance.logIncident(
                  eventId: widget.eventId,
                  title: _title.text.trim(),
                  category: _category,
                  priority: _priority,
                  reporter: _reporter.text.trim(),
                );
                bumpOperationsRevision(ref);
                _title.clear();
                Navigator.pop(ctx);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
