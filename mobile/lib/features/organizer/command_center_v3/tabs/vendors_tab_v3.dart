import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/utils/platform_message_guard.dart';
import '../../../../eos/eos.dart';
import '../../../../portals/customer/models/vendor_crm_models.dart';
import '../../../../portals/customer/navigation/event_navigator.dart';
import '../../../../portals/customer/providers/vendor_crm_providers.dart';
import '../../../../portals/customer/router/event_route_registry.dart';
import '../../../../portals/customer/widgets/vendor_crm/vendor_stage_badge.dart';
import '../../widgets/invite_vendor_sheet.dart';
import '../widgets/cc_v3_health_cards.dart';

/// Event Workspace Vendors — canonical CRM spine (`vendor_event_requests`).
class VendorsTabV3 extends ConsumerWidget {
  const VendorsTabV3({
    super.key,
    required this.eventId,
    this.nestedInParentScroll = false,
  });

  final String eventId;
  /// When true, render as Column (parent EosPageScaffold scrolls).
  final bool nestedInParentScroll;

  static List<Widget> _groupedVendorBlocks(
    BuildContext context,
    String eventId,
    List<VendorRequest> items,
  ) {
    final byVendor = <String, List<VendorRequest>>{};
    for (final r in items) {
      byVendor.putIfAbsent(r.vendorId, () => []).add(r);
    }
    final widgets = <Widget>[];
    for (final entry in byVendor.entries) {
      final list = entry.value..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final name = list.first.vendorName ?? 'Vendor';
      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
          child: Text(
            '$name · ${list.length} service${list.length == 1 ? '' : 's'}',
            style: context.eosText.titleSmall,
          ),
        ),
      );
      for (final r in list) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: context.eos.spacing.md),
            child: _CrmVendorCard(eventId: eventId, request: r),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = ref.watch(eventVendorCrmProvider(eventId));

    Widget bodyFor(VendorCrmSnapshot snap) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Vendor CRM', style: context.eosText.headlineSmall),
            ),
            SizedBox(height: context.eos.spacing.xs),
            Text(
              'Marketplace hire → request → vendor response → assignment → completion. Same records as Vendor Inbox.',
              style: context.eosText.bodySmall,
            ),
            SizedBox(height: context.eos.spacing.md),
            Wrap(
              spacing: context.eos.spacing.sm,
              runSpacing: context.eos.spacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: () => showInviteVendorSheet(
                    context,
                    eventId: eventId,
                    // Same vendor may be hired for another service — do not block by vendorId alone.
                    alreadyInvitedCatalogIds: const {},
                    alreadyInvitedNames: const {},
                  ),
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Request vendor'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.eventNav.openMarketplace(eventId: eventId),
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  label: const Text('Marketplace'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push(EventRouteRegistry.eventVendorPipeline(eventId)),
                  icon: const Icon(Icons.view_kanban_outlined, size: 18),
                  label: const Text('Full pipeline'),
                ),
              ],
            ),
            SizedBox(height: context.eos.spacing.lg),
            const CcV3SectionHeader(
              title: 'Event Funds',
              subtitle: 'Fund the event pool before allocating booking escrow',
            ),
            _EventFundsCard(eventId: eventId),
            SizedBox(height: context.eos.spacing.lg),
            const CcV3SectionHeader(
              title: 'Insights',
              subtitle: 'From CRM offers + stages — not invented analytics',
            ),
            Wrap(
              spacing: context.eos.spacing.md,
              runSpacing: context.eos.spacing.md,
              children: [
                _Kpi('Attached', '${snap.insights.attachedVendors}', Icons.groups_outlined),
                _Kpi('Pending response', '${snap.stats.newCount + snap.stats.negotiating}', Icons.hourglass_empty_outlined),
                _Kpi('Spend (quoted)', formatRevenue(snap.insights.vendorSpendMinor), Icons.payments_outlined),
                _Kpi('Completed', '${snap.insights.completedCount}', Icons.verified_outlined),
                _Kpi('Completion', '${snap.insights.completionPct.toStringAsFixed(1)}%', Icons.percent),
              ],
            ),
            SizedBox(height: context.eos.spacing.lg),
            const CcV3SectionHeader(title: 'Pipeline', subtitle: 'Request status by stage'),
            _PipelineStats(stats: snap.stats),
            SizedBox(height: context.eos.spacing.xl),
            const CcV3SectionHeader(
              title: 'Attached vendors',
              subtitle: 'Grouped by vendor · each service is an independent request',
            ),
            if (snap.items.isEmpty)
              EosSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No vendor requests yet.', style: context.eosText.bodyMedium),
                    SizedBox(height: context.eos.spacing.sm),
                    Text(
                      'Browse the marketplace and request a vendor — they appear here and in the vendor inbox.',
                      style: context.eosText.bodySmall,
                    ),
                  ],
                ),
              )
            else
              ..._groupedVendorBlocks(context, eventId, snap.items),
          ],
        );

    if (nestedInParentScroll) {
      return crm.when(
        loading: () => const _VendorsSkeleton(),
        error: (e, _) => EosAttentionBanner(
          headline: 'Vendor CRM unavailable',
          message: '$e',
          severity: 'WARNING',
          actionLabel: 'Retry',
          onAction: () {
            refreshVendorCrm(ref);
            ref.invalidate(eventVendorCrmProvider(eventId));
          },
        ),
        data: bodyFor,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        refreshVendorCrm(ref);
        await ref.read(eventVendorCrmProvider(eventId).future);
      },
      child: crm.when(
        loading: () => const _VendorsSkeleton(),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            EosAttentionBanner(
              headline: 'Vendor CRM unavailable',
              message: '$e',
              severity: 'WARNING',
              actionLabel: 'Retry',
              onAction: () {
                refreshVendorCrm(ref);
                ref.invalidate(eventVendorCrmProvider(eventId));
              },
            ),
          ],
        ),
        data: (snap) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [bodyFor(snap)],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.title, this.value, this.icon);
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: EosKpiCard(title: title, value: value, icon: icon),
    );
  }
}

