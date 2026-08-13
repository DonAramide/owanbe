import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../navigation/event_navigator.dart';
import '../models/vendor_crm_models.dart';
import '../providers/vendor_crm_providers.dart';
import '../workspace/event_empty_states.dart';
import '../workspace/event_module_scaffold.dart';
import '../workspace/widgets/event_error_view.dart';
import '../workspace/widgets/event_loading_skeleton.dart';
import '../widgets/vendor_crm/vendor_stage_badge.dart';
import '../../../core/utils/money.dart';

/// Vendor CRM pipeline at `/events/:eventId/vendor-pipeline`.
class CustomerEventVendorPipelineScreen extends ConsumerStatefulWidget {
  const CustomerEventVendorPipelineScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<CustomerEventVendorPipelineScreen> createState() => _CustomerEventVendorPipelineScreenState();
}

class _CustomerEventVendorPipelineScreenState extends ConsumerState<CustomerEventVendorPipelineScreen> {
  bool _saving = false;

  Future<void> _transition(VendorRequest request, String stage) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(vendorCrmApiProvider).transitionStage(request.id, stage);
      refreshVendorCrm(ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update vendor stage. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = ref.watch(eventVendorCrmProvider(widget.eventId));

    return EventModuleScaffold(
      eventId: widget.eventId,
      title: 'Vendor pipeline',
      subtitle: 'Requests through day-of arrival',
      body: crm.when(
        loading: () => const EventLoadingSkeleton(),
        error: (_, _) => ListView(
          padding: EosSpacing.pagePadding,
          children: [
            EventErrorView.module(
              moduleLabel: 'vendor pipeline',
              onRetry: () {
                refreshVendorCrm(ref);
                ref.invalidate(eventVendorCrmProvider(widget.eventId));
              },
              onBackToOverview: () => context.eventNav.backToOverview(widget.eventId),
            ),
          ],
        ),
        data: (snapshot) => EventModuleScrollBody(
          onRefresh: () async {
            refreshVendorCrm(ref);
            await ref.read(eventVendorCrmProvider(widget.eventId).future);
          },
          primaryKpi: _PipelineStatsRow(stats: snapshot.stats),
          content: snapshot.items.isEmpty
              ? EventEmptyStates.vendors(
                  onBrowse: () => context.eventNav.openMarketplace(eventId: widget.eventId),
                )
              : Column(
                  children: [
                    ...snapshot.items.map((r) => _RequestCard(
                          request: r,
                          onStage: (s) => _transition(r, s),
                        )),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PipelineStatsRow extends StatelessWidget {
  const _PipelineStatsRow({required this.stats});

  final VendorPipelineStats stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.eos.spacing.sm,
      runSpacing: context.eos.spacing.sm,
      children: [
        for (final stage in vendorCrmPipelineStages)
          Chip(
            label: Text('${vendorCrmStageLabels[stage]}: ${stats.countForStage(stage)}'),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onStage});

  final VendorRequest request;
  final ValueChanged<String> onStage;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: context.eos.spacing.md),
      child: Padding(
        padding: EdgeInsets.all(context.eos.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.vendorName ?? 'Vendor',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                VendorStageBadge(stage: request.stage),
              ],
            ),
            if (request.serviceLabel != null)
              Text(request.serviceLabel!, style: Theme.of(context).textTheme.bodySmall),
            SizedBox(height: context.eos.spacing.xs),
            Wrap(
              spacing: 6,
              children: [
                Chip(
                  label: Text('Contract: ${vendorCrmContractLabels[request.contractStatus] ?? request.contractStatus}'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text('Assign: ${vendorCrmAssignmentLabels[request.assignmentStatus] ?? request.assignmentStatus}'),
                  visualDensity: VisualDensity.compact,
                ),
                if (request.displayAmountMinor != null)
                  Chip(
                    label: Text('Service price ${formatRevenue(request.displayAmountMinor!)}'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (request.message.isNotEmpty) ...[
              SizedBox(height: context.eos.spacing.sm),
              Text(request.message),
            ],
            SizedBox(height: context.eos.spacing.sm),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('View Request'),
                  onPressed: () => _showHonestContractDialog(context, request),
                ),
                if (request.canWithdraw)
                  ActionChip(
                    label: const Text('Withdraw Request'),
                    onPressed: () => onStage('cancelled'),
                  ),
                if (request.stage == 'accepted')
                  ActionChip(label: const Text('Schedule'), onPressed: () => onStage('scheduled')),
                if (request.stage == 'scheduled')
                  ActionChip(label: const Text('Mark arrived'), onPressed: () => onStage('arrived')),
                if (request.stage == 'arrived')
                  ActionChip(label: const Text('Complete'), onPressed: () => onStage('completed')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showHonestContractDialog(BuildContext context, VendorRequest req) {
    final status = vendorCrmStageLabels[req.stage] ?? req.stage;
    final amount = req.displayAmountMinor;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Request · ${req.vendorName ?? 'Vendor'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service: ${req.serviceLabel ?? 'Service'}'),
            Text('Status: $status'),
            Text('Contract: ${vendorCrmContractLabels[req.contractStatus] ?? req.contractStatus}'),
            Text('Assignment: ${vendorCrmAssignmentLabels[req.assignmentStatus] ?? req.assignmentStatus}'),
            if (amount != null) Text('Service price: ${formatRevenue(amount)}'),
            if (req.message.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Requirements: ${req.message}'),
            ],
            const SizedBox(height: 12),
            const Text(
              'The vendor accepts or declines this request. '
              'Payment stays in Owanbe escrow. Vendor payout and platform margin are not shown here.',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
