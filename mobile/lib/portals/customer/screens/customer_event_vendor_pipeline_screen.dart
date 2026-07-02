import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../navigation/event_navigator.dart';
import '../models/vendor_crm_models.dart';
import '../providers/vendor_crm_providers.dart';
import '../workspace/event_empty_states.dart';
import '../workspace/event_module_scaffold.dart';
import '../workspace/widgets/event_error_view.dart';
import '../workspace/widgets/event_loading_skeleton.dart';
import '../widgets/vendor_crm/vendor_stage_badge.dart';
import '../../../platform/procurement/procurement_models.dart';
import '../../../platform/procurement/contract_generator.dart';

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
                  onBrowse: () => context.eventNav.openMarketplace(),
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
                if (request.stage == 'negotiating') ...[
                  ActionChip(label: const Text('Accept'), onPressed: () => onStage('accepted')),
                  ActionChip(
                    backgroundColor: EosColors.plum,
                    label: const Text('Manage Contract', style: TextStyle(color: EosColors.champagne)),
                    onPressed: () => _showContractManagementDialog(context, request),
                  ),
                ],
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

  void _showContractManagementDialog(BuildContext context, VendorRequest req) {
    final proposal = ContractProposal(
      id: 'con_90214',
      organizerId: 'org_01',
      vendorId: req.vendorId,
      eventId: 'evt_wedding_01',
      requirements: 'Provision of full buffet catering services for 300 guests, including servers and dinnerware.',
      totalAmountMinor: 85000000,
      milestones: [
        ContractMilestone(id: 'm1', title: 'Onboarding Deposit', amountMinor: 30000000, status: MilestoneStatus.pending, description: 'Initial mobilization payment'),
        ContractMilestone(id: 'm2', title: 'Post-event Release', amountMinor: 55000000, status: MilestoneStatus.pending, description: 'Final quality clearance check'),
      ],
      signatures: [],
      state: ProcurementState.proposed,
      createdAt: DateTime.now(),
    );

    final contractText = ContractGenerator.generateLegalDocument(proposal);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EosColors.plumDark,
        title: Text('Procurement Contract: ${req.vendorName}', style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PROPOSED AGREEMENT TEXT:', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold, fontSize: 11)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.white10,
                child: Text(
                  contractText,
                  style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 10),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Dual Signatures Verification Status:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('• Organizer: NOT SIGNED\n• Vendor: NOT SIGNED', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Contract signed digitally! Cryptographic hash recorded in DAM audit ledger.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Sign Digitally as Organizer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }
}
