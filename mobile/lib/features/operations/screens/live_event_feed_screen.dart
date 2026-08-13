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
    final feed = ref.watch(operationsLiveFeedProvider(eventId));

    return EosPageScaffold(
      title: 'Live event feed',
      subtitle: 'SSE stream · check-ins, duplicates, invalid attempts',
      floatingHeader: const Row(
        children: [
          EosLiveIndicator(compact: true, label: 'Streaming'),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => bumpOperationsRevision(ref),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: feed.when(
        data: (items) {
          if (items.isEmpty) {
            return EosSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Waiting for event activity…', style: context.eosText.titleSmall),
                  SizedBox(height: context.eos.spacing.xs),
                  Text(
                    'Check-ins, invitation arrivals, duplicate/invalid attempts, and incidents appear here in near real time.',
                    style: context.eosText.bodySmall,
                  ),
                ],
              ),
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
        loading: () => Column(
          children: [
            for (var i = 0; i < 4; i++)
              Padding(
                padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                child: EosSurfaceCard(
                  child: SizedBox(height: 48, child: Center(child: LinearProgressIndicator(minHeight: 2))),
                ),
              ),
          ],
        ),
        error: (e, _) => EosAttentionBanner(
          headline: 'Feed unavailable',
          message: '$e',
          severity: 'WARNING',
          actionLabel: 'Retry',
          onAction: () => bumpOperationsRevision(ref),
        ),
      ),
    );
  }
}
