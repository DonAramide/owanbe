import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/identity_security_api.dart';
import '../../../eos/eos.dart';

/// Phase 29 — Nest-backed Security Operations Center.
class SecurityCenterScreen extends ConsumerWidget {
  const SecurityCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final center = ref.watch(identitySecurityCenterProvider);
    final users = ref.watch(identitySecurityUsersProvider(''));

    return EosPageScaffold(
      title: 'Security Operations Center',
      subtitle: 'Live platform_security_events + identity lifecycle (Phase 29)',
      floatingHeader: Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: () => ref.invalidate(identitySecurityCenterProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final csv = await ref.read(identitySecurityApiProvider).securityReportCsv();
                await Clipboard.setData(ClipboardData(text: csv));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Security report CSV copied')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            icon: const Icon(Icons.download_outlined),
            label: const Text('Security CSV'),
          ),
        ],
      ),
      body: center.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EosSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Security center unavailable: $e'),
          ),
        ),
        data: (d) {
          final summary = d['summary'] as Map<String, dynamic>? ?? {};
          final events = (d['events'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
          final login = (d['loginActivity'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
          final audits = (d['auditHighlights'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
          return ListView(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _kpi('Failed logins', '${summary['failedLogins'] ?? 0}'),
                  _kpi('Permission escalations', '${summary['permissionEscalations'] ?? 0}'),
                  _kpi('Session abuse', '${summary['sessionAbuse'] ?? 0}'),
                  _kpi('MFA enrolled', '${summary['mfaEnrolled'] ?? 0}'),
                  _kpi('MFA verified', '${summary['mfaVerified'] ?? 0}'),
                  _kpi('MFA recovery', '${summary['mfaRecovery'] ?? 0}'),
                  _kpi('Account lifecycle', '${summary['accountLifecycle'] ?? 0}'),
                  _kpi('Suspended users', '${d['suspendedUsers'] ?? 0}'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                d['supabaseAdminConfigured'] == true
                    ? 'Supabase Auth Admin: configured'
                    : 'Supabase Auth Admin: not configured — MFA recovery/sessions may be Unavailable',
                style: context.eosText.bodySmall,
              ),
              const SizedBox(height: 24),
              Text('Login / MFA activity', style: context.eosText.titleMedium),
              const SizedBox(height: 8),
              EosSurfaceCard(
                child: Column(
                  children: [
                    if (login.isEmpty)
                      const ListTile(title: Text('No login/MFA security events yet'))
                    else
                      for (final e in login.take(20))
                        ListTile(
                          dense: true,
                          title: Text('${e['eventType']}'),
                          subtitle: Text('${e['actorUserId'] ?? ''} · ${e['timestamp'] ?? ''}'),
                          trailing: Text('${e['severity']}'),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Security events', style: context.eosText.titleMedium),
              const SizedBox(height: 8),
              EosSurfaceCard(
                elevated: true,
                child: Column(
                  children: [
                    for (final e in events.take(40))
                      ListTile(
                        dense: true,
                        title: Text('${e['eventType']} · ${e['tenantName'] ?? e['tenantId'] ?? ''}'),
                        subtitle: Text('${e['timestamp']}'),
                        trailing: Text('${e['severity']}'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Identity audit highlights', style: context.eosText.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final a in audits)
                    Chip(label: Text('${a['action']}: ${a['count']}')),
                  if (audits.isEmpty) const Text('No identity.* audit aggregates yet'),
                ],
              ),
              const SizedBox(height: 24),
              Text('User lifecycle', style: context.eosText.titleMedium),
              const SizedBox(height: 8),
              users.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (items) => EosSurfaceCard(
                  elevated: true,
                  child: Column(
                    children: [
                      for (final u in items.take(30))
                        ListTile(
                          title: Text('${u['email'] ?? u['displayName'] ?? u['id']}'),
                          subtitle: Text(
                            '${u['tenantSlug'] ?? ''} · ${u['status']}'
                            '${u['suspendedReason'] != null ? '\n${u['suspendedReason']}' : ''}',
                          ),
                          isThreeLine: u['suspendedReason'] != null,
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              if (u['status'] != 'suspended')
                                TextButton(
                                  onPressed: () async {
                                    final reason = await _prompt(context, 'Suspension reason');
                                    if (reason == null) return;
                                    try {
                                      await ref.read(identitySecurityApiProvider).suspendUser(
                                            u['id'].toString(),
                                            reason: reason,
                                          );
                                      ref.invalidate(identitySecurityUsersProvider(''));
                                      ref.invalidate(identitySecurityCenterProvider);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(content: Text('$e')));
                                      }
                                    }
                                  },
                                  child: const Text('Suspend'),
                                ),
                              if (u['status'] == 'suspended')
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      await ref
                                          .read(identitySecurityApiProvider)
                                          .reactivateUser(u['id'].toString());
                                      ref.invalidate(identitySecurityUsersProvider(''));
                                      ref.invalidate(identitySecurityCenterProvider);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(content: Text('$e')));
                                      }
                                    }
                                  },
                                  child: const Text('Restore'),
                                ),
                              TextButton(
                                onPressed: () async {
                                  try {
                                    final r = await ref
                                        .read(identitySecurityApiProvider)
                                        .revokeSessions(u['id'].toString());
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            r['available'] == true
                                                ? 'Sessions revoked'
                                                : 'Unavailable: ${r['reason']}',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(content: Text('$e')));
                                    }
                                  }
                                },
                                child: const Text('Revoke sessions'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  try {
                                    final r = await ref
                                        .read(identitySecurityApiProvider)
                                        .resetMfa(u['id'].toString(), reason: 'Admin recovery');
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            r['available'] == true
                                                ? 'MFA reset (${r['removed']} factors)'
                                                : 'Unavailable: ${r['reason']}',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(content: Text('$e')));
                                    }
                                  }
                                },
                                child: const Text('MFA recovery'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kpi(String title, String value) {
    return SizedBox(
      width: 160,
      child: EosSurfaceCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _prompt(BuildContext context, String title) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('OK')),
        ],
      ),
    );
  }
}
