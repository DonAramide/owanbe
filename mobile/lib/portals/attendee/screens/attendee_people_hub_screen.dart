import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/networking_api.dart';
import '../../../eos/eos.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../../../identity/identity_provider.dart';
import '../../../portals/customer/models/celebration_wall_models.dart';
import '../../../portals/customer/providers/celebration_wall_providers.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_networking_providers.dart';
import '../widgets/attendee_flow_scaffold.dart';
import '../widgets/attendee_networking_widgets.dart';

/// Event-scoped people directory + discover + connections + community wall (Phase 8).
class AttendeePeopleHubScreen extends ConsumerStatefulWidget {
  const AttendeePeopleHubScreen({super.key, required this.eventId, this.initialTab = 0});

  final String eventId;
  final int initialTab;

  @override
  ConsumerState<AttendeePeopleHubScreen> createState() => _AttendeePeopleHubScreenState();
}

class _AttendeePeopleHubScreenState extends ConsumerState<AttendeePeopleHubScreen>
    with SingleTickerProviderStateMixin, NetworkingActionsMixin<AttendeePeopleHubScreen> {
  late final TabController _tabs;
  final _search = TextEditingController();
  final _company = TextEditingController();
  final _interest = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this, initialIndex: widget.initialTab.clamp(0, 3));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    _company.dispose();
    _interest.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref.read(networkingPeopleQueryProvider(widget.eventId).notifier).state = (
      q: _search.text.trim(),
      company: _company.text.trim(),
      interest: _interest.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(attendeeOfflineProvider);

    return AttendeeFlowScaffold(
      backLabel: 'Back',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.live(widget.eventId)),
      body: Column(
        children: [
          if (offline)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: EosAttentionBanner(
                headline: 'Offline',
                message: 'Directory may be stale. Reconnect to refresh people and connections.',
                severity: 'WARNING',
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.eos.spacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('People', style: context.eosText.headlineMedium),
                      Text(
                        'Discover and connect with attendees at this event.',
                        style: context.eosText.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => context.push(AttendeeRoutes.networkingNotifications),
                  icon: const Icon(Icons.notifications_outlined),
                ),
                IconButton(
                  tooltip: 'My business card',
                  onPressed: () => context.push(AttendeeRoutes.businessCard(widget.eventId)),
                  icon: const Icon(Icons.badge_outlined),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Directory'),
              Tab(text: 'Discover'),
              Tab(text: 'Connections'),
              Tab(text: 'Community'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _DirectoryTab(
                  eventId: widget.eventId,
                  search: _search,
                  company: _company,
                  interest: _interest,
                  onApplyFilters: _applyFilters,
                  onConnect: (p) => networkingRequest(widget.eventId, p.userId),
                  onAccept: (p) {
                    final id = p.connectionId;
                    if (id != null) networkingAccept(widget.eventId, id);
                  },
                ),
                _DiscoverTab(
                  eventId: widget.eventId,
                  onConnect: (p) => networkingRequest(widget.eventId, p.userId),
                ),
                _ConnectionsTab(
                  eventId: widget.eventId,
                  onAccept: (c) => networkingAccept(widget.eventId, c.id),
                  onDecline: (c) => networkingDecline(widget.eventId, c.id),
                  onRemove: (c) => networkingRemove(widget.eventId, c.id),
                ),
                _CommunityTab(eventId: widget.eventId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectoryTab extends ConsumerWidget {
  const _DirectoryTab({
    required this.eventId,
    required this.search,
    required this.company,
    required this.interest,
    required this.onApplyFilters,
    required this.onConnect,
    required this.onAccept,
  });

  final String eventId;
  final TextEditingController search;
  final TextEditingController company;
  final TextEditingController interest;
  final VoidCallback onApplyFilters;
  final void Function(DirectoryPerson) onConnect;
  final void Function(DirectoryPerson) onAccept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(networkingPeopleProvider(eventId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(networkingPeopleProvider(eventId));
        await ref.read(networkingPeopleProvider(eventId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: [
          TextField(
            controller: search,
            decoration: const InputDecoration(
              labelText: 'Search',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onApplyFilters(),
          ),
          SizedBox(height: context.eos.spacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: company,
                  decoration: const InputDecoration(
                    labelText: 'Company',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => onApplyFilters(),
                ),
              ),
              SizedBox(width: context.eos.spacing.sm),
              Expanded(
                child: TextField(
                  controller: interest,
                  decoration: const InputDecoration(
                    labelText: 'Interest',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => onApplyFilters(),
                ),
              ),
            ],
          ),
          SizedBox(height: context.eos.spacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: onApplyFilters,
              child: const Text('Apply filters'),
            ),
          ),
          SizedBox(height: context.eos.spacing.md),
          async.when(
            loading: () => const NetworkingListSkeleton(),
            error: (e, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EosAttentionBanner(headline: 'Directory unavailable', message: '$e', severity: 'CRITICAL'),
                TextButton(
                  onPressed: () => ref.invalidate(networkingPeopleProvider(eventId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
            data: (people) {
              final others = people.where((p) => !p.isSelf).toList();
              if (others.isEmpty) {
                return EosSurfaceCard(
                  child: Text(
                    'No opted-in attendees match your filters. Profiles appear when attendees enable “Show to attendees”.',
                    style: context.eosText.bodyMedium,
                  ),
                );
              }
              return Column(
                children: [
                  for (final p in others) ...[
                    NetworkingPersonTile(
                      name: p.displayName,
                      avatarUrl: p.avatarUrl,
                      company: p.company,
                      occupation: p.occupation,
                      interests: p.interests,
                      mutual: p.mutualInterests,
                      status: p.connectionStatus,
                      onTap: () => context.push(AttendeeRoutes.peerProfile(eventId, p.userId)),
                      trailing: _quickAction(context, p, onConnect, onAccept),
                    ),
                    SizedBox(height: context.eos.spacing.sm),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget? _quickAction(
    BuildContext context,
    DirectoryPerson p,
    void Function(DirectoryPerson) onConnect,
    void Function(DirectoryPerson) onAccept,
  ) {
    switch (p.connectionStatus) {
      case NetworkingConnectionStatus.none:
      case NetworkingConnectionStatus.declined:
        return IconButton(
          tooltip: 'Connect',
          onPressed: () => onConnect(p),
          icon: const Icon(Icons.person_add_alt_1_outlined),
        );
      case NetworkingConnectionStatus.pendingIncoming:
        return IconButton(
          tooltip: 'Accept',
          onPressed: () => onAccept(p),
          icon: const Icon(Icons.check_circle_outline),
        );
      default:
        return null;
    }
  }
}

class _DiscoverTab extends ConsumerWidget {
  const _DiscoverTab({required this.eventId, required this.onConnect});

  final String eventId;
  final void Function(DirectoryPerson) onConnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(networkingSuggestionsProvider(eventId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(networkingSuggestionsProvider(eventId));
        await ref.read(networkingSuggestionsProvider(eventId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: [
          Text('Suggested people', style: context.eosText.titleLarge),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            'Based on shared interests, same company, and pending requests at this event.',
            style: context.eosText.bodySmall,
          ),
          SizedBox(height: context.eos.spacing.lg),
          async.when(
            loading: () => const NetworkingListSkeleton(count: 3),
            error: (e, _) => EosAttentionBanner(
              headline: 'Suggestions unavailable',
              message: '$e',
              severity: 'CRITICAL',
            ),
            data: (items) {
              if (items.isEmpty) {
                return EosSurfaceCard(
                  child: Text(
                    'No suggestions yet. Opt into attendee visibility and add interests on your profile.',
                    style: context.eosText.bodyMedium,
                  ),
                );
              }
              return Column(
                children: [
                  for (final p in items) ...[
                    NetworkingPersonTile(
                      name: p.displayName,
                      avatarUrl: p.avatarUrl,
                      company: p.company,
                      occupation: p.occupation,
                      interests: p.interests,
                      mutual: p.mutualInterests,
                      status: p.connectionStatus,
                      onTap: () => context.push(AttendeeRoutes.peerProfile(eventId, p.userId)),
                      trailing: p.connectionStatus == NetworkingConnectionStatus.none ||
                              p.connectionStatus == NetworkingConnectionStatus.declined
                          ? IconButton(
                              onPressed: () => onConnect(p),
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                            )
                          : null,
                    ),
                    SizedBox(height: context.eos.spacing.sm),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ConnectionsTab extends ConsumerWidget {
  const _ConnectionsTab({
    required this.eventId,
    required this.onAccept,
    required this.onDecline,
    required this.onRemove,
  });

  final String eventId;
  final void Function(NetworkingConnection) onAccept;
  final void Function(NetworkingConnection) onDecline;
  final void Function(NetworkingConnection) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(networkingConnectionsProvider(eventId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(networkingConnectionsProvider(eventId));
        await ref.read(networkingConnectionsProvider(eventId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: [
          async.when(
            loading: () => const NetworkingListSkeleton(count: 3),
            error: (e, _) => EosAttentionBanner(
              headline: 'Connections unavailable',
              message: '$e',
              severity: 'CRITICAL',
            ),
            data: (items) {
              final pending = items
                  .where((c) => c.connectionStatus == NetworkingConnectionStatus.pendingIncoming)
                  .toList();
              final outgoing = items
                  .where((c) => c.connectionStatus == NetworkingConnectionStatus.pendingOutgoing)
                  .toList();
              final connected = items
                  .where((c) => c.connectionStatus == NetworkingConnectionStatus.connected)
                  .toList();

              if (items.isEmpty) {
                return EosSurfaceCard(
                  child: Text(
                    'No connections yet. Browse the directory to send a request.',
                    style: context.eosText.bodyMedium,
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pending.isNotEmpty) ...[
                    Text('Pending requests', style: context.eosText.titleMedium),
                    SizedBox(height: context.eos.spacing.sm),
                    for (final c in pending) ...[
                      NetworkingPersonTile(
                        name: c.displayName,
                        avatarUrl: c.avatarUrl,
                        company: c.company,
                        status: c.connectionStatus,
                        onTap: () => context.push(AttendeeRoutes.peerProfile(eventId, c.otherUserId)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Accept',
                              onPressed: () => onAccept(c),
                              icon: const Icon(Icons.check),
                            ),
                            IconButton(
                              tooltip: 'Decline',
                              onPressed: () => onDecline(c),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.eos.spacing.sm),
                    ],
                    SizedBox(height: context.eos.spacing.md),
                  ],
                  if (outgoing.isNotEmpty) ...[
                    Text('Sent', style: context.eosText.titleMedium),
                    SizedBox(height: context.eos.spacing.sm),
                    for (final c in outgoing) ...[
                      NetworkingPersonTile(
                        name: c.displayName,
                        avatarUrl: c.avatarUrl,
                        company: c.company,
                        status: c.connectionStatus,
                        onTap: () => context.push(AttendeeRoutes.peerProfile(eventId, c.otherUserId)),
                        trailing: TextButton(
                          onPressed: () => onRemove(c),
                          child: const Text('Cancel'),
                        ),
                      ),
                      SizedBox(height: context.eos.spacing.sm),
                    ],
                    SizedBox(height: context.eos.spacing.md),
                  ],
                  Text('Connected', style: context.eosText.titleMedium),
                  SizedBox(height: context.eos.spacing.sm),
                  if (connected.isEmpty)
                    EosSurfaceCard(
                      child: Text('No mutual connections yet.', style: context.eosText.bodySmall),
                    )
                  else
                    for (final c in connected) ...[
                      NetworkingPersonTile(
                        name: c.displayName,
                        avatarUrl: c.avatarUrl,
                        company: c.company,
                        status: c.connectionStatus,
                        onTap: () => context.push(AttendeeRoutes.peerProfile(eventId, c.otherUserId)),
                        trailing: IconButton(
                          tooltip: 'Remove',
                          onPressed: () => onRemove(c),
                          icon: const Icon(Icons.link_off),
                        ),
                      ),
                      SizedBox(height: context.eos.spacing.sm),
                    ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CommunityTab extends ConsumerStatefulWidget {
  const _CommunityTab({required this.eventId});
  final String eventId;

  @override
  ConsumerState<_CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends ConsumerState<_CommunityTab> {
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _message.text.trim();
    if (text.length < 2) return;
    final identity = ref.read(userIdentityProvider).valueOrNull;
    final name = (identity?.displayName.trim().isNotEmpty ?? false)
        ? identity!.displayName.trim()
        : 'Attendee';
    setState(() => _busy = true);
    try {
      await ref.read(celebrationWallApiProvider).createPost(
            eventId: widget.eventId,
            guestName: name,
            message: text,
          );
      _message.clear();
      refreshCelebrationWall(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Posted to the community wall')),
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

  Future<void> _react(WallPost post, String reaction) async {
    try {
      await ref.read(celebrationWallApiProvider).react(
            eventId: widget.eventId,
            postId: post.id,
            reaction: reaction,
          );
      refreshCelebrationWall(ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wall = ref.watch(celebrationWallPublicProvider(widget.eventId));

    return RefreshIndicator(
      onRefresh: () async {
        refreshCelebrationWall(ref);
        await ref.read(celebrationWallPublicProvider(widget.eventId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(context.eos.spacing.lg),
        children: [
          Text('Community wall', style: context.eosText.titleLarge),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            'Short updates for this event. React to recent posts — not a full social feed.',
            style: context.eosText.bodySmall,
          ),
          SizedBox(height: context.eos.spacing.md),
          EosSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _message,
                  maxLength: 280,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Share a short update…',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: context.eos.spacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _busy ? null : _post,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Post'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.eos.spacing.lg),
          wall.when(
            loading: () => const NetworkingListSkeleton(count: 3),
            error: (e, _) => EosAttentionBanner(
              headline: 'Wall unavailable',
              message: '$e',
              severity: 'CRITICAL',
            ),
            data: (snap) {
              final posts = snap.items.where((p) => p.isVisible).toList();
              if (posts.isEmpty) {
                return EosSurfaceCard(
                  child: Text(
                    'No posts yet. Be the first to share something.',
                    style: context.eosText.bodyMedium,
                  ),
                );
              }
              return Column(
                children: [
                  for (final post in posts.take(40)) ...[
                    EosSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post.guestName, style: context.eosText.titleSmall),
                          SizedBox(height: context.eos.spacing.xs),
                          Text(post.message, style: context.eosText.bodyMedium),
                          SizedBox(height: context.eos.spacing.sm),
                          Wrap(
                            spacing: 4,
                            children: [
                              for (final r in wallReactionTypes)
                                TextButton(
                                  onPressed: () => _react(post, r),
                                  child: Text(
                                    '${wallReactionEmoji[r] ?? r} ${post.reactionCount(r)}',
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: context.eos.spacing.sm),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
