import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../providers/operations_providers.dart';
import '../widgets/operations_shared.dart';

class LiveEventFeedScreen extends ConsumerWidget {
  const LiveEventFeedScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(operationsFeedProvider(eventId));

    return EosPageScaffold(
      title: 'Live event feed',
      subtitle: 'Real-time operational timeline',
      floatingHeader: const Row(
        children: [
          EosLiveIndicator(compact: true, label: 'Streaming'),
        ],
      ),
      body: feed.when(
        data: (items) {
          if (items.isEmpty) {
            return EosSurfaceCard(
              child: Text('Waiting for event activity…', style: context.eosText.bodyMedium),
            );
          }
          return Column(
            children: [
              for (final item in items)
                EosFeedItem(
                  title: item.headline,
                  subtitle: item.detail,
                  timestamp: formatOpsTime(item.timestamp),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: context.eosColors.primaryContainer,
                    child: Icon(feedIcon(item.type), size: 18, color: context.eosColors.primary),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }
}
