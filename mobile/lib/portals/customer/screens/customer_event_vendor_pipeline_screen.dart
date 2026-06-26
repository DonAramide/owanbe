import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../models/vendor_crm_models.dart';
import '../providers/vendor_crm_providers.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/section_header.dart';
import '../widgets/vendor_crm/vendor_stage_badge.dart';

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = ref.watch(eventVendorCrmProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Vendor pipeline'),
      ),
      body: crm.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [EmptyStateCard(title: 'Could not load vendor pipeline', message: '$e')],
        ),
        data: (snapshot) => RefreshIndicator(
          onRefresh: () async {
            refreshVendorCrm(ref);
            await ref.read(eventVendorCrmProvider(widget.eventId).future);
          },
          child: ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              const SectionHeader(
                title: 'Pipeline',
                subtitle: 'New request through completed service.',
              ),
              _PipelineStatsRow(stats: snapshot.stats),
              SizedBox(height: context.eos.spacing.lg),
              if (snapshot.items.isEmpty)
                const EmptyStateCard(
                  title: 'No vendor requests',
                  message: 'Request vendors from the marketplace to start your pipeline.',
                  icon: Icons.handshake_outlined,
                )
              else
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
            if (request.message.isNotEmpty) ...[
              SizedBox(height: context.eos.spacing.sm),
              Text(request.message),
            ],
            SizedBox(height: context.eos.spacing.sm),
            Wrap(
              spacing: 8,
              children: [
                if (request.stage == 'new')
                  ActionChip(label: const Text('Start negotiating'), onPressed: () => onStage('negotiating')),
                if (request.stage == 'negotiating')
                  ActionChip(label: const Text('Accept'), onPressed: () => onStage('accepted')),
                if (request.stage == 'accepted')
                  ActionChip(label: const Text('Schedule'), onPressed: () => onStage('scheduled')),
                if (request.stage == 'scheduled')
                  ActionChip(label: const Text('Mark arrived'), onPressed: () => onStage('arrived')),
                if (request.stage == 'arrived')
                  ActionChip(label: const Text('Complete'), onPressed: () => onStage('completed')),
                if (!['declined', 'cancelled', 'completed'].contains(request.stage))
                  ActionChip(label: const Text('Decline'), onPressed: () => onStage('declined')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
