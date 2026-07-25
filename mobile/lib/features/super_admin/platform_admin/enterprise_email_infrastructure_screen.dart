import 'package:flutter/material.dart';

import '../../../core/api/enterprise_email_api.dart';
import '../../../eos/eos.dart';

/// Super Admin — Enterprise Email Infrastructure configuration.
class EnterpriseEmailInfrastructureScreen extends StatefulWidget {
  const EnterpriseEmailInfrastructureScreen({super.key});

  @override
  State<EnterpriseEmailInfrastructureScreen> createState() =>
      _EnterpriseEmailInfrastructureScreenState();
}

class _EnterpriseEmailInfrastructureScreenState
    extends State<EnterpriseEmailInfrastructureScreen> {
  final _api = EnterpriseEmailApi();
  List<Map<String, dynamic>> _providers = [];
  Map<String, dynamic>? _syncStatus;
  Map<String, dynamic>? _readiness;
  bool _loading = true;
  String? _error;
  String? _busyId;

  static const _types = [
    'zoho_smtp',
    'generic_smtp',
    'microsoft_365',
    'google_workspace',
    'amazon_ses',
    'sendgrid',
    'mailgun',
    'postmark',
    'custom_smtp',
    'resend',
  ];

  bool get _hasProviders => _providers.isNotEmpty;
  bool get _hasDefault => _providers.any((p) => p['isDefault'] == true && p['enabled'] == true);
  bool get _syncConfigured => _syncStatus?['managementApiConfigured'] == true;
  bool get _syncEnabled => _syncStatus?['syncEnabled'] == true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final providers = await _api.listProviders();
      final sync = await _api.supabaseSyncStatus();
      final ready = await _api.readiness();
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _syncStatus = sync;
        _readiness = ready;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _showProviderForm({Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? 'Zoho Production');
    final host = TextEditingController(text: existing?['smtpHost']?.toString() ?? 'smtp.zoho.com');
    final port = TextEditingController(text: '${existing?['smtpPort'] ?? 587}');
    final username = TextEditingController(text: existing?['username']?.toString() ?? '');
    final password = TextEditingController();
    final apiKey = TextEditingController();
    final senderName = TextEditingController(text: existing?['senderName']?.toString() ?? 'Owanbe');
    final senderEmail = TextEditingController(text: existing?['senderEmail']?.toString() ?? '');
    final replyTo = TextEditingController(text: existing?['replyTo']?.toString() ?? '');
    var type = existing?['providerType']?.toString() ?? 'zoho_smtp';
    var encryption = existing?['encryptionMode']?.toString() ?? 'starttls';
    var isDefault = existing?['isDefault'] == true || existing == null;
    var enabled = existing?['enabled'] != false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add email provider' : 'Edit email provider'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Provider type'),
                    items: _types
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setLocal(() => type = v ?? type),
                  ),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                  TextField(controller: host, decoration: const InputDecoration(labelText: 'SMTP host')),
                  TextField(controller: port, decoration: const InputDecoration(labelText: 'SMTP port')),
                  DropdownButtonFormField<String>(
                    value: encryption,
                    decoration: const InputDecoration(labelText: 'TLS / SSL'),
                    items: const [
                      DropdownMenuItem(value: 'starttls', child: Text('STARTTLS (587)')),
                      DropdownMenuItem(value: 'ssl', child: Text('SSL (465)')),
                      DropdownMenuItem(value: 'none', child: Text('None')),
                    ],
                    onChanged: (v) => setLocal(() => encryption = v ?? encryption),
                  ),
                  TextField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: existing == null ? 'Password' : 'Password (leave blank to keep)',
                    ),
                  ),
                  TextField(
                    controller: apiKey,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: existing == null ? 'API key (SendGrid/Resend/…)' : 'API key (leave blank to keep)',
                    ),
                  ),
                  TextField(controller: senderName, decoration: const InputDecoration(labelText: 'Sender name')),
                  TextField(controller: senderEmail, decoration: const InputDecoration(labelText: 'Sender email')),
                  TextField(controller: replyTo, decoration: const InputDecoration(labelText: 'Reply-To')),
                  SwitchListTile(
                    title: const Text('Default provider'),
                    value: isDefault,
                    onChanged: (v) => setLocal(() => isDefault = v),
                  ),
                  SwitchListTile(
                    title: const Text('Enabled'),
                    value: enabled,
                    onChanged: (v) => setLocal(() => enabled = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    final body = <String, dynamic>{
      'name': name.text.trim(),
      'providerType': type,
      'smtpHost': host.text.trim().isEmpty ? null : host.text.trim(),
      'smtpPort': int.tryParse(port.text.trim()) ?? 587,
      'encryptionMode': encryption,
      'username': username.text.trim().isEmpty ? null : username.text.trim(),
      'senderName': senderName.text.trim(),
      'senderEmail': senderEmail.text.trim(),
      'replyTo': replyTo.text.trim().isEmpty ? null : replyTo.text.trim(),
      'isDefault': isDefault,
      'enabled': enabled,
      if (password.text.isNotEmpty) 'password': password.text,
      if (apiKey.text.isNotEmpty) 'apiKey': apiKey.text,
    };

    try {
      if (existing == null) {
        await _api.createProvider(body);
      } else {
        await _api.updateProvider(existing['id'].toString(), body);
      }
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provider saved. Password is never returned to the client.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _run(String id, Future<Map<String, dynamic>> Function() op, String okMsg) async {
    setState(() => _busyId = id);
    try {
      final r = await op();
      if (!mounted) return;
      final ok = r['ok'] == true;
      final detail = ok
          ? okMsg
          : _formatFailure(r);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail)));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _formatFailure(Map<String, dynamic> r) {
    final parts = <String>[
      if (r['httpStatus'] != null) 'HTTP ${r['httpStatus']}',
      if (r['errorCode'] != null) 'code=${r['errorCode']}',
      if (r['reason'] != null) '${r['reason']}',
      if (r['recommendedAction'] != null) 'Action: ${r['recommendedAction']}',
    ];
    if (parts.isEmpty) return 'Failed: $r';
    return 'Failed: ${parts.join(' · ')}';
  }

  @override
  Widget build(BuildContext context) {
    final blockers = (_readiness?['blockers'] as List?)?.map((e) => '$e').toList() ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enterprise Email Infrastructure', style: context.eosText.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Single source of truth for Owanbe business email. Provider-agnostic — Zoho is the first SMTP provider, not the only one.',
          style: context.eosText.bodySmall,
        ),
        const SizedBox(height: 12),
        if (!_loading && !_hasProviders)
          EosSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No SMTP provider configured.', style: context.eosText.titleSmall),
                const SizedBox(height: 8),
                Text(
                  'Test Email, Sync to Supabase, Make Default, and outbound mail are disabled until you configure a provider.',
                  style: context.eosText.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _showProviderForm(),
                  icon: const Icon(Icons.settings_ethernet),
                  label: const Text('Configure SMTP Provider'),
                ),
              ],
            ),
          ),
        if (!_loading && _hasProviders && !_hasDefault) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade700),
            ),
            child: Text(
              'Warning: No default provider selected. Outbound mail and Supabase sync stay blocked until you mark a provider as default.',
              style: context.eosText.bodySmall?.copyWith(color: Colors.amber.shade100),
            ),
          ),
        ],
        if (!_loading && blockers.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Readiness blockers:', style: context.eosText.labelMedium),
          ...blockers.map((b) => Text('• $b', style: context.eosText.bodySmall)),
        ],
        const SizedBox(height: 12),
        if (_syncStatus != null)
          EosSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Supabase Auth SMTP sync', style: context.eosText.titleSmall),
                const SizedBox(height: 6),
                Text(
                  _syncConfigured
                      ? (_syncEnabled
                          ? 'Management API configured — sync is available.'
                          : 'Management API configured, but email infrastructure is not ready: ${_syncStatus!['syncDisabledReason'] ?? 'see readiness blockers'}.')
                      : (_syncStatus!['syncDisabledReason']?.toString() ??
                          'SUPABASE_ACCESS_TOKEN is not configured. Sync is disabled. Set an Owner/Administrator PAT on the API and restart, or configure Auth SMTP in the Supabase Dashboard.'),
                  style: context.eosText.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: !_syncEnabled || _busyId != null
                          ? null
                          : () => _run('sync', () => _api.syncToSupabase(), 'Synced to Supabase Auth'),
                      child: const Text('Sync default → Supabase Auth'),
                    ),
                    OutlinedButton(onPressed: _reload, child: const Text('Refresh')),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () => _showProviderForm(),
              icon: const Icon(Icons.add),
              label: Text(_hasProviders ? 'Add provider' : 'Configure SMTP Provider'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(onPressed: _reload, child: const Text('Reload')),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Text(_error!, style: TextStyle(color: context.eosColors.error)),
        ..._providers.map((p) {
          final id = p['id'].toString();
          final busy = _busyId == id;
          final enabled = p['enabled'] == true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: EosSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${p['name']} (${p['providerType']})',
                          style: context.eosText.titleSmall,
                        ),
                      ),
                      if (p['isDefault'] == true)
                        Chip(label: Text('DEFAULT', style: context.eosText.labelSmall)),
                      if (!enabled)
                        Chip(label: Text('DISABLED', style: context.eosText.labelSmall)),
                    ],
                  ),
                  Text(
                    '${p['senderName']} <${p['senderEmail']}> · ${p['smtpHost'] ?? 'API'} · health: ${p['healthStatus']}',
                    style: context.eosText.bodySmall,
                  ),
                  Text(
                    'Secrets: password=${p['hasPassword'] == true ? 'set' : '—'} · apiKey=${p['hasApiKey'] == true ? 'set' : '—'}',
                    style: context.eosText.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: busy ? null : () => _showProviderForm(existing: p),
                        child: const Text('Edit'),
                      ),
                      OutlinedButton(
                        onPressed: busy || !enabled
                            ? null
                            : () => _run(id, () => _api.testConnection(id), 'Connection OK'),
                        child: const Text('Test connection'),
                      ),
                      OutlinedButton(
                        onPressed: busy || !enabled
                            ? null
                            : () async {
                                final to = await _promptEmail();
                                if (to == null || to.isEmpty) return;
                                await _run(id, () => _api.sendTestEmail(id, to), 'Test email sent');
                              },
                        child: const Text('Send test email'),
                      ),
                      OutlinedButton(
                        onPressed: busy || !_hasProviders
                            ? null
                            : () => _run(id, () => _api.setDefault(id), 'Set as default'),
                        child: const Text('Make default'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                await _api.deleteProvider(id);
                                await _reload();
                              },
                        child: Text('Delete', style: TextStyle(color: context.eosColors.error)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<String?> _promptEmail() async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send test email to'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'Use an email address you can access.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Send')),
        ],
      ),
    );
  }
}
