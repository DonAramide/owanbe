import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../models/rentals_constants.dart';
import '../models/rentals_models.dart';
import '../navigation/event_navigator.dart';
import '../providers/rentals_providers.dart';
import '../workspace/event_empty_states.dart';
import '../workspace/event_module_scaffold.dart';
import '../workspace/widgets/event_error_view.dart';
import '../workspace/widgets/event_loading_skeleton.dart';

/// Equipment & Rentals at `/events/:eventId/rentals`.
class CustomerEventRentalsScreen extends ConsumerWidget {
  const CustomerEventRentalsScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(eventRentalsProvider(eventId));

    return EventModuleScaffold(
      eventId: eventId,
      title: 'Rentals',
      subtitle: 'Equipment and event hire',
      actions: [
        TextButton(
          onPressed: () => context.eventNav.openRentalsMarketplace(eventId: eventId),
          child: const Text('Browse rentals'),
        ),
      ],
      body: bookings.when(
        loading: () => const EventLoadingSkeleton(),
        error: (_, _) => ListView(
          padding: EosSpacing.pagePadding,
          children: [
            EventErrorView.module(
              moduleLabel: 'rentals',
              onRetry: () {
                refreshRentals(ref);
                ref.invalidate(eventRentalsProvider(eventId));
              },
              onBackToOverview: () => context.eventNav.backToOverview(eventId),
            ),
          ],
        ),
        data: (list) => EventModuleScrollBody(
          onRefresh: () async {
            refreshRentals(ref);
            await ref.read(eventRentalsProvider(eventId).future);
          },
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () => context.eventNav.openRentalsMarketplace(eventId: eventId),
                icon: const Icon(Icons.add),
                label: const Text('Request equipment'),
              ),
              SizedBox(height: context.eos.spacing.lg),
              if (list.isEmpty)
                EventEmptyStates.rentals(
                  onBrowse: () => context.eventNav.openRentalsMarketplace(eventId: eventId),
                )
              else
                ...list.map((b) => _BookingCard(booking: b)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final RentalBooking booking;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (booking.status) {
      'pending' => 'Pending vendor approval',
      'approved' => 'Approved',
      'countered' => 'Vendor counter: ${booking.counterQuantity} units',
      'declined' => 'Declined',
      'delivered' => 'Delivered',
      'returned' => 'Returned',
      _ => booking.status,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: EosSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(booking.itemName, style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            Text('${rentalCategoryLabel(booking.categorySlug)} · ${booking.vendorName}'),
            Text('Qty ${booking.quantityApproved ?? booking.quantityRequested} · $statusLabel'),
            Text('Rental ${formatRevenue(booking.rentalFeeMinor)} · Deposit ${formatRevenue(booking.depositMinor)}'),
            if (booking.deliveryDate != null)
              Text(
                'Delivery ${booking.deliveryDate}${booking.deliveryAddress != null ? ' · ${booking.deliveryAddress}' : ''}',
              ),
            if (booking.pickupDate != null) Text('Pickup ${booking.pickupDate}'),
            if (booking.damageNotes != null && booking.damageNotes!.isNotEmpty)
              Text('Damage claim: ${booking.damageNotes}', style: const TextStyle(color: EosColors.critical)),
          ],
        ),
      ),
    );
  }
}
