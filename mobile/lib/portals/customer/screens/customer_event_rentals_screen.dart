import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../models/rentals_constants.dart';
import '../models/rentals_models.dart';
import '../providers/rentals_providers.dart';
import '../router/customer_routes.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/section_header.dart';

/// Equipment & Rentals at `/events/:eventId/rentals`.
class CustomerEventRentalsScreen extends ConsumerWidget {
  const CustomerEventRentalsScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(eventRentalsProvider(eventId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Equipment & rentals'),
        actions: [
          TextButton(
            onPressed: () => context.push(CustomerRoutes.rentalsMarketplace(eventId: eventId)),
            child: const Text('Browse rentals'),
          ),
        ],
      ),
      body: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: EdgeInsets.all(context.eos.spacing.lg),
          children: [EmptyStateCard(title: 'Could not load rentals', message: '$e')],
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () async {
            refreshRentals(ref);
            await ref.read(eventRentalsProvider(eventId).future);
          },
          child: ListView(
            padding: EdgeInsets.all(context.eos.spacing.lg),
            children: [
              const SectionHeader(
                title: 'Event equipment',
                subtitle: 'Rental bookings, delivery schedule, and returns.',
              ),
              FilledButton.icon(
                onPressed: () => context.push(CustomerRoutes.rentalsMarketplace(eventId: eventId)),
                icon: const Icon(Icons.add),
                label: const Text('Request equipment'),
              ),
              SizedBox(height: context.eos.spacing.lg),
              if (list.isEmpty)
                const EmptyStateCard(
                  title: 'No rental bookings',
                  message: 'Browse the rentals marketplace to request chairs, tents, sound, and more.',
                  icon: Icons.inventory_2_outlined,
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
              Text('Delivery ${booking.deliveryDate}${booking.deliveryAddress != null ? ' · ${booking.deliveryAddress}' : ''}'),
            if (booking.pickupDate != null) Text('Pickup ${booking.pickupDate}'),
            if (booking.damageNotes != null && booking.damageNotes!.isNotEmpty)
              Text('Damage claim: ${booking.damageNotes}', style: const TextStyle(color: EosColors.critical)),
          ],
        ),
      ),
    );
  }
}
