import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../models/celebration_wall_models.dart';
import '../providers/celebration_wall_providers.dart';

/// Large-screen celebration wall display at `/events/:eventId/wall/display`.
class CustomerEventWallDisplayScreen extends ConsumerStatefulWidget {
  const CustomerEventWallDisplayScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<CustomerEventWallDisplayScreen> createState() => _CustomerEventWallDisplayScreenState();
}

class _CustomerEventWallDisplayScreenState extends ConsumerState<CustomerEventWallDisplayScreen> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleRefresh(bool liveMode) {
    _timer?.cancel();
    if (!liveMode) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) refreshCelebrationWall(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final wall = ref.watch(celebrationWallPublicProvider(widget.eventId));

    wall.whenData((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleRefresh(data.settings.liveMode);
      });
    });

    return Scaffold(
      backgroundColor: const Color(0xFF1A0F1E),
      body: SafeArea(
        child: wall.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
          error: (e, _) => Center(
            child: Text('Could not load wall', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
          ),
          data: (data) {
            final posts = data.items.where((p) => p.isVisible).take(12).toList();
            final pinned = posts.where((p) => p.pinned).toList();
            final rest = posts.where((p) => !p.pinned).toList();
            final ordered = [...pinned, ...rest];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.celebration, color: EosColors.champagne, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Celebration Wall',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              data.settings.liveMode ? 'Live' : 'Wall display',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ordered.isEmpty
                      ? Center(
                          child: Text(
                            'Messages will appear here',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 20),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final crossCount = constraints.maxWidth > 1200
                                ? 3
                                : constraints.maxWidth > 800
                                    ? 2
                                    : 1;
                            return GridView.builder(
                              padding: const EdgeInsets.all(24),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossCount,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                                childAspectRatio: crossCount == 1 ? 2.2 : 1.35,
                              ),
                              itemCount: ordered.length,
                              itemBuilder: (context, index) => _DisplayCard(post: ordered[index]),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DisplayCard extends StatelessWidget {
  const _DisplayCard({required this.post});

  final WallPost post;

  @override
  Widget build(BuildContext context) {
    final time = _formatWallTime(post.createdAt);
    final topReactions = wallReactionTypes
        .where((t) => post.reactionCount(t) > 0)
        .map((t) => '${wallReactionEmoji[t]} ${post.reactionCount(t)}')
        .join('  ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: post.pinned ? Border.all(color: EosColors.champagne, width: 2) : null,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (post.pinned) const Icon(Icons.push_pin, color: EosColors.champagne, size: 18),
              if (post.pinned) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  post.guestName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(time, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Text(
              post.message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 18,
                height: 1.35,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (post.photoUrl != null && post.photoUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                post.photoUrl!,
                height: 80,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (topReactions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(topReactions, style: const TextStyle(fontSize: 20)),
          ],
        ],
      ),
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
