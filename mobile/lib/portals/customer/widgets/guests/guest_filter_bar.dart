import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../eos/eos.dart';
import '../../models/customer_guest_models.dart';
import '../../providers/customer_guest_providers.dart';

class GuestFilterBar extends ConsumerWidget {
  const GuestFilterBar({super.key});

  static const filters = [
    CustomerGuestFilter.all,
    CustomerGuestFilter.rsvpConfirmed,
    CustomerGuestFilter.rsvpPending,
    CustomerGuestFilter.checkedIn,
    CustomerGuestFilter.notCheckedIn,
    CustomerGuestFilter.vip,
    CustomerGuestFilter.vvip,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(customerGuestFilterProvider);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.xs),
        itemBuilder: (context, index) {
          final filter = filters[index];
          return FilterChip(
            label: Text(filter.label),
            selected: selected == filter,
            onSelected: (_) => ref.read(customerGuestFilterProvider.notifier).state = filter,
          );
        },
      ),
    );
  }
}
