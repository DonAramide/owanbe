import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../../../eos/eos.dart';
import '../../data/organizer_persistence.dart';
import '../../models/organizer_models.dart';
import '../../providers/organizer_providers.dart';
import '../../widgets/invite_vendor_sheet.dart';
import '../../widgets/organizer_shared.dart';
import '../models/event_command_center_v3_models.dart';
import '../providers/event_command_center_v3_providers.dart';
import '../widgets/cc_v3_health_cards.dart';

class VendorsTabV3 extends ConsumerWidget {
  const VendorsTabV3({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(eventCommandCenterV3Provider(eventId));
    final eventAsync = ref.watch(organizerEventProvider(eventId));

    return snapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (snap) {
        final event = eventAsync.value ?? snap.event;
        return SingleChildScrollView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: const CcV3SectionHeader(
                      title: 'Vendor pipeline',
                      subtitle: 'From request to celebration day',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => showInviteVendorSheet(
                      context,
                      eventId: eventId,
                      alreadyInvitedCatalogIds: invitedCatalogIdsFromEvent(event),
                      alreadyInvitedNames: invitedVendorNamesFromEvent(event),
                      cityHint: event.city,
                    ),
                    icon: const Icon(Icons.person_add_outlined, size: 18),
                    label: const Text('Add vendor'),
                  ),
                ],
              ),
              CcV3HealthCard(
                title: 'Vendor progress',
                progressPercent: snap.vendorHealth.progressPercent,
                metrics: [
                  CcV3MetricItem(label: 'Requested', value: '${snap.vendorHealth.requested}'),
                  CcV3MetricItem(label: 'Negotiating', value: '${snap.vendorHealth.negotiating}'),
                  CcV3MetricItem(label: 'Confirmed', value: '${snap.vendorHealth.confirmed}'),
                  CcV3MetricItem(label: 'Completed', value: '${snap.vendorHealth.completed}'),
                ],
              ),
              SizedBox(height: context.eos.spacing.lg),
              _PipelineBar(snap: snap),
              SizedBox(height: context.eos.spacing.xl),
              const CcV3SectionHeader(title: 'Selected vendors'),
              if (snap.vendorDetails.isEmpty)
                EosSurfaceCard(
                  child: Text(
                    'No vendors yet. Browse the Marketplace tab for smart suggestions.',
                    style: context.eosText.bodyMedium,
                  ),
                )
              else
                for (final detail in snap.vendorDetails)
                  Padding(
                    padding: EdgeInsets.only(bottom: context.eos.spacing.md),
                    child: _VendorDetailCard(detail: detail, eventId: eventId, ref: ref),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _PipelineBar extends StatelessWidget {
  const _PipelineBar({required this.snap});
  final EventCommandCenterV3Snapshot snap;

  @override
  Widget build(BuildContext context) {
    final stages = [
      ('Requested', snap.vendorHealth.requested, Icons.send_outlined),
      ('Negotiating', snap.vendorHealth.negotiating, Icons.handshake_outlined),
      ('Confirmed', snap.vendorHealth.confirmed, Icons.verified_outlined),
      ('Completed', snap.vendorHealth.completed, Icons.celebration_outlined),
    ];
    return EosSurfaceCard(
      child: Row(
        children: [
          for (var i = 0; i < stages.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Icon(stages[i].$3, color: EosColors.plum),
                  Text('${stages[i].$2}', style: context.eosText.titleMedium),
                  Text(stages[i].$1, style: context.eosText.labelSmall, textAlign: TextAlign.center),
                ],
              ),
            ),
            if (i < stages.length - 1) Icon(Icons.chevron_right, color: context.eosColors.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _VendorDetailCard extends StatelessWidget {
  const _VendorDetailCard({required this.detail, required this.eventId, required this.ref});
  final EventVendorDetail detail;
  final String eventId;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final slot = detail.slot;
    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: EosColors.plum.withValues(alpha: 0.12),
                child: const Icon(Icons.storefront, color: EosColors.plum),
              ),
              SizedBox(width: context.eos.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(slot.businessName, style: context.eosText.titleSmall),
                    Text('${slot.category}${slot.city != null ? ' · ${slot.city}' : ''}', style: context.eosText.bodySmall),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 16, color: EosColors.champagne),
                        Text(' ${detail.rating.toStringAsFixed(1)}', style: context.eosText.bodySmall),
                        const SizedBox(width: 12),
                        EosFinanceChip(label: _stageLabel(detail.stage), compact: true),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Contract', style: context.eosText.labelSmall),
                  Text(formatRevenue(detail.contractAmountMinor), style: context.eosText.titleSmall),
                ],
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.md),
          ExpansionTile(
            title: Text('Negotiation timeline', style: context.eosText.titleSmall),
            children: [
              for (final n in detail.negotiation)
                ListTile(
                  dense: true,
                  leading: Icon(n.byOrganizer ? Icons.person_outline : Icons.storefront_outlined, size: 18),
                  title: Text(n.label),
                  subtitle: Text(n.at.toString()),
                  trailing: Text(formatRevenue(n.amountMinor)),
                ),
            ],
          ),
          Wrap(
            spacing: context.eos.spacing.xs,
            runSpacing: context.eos.spacing.xs,
            children: [
              OutlinedButton.icon(onPressed: () => _toast(context, 'Portfolio'), icon: const Icon(Icons.photo_library_outlined, size: 16), label: const Text('Portfolio')),
              OutlinedButton.icon(onPressed: () => _toast(context, 'Call'), icon: const Icon(Icons.call_outlined, size: 16), label: const Text('Call')),
              OutlinedButton.icon(onPressed: () => _toast(context, 'Video'), icon: const Icon(Icons.videocam_outlined, size: 16), label: const Text('Video')),
              if (slot.status == VendorSlotStatus.pending) ...[
                FilledButton(onPressed: () => updateVendorSlot(ref, eventId, slot.id, VendorSlotStatus.approved), child: const Text('Accept')),
                OutlinedButton(onPressed: () => updateVendorSlot(ref, eventId, slot.id, VendorSlotStatus.rejected), child: const Text('Decline')),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _stageLabel(VendorPipelineStage s) => switch (s) {
        VendorPipelineStage.requested => 'Requested',
        VendorPipelineStage.negotiating => 'Negotiating',
        VendorPipelineStage.confirmed => 'Confirmed',
        VendorPipelineStage.completed => 'Completed',
      };

  void _toast(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action with ${detail.slot.businessName}')),
    );
  }
}
