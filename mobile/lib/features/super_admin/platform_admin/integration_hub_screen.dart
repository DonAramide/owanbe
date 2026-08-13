import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/integrations_api.dart';
import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';

/// Phase 24 — Super Admin Integrations Hub (Nest-backed).
class IntegrationHubScreen extends ConsumerStatefulWidget {
  const IntegrationHubScreen({super.key});

  @override
  ConsumerState<IntegrationHubScreen> createState() => _IntegrationHubScreenState();
}

class _IntegrationHubScreenState extends ConsumerState<IntegrationHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _webhookUrl = TextEditingController();
  final _smsName = TextEditingController(text: 'Platform Twilio');
  final _smsFrom = TextEditingController();
  final _smsSid = TextEditingController();
  final _smsToken = TextEditingController();
  String? _createdSecret;
  bool _saving = false;

  static const _webhookTopics = [
    'ticket.issued',
    'rsvp.changed',
    'vendor.stage_changed',
    'refund.completed',
    'report.generated',
  ];
  final Set<String> _selectedTopics = {'ticket.issued', 'rsvp.changed'};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _webhookUrl.dispose();
    _smsName.dispose();
    _smsFrom.dispose();
    _smsSid.dispose();
    _smsToken.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(integrationRegistryProvider);
    ref.invalidate(integrationDeliveriesProvider);
    ref.invalidate(integrationWebhooksProvider);
    ref.invalidate(integrationMessagingProvider);
  }

  @override
  Widget build(BuildContext context) {
    final registryAsync = ref.watch(integrationRegistryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EosSurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Integrations Hub',
                        style: context.eosText.headlineMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Live provider registry, messaging credentials, signed outbound webhooks, and delivery history',
                  style: context.eosText.bodySmall,
                ),
                const SizedBox(height: 16),
                registryAsync.when(
                  data: (data) {
                    final items = (data['items'] as List? ?? const [])
                        .cast<Map<String, dynamic>>();
                    final live = items.where((i) => i['live'] == true).length;
                    final degraded =
                        items.where((i) => i['status'] == 'degraded').length;
                    return Row(
                      children: [
                        _stat('Mode', '${data['mode'] ?? '—'}', Icons.tune),
                        _stat('Live providers', '$live', Icons.check_circle),
                        _stat('Degraded', '$degraded', Icons.warning_amber),
                        _stat('Catalog', '${items.length}', Icons.hub),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(
                    'Registry unavailable: $e',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
                TextButton(
                  onPressed: _refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Registry'),
            Tab(text: 'Messaging'),
            Tab(text: 'Webhooks'),
            Tab(text: 'Deliveries'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 640,
          child: TabBarView(
            controller: _tabs,
            children: [
              _registryTab(),
              _messagingTab(),
              _webhooksTab(),
              _deliveriesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: context.eosColors.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text(label, style: context.eosText.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _registryTab() {
    final async = ref.watch(integrationRegistryProvider);
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (data) {
            final items = (data['items'] as List? ?? const [])
                .cast<Map<String, dynamic>>();
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                final status = '${item['status'] ?? 'unknown'}';
                final live = item['live'] == true;
                return ListTile(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: context.eosColors.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: Icon(
                    live ? Icons.cloud_done : Icons.cloud_off,
                    color: live ? Colors.green : Colors.orange,
                  ),
                  title: Text('${item['label'] ?? item['key']}'),
                  subtitle: Text(
                    '${item['category']} · ${item['healthDetail'] ?? status}',
                  ),
                  trailing: EosFinanceChip(
                    label: status.toUpperCase(),
                    compact: true,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _messagingTab() {
    final async = ref.watch(integrationMessagingProvider);
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (items) {
                  if (items.isEmpty) {
                    return Text(
                      'No messaging providers configured yet. Add Twilio SMS or WhatsApp credentials on the right.',
                      style: context.eosText.bodyMedium,
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (context, i) {
                      final m = items[i];
                      return ListTile(
                        title: Text('${m['name']}'),
                        subtitle: Text(
                          '${m['channel']} · ${m['providerType']} · '
                          '${m['enabled'] == true ? 'enabled' : 'disabled'}'
                          '${m['isDefault'] == true ? ' · default' : ''}'
                          '${m['hasSecrets'] == true ? ' · secrets set' : ''}',
                        ),
                        trailing: m['lastError'] != null
                            ? Tooltip(
                                message: '${m['lastError']}',
                                child: const Icon(Icons.error_outline, color: Colors.red),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Configure SMS (Twilio)', style: context.eosText.titleMedium),
                  const SizedBox(height: 8),
                  TextField(controller: _smsName, decoration: const InputDecoration(labelText: 'Name')),
                  TextField(controller: _smsFrom, decoration: const InputDecoration(labelText: 'From number')),
                  TextField(controller: _smsSid, decoration: const InputDecoration(labelText: 'Account SID')),
                  TextField(
                    controller: _smsToken,
                    decoration: const InputDecoration(labelText: 'Auth token'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : _saveSms,
                    child: Text(_saving ? 'Saving…' : 'Save SMS provider'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'WhatsApp: create via API with channel=whatsapp (foundation). '
                    'Email remains under Enterprise Email.',
                    style: context.eosText.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSms() async {
    setState(() => _saving = true);
    try {
      await ref.read(integrationsApiProvider).createMessaging({
        'channel': 'sms',
        'providerType': 'twilio',
        'name': _smsName.text.trim().isEmpty ? 'Platform Twilio' : _smsName.text.trim(),
        'fromAddress': _smsFrom.text.trim(),
        'setDefault': true,
        'secrets': {
          'accountSid': _smsSid.text.trim(),
          'authToken': _smsToken.text.trim(),
        },
      });
      _smsSid.clear();
      _smsToken.clear();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS provider saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _webhooksTab() {
    final async = ref.watch(integrationWebhooksProvider);
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (items) {
                  if (items.isEmpty) {
                    return const Text('No outbound webhook endpoints registered.');
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, i) {
                      final w = items[i];
                      final active = w['isActive'] == true;
                      return ListTile(
                        title: Text('${w['label'] ?? w['clientId'] ?? w['id']}'),
                        subtitle: Text(
                          '${w['targetUrl']}\n'
                          'Topics: ${(w['subscribedTopics'] as List? ?? const []).join(', ')}',
                        ),
                        isThreeLine: true,
                        trailing: Switch(
                          value: active,
                          onChanged: (v) async {
                            await ref
                                .read(integrationsApiProvider)
                                .setWebhookActive('${w['id']}', v);
                            await _refresh();
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 340,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Register outbound webhook', style: context.eosText.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _webhookUrl,
                    decoration: const InputDecoration(
                      labelText: 'HTTPS target URL',
                      hintText: 'https://partner.example/hooks/owanbe',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _webhookTopics.map((t) {
                      final selected = _selectedTopics.contains(t);
                      return FilterChip(
                        label: Text(t),
                        selected: selected,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _selectedTopics.add(t);
                            } else {
                              _selectedTopics.remove(t);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : _createWebhook,
                    child: Text(_saving ? 'Creating…' : 'Create signed endpoint'),
                  ),
                  if (_createdSecret != null) ...[
                    const SizedBox(height: 12),
                    SelectableText(
                      'Signing secret (copy now):\n$_createdSecret',
                      style: context.eosText.bodySmall,
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _createdSecret!));
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy secret'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createWebhook() async {
    setState(() => _saving = true);
    try {
      final created = await ref.read(integrationsApiProvider).createWebhook(
            targetUrl: _webhookUrl.text.trim(),
            subscribedTopics: _selectedTopics.toList(),
            label: 'Platform webhook',
          );
      setState(() => _createdSecret = created['secret']?.toString());
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Create failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _deliveriesTab() {
    final async = ref.watch(integrationDeliveriesProvider);
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (data) {
            final webhooks = (data['webhooks'] as List? ?? const [])
                .cast<Map<String, dynamic>>();
            final notifications = (data['notifications'] as List? ?? const [])
                .cast<Map<String, dynamic>>();
            return ListView(
              children: [
                Text('Outbound webhooks', style: context.eosText.titleMedium),
                const SizedBox(height: 8),
                if (webhooks.isEmpty)
                  const Text('No webhook deliveries yet.')
                else
                  ...webhooks.take(40).map((d) => ListTile(
                        dense: true,
                        title: Text('${d['topic']} → ${d['status']}'),
                        subtitle: Text(
                          '${d['targetUrl'] ?? ''}'
                          '${d['lastError'] != null ? '\n${d['lastError']}' : ''}',
                        ),
                        trailing: Text('x${d['attempts'] ?? 0}'),
                      )),
                const Divider(height: 32),
                Text('Notification deliveries', style: context.eosText.titleMedium),
                const SizedBox(height: 8),
                if (notifications.isEmpty)
                  const Text('No notification deliveries yet.')
                else
                  ...notifications.take(40).map((d) => ListTile(
                        dense: true,
                        title: Text('${d['channel']} · ${d['template']} · ${d['status']}'),
                        subtitle: Text('${d['provider']} → ${d['recipient']}'),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}
