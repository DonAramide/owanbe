import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_notifier.dart';
import '../../../core/api/event_services_api.dart';
import '../../../core/api/persistence_providers.dart';
import '../../../eos/eos.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../../../identity/identity_provider.dart';
import '../../../portals/customer/models/rentals_models.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_event_services_providers.dart';
import '../widgets/attendee_flow_scaffold.dart';
import '../widgets/attendee_networking_widgets.dart';

/// Event-scoped rentals browse + book (Phase 9 reference vertical).
class AttendeeEventRentalsScreen extends ConsumerStatefulWidget {
  const AttendeeEventRentalsScreen({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<AttendeeEventRentalsScreen> createState() => _AttendeeEventRentalsScreenState();
}

class _AttendeeEventRentalsScreenState extends ConsumerState<AttendeeEventRentalsScreen> {
  bool _busy = false;

  Future<void> _book(RentalCatalogItem item) async {
    final qtyCtrl = TextEditingController(text: '1');
    final addressCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Book ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(labelText: 'Delivery notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Request')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final session = ref.read(authSessionProvider);
    if (session == null) return;
    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
    if (qty < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a quantity')));
      return;
    }

    final identity = ref.read(userIdentityProvider).valueOrNull;
    setState(() => _busy = true);
    try {
      final booking = await ref.read(eventServicesApiProvider).bookRental(
            session: session,
            eventId: widget.eventId,
            catalogItemId: item.id,
            quantityRequested: qty,
            requesterName: identity?.displayName,
            deliveryAddress: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
          );
      await refreshEventServices(ref, widget.eventId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Request sent · ${booking.confirmationNumber} · ${serviceStatusLabel(booking.serviceStatus)}',
            ),
          ),
        );
        context.push(AttendeeRoutes.serviceBookings(widget.eventId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _money(int minor) {
    if (minor <= 0) return 'Quote on request';
    return '₦${(minor / 100).toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(eventServiceRentalsProvider(widget.eventId));
    final offline = ref.watch(attendeeOfflineProvider);

    return AttendeeFlowScaffold(
      backLabel: 'Services',
      onBack: () => context.canPop()
          ? context.pop()
          : context.go(AttendeeRoutes.eventServices(widget.eventId)),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(eventServiceRentalsProvider(widget.eventId));
              await ref.read(eventServiceRentalsProvider(widget.eventId).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(context.eos.spacing.lg),
              children: [
                Text('Equipment rentals', style: context.eosText.headlineMedium),
                Text(
                  'Items from vendors attached to this event.',
                  style: context.eosText.bodySmall,
                ),
                if (offline) ...[
                  SizedBox(height: context.eos.spacing.sm),
                  const EosAttentionBanner(
                    headline: 'Offline',
                    message: 'Booking requires a connection.',
                    severity: 'WARNING',
                  ),
                ],
                SizedBox(height: context.eos.spacing.lg),
                async.when(
                  loading: () => const NetworkingListSkeleton(count: 4),
                  error: (e, _) => EosAttentionBanner(
                    headline: 'Rentals unavailable',
                    message: '$e',
                    severity: 'CRITICAL',
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return EosSurfaceCard(
                        child: Text(
                          'No rental items from event vendors yet.',
                          style: context.eosText.bodyMedium,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final item in items) ...[
                          EosSurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: context.eosText.titleSmall),
                                Text(item.vendorName, style: context.eosText.bodySmall),
                                if (item.description.trim().isNotEmpty)
                                  Text(item.description, style: context.eosText.bodySmall),
                                SizedBox(height: context.eos.spacing.xs),
                                Text(
                                  '${item.categorySlug} · ${item.availableQuantity} available · ${_money(item.rentalFeeMinor)}',
                                  style: context.eosText.labelSmall,
                                ),
                                SizedBox(height: context.eos.spacing.sm),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton(
                                    onPressed: offline || _busy || item.availableQuantity < 1
                                        ? null
                                        : () => _book(item),
                                    child: const Text('Book'),
                                  ),
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
          ),
          if (_busy)
            const ModalBarrier(dismissible: false, color: Color(0x33000000)),
          if (_busy) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

/// My service bookings with status buckets.
class AttendeeServiceBookingsScreen extends ConsumerWidget {
  const AttendeeServiceBookingsScreen({super.key, this.eventId});
  final String? eventId;

  List<EventServiceBooking> _filter(List<EventServiceBooking> all, String bucket) {
    switch (bucket) {
      case 'upcoming':
        return all
            .where((b) =>
                b.serviceStatus == AttendeeServiceStatus.pending ||
                b.serviceStatus == AttendeeServiceStatus.confirmed)
            .toList();
      case 'active':
        return all
            .where((b) =>
                b.serviceStatus == AttendeeServiceStatus.inProgress ||
                b.serviceStatus == AttendeeServiceStatus.ready)
            .toList();
      case 'completed':
        return all.where((b) => b.serviceStatus == AttendeeServiceStatus.completed).toList();
      case 'cancelled':
        return all
            .where((b) =>
                b.serviceStatus == AttendeeServiceStatus.cancelled ||
                b.serviceStatus == AttendeeServiceStatus.expired)
            .toList();
      default:
        return all;
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, EventServiceBooking booking) async {
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Text('Cancel ${booking.booking.itemName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel booking')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(eventServicesApiProvider).cancelBooking(
            session: session,
            bookingId: booking.booking.id,
          );
      ref.invalidate(myServiceBookingsProvider(eventId));
      ref.invalidate(myServiceBookingsProvider(null));
      ref.invalidate(serviceNotificationsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myServiceBookingsProvider(eventId));
    final offline = ref.watch(attendeeOfflineProvider);

    return DefaultTabController(
      length: 4,
      child: AttendeeFlowScaffold(
        backLabel: 'Back',
        onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.services),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.eos.spacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('My service bookings', style: context.eosText.headlineMedium),
              ),
            ),
            if (offline)
              const Padding(
                padding: EdgeInsets.all(16),
                child: EosAttentionBanner(
                  headline: 'Offline',
                  message: 'Bookings refresh when you reconnect.',
                  severity: 'WARNING',
                ),
              ),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Upcoming'),
                Tab(text: 'Active'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  padding: EdgeInsets.all(context.eos.spacing.lg),
                  children: [
                    EosAttentionBanner(headline: 'Bookings unavailable', message: '$e', severity: 'CRITICAL'),
                    TextButton(
                      onPressed: () => ref.invalidate(myServiceBookingsProvider(eventId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
                data: (all) => TabBarView(
                  children: [
                    for (final bucket in ['upcoming', 'active', 'completed', 'cancelled'])
                      RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(myServiceBookingsProvider(eventId));
                          await ref.read(myServiceBookingsProvider(eventId).future);
                        },
                        child: Builder(
                          builder: (context) {
                            final items = _filter(all, bucket);
                            if (items.isEmpty) {
                              return ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.all(context.eos.spacing.lg),
                                children: [
                                  EosSurfaceCard(
                                    child: Text('No $bucket bookings.', style: context.eosText.bodyMedium),
                                  ),
                                ],
                              );
                            }
                            return ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.all(context.eos.spacing.lg),
                              itemCount: items.length,
                              itemBuilder: (context, i) {
                                final b = items[i];
                                final booking = b.booking;
                                final canCancel = booking.status == 'pending' || booking.status == 'countered';
                                return Padding(
                                  padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
                                  child: EosSurfaceCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(booking.itemName, style: context.eosText.titleSmall),
                                        Text(
                                          '${booking.vendorName} · ${booking.eventTitle}',
                                          style: context.eosText.bodySmall,
                                        ),
                                        SizedBox(height: context.eos.spacing.xs),
                                        Text(
                                          'Status: ${serviceStatusLabel(b.serviceStatus)}',
                                          style: context.eosText.labelMedium,
                                        ),
                                        Text(
                                          'Confirmation: ${b.confirmationNumber}',
                                          style: context.eosText.labelSmall,
                                        ),
                                        Text(
                                          'Requested: ${booking.createdAt.toLocal()}',
                                          style: context.eosText.bodySmall,
                                        ),
                                        if (canCancel) ...[
                                          SizedBox(height: context.eos.spacing.sm),
                                          OutlinedButton(
                                            onPressed: offline ? null : () => _cancel(context, ref, b),
                                            child: const Text('Cancel booking'),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendeeServiceNotificationsScreen extends ConsumerWidget {
  const AttendeeServiceNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serviceNotificationsProvider);

    return AttendeeFlowScaffold(
      backLabel: 'Services',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.services),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(serviceNotificationsProvider);
          await ref.read(serviceNotificationsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            Text('Service notifications', style: context.eosText.headlineMedium),
            SizedBox(height: context.eos.spacing.lg),
            async.when(
              loading: () => const NetworkingListSkeleton(count: 3),
              error: (e, _) => EosAttentionBanner(
                headline: 'Notifications unavailable',
                message: '$e',
                severity: 'CRITICAL',
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EosSurfaceCard(
                    child: Text('No service notifications yet.', style: context.eosText.bodyMedium),
                  );
                }
                return Column(
                  children: [
                    for (final n in items) ...[
                      EosSurfaceCard(
                        onTap: () {
                          final eventId = n.data['eventId']?.toString();
                          if (eventId != null && eventId.isNotEmpty) {
                            context.push(AttendeeRoutes.serviceBookings(eventId));
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title ?? n.kind, style: context.eosText.titleSmall),
                            if (n.body != null) Text(n.body!, style: context.eosText.bodySmall),
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
      ),
    );
  }
}
