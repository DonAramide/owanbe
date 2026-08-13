import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../eos/eos.dart';
import 'organizer_automation_api.dart';

/// Phase 23 — Automations hub (catalog + execution history). No visual builder.
class AutomationsScreen extends ConsumerWidget {
  const AutomationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defs = ref.watch(organizerAutomationsProvider);
    final runs = ref.watch(organizerAutomationRunsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(organizerAutomationsProvider);
        ref.invalidate(organizerAutomationRunsProvider);
      },
      child: ListView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: [
          Semantics(
            header: true,
            child: Text('Automations', style: context.eosText.headlineSmall),
          ),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            'Orchestration only — rules trigger Notifications, Reporting, and existing services. '
            'Business data stays in Finance, Ops, CRM, and Invitations.',
            style: context.eosText.bodySmall,
          ),
          SizedBox(height: context.eos.spacing.lg),
          Text('Active workflows', style: context.eosText.titleMedium),
          SizedBox(height: context.eos.spacing.sm),
          defs.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (e, _) => EosAttentionBanner(
              headline: 'Automations unavailable',
              message: '$e',
              severity: 'WARNING',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(organizerAutomationsProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Text('No workflow definitions published yet.', style: context.eosText.bodySmall);
              }
              return Column(
                children: [
                  for (final d in items) ...[
                    _WorkflowTile(definition: d),
                    SizedBox(height: context.eos.spacing.sm),
                  ],
                ],
              );
            },
          ),
          SizedBox(height: context.eos.spacing.xl),
          Text('Recent executions', style: context.eosText.titleMedium),
          SizedBox(height: context.eos.spacing.sm),
          runs.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (e, _) => EosAttentionBanner(
              headline: 'Execution history unavailable',
              message: '$e',
              severity: 'WARNING',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(organizerAutomationRunsProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  'No runs yet. Ticket, RSVP, vendor, refund, and report events will appear here.',
                  style: context.eosText.bodySmall,
                );
              }
              return Column(
                children: [
                  for (final r in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        r.status == 'failed'
                            ? Icons.error_outline
                            : r.status == 'skipped'
                                ? Icons.skip_next
                                : Icons.check_circle_outline,
                        size: 20,
                      ),
                      title: Text(r.workflowKey),
                      subtitle: Text(
                        [
                          '${r.triggerKind}:${r.triggerKey}',
                          r.status,
                          if (r.errorMessage != null && r.errorMessage!.isNotEmpty) r.errorMessage!,
                          if (r.startedAt != null) r.startedAt!,
                        ].join(' · '),
                      ),
                      dense: true,
                    ),
                ],
              );
            },
          ),
          SizedBox(height: context.eos.spacing.lg),
          EosAttentionBanner(
            headline: 'Visual builder deferred',
            message: 'Drag-and-drop workflow design, BullMQ, and Marketing automations are out of Phase 23.',
            severity: 'INFO',
          ),
        ],
      ),
    );
  }
}

class _WorkflowTile extends ConsumerWidget {
  const _WorkflowTile({required this.definition});
  final AutomationDefinition definition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: context.eosColors.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.all(context.eos.spacing.md),
        child: Row(
          children: [
            Icon(
              definition.triggerKind == 'schedule' ? Icons.schedule : Icons.bolt_outlined,
              size: 22,
            ),
            SizedBox(width: context.eos.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(definition.label, style: context.eosText.titleSmall),
                  Text(
                    [
                      definition.triggerKind,
                      if (definition.triggerKey != null) definition.triggerKey!,
                      if (definition.scheduleExpr != null) definition.scheduleExpr!,
                    ].join(' · '),
                    style: context.eosText.bodySmall,
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      Chip(
                        label: Text(definition.scope ?? 'organizer'),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(definition.enabled ? 'Enabled' : 'Disabled'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: definition.enabled,
              onChanged: definition.scope == 'platform'
                  ? null
                  : (v) async {
                      try {
                        await ref.read(organizerAutomationApiProvider).setEnabled(
                              workflowKey: definition.workflowKey,
                              enabled: v,
                              session: ref.read(authSessionProvider),
                            );
                        ref.invalidate(organizerAutomationsProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
