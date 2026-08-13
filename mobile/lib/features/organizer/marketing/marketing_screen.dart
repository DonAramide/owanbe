import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../providers/organizer_providers.dart';
import 'organizer_marketing_api.dart';

/// Phase 26 — Organizer Marketing workspace (consumer layer).
class MarketingScreen extends ConsumerStatefulWidget {
  const MarketingScreen({super.key, this.initialEventId});

  final String? initialEventId;

  @override
  ConsumerState<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends ConsumerState<MarketingScreen> {
  String? _eventId;
  String _channel = 'email';
  String _segment = 'all_guests';
  final _nameCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _busy = false;
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    _eventId = widget.initialEventId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(organizerMarketingCampaignsProvider(_eventId));
    ref.invalidate(organizerMarketingChannelsProvider);
    setState(() => _detail = null);
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(organizerEventsProvider);
    final campaignsAsync = ref.watch(organizerMarketingCampaignsProvider(_eventId));
    final channelsAsync = ref.watch(organizerMarketingChannelsProvider);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: [
          Text('Marketing', style: context.eosText.headlineSmall),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            'Reach guests and buyers via NotificationService. '
            'Conversion is read-only from tickets and RSVPs — Finance owns revenue.',
            style: context.eosText.bodySmall,
          ),
          SizedBox(height: context.eos.spacing.lg),
          Text('Delivery channels', style: context.eosText.titleMedium),
          SizedBox(height: context.eos.spacing.sm),
          channelsAsync.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (e, _) => EosAttentionBanner(
              headline: 'Channels unavailable',
              message: '$e',
              severity: 'WARNING',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(organizerMarketingChannelsProvider),
            ),
            data: (ch) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in ['email', 'sms', 'whatsapp'])
                  _ChannelChip(
                    label: key,
                    available: (ch[key] as Map?)?['available'] == true,
                    reason: (ch[key] as Map?)?['reason']?.toString(),
                    selected: _channel == key,
                    onTap: () {
                      final ok = (ch[key] as Map?)?['available'] == true;
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              (ch[key] as Map?)?['reason']?.toString() ??
                                  '$key unavailable',
                            ),
                          ),
                        );
                        return;
                      }
                      setState(() => _channel = key);
                    },
                  ),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.lg),
          Text('Create campaign', style: context.eosText.titleMedium),
          SizedBox(height: context.eos.spacing.sm),
          eventsAsync.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (e, _) => Text('$e', style: context.eosText.bodySmall),
            data: (events) {
              final items = events;
              return DropdownButtonFormField<String>(
                value: _eventId != null && items.any((e) => e.id == _eventId)
                    ? _eventId
                    : null,
                decoration: const InputDecoration(labelText: 'Event'),
                items: [
                  for (final e in items)
                    DropdownMenuItem(value: e.id, child: Text(e.title)),
                ],
                onChanged: (v) => setState(() => _eventId = v),
              );
            },
          ),
          SizedBox(height: context.eos.spacing.sm),
          DropdownButtonFormField<String>(
            value: _segment,
            decoration: const InputDecoration(labelText: 'Audience'),
            items: const [
              DropdownMenuItem(value: 'all_guests', child: Text('All guests')),
              DropdownMenuItem(value: 'rsvp_confirmed', child: Text('RSVP confirmed')),
              DropdownMenuItem(value: 'rsvp_pending', child: Text('RSVP pending')),
              DropdownMenuItem(value: 'rsvp_declined', child: Text('RSVP declined')),
              DropdownMenuItem(value: 'ticket_buyers', child: Text('Ticket buyers')),
              DropdownMenuItem(
                value: 'attendees_checked_in',
                child: Text('Checked-in attendees'),
              ),
            ],
            onChanged: (v) => setState(() => _segment = v ?? 'all_guests'),
          ),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Campaign name'),
          ),
          if (_channel == 'email')
            TextField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(labelText: 'Email subject'),
            ),
          TextField(
            controller: _bodyCtrl,
            decoration: const InputDecoration(labelText: 'Message body'),
            maxLines: 4,
          ),
          SizedBox(height: context.eos.spacing.sm),
          Row(
            children: [
              OutlinedButton(
                onPressed: _busy || _eventId == null ? null : _preview,
                child: const Text('Preview audience'),
              ),
              SizedBox(width: context.eos.spacing.sm),
              FilledButton(
                onPressed: _busy || _eventId == null ? null : _createAndSend,
                child: Text(_busy ? 'Working…' : 'Create & send'),
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.xl),
          Text('Campaign history', style: context.eosText.titleMedium),
          SizedBox(height: context.eos.spacing.sm),
          campaignsAsync.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (e, _) => EosAttentionBanner(
              headline: 'Campaigns unavailable',
              message: '$e',
              severity: 'WARNING',
              actionLabel: 'Retry',
              onAction: _refresh,
            ),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  'No campaigns yet. Create one to reach an audience.',
                  style: context.eosText.bodySmall,
                );
              }
              return Column(
                children: [
                  for (final c in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.name),
                      subtitle: Text(
                        [
                          c.status,
                          c.channel,
                          c.audienceSegment,
                          if (c.eventTitle != null) c.eventTitle!,
                          'sent ${c.sentCount}/${c.recipientCount}',
                          if (c.failedCount > 0) 'failed ${c.failedCount}',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openDetail(c.id),
                    ),
                ],
              );
            },
          ),
          if (_detail != null) ...[
            SizedBox(height: context.eos.spacing.lg),
            Text('Campaign detail', style: context.eosText.titleMedium),
            SizedBox(height: context.eos.spacing.sm),
            _DetailCard(detail: _detail!),
          ],
        ],
      ),
    );
  }

  Future<void> _preview() async {
    if (_eventId == null) return;
    setState(() => _busy = true);
    try {
      final preview = await ref.read(organizerMarketingApiProvider).previewAudience(
            eventId: _eventId!,
            segment: _segment,
            channel: _channel,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${preview['count']} recipients for $_segment / $_channel')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createAndSend() async {
    if (_eventId == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Campaign name required')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final api = ref.read(organizerMarketingApiProvider);
      final created = await api.createCampaign({
        'eventId': _eventId,
        'name': name,
        'channel': _channel,
        'audienceSegment': _segment,
        'subject': _subjectCtrl.text.trim().isEmpty ? name : _subjectCtrl.text.trim(),
        'body': _bodyCtrl.text.trim().isEmpty
            ? '<p>$name</p>'
            : _bodyCtrl.text.trim(),
      });
      final detail = await api.sendCampaign(created.id);
      setState(() => _detail = detail);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Campaign sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDetail(String id) async {
    setState(() => _busy = true);
    try {
      final detail = await ref.read(organizerMarketingApiProvider).getCampaign(id);
      setState(() => _detail = detail);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({
    required this.label,
    required this.available,
    required this.selected,
    required this.onTap,
    this.reason,
  });

  final String label;
  final bool available;
  final bool selected;
  final String? reason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        available ? label : '$label (unavailable)',
      ),
      selected: selected && available,
      onSelected: (_) => onTap(),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.detail});
  final Map<String, dynamic> detail;

  @override
  Widget build(BuildContext context) {
    final campaign = detail['campaign'] as Map<String, dynamic>? ?? const {};
    final engagement = detail['engagement'] as Map<String, dynamic>? ?? const {};
    final conversion = detail['conversion'] as Map<String, dynamic>? ?? const {};
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${campaign['name']}', style: context.eosText.titleSmall),
            Text(
              '${campaign['status']} · ${campaign['channel']} · ${campaign['audienceSegment']}',
              style: context.eosText.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Engagement — sent ${engagement['sent'] ?? 0}, failed ${engagement['failed'] ?? 0}',
              style: context.eosText.bodySmall,
            ),
            Text(
              conversion['available'] == true
                  ? 'Conversion (post-send) — tickets ${conversion['ticketsSoldAfter']}, '
                      'RSVP confirmed ${conversion['rsvpConfirmedAfter']}'
                  : 'Conversion — ${conversion['reason'] ?? 'n/a'}',
              style: context.eosText.bodySmall,
            ),
            if (conversion['note'] != null)
              Text('${conversion['note']}', style: context.eosText.labelSmall),
          ],
        ),
      ),
    );
  }
}