class _PipelineStats extends StatelessWidget {
  const _PipelineStats({required this.stats});
  final VendorPipelineStats stats;

  @override
  Widget build(BuildContext context) {
    final stages = [
      ('Pending', stats.newCount + stats.negotiating),
      ('Accepted', stats.accepted),
      ('Scheduled', stats.scheduled),
      ('Arrived', stats.arrived),
      ('Done', stats.completed),
    ];
    return EosSurfaceCard(
      child: Wrap(
        spacing: context.eos.spacing.md,
        runSpacing: context.eos.spacing.sm,
        children: [
          for (final s in stages)
            Column(
              children: [
                Text('${s.$2}', style: context.eosText.titleMedium),
                Text(s.$1, style: context.eosText.labelSmall),
              ],
            ),
        ],
      ),
    );
  }
}

class _CrmVendorCard extends ConsumerStatefulWidget {
  const _CrmVendorCard({required this.eventId, required this.request});
  final String eventId;
  final VendorRequest request;

  @override
  ConsumerState<_CrmVendorCard> createState() => _CrmVendorCardState();
}

class _CrmVendorCardState extends ConsumerState<_CrmVendorCard> {
  bool _saving = false;
  bool _expanded = false;

  Future<void> _stage(String stage) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(vendorCrmApiProvider).transitionStage(widget.request.id, stage);
      refreshVendorCrm(ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stage update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _message() async {
    if (!widget.request.canMessage) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Messaging opens after the vendor accepts this request'),
          ),
        );
      }
      return;
    }
    final controller = TextEditingController();
    final timeline = await ref.read(vendorRequestTimelineProvider(widget.request.id).future);
    final prior = timeline.conversationMessages
        .where((m) => m.note != null && m.note!.trim().isNotEmpty && m.note != 'Request created')
        .toList();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Message vendor'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.request.vendorName ?? 'Vendor'} · ${widget.request.serviceLabel ?? 'Service'}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (prior.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final m in prior.take(20))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${m.actorType == 'vendor' ? 'Vendor' : 'Organizer'}: ${m.note}',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Operational message (service requirements only)',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 6),
              Text(
                'Keep communication and payment within Owanbe.',
                style: Theme.of(ctx).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;
    final blocked = PlatformMessageGuard.blockReason(controller.text.trim());
    if (blocked != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(blocked)));
      }
      return;
    }
    try {
      await ref.read(vendorCrmApiProvider).postMessage(widget.request.id, message: controller.text.trim());
      refreshVendorCrm(ref);
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.contains('PLATFORM_BYPASS') || msg.contains('keep communication')
                  ? PlatformMessageGuard.keepInOwanbe
                  : 'Message failed: $e',
            ),
          ),
        );
      }
    }
  }

  void _viewRequest() {
    final r = widget.request;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(r.vendorName ?? 'Vendor request'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Service: ${r.serviceLabel ?? 'Service'}'),
              Text('Event: ${r.eventTitle ?? widget.eventId}'),
              Text('Status: ${vendorCrmStageLabels[r.stage] ?? r.stage}'),
              if (r.displayAmountMinor != null)
                Text('Service price: ${formatRevenue(r.displayAmountMinor!)}'),
              if (r.message.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Requirements: ${r.message}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final timeline = _expanded ? ref.watch(vendorRequestTimelineProvider(r.id)) : null;

    return EosSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: EosColors.plum.withValues(alpha: 0.12),
                child: const Icon(Icons.storefront, color: EosColors.plum),
              ),
              SizedBox(width: context.eos.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.vendorName ?? 'Vendor', style: context.eosText.titleSmall),
                    Text(r.serviceLabel ?? 'Service', style: context.eosText.bodySmall),
                    if (r.serviceCode != null && r.serviceCode!.isNotEmpty)
                      Text(
                        'Service Code: ${r.serviceCode}',
                        style: context.eosText.bodySmall?.copyWith(
                          color: EosColors.plum,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    SizedBox(height: context.eos.spacing.xs),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        VendorStageBadge(stage: r.stage),
                        if (r.unreadCount > 0)
                          EosFinanceChip(
                            label: '${r.unreadCount} new',
                            compact: true,
                          ),
                        EosFinanceChip(
                          label: 'Contract: ${vendorCrmContractLabels[r.contractStatus] ?? r.contractStatus}',
                          compact: true,
                        ),
                        EosFinanceChip(
                          label: 'Assign: ${vendorCrmAssignmentLabels[r.assignmentStatus] ?? r.assignmentStatus}',
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (r.displayAmountMinor != null)
                Text(
                  'Service price\n${formatRevenue(r.displayAmountMinor!)}',
                  textAlign: TextAlign.end,
                  style: context.eosText.titleSmall,
                ),
            ],
          ),
          if (r.message.isNotEmpty) ...[
            SizedBox(height: context.eos.spacing.sm),
            Text(r.message, style: context.eosText.bodySmall),
          ],
          SizedBox(height: context.eos.spacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(label: const Text('View Request'), onPressed: _viewRequest),
              ActionChip(
                label: Text(_expanded ? 'Hide timeline' : 'Timeline'),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              if (r.canWithdraw)
                ActionChip(
                  label: const Text('Withdraw Request'),
                  onPressed: _saving ? null : () => _stage('cancelled'),
                ),
              if (r.canMessage)
                ActionChip(label: const Text('Message'), onPressed: _message),
              // Post-accept organizer operations (contract / escrow / schedule) — not accept/decline.
              if (r.stage == 'accepted')
                ActionChip(
                  label: const Text('Confirm agreement'),
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          try {
                            await ref.read(vendorCrmApiProvider).confirmAgreement(r.id);
                            refreshVendorCrm(ref);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Confirm failed: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                ),
              if (r.stage == 'accepted' && r.fundingStatus != 'funded' && r.fundingStatus != 'released')
                ActionChip(
                  label: const Text('Fund from event'),
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          try {
                            await ref.read(vendorCrmApiProvider).fundRequest(r.id);
                            refreshVendorCrm(ref);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Booking funded in Owanbe escrow')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                ),
              if (r.stage == 'accepted')
                ActionChip(label: const Text('Schedule'), onPressed: _saving ? null : () => _stage('scheduled')),
              if (r.stage == 'scheduled')
                ActionChip(label: const Text('Arrived'), onPressed: _saving ? null : () => _stage('arrived')),
              if (r.stage == 'arrived') ...[
                ActionChip(
                  label: const Text('Confirm completion'),
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          try {
                            await ref.read(vendorCrmApiProvider).confirmCompletion(r.id);
                            refreshVendorCrm(ref);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                ),
                ActionChip(
                  label: const Text('Report issue'),
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          try {
                            await ref.read(vendorCrmApiProvider).reportIssue(r.id);
                            refreshVendorCrm(ref);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                ),
                ActionChip(label: const Text('Complete'), onPressed: _saving ? null : () => _stage('completed')),
              ],
            ],
          ),
          if (_expanded) ...[
            SizedBox(height: context.eos.spacing.md),
            const Divider(),
            Text('Activity timeline', style: context.eosText.titleSmall),
            SizedBox(height: context.eos.spacing.sm),
            if (timeline == null)
              const SizedBox.shrink()
            else
              timeline.when(
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (e, _) => Text('$e', style: context.eosText.bodySmall),
                data: (t) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contract ${vendorCrmContractLabels[t.contractStatus] ?? t.contractStatus}'
                      ' · derived from CRM stage (no mock signatures)',
                      style: context.eosText.bodySmall,
                    ),
                    SizedBox(height: context.eos.spacing.sm),
                    if (t.history.isEmpty)
                      Text('No history yet — stage changes and messages appear here.', style: context.eosText.bodySmall)
                    else
                      for (final h in t.history)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.timeline, size: 18),
                          title: Text(
                            h.fromStage == h.toStage
                                ? '${h.actorType} note'
                                : '${h.fromStage ?? '—'} → ${h.toStage}',
                          ),
                          subtitle: Text(
                            [
                              if (h.note != null && h.note!.isNotEmpty) h.note!,
                              h.createdAt.toLocal().toString(),
                            ].join(' · '),
                          ),
                        ),
                    SizedBox(height: context.eos.spacing.sm),
                    Text(
                      'Documents: notes via messages/stage history. Attachments & legal e-sign unavailable in this phase.',
                      style: context.eosText.labelSmall,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _EventFundsCard extends ConsumerStatefulWidget {
  const _EventFundsCard({required this.eventId});
  final String eventId;

  @override
  ConsumerState<_EventFundsCard> createState() => _EventFundsCardState();
}

class _EventFundsCardState extends ConsumerState<_EventFundsCard> {
  var _busy = false;

  Future<void> _fund() async {
    final controller = TextEditingController(text: '6000000');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fund Event'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount (NGN)',
            helperText: 'Example: 6000000 → ₦6,000,000.00',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Fund')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final naira = int.tryParse(controller.text.trim().replaceAll(',', ''));
    if (naira == null || naira <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    final amountMinor = naira * 100;
    setState(() => _busy = true);
    try {
      await ref.read(vendorCrmApiProvider).fundEventPool(
            widget.eventId,
            amountMinor: amountMinor,
          );
      refreshVendorCrm(ref);
      ref.invalidate(eventVendorFundsProvider(widget.eventId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Event funded ${formatRevenue(amountMinor)}')),
        );
      }
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
    final funds = ref.watch(eventVendorFundsProvider(widget.eventId));
    return EosSurfaceCard(
      child: funds.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => Text('Event funds unavailable: $e', style: context.eosText.bodySmall),
        data: (m) {
          final total = int.tryParse('${m['totalFundedMinor'] ?? 0}') ?? 0;
          final available = int.tryParse('${m['remainingMinor'] ?? 0}') ?? 0;
          final reserved = int.tryParse('${m['reservedMinor'] ?? 0}') ?? 0;
          final released = int.tryParse('${m['releasedMinor'] ?? 0}') ?? 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text('Total Funded: ${formatRevenue(total)}'),
                  Text('Available: ${formatRevenue(available)}'),
                  Text('Reserved: ${formatRevenue(reserved)}'),
                  Text('Released: ${formatRevenue(released)}'),
                ],
              ),
              SizedBox(height: context.eos.spacing.sm),
              FilledButton.icon(
                onPressed: _busy ? null : _fund,
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                label: Text(_busy ? 'Funding…' : 'Fund Event'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VendorsSkeleton extends StatelessWidget {
  const _VendorsSkeleton();

  @override
  Widget build(BuildContext context) {
    // Column (not ListView): this widget is often nested under EosPageScaffold /
    // another scroll view — a vertical ListView gets unbounded height and freezes paint.
    return Padding(
      padding: EdgeInsets.all(context.eos.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              height: 96,
              margin: EdgeInsets.only(bottom: context.eos.spacing.md),
              decoration: BoxDecoration(
                color: context.eosColors.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
