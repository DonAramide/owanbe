import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/networking_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../../../profile/widgets/profile_network_avatar.dart';
import '../providers/attendee_networking_providers.dart';

String connectionStatusLabel(NetworkingConnectionStatus status) {
  switch (status) {
    case NetworkingConnectionStatus.connected:
      return 'Connected';
    case NetworkingConnectionStatus.pendingOutgoing:
      return 'Request sent';
    case NetworkingConnectionStatus.pendingIncoming:
      return 'Wants to connect';
    case NetworkingConnectionStatus.declined:
      return 'Declined';
    case NetworkingConnectionStatus.none:
      return 'Not connected';
  }
}

class NetworkingPersonTile extends StatelessWidget {
  const NetworkingPersonTile({
    super.key,
    required this.name,
    required this.onTap,
    this.avatarUrl,
    this.company,
    this.occupation,
    this.interests = const [],
    this.mutual = const [],
    this.status,
    this.trailing,
  });

  final String name;
  final String? avatarUrl;
  final String? company;
  final String? occupation;
  final List<String> interests;
  final List<String> mutual;
  final NetworkingConnectionStatus? status;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (occupation != null && occupation!.trim().isNotEmpty) occupation!.trim(),
      if (company != null && company!.trim().isNotEmpty) company!.trim(),
    ].join(' · ');

    return EosSurfaceCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileNetworkAvatar(name: name, avatarUrl: avatarUrl, radius: 28),
          SizedBox(width: context.eos.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: context.eosText.titleSmall),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: context.eosText.bodySmall),
                if (status != null) ...[
                  SizedBox(height: context.eos.spacing.xs),
                  Text(
                    connectionStatusLabel(status!),
                    style: context.eosText.labelSmall?.copyWith(
                      color: status == NetworkingConnectionStatus.connected
                          ? EosColors.success
                          : context.eosColors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (mutual.isNotEmpty) ...[
                  SizedBox(height: context.eos.spacing.xs),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: mutual
                        .take(4)
                        .map(
                          (t) => Chip(
                            label: Text(t, style: context.eosText.labelSmall),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
                  ),
                ] else if (interests.isNotEmpty) ...[
                  SizedBox(height: context.eos.spacing.xs),
                  Text(
                    interests.take(3).join(' · '),
                    style: context.eosText.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class NetworkingListSkeleton extends StatelessWidget {
  const NetworkingListSkeleton({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          EosSurfaceCard(
            child: Row(
              children: [
                CircleAvatar(radius: 28, backgroundColor: context.eosColors.surfaceContainerHighest),
                SizedBox(width: context.eos.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 14, width: 140, color: context.eosColors.surfaceContainerHighest),
                      SizedBox(height: context.eos.spacing.xs),
                      Container(height: 12, width: 100, color: context.eosColors.surfaceContainerHighest),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.sm),
        ],
      ],
    );
  }
}

mixin NetworkingActionsMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Future<void> networkingRequest(String eventId, String userId) async {
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    try {
      await ref.read(networkingApiProvider).requestConnection(
            session: session,
            eventId: eventId,
            userId: userId,
          );
      await refreshNetworking(ref, eventId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection request sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> networkingAccept(String eventId, String connectionId) async {
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    try {
      await ref.read(networkingApiProvider).acceptConnection(session: session, connectionId: connectionId);
      await refreshNetworking(ref, eventId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection accepted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> networkingDecline(String eventId, String connectionId) async {
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    try {
      await ref.read(networkingApiProvider).declineConnection(session: session, connectionId: connectionId);
      await refreshNetworking(ref, eventId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> networkingRemove(String eventId, String connectionId) async {
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    try {
      await ref.read(networkingApiProvider).removeConnection(session: session, connectionId: connectionId);
      await refreshNetworking(ref, eventId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
