import 'package:flutter/material.dart';



import '../../../../core/utils/money.dart';

import '../../../../eos/eos.dart';

import '../../../../shared/models/event_access_mode.dart';

import '../summary_metric_card.dart';



class CommandSummaryGrid extends StatelessWidget {

  const CommandSummaryGrid({

    super.key,

    required this.eventAccessMode,

    required this.guestInvited,

    required this.guestRsvp,

    required this.guestCheckedIn,

    required this.ticketsSold,

    required this.revenueMinor,

    required this.totalCapacity,

    required this.vendorRequested,

    required this.vendorAccepted,

    required this.vendorCompleted,

    required this.budgetMinor,

    required this.committedMinor,

    required this.remainingMinor,

    this.onGuestsTap,

    this.onTicketsTap,

    this.onVendorsTap,

    this.onBudgetTap,

  });



  final EventAccessMode eventAccessMode;

  final int guestInvited;

  final int guestRsvp;

  final int guestCheckedIn;

  final int ticketsSold;

  final int revenueMinor;

  final int totalCapacity;

  final int vendorRequested;

  final int vendorAccepted;

  final int vendorCompleted;

  final int budgetMinor;

  final int committedMinor;

  final int remainingMinor;

  final VoidCallback? onGuestsTap;

  final VoidCallback? onTicketsTap;

  final VoidCallback? onVendorsTap;

  final VoidCallback? onBudgetTap;



  @override

  Widget build(BuildContext context) {

    return LayoutBuilder(

      builder: (context, constraints) {

        final wide = constraints.maxWidth >= 720;

        final cardWidth = wide ? (constraints.maxWidth - 2 * context.eos.spacing.md) / 3 : constraints.maxWidth;

        final conversion = totalCapacity == 0 ? 0.0 : ticketsSold / totalCapacity;



        final cards = <Widget>[

          if (eventAccessMode.showsGuestMetrics)

            SizedBox(

              width: cardWidth,

              child: SummaryMetricCard(

                label: 'Guests',

                value: '$guestInvited invited',

                subtitle: '$guestRsvp RSVP · $guestCheckedIn checked in',

                icon: Icons.groups_outlined,

                accentColor: EosColors.plum,

                onTap: onGuestsTap,

              ),

            )

          else

            SizedBox(

              width: cardWidth,

              child: SummaryMetricCard(

                label: 'Tickets',

                value: '$ticketsSold sold',

                subtitle: '${formatRevenue(revenueMinor)} revenue · ${(conversion * 100).round()}% conversion',

                icon: Icons.confirmation_number_outlined,

                accentColor: EosColors.plum,

                onTap: onTicketsTap,

              ),

            ),

          SizedBox(

            width: cardWidth,

            child: SummaryMetricCard(

              label: 'Vendors',

              value: '$vendorAccepted accepted',

              subtitle: '$vendorRequested requested · $vendorCompleted completed',

              icon: Icons.storefront_outlined,

              accentColor: EosColors.champagne,

              onTap: onVendorsTap,

            ),

          ),

          SizedBox(

            width: cardWidth,

            child: SummaryMetricCard(

              label: 'Budget',

              value: formatRevenue(budgetMinor),

              subtitle: '${formatRevenue(committedMinor)} committed · ${formatRevenue(remainingMinor)} left',

              icon: Icons.account_balance_wallet_outlined,

              accentColor: EosColors.success,

              onTap: onBudgetTap,

            ),

          ),

        ];



        return Wrap(

          spacing: context.eos.spacing.md,

          runSpacing: context.eos.spacing.md,

          children: cards,

        );

      },

    );

  }

}

