import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../platform/compliance_providers.dart';
import '../widgets/admin_async_body.dart';
import '../widgets/admin_error_states.dart';
import '../widgets/admin_page_layout.dart';

/// Phase 27 — Compliance operations (Nest `/compliance/*`).
class AdminComplianceScreen extends ConsumerWidget {
  const AdminComplianceScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(complianceDashboardProvider);
    ref.invalidate(complianceRetentionProvider);
    ref.invalidate(complianceExportsProvider);
    ref.invalidate(complianceDeletionsProvider);
    ref.invalidate(complianceActivityProvider);
  }

  Future<void> _snack(BuildContext context, String msg, {bool error = false}) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade800 : null),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(complianceDashboardProvider);
    final retention = ref.watch(complianceRetentionProvider);
    final exports = ref.watch(complianceExportsProvider);
    final deletions = ref.watch(complianceDeletionsProvider);
    final activity = ref.watch(complianceActivityProvider);

    return AdminPageLayout(
      title: 'Compliance',
      subtitle: 'Data governance, exports, retention, and deletion workflows',
      actions: [
        TextButton.icon(
          onPressed: () => _refresh(ref),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
        FilledButton.icon(
          onPressed: () async {
            try {
              final csv = await ref.read(complianceApiProvider).governanceReportCsv();
              await Clipboard.setData(ClipboardData(text: csv));
              if (context.mounted) {
                await _snack(context, 'Governance CSV copied to clipboard');
              }
            } catch (e) {
              if (context.mounted) await _snack(context, e.toString(), error: true);
            }
          },
          icon: const Icon(Icons.download_outlined),
          label: const Text('Governance CSV'),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminAsyncBody(
            value: dash,
            onRetry: () => ref.invalidate(complianceDashboardProvider),
            builder: (d) {
              final pending = (d['pendingDeletions'] as num?)?.toInt() ?? 0;
              final gov = d['governanceStatus'] as Map<String, dynamic>? ?? {};
              final retentionOk = gov['retentionConfigured'] == true;
              return AdminKpiGrid(
                children: [
                  EosKpiCard(
                    title: 'Governance',
                    value: retentionOk ? 'CONFIGURED' : 'SETUP NEEDED',
                    icon: Icons.policy_outlined,
                    attention: retentionOk ? EosKpiAttention.none : EosKpiAttention.warning,
                  ),
                  EosKpiCard(
                    title: 'Open deletion queue',
                    value: '$pending',
                    icon: Icons.delete_outline,
                    attention: pending > 0 ? EosKpiAttention.warning : EosKpiAttention.none,
                  ),
                  EosKpiCard(
                    title: 'Export activity',
                    value: '${(d['exportByStatus'] as Map?)?.values.fold<int>(0, (a, v) => a + ((v as num?)?.toInt() ?? 0)) ?? 0}',
                    icon: Icons.file_download_outlined,
                  ),
                ],
              );
            },
          ),
          SizedBox(height: context.eos.spacing.xl),
          AdminSectionHeader(
            title: 'Retention policies',
            subtitle: 'Category retention periods (days) — enforcement before deletion',
          ),
          AdminAsyncBody(
            value: retention,
            onRetry: () => ref.invalidate(complianceRetentionProvider),
            builder: (r) {
              final cats = (r['categories'] as List<dynamic>? ?? const [])
                  .cast<Map<String, dynamic>>();
              return EosSurfaceCard(
                elevated: true,
                child: Column(
                  children: [
                    for (final c in cats)
                      ListTile(
                        title: Text('${c['label'] ?? c['id']}'),
                        subtitle: Text('${c['retentionDays']} days'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editRetention(context, ref, c),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: context.eos.spacing.xl),
          AdminSectionHeader(
            title: 'Data exports',
            subtitle: 'Composes audit_log / security events / subject packages — not a second export engine',
          ),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: () async {
                  try {
                    await ref.read(complianceApiProvider).createExport();
                    _refresh(ref);
                    if (context.mounted) await _snack(context, 'Audit bundle export completed');
                  } catch (e) {
                    if (context.mounted) await _snack(context, e.toString(), error: true);
                  }
                },
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Request audit export'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _requestSubjectExport(context, ref),
                icon: const Icon(Icons.person_search_outlined),
                label: const Text('Subject package'),
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.md),
          AdminAsyncBody(
            value: exports,
            onRetry: () => ref.invalidate(complianceExportsProvider),
            isEmpty: (items) => items.isEmpty,
            empty: const EmptyStateCard(
              title: 'No export requests yet',
              message: 'Request an audit bundle or subject package to start history.',
            ),
            builder: (items) {
              return EosSurfaceCard(
                elevated: true,
                child: Column(
                  children: [
                    for (final e in items.take(20))
                      ListTile(
                        leading: Icon(
                          e['status'] == 'completed'
                              ? Icons.check_circle_outline
                              : Icons.hourglass_empty,
                          color: context.eosColors.primary,
                        ),
                        title: Text('${e['exportKind'] ?? 'export'} · ${e['status']}'),
                        subtitle: Text('${e['id']} · ${e['createdAt'] ?? ''}'),
                        trailing: e['status'] == 'completed'
                            ? IconButton(
                                tooltip: 'Copy download JSON',
                                icon: const Icon(Icons.copy_outlined),
                                onPressed: () async {
                                  try {
                                    final pack = await ref
                                        .read(complianceApiProvider)
                                        .downloadExport(e['id'].toString());
                                    await Clipboard.setData(
                                      ClipboardData(text: pack.toString()),
                                    );
                                    if (context.mounted) {
                                      await _snack(context, 'Export package copied');
                                    }
                                  } catch (err) {
                                    if (context.mounted) {
                                      await _snack(context, err.toString(), error: true);
                                    }
                                  }
                                },
                              )
                            : null,
                      ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: context.eos.spacing.xl),
          AdminSectionHeader(
            title: 'Deletion requests',
            subtitle: 'Request → review → approve → process (identity anonymization only)',
          ),
          OutlinedButton.icon(
            onPressed: () => _requestDeletion(context, ref),
            icon: const Icon(Icons.person_off_outlined),
            label: const Text('New deletion request'),
          ),
          SizedBox(height: context.eos.spacing.md),
          AdminAsyncBody(
            value: deletions,
            onRetry: () => ref.invalidate(complianceDeletionsProvider),
            isEmpty: (items) => items.isEmpty,
            empty: const EmptyStateCard(title: 'No deletion requests'),
            builder: (items) {
              return EosSurfaceCard(
                elevated: true,
                child: Column(
                  children: [
                    for (final d in items.take(25))
                      ListTile(
                        title: Text(d['subjectEmail']?.toString() ?? d['subjectUserId']?.toString() ?? ''),
                        subtitle: Text('${d['status']} · ${d['reason'] ?? ''}'),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 4,
                          children: _deletionActions(context, ref, d),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: context.eos.spacing.xl),
          AdminSectionHeader(title: 'Compliance activity', subtitle: 'Audit evidence (compliance.*)'),
          AdminAsyncBody(
            value: activity,
            onRetry: () => ref.invalidate(complianceActivityProvider),
            isEmpty: (items) => items.isEmpty,
            empty: const EmptyStateCard(title: 'No compliance audit events yet'),
            builder: (items) {
              return EosSurfaceCard(
                elevated: true,
                child: Column(
                  children: [
                    for (final a in items.take(30))
                      ListTile(
                        dense: true,
                        title: Text('${a['action']}'),
                        subtitle: Text('${a['resourceType']} · ${a['createdAt'] ?? ''}'),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _deletionActions(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> d,
  ) {
    final status = (d['status'] ?? '').toString();
    final id = d['id'].toString();
    Widget btn(String label, String action) {
      return TextButton(
        onPressed: () async {
          try {
            String? reason;
            if (action == 'reject') {
              reason = await _prompt(context, title: 'Rejection reason', hint: 'Reason');
              if (reason == null) return;
            }
            await ref.read(complianceApiProvider).transitionDeletion(
                  id: id,
                  action: action,
                  reason: reason,
                );
            _refresh(ref);
            if (context.mounted) await _snack(context, 'Updated: $action');
          } catch (e) {
            if (context.mounted) await _snack(context, e.toString(), error: true);
          }
        },
        child: Text(label),
      );
    }

    final out = <Widget>[];
    if (status == 'pending') {
      out.add(btn('Review', 'review'));
      out.add(btn('Approve', 'approve'));
      out.add(btn('Reject', 'reject'));
    } else if (status == 'reviewing') {
      out.add(btn('Approve', 'approve'));
      out.add(btn('Reject', 'reject'));
    } else if (status == 'approved') {
      out.add(btn('Process', 'process'));
      out.add(btn('Reject', 'reject'));
    }
    return out;
  }

  Future<void> _editRetention(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> cat,
  ) async {
    final id = (cat['id'] ?? '').toString();
    final current = (cat['retentionDays'] as num?)?.toInt() ?? 365;
    final raw = await _prompt(
      context,
      title: 'Retention days — ${cat['label'] ?? id}',
      hint: '$current',
      initial: '$current',
      keyboard: TextInputType.number,
    );
    if (raw == null) return;
    final days = int.tryParse(raw.trim());
    if (days == null || days < 30) {
      await _snack(context, 'Enter a valid day count (≥ 30)', error: true);
      return;
    }
    final key = switch (id) {
      'audit' => 'auditRetentionDays',
      'finance' => 'financeRetentionDays',
      'marketing' => 'marketingRetentionDays',
      'notifications' => 'notificationRetentionDays',
      'guests' => 'guestRetentionDays',
      _ => null,
    };
    if (key == null) return;
    try {
      await ref.read(complianceApiProvider).updateRetention({key: days});
      _refresh(ref);
      if (context.mounted) await _snack(context, 'Retention updated');
    } catch (e) {
      if (context.mounted) await _snack(context, e.toString(), error: true);
    }
  }

  Future<void> _requestSubjectExport(BuildContext context, WidgetRef ref) async {
    final uid = await _prompt(context, title: 'Subject user ID', hint: 'UUID');
    if (uid == null || uid.trim().isEmpty) return;
    try {
      await ref.read(complianceApiProvider).createExport(
            exportKind: 'subject_package',
            subjectUserId: uid.trim(),
          );
      _refresh(ref);
      if (context.mounted) await _snack(context, 'Subject package export completed');
    } catch (e) {
      if (context.mounted) await _snack(context, e.toString(), error: true);
    }
  }

  Future<void> _requestDeletion(BuildContext context, WidgetRef ref) async {
    final uid = await _prompt(context, title: 'Subject user ID', hint: 'UUID');
    if (uid == null || uid.trim().isEmpty) return;
    final reason = await _prompt(context, title: 'Reason', hint: 'DSAR / NDPR request');
    try {
      await ref.read(complianceApiProvider).requestDeletion(
            subjectUserId: uid.trim(),
            reason: reason,
          );
      _refresh(ref);
      if (context.mounted) await _snack(context, 'Deletion request created');
    } catch (e) {
      if (context.mounted) await _snack(context, e.toString(), error: true);
    }
  }

  Future<String?> _prompt(
    BuildContext context, {
    required String title,
    required String hint,
    String? initial,
    TextInputType keyboard = TextInputType.text,
  }) async {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          keyboardType: keyboard,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
