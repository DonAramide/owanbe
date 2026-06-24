import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../models/celebration_wall_models.dart';
import '../providers/celebration_wall_providers.dart';
import '../providers/customer_event_command_providers.dart';
import '../router/customer_routes.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/section_header.dart';

/// Phase 2B — Celebration wall at `/events/:eventId/wall`.
class CustomerEventWallScreen extends ConsumerStatefulWidget {
  const CustomerEventWallScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<CustomerEventWallScreen> createState() => _CustomerEventWallScreenState();
}

class _CustomerEventWallScreenState extends ConsumerState<CustomerEventWallScreen> {
  final _guestNameCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _photoUrlCtrl = TextEditingController();
  bool _busy = false;
  Timer? _liveTimer;

  @override
  void dispose() {
    _liveTimer?.cancel();
    _guestNameCtrl.dispose();
    _messageCtrl.dispose();
    _photoUrlCtrl.dispose();
    super.dispose();
  }

  void _scheduleLiveRefresh(bool liveMode) {
    _liveTimer?.cancel();
    if (!liveMode) return;
    _liveTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) refreshCelebrationWall(ref);
    });
  }

  Future<void> _submitPost() async {
    final name = _guestNameCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (name.length < 2 || message.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your name and a message')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(celebrationWallApiProvider).createPost(
            eventId: widget.eventId,
            guestName: name,
            message: message,
            photoUrl: _photoUrlCtrl.text.trim(),
          );
      _messageCtrl.clear();
      _photoUrlCtrl.clear();
      refreshCelebrationWall(ref);
      refreshEventCommandCenter(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message posted to the wall')),
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

  Future<void> _moderate(WallPost post, String action) async {
    try {
      await ref.read(celebrationWallApiProvider).moderate(
            eventId: widget.eventId,
            postId: post.id,
            action: action,
          );
      refreshCelebrationWall(ref);
      refreshEventCommandCenter(ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _toggleLiveMode(bool value) async {
    try {
      await ref.read(celebrationWallApiProvider).patchSettings(
            eventId: widget.eventId,
            liveMode: value,
          );
      refreshCelebrationWall(ref);
      _scheduleLiveRefresh(value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownership = ref.watch(customerEventOwnershipProvider(widget.eventId));
    final isOwner = ownership.valueOrNull == true;
    final wall = isOwner
        ? ref.watch(celebrationWallManageProvider(widget.eventId))
        : ref.watch(celebrationWallPublicProvider(widget.eventId));

    wall.whenData((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleLiveRefresh(data.settings.liveMode);
      });
    });

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(CustomerRoutes.eventDetail(widget.eventId));
            }
          },
        ),
        title: const Text('Celebration wall'),
        actions: [
          IconButton(
            tooltip: 'Large-screen display',
            icon: const Icon(Icons.tv_outlined),
            onPressed: () => context.push(CustomerRoutes.eventWallDisplay(widget.eventId)),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: wall.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            EmptyStateCard(
              title: 'Could not load wall',
              message: error.toString(),
              actionLabel: 'Back to event',
              onAction: () => context.go(CustomerRoutes.eventDetail(widget.eventId)),
            ),
          ],
        ),
        data: (data) {
          final visiblePosts = isOwner
              ? data.items
              : data.items.where((p) => p.isVisible).toList();

          return RefreshIndicator(
            onRefresh: () async {
              refreshCelebrationWall(ref);
              await (isOwner
                      ? ref.read(celebrationWallManageProvider(widget.eventId).future)
                      : ref.read(celebrationWallPublicProvider(widget.eventId).future));
            },
            child: ListView(
              padding: EdgeInsets.all(context.eos.spacing.lg),
              children: [
                if (isOwner) ...[
                  EosSurfaceCard(
                    child: Row(
                      children: [
                        const Icon(Icons.bolt_outlined, color: EosColors.plum),
                        SizedBox(width: context.eos.spacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Live mode', style: context.eosText.titleSmall),
                              Text(
                                data.settings.liveMode
                                    ? 'Wall auto-refreshes for guests'
                                    : 'Manual refresh only',
                                style: context.eosText.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: data.settings.liveMode,
                          onChanged: _toggleLiveMode,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.eos.spacing.lg),
                ],
                const SectionHeader(
                  title: 'Leave a message',
                  subtitle: 'Share congratulations, photos, and well wishes.',
                ),
                EosSurfaceCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _guestNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: context.eos.spacing.sm),
                      TextField(
                        controller: _messageCtrl,
                        maxLines: 3,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: context.eos.spacing.sm),
                      TextField(
                        controller: _photoUrlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Photo URL (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: context.eos.spacing.md),
                      FilledButton.icon(
                        onPressed: _busy ? null : _submitPost,
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Post to wall'),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.eos.spacing.lg),
                SectionHeader(
                  title: 'Wall',
                  subtitle: data.settings.liveMode ? 'Live · updates every few seconds' : 'Messages from guests',
                ),
                if (visiblePosts.isEmpty)
                  const EmptyStateCard(
                    title: 'No messages yet',
                    message: 'Be the first to congratulate the hosts.',
                    icon: Icons.forum_outlined,
                  )
                else
                  ...visiblePosts.map(
                    (post) => Padding(
                      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                      child: _WallPostCard(
                        post: post,
                        isOwner: isOwner,
                        onReact: (r) => _react(post, r),
                        onModerate: (a) => _moderate(post, a),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WallPostCard extends StatelessWidget {
  const _WallPostCard({
    required this.post,
    required this.isOwner,
    required this.onReact,
    required this.onModerate,
  });

  final WallPost post;
  final bool isOwner;
  final ValueChanged<String> onReact;
  final ValueChanged<String> onModerate;

  @override
  Widget build(BuildContext context) {
    final time = _formatWallTime(post.createdAt);

    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (post.pinned)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.push_pin, size: 16, color: EosColors.plum),
                ),
              Expanded(
                child: Text(
                  post.guestName,
                  style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(time, style: context.eosText.labelSmall),
              if (isOwner)
                PopupMenuButton<String>(
                  onSelected: onModerate,
                  itemBuilder: (context) => [
                    if (post.isHidden)
                      const PopupMenuItem(value: 'show', child: Text('Show post'))
                    else
                      const PopupMenuItem(value: 'hide', child: Text('Hide post')),
                    PopupMenuItem(
                      value: post.pinned ? 'unpin' : 'pin',
                      child: Text(post.pinned ? 'Unpin post' : 'Pin post'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete post')),
                  ],
                ),
            ],
          ),
          if (post.isHidden && isOwner)
            Padding(
              padding: EdgeInsets.only(top: context.eos.spacing.xxs),
              child: Text('Hidden from guests', style: context.eosText.labelSmall?.copyWith(color: Colors.orange)),
            ),
          SizedBox(height: context.eos.spacing.xs),
          Text(post.message, style: context.eosText.bodyMedium),
          if (post.photoUrl != null && post.photoUrl!.isNotEmpty) ...[
            SizedBox(height: context.eos.spacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                post.photoUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          SizedBox(height: context.eos.spacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final type in wallReactionTypes)
                _ReactionChip(
                  emoji: wallReactionEmoji[type]!,
                  count: post.reactionCount(type),
                  onTap: post.isVisible ? () => onReact(type) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.emoji, required this.count, this.onTap});

  final String emoji;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      label: Text('$emoji ${count > 0 ? count : ''}'.trim()),
    );
  }
}

String _formatWallTime(DateTime dt) {
  final h = dt.hour;
  final m = dt.minute.toString().padLeft(2, '0');
  final period = h >= 12 ? 'PM' : 'AM';
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  return '$hour12:$m $period';
}
