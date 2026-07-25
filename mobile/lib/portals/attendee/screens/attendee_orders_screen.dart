import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/ticket_commerce_api.dart';
import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../features/public/providers/ticket_commerce_providers.dart';
import '../navigation/attendee_routes.dart';
import '../widgets/attendee_flow_scaffold.dart';

final attendeeOrdersProvider = FutureProvider.autoDispose<List<TicketOrderSummary>>((ref) async {
  final session = ref.watch(authSessionProvider);
  if (session == null) return const [];
  return ref.read(ticketCommerceApiProvider).fetchMyOrders(session);
});

class AttendeeOrdersScreen extends ConsumerWidget {
  const AttendeeOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(attendeeOrdersProvider);

    return AttendeeFlowScaffold(
      backLabel: 'Back',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.dashboard),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(attendeeOrdersProvider);
          await ref.read(attendeeOrdersProvider.future);
        },
        child: async.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: const [
              EosSurfaceCard(child: SizedBox(height: 72, child: Center(child: CircularProgressIndicator()))),
              SizedBox(height: 12),
              EosSurfaceCard(child: SizedBox(height: 72)),
            ],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              EosAttentionBanner(headline: 'Could not load orders', message: '$e', severity: 'CRITICAL'),
              TextButton(
                onPressed: () => ref.invalidate(attendeeOrdersProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(context.eos.spacing.lg),
                children: [
                  Text('Purchase history', style: context.eosText.headlineMedium),
                  SizedBox(height: context.eos.spacing.md),
                  EosSurfaceCard(
                    child: Text(
                      'No ticket orders yet. Purchases will appear here with status and refund updates.',
                      style: context.eosText.bodyMedium,
                    ),
                  ),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(context.eos.spacing.lg),
              children: [
                Text('Purchase history', style: context.eosText.headlineMedium),
                SizedBox(height: context.eos.spacing.sm),
                Text('Orders, payment status, and refunds.', style: context.eosText.bodySmall),
                SizedBox(height: context.eos.spacing.lg),
                for (final order in orders) ...[
                  EosSurfaceCard(
                    onTap: () => context.push(AttendeeRoutes.orderDetail(order.id)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.eventTitle, style: context.eosText.titleSmall),
                              SizedBox(height: context.eos.spacing.xxs),
                              Text(
                                '${order.status} · ${ngnFromMinor(order.totalMinor)}',
                                style: context.eosText.bodySmall,
                              ),
                              Text(
                                order.createdAt.toLocal().toString().split('.').first,
                                style: context.eosText.labelSmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                  SizedBox(height: context.eos.spacing.sm),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
