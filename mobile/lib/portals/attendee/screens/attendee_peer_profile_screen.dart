import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/networking_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../../../profile/widgets/profile_network_avatar.dart';
import '../models/attendee_profile_card.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_networking_providers.dart';
import '../screens/attendee_profile_card_sheet.dart';
import '../widgets/attendee_flow_scaffold.dart';
import '../widgets/attendee_networking_widgets.dart';

/// Public peer attendee profile for an event (Phase 8.2).
class AttendeePeerProfileScreen extends ConsumerStatefulWidget {
  const AttendeePeerProfileScreen({
    super.key,
    required this.eventId,
    required this.userId,
  });

  final String eventId;
  final String userId;

  @override
  ConsumerState<AttendeePeerProfileScreen> createState() => _AttendeePeerProfileScreenState();
}

class _AttendeePeerProfileScreenState extends ConsumerState<AttendeePeerProfileScreen>
    with NetworkingActionsMixin<AttendeePeerProfileScreen> {
  bool _busy = false;

  DirectoryPerson? _matchFromDirectory(List<DirectoryPerson> people) {
    for (final p in people) {
      if (p.userId == widget.userId) return p;
    }
    return null;
  }

  Future<void> _shareMyCardWithPeer() async {
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    final card = await ref.read(networkingBusinessCardProvider.future);
    if (card == null) return;
    await SharePlus.instance.share(
      ShareParams(text: card.shareText, subject: '${card.displayName} · Business card'),
    );
    try {
      await ref.read(networkingApiProvider).notifyShare(
            session: session,
            kind: 'business_card_shared',
            recipientUserId: widget.userId,
            eventId: widget.eventId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business card shared')),
        );
      }
    } catch (_) {}
  }

  Future<void> _shareProfile(AttendeeProfileCard card) async {
    final text = [
      card.displayName,
      if (card.occupation != null) card.occupation,
      if (card.company != null) card.company,
      if (card.bio != null) card.bio,
      ...card.socialLinks.entries.map((e) => '${e.key}: ${e.value}'),
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join('\n');

    await SharePlus.instance.share(
      ShareParams(text: text, subject: '${card.displayName} · Owanbe'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardAsync = ref.watch(attendeeProfileCardProvider(widget.userId));
    final peopleAsync = ref.watch(networkingPeopleProvider(widget.eventId));
    final offline = ref.watch(attendeeOfflineProvider);

    return AttendeeFlowScaffold(
      backLabel: 'People',
      onBack: () =>
          context.canPop() ? context.pop() : context.go(AttendeeRoutes.people(widget.eventId)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(attendeeProfileCardProvider(widget.userId));
          await refreshNetworking(ref, widget.eventId);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            if (offline)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: EosAttentionBanner(
                  headline: 'Offline',
                  message: 'Showing cached profile where available.',
                  severity: 'WARNING',
                ),
              ),
            cardAsync.when(
              loading: () => const NetworkingListSkeleton(count: 2),
              error: (e, _) => EosAttentionBanner(
                headline: 'Profile unavailable',
                message: '$e',
                severity: 'CRITICAL',
              ),
              data: (card) {
                final person = peopleAsync.valueOrNull == null
                    ? null
                    : _matchFromDirectory(peopleAsync.valueOrNull!);
                final status = person?.connectionStatus ?? NetworkingConnectionStatus.none;
                final connectionId = person?.connectionId;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ProfileNetworkAvatar(
                          name: card.displayName,
                          avatarUrl: card.avatarUrl,
                          radius: 40,
                        ),
                        SizedBox(width: context.eos.spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(card.displayName, style: context.eosText.headlineSmall),
                              if (card.occupation != null || card.company != null)
                                Text(
                                  [card.occupation, card.company]
                                      .whereType<String>()
                                      .where((s) => s.trim().isNotEmpty)
                                      .join(' · '),
                                  style: context.eosText.bodyMedium,
                                ),
                              SizedBox(height: context.eos.spacing.xs),
                              Text(
                                connectionStatusLabel(status),
                                style: context.eosText.labelMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.eos.spacing.md),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: Icon(
                            card.privacyShowToAttendees
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 16,
                          ),
                          label: Text(
                            card.privacyShowToAttendees
                                ? 'Visible to attendees'
                                : 'Limited visibility',
                          ),
                        ),
                        if (!card.visible)
                          Chip(
                            label: Text(card.visibilityReason ?? 'Private profile'),
                          ),
                      ],
                    ),
                    if (card.visible) ...[
                      if (card.bio != null && card.bio!.trim().isNotEmpty) ...[
                        SizedBox(height: context.eos.spacing.lg),
                        Text('Bio', style: context.eosText.titleSmall),
                        SizedBox(height: context.eos.spacing.xs),
                        Text(card.bio!, style: context.eosText.bodyMedium),
                      ],
                      if (card.interests.isNotEmpty) ...[
                        SizedBox(height: context.eos.spacing.lg),
                        Text('Interests', style: context.eosText.titleSmall),
                        SizedBox(height: context.eos.spacing.sm),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: card.interests.map((i) => Chip(label: Text(i))).toList(),
                        ),
                      ],
                      if (person?.mutualInterests.isNotEmpty == true) ...[
                        SizedBox(height: context.eos.spacing.md),
                        Text('Mutual tags', style: context.eosText.titleSmall),
                        SizedBox(height: context.eos.spacing.sm),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: person!.mutualInterests
                              .map((i) => Chip(label: Text(i), avatar: const Icon(Icons.handshake, size: 14)))
                              .toList(),
                        ),
                      ],
                      if (card.socialLinks.isNotEmpty) ...[
                        SizedBox(height: context.eos.spacing.lg),
                        Text('Social links', style: context.eosText.titleSmall),
                        SizedBox(height: context.eos.spacing.sm),
                        for (final e in card.socialLinks.entries)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(e.key),
                            subtitle: Text(e.value),
                            trailing: const Icon(Icons.open_in_new, size: 18),
                            onTap: () async {
                              final uri = Uri.tryParse(e.value.startsWith('http') ? e.value : 'https://${e.value}');
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                      ],
                    ] else
                      Padding(
                        padding: EdgeInsets.only(top: context.eos.spacing.lg),
                        child: EosSurfaceCard(
                          child: Text(
                            card.visibilityReason ?? 'This profile is not shared with attendees.',
                            style: context.eosText.bodyMedium,
                          ),
                        ),
                      ),
                    SizedBox(height: context.eos.spacing.xl),
                    if (!card.isSelf) ...[
                      if (status == NetworkingConnectionStatus.none ||
                          status == NetworkingConnectionStatus.declined)
                        FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  await networkingRequest(widget.eventId, widget.userId);
                                  if (mounted) setState(() => _busy = false);
                                },
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Connect'),
                        ),
                      if (status == NetworkingConnectionStatus.pendingIncoming && connectionId != null)
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => networkingAccept(widget.eventId, connectionId),
                                child: const Text('Accept'),
                              ),
                            ),
                            SizedBox(width: context.eos.spacing.sm),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => networkingDecline(widget.eventId, connectionId),
                                child: const Text('Decline'),
                              ),
                            ),
                          ],
                        ),
                      if (status == NetworkingConnectionStatus.pendingOutgoing)
                        OutlinedButton(
                          onPressed: connectionId == null
                              ? null
                              : () => networkingRemove(widget.eventId, connectionId),
                          child: const Text('Cancel request'),
                        ),
                      if (status == NetworkingConnectionStatus.connected)
                        OutlinedButton.icon(
                          onPressed: connectionId == null
                              ? null
                              : () => networkingRemove(widget.eventId, connectionId),
                          icon: const Icon(Icons.link_off),
                          label: const Text('Remove connection'),
                        ),
                      SizedBox(height: context.eos.spacing.sm),
                      OutlinedButton.icon(
                        onPressed: () => _shareProfile(card),
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Share profile'),
                      ),
                      SizedBox(height: context.eos.spacing.sm),
                      OutlinedButton.icon(
                        onPressed: _shareMyCardWithPeer,
                        icon: const Icon(Icons.badge_outlined),
                        label: const Text('Share my card'),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
