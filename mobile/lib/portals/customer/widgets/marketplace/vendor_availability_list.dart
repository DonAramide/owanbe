import 'package:flutter/material.dart';

import '../../../../core/api/vendor_availability_display.dart';
import '../../../../core/api/vendors_api.dart';
import '../../../../eos/eos.dart';

/// Public occupancy list for one vendor service. Dates and times only.
class VendorAvailabilityList extends StatelessWidget {
  const VendorAvailabilityList({
    super.key,
    required this.serviceName,
    required this.from,
    required this.to,
    required this.bookedRanges,
    this.unavailableRanges = const [],
    this.availabilityStatus,
    this.serviceCode,
    this.vendorName,
  });

  final String serviceName;
  final String? serviceCode;
  final String? vendorName;
  final DateTime from;
  final DateTime to;
  final List<BookedRange> bookedRanges;
  final List<BookedRange> unavailableRanges;
  final String? availabilityStatus;

  @override
  Widget build(BuildContext context) {
    final rows = compactAvailabilityDayRows(
      availabilityDayRows(
        from: from,
        to: to,
        bookedRanges: bookedRanges,
        unavailableRanges: unavailableRanges,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${serviceName.toUpperCase()} AVAILABILITY',
          style: context.eosText.labelSmall,
        ),
        if (vendorName != null && vendorName!.trim().isNotEmpty) ...[
          SizedBox(height: context.eos.spacing.xxs),
          Text(vendorName!, style: context.eosText.titleSmall),
        ],
        if (serviceCode != null && serviceCode!.trim().isNotEmpty)
          Text('Service Code: $serviceCode', style: context.eosText.bodySmall),
        SizedBox(height: context.eos.spacing.sm),
        Text(
          '🟢 Available   🔴 Booked   ⚠️ Vendor unavailable',
          style: context.eosText.bodySmall,
        ),
        SizedBox(height: context.eos.spacing.sm),
        if (rows.isEmpty)
          Text(
            'Currently available on all dates in this range.',
            style: context.eosText.bodyMedium,
          )
        else ...[
          ..._monthSections(context, rows),
          SizedBox(height: context.eos.spacing.sm),
          Text(
            'All other dates in this range are available.',
            style: context.eosText.bodySmall,
          ),
        ],
      ],
    );
  }

  List<Widget> _monthSections(BuildContext context, List<AvailabilityDayRow> rows) {
    final widgets = <Widget>[];
    String? lastHeading;
    for (final row in rows) {
      final heading = formatAvailabilityMonthHeading(row.day);
      if (heading != lastHeading) {
        lastHeading = heading;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: context.eos.spacing.sm, bottom: context.eos.spacing.xs),
            child: Text(heading, style: context.eosText.titleSmall),
          ),
        );
      }
      widgets.add(_DayRow(row: row));
    }
    return widgets;
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.row});

  final AvailabilityDayRow row;

  @override
  Widget build(BuildContext context) {
    final kind = row.kind;
    final color = switch (kind) {
      AvailabilityDayKind.booked => Colors.red,
      AvailabilityDayKind.vendorUnavailable => Colors.orange,
      AvailabilityDayKind.available => Colors.green,
    };
    final label = switch (kind) {
      AvailabilityDayKind.booked => 'BOOKED',
      AvailabilityDayKind.vendorUnavailable => 'VENDOR UNAVAILABLE',
      AvailabilityDayKind.available => 'AVAILABLE',
    };
    return Padding(
      padding: EdgeInsets.only(bottom: context.eos.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(
              kind == AvailabilityDayKind.vendorUnavailable ? Icons.warning_amber_rounded : Icons.circle,
              size: 12,
              color: color,
            ),
          ),
          SizedBox(width: context.eos.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatAvailabilityDayLabel(row.day), style: context.eosText.bodyMedium),
                Text(label, style: context.eosText.labelSmall),
                if (kind == AvailabilityDayKind.booked)
                  for (final window in row.windows)
                    Text(
                      formatTimeRange12(window.startsAt, window.endsAt),
                      style: context.eosText.bodySmall,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NextBookedSummary extends StatelessWidget {
  const NextBookedSummary({
    super.key,
    required this.bookedRanges,
  });

  final List<BookedRange> bookedRanges;

  @override
  Widget build(BuildContext context) {
    final next = nextBookedWindows(bookedRanges);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Next booked:', style: context.eosText.labelSmall),
        if (next.isEmpty)
          Text('Currently available', style: context.eosText.bodySmall)
        else
          for (final range in next)
            Text(
              '● ${formatAvailabilityDayLabel(range.startsAt)} · ${formatTimeRange12(range.startsAt, range.endsAt)}',
              style: context.eosText.bodySmall,
            ),
      ],
    );
  }
}

Future<void> showVendorAvailabilitySheet(
  BuildContext context, {
  required String serviceName,
  required DateTime from,
  required DateTime to,
  required List<BookedRange> bookedRanges,
  List<BookedRange> unavailableRanges = const [],
  String? availabilityStatus,
  String? serviceCode,
  String? vendorName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: context.eos.spacing.lg,
          right: context.eos.spacing.lg,
          top: context.eos.spacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + context.eos.spacing.lg,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: SingleChildScrollView(
            child: VendorAvailabilityList(
              serviceName: serviceName,
              serviceCode: serviceCode,
              vendorName: vendorName,
              from: from,
              to: to,
              bookedRanges: bookedRanges,
              unavailableRanges: unavailableRanges,
              availabilityStatus: availabilityStatus,
            ),
          ),
        ),
      );
    },
  );
}
