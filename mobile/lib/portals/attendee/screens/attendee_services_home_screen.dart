import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/event_services_api.dart';
import '../../../eos/eos.dart';
import '../../../features/public/providers/attendee_events_provider.dart';
import '../../../features/public/providers/event_detail_providers.dart';
import '../navigation/attendee_routes.dart';
import '../providers/attendee_event_services_providers.dart';
import '../widgets/attendee_flow_scaffold.dart';
import '../widgets/attendee_networking_widgets.dart';

/// Global Services entry — pick an upcoming ticketed event, then open event-scoped hub.
class AttendeeServicesHomeScreen extends ConsumerWidget {
  const AttendeeServicesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(attendeeEventsProvider);
    final bookingsAsync = ref.watch(myServiceBookingsProvider(null));
    final offline = ref.watch(attendeeOfflineProvider);

    return AttendeeFlowScaffold(
      backLabel: 'Dashboard',
      onBack: () => context.canPop() ? context.pop() : context.go(AttendeeRoutes.dashboard),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(attendeeTicketsSyncProvider);
          ref.invalidate(myServiceBookingsProvider(null));
          await Future.wait([
            ref.read(attendeeEventsProvider.future),
            ref.read(myServiceBookingsProvider(null).future),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Services', style: context.eosText.headlineMedium),
                      Text(
                        'Event-scoped rentals and vendors for events you are attending.',
                        style: context.eosText.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => context.push(AttendeeRoutes.serviceNotifications),
                  icon: const Icon(Icons.notifications_outlined),
                ),
                IconButton(
                  tooltip: 'My bookings',
                  onPressed: () => context.push(AttendeeRoutes.serviceBookings()),
                  icon: const Icon(Icons.receipt_long_outlined),
                ),
              ],
            ),
            if (offline) ...[
              SizedBox(height: context.eos.spacing.sm),
              const EosAttentionBanner(
                headline: 'Offline',
                message: 'Services may be stale until you reconnect.',
                severity: 'WARNING',
              ),
            ],
            SizedBox(height: context.eos.spacing.lg),
            Text('Upcoming events', style: context.eosText.titleLarge),
            SizedBox(height: context.eos.spacing.sm),
            eventsAsync.when(
              loading: () => const NetworkingListSkeleton(count: 2),
              error: (e, _) => EosAttentionBanner(
                headline: 'Events unavailable',
                message: '$e',
                severity: 'CRITICAL',
              ),
              data: (events) {
                if (events.isEmpty) {
                  return EosSurfaceCard(
                    child: Text(
                      'Buy or accept a ticket to unlock event services.',
                      style: context.eosText.bodyMedium,
                    ),
                  );
                }
                final upcoming = [...events]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
                return Column(
                  children: [
                    for (final e in upcoming.take(8)) ...[
                      EosSurfaceCard(
                        onTap: () => context.push(AttendeeRoutes.eventServices(e.eventId)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.eventTitle, style: context.eosText.titleSmall),
                                  Text(
                                    '${e.venue}, ${e.city}',
                                    style: context.eosText.bodySmall,
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
            SizedBox(height: context.eos.spacing.xl),
            Text('My bookings', style: context.eosText.titleLarge),
            SizedBox(height: context.eos.spacing.sm),
            bookingsAsync.when(
              loading: () => const NetworkingListSkeleton(count: 2),
              error: (e, _) => Text('$e', style: context.eosText.bodySmall),
              data: (items) {
                if (items.isEmpty) {
                  return EosSurfaceCard(
                    child: Text('No service bookings yet.', style: context.eosText.bodyMedium),
                  );
                }
                return Column(
                  children: [
                    for (final b in items.take(4)) ...[
                      _BookingSummaryTile(booking: b),
                      SizedBox(height: context.eos.spacing.sm),
                    ],
                    TextButton(
                      onPressed: () => context.push(AttendeeRoutes.serviceBookings()),
                      child: const Text('View all bookings'),
                    ),
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

class _BookingSummaryTile extends StatelessWidget {
  const _BookingSummaryTile({required this.booking});
  final EventServiceBooking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking.booking;
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(b.itemName, style: context.eosText.titleSmall),
          Text('${b.vendorName} · ${b.eventTitle}', style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.xs),
          Text(
            '${serviceStatusLabel(booking.serviceStatus)} · ${booking.confirmationNumber}',
            style: context.eosText.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Event-scoped services hub: directory, rentals CTA, bookings snapshot.
class AttendeeEventServicesHubScreen extends ConsumerStatefulWidget {
  const AttendeeEventServicesHubScreen({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<AttendeeEventServicesHubScreen> createState() =>
      _AttendeeEventServicesHubScreenState();
}

class _AttendeeEventServicesHubScreenState extends ConsumerState<AttendeeEventServicesHubScreen> {
  final _search = TextEditingController();
  String _category = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref.read(eventServicesVendorQueryProvider(widget.eventId).notifier).state = (
      q: _search.text.trim(),
      category: _category,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hubAsync = ref.watch(eventServicesHubProvider(widget.eventId));
    final vendorsAsync = ref.watch(eventServiceVendorsProvider(widget.eventId));
    final offline = ref.watch(attendeeOfflineProvider);

    return AttendeeFlowScaffold(
      backLabel: 'Services',
      onBack: () =>
          context.canPop() ? context.pop() : context.go(AttendeeRoutes.services),
      body: RefreshIndicator(
        onRefresh: () => refreshEventServices(ref, widget.eventId),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [
            if (offline)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: EosAttentionBanner(
                  headline: 'Offline',
                  message: 'Showing last loaded services for this event.',
                  severity: 'WARNING',
                ),
              ),
            hubAsync.when(
              loading: () => const NetworkingListSkeleton(count: 2),
              error: (e, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EosAttentionBanner(headline: 'Services unavailable', message: '$e', severity: 'CRITICAL'),
                  TextButton(
                    onPressed: () => ref.invalidate(eventServicesHubProvider(widget.eventId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
              data: (hub) {
                if (hub == null) {
                  return EosSurfaceCard(
                    child: Text('Sign in to view event services.', style: context.eosText.bodyMedium),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(hub.eventTitle, style: context.eosText.headlineMedium),
                    Text('Event services', style: context.eosText.bodySmall),
                    SizedBox(height: context.eos.spacing.lg),
                    Text('Available services', style: context.eosText.titleMedium),
                    SizedBox(height: context.eos.spacing.sm),
                    for (final s in hub.availableServices) ...[
                      EosSurfaceCard(
                        onTap: s.id == 'rentals'
                            ? () => context.push(AttendeeRoutes.eventRentals(widget.eventId))
                            : null,
                        child: Row(
                          children: [
                            const Icon(Icons.handyman_outlined),
                            SizedBox(width: context.eos.spacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.label, style: context.eosText.titleSmall),
                                  Text(
                                    '${s.description} · ${s.itemCount} items',
                                    style: context.eosText.bodySmall,
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
                    SizedBox(height: context.eos.spacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.push(AttendeeRoutes.serviceBookings(widget.eventId)),
                            icon: const Icon(Icons.receipt_long_outlined, size: 18),
                            label: Text('My bookings (${hub.bookingCount})'),
                          ),
                        ),
                      ],
                    ),
                    if (hub.categories.isNotEmpty) ...[
                      SizedBox(height: context.eos.spacing.lg),
                      Text('Service categories', style: context.eosText.titleMedium),
                      SizedBox(height: context.eos.spacing.sm),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          FilterChip(
                            label: const Text('All'),
                            selected: _category.isEmpty,
                            onSelected: (_) {
                              setState(() => _category = '');
                              _applyFilters();
                            },
                          ),
                          for (final c in hub.categories)
                            FilterChip(
                              label: Text(c),
                              selected: _category == c,
                              onSelected: (_) {
                                setState(() => _category = c);
                                _applyFilters();
                              },
                            ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
            SizedBox(height: context.eos.spacing.xl),
            Text('Vendors at this event', style: context.eosText.titleLarge),
            SizedBox(height: context.eos.spacing.sm),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Search vendors',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _applyFilters(),
            ),
            SizedBox(height: context.eos.spacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(onPressed: _applyFilters, child: const Text('Search')),
            ),
            SizedBox(height: context.eos.spacing.md),
            vendorsAsync.when(
              loading: () => const NetworkingListSkeleton(count: 3),
              error: (e, _) => EosAttentionBanner(
                headline: 'Directory unavailable',
                message: '$e',
                severity: 'CRITICAL',
              ),
              data: (vendors) {
                if (vendors.isEmpty) {
                  return EosSurfaceCard(
                    child: Text(
                      'No vendors are attached to this event yet. Organizers add vendors via the event pipeline.',
                      style: context.eosText.bodyMedium,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final v in vendors) ...[
                      _VendorTile(
                        vendor: v,
                        onBook: v.hasRentals
                            ? () => context.push(AttendeeRoutes.eventRentals(widget.eventId))
                            : null,
                        onDetails: () => _showVendorDetails(context, v),
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

  void _showVendorDetails(BuildContext context, EventServiceVendor v) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(context.eos.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(v.businessName, style: context.eosText.titleLarge),
            if (v.category != null) Text(v.category!, style: context.eosText.bodySmall),
            SizedBox(height: context.eos.spacing.sm),
            Text(v.description?.trim().isNotEmpty == true ? v.description! : 'No description.'),
            SizedBox(height: context.eos.spacing.sm),
            Text('Availability: ${v.availability}', style: context.eosText.labelMedium),
            if (v.hasRentals) ...[
              SizedBox(height: context.eos.spacing.md),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push(AttendeeRoutes.eventRentals(widget.eventId));
                },
                child: Text('Browse ${v.rentalItemCount} rentals'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VendorTile extends StatelessWidget {
  const _VendorTile({required this.vendor, this.onBook, this.onDetails});
  final EventServiceVendor vendor;
  final VoidCallback? onBook;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      onTap: onDetails,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: vendor.logoUrl != null && vendor.logoUrl!.isNotEmpty
                ? NetworkImage(vendor.logoUrl!)
                : null,
            child: vendor.logoUrl == null || vendor.logoUrl!.isEmpty
                ? Text(vendor.businessName.isNotEmpty ? vendor.businessName[0] : '?')
                : null,
          ),
          SizedBox(width: context.eos.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vendor.businessName, style: context.eosText.titleSmall),
                if (vendor.category != null)
                  Text(vendor.category!, style: context.eosText.bodySmall),
                if (vendor.description != null && vendor.description!.trim().isNotEmpty)
                  Text(
                    vendor.description!,
                    style: context.eosText.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  'Availability: ${vendor.availability}',
                  style: context.eosText.labelSmall,
                ),
              ],
            ),
          ),
          if (onBook != null)
            FilledButton(
              onPressed: onBook,
              child: const Text('Book'),
            ),
        ],
      ),
    );
  }
}
