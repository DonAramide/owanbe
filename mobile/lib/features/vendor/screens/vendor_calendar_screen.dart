import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../core/api/vendors_api.dart';
import '../../../core/providers/silent_refresh.dart';
import '../../../portals/customer/models/vendor_crm_models.dart';
import '../../../portals/customer/providers/vendor_crm_providers.dart';
import '../providers/vendor_providers.dart';
import '../widgets/vendor_request_detail_sheet.dart';

/// Vendor MY SCHEDULE — view over CRM bookings + calendar-block overlay.
class VendorCalendarScreen extends ConsumerWidget {
  const VendorCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorIdAsync = ref.watch(canonicalVendorIdProvider);

    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        backgroundColor: EosColors.plumDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/vendor');
              }
            },
          ),
          title: Text(
            'My Schedule',
            style: context.eosText.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: vendorIdAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white70))),
          data: (vendorId) => _ScheduleBody(vendorId: vendorId),
        ),
      ),
    );
  }
}

class _ScheduleBody extends ConsumerWidget {
  const _ScheduleBody({required this.vendorId});

  final String vendorId;

  Future<void> _refresh(WidgetRef ref) async {
    refreshVendorCrm(ref);
    ref.invalidate(vendorCalendarProvider(vendorId));
    ref.invalidate(vendorInboxProvider(vendorId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cal = ref.watch(vendorCalendarProvider(vendorId));
    final inbox = ref.watch(vendorInboxProvider(vendorId));

    return cal.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Calendar unavailable', style: context.eosText.titleMedium?.copyWith(color: Colors.white)),
          Text('$e', style: const TextStyle(color: Colors.white70)),
          TextButton(
            onPressed: () => _refresh(ref),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (snap) => RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'MY SCHEDULE',
              style: context.eosText.labelMedium?.copyWith(color: EosColors.champagne),
            ),
            const SizedBox(height: 8),
            const Text(
              'Confirmed bookings come from accepted requests and event dates. '
              'Pending requests do not block availability.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _openBlockDates(context, ref),
                icon: const Icon(Icons.event_busy_outlined, size: 18),
                label: const Text('BLOCK DATES'),
                style: FilledButton.styleFrom(backgroundColor: EosColors.champagne, foregroundColor: EosColors.plumDark),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.white.withValues(alpha: 0.04),
              child: SwitchListTile(
                title: const Text('Vacation mode', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text(
                  snap.vacationUntil == null
                      ? 'Pause new booking windows when enabled'
                      : 'Until ${snap.vacationUntil}',
                  style: const TextStyle(color: Colors.white70),
                ),
                value: snap.vacationMode,
                onChanged: (val) async {
                  try {
                    await ref.read(vendorCrmApiProvider).patchVacation(vendorId, vacationMode: val);
                    await _refresh(ref);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
            inbox.whenStable(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (_, _) => const Text('Inbox unavailable', style: TextStyle(color: Colors.white54)),
              data: (s) => _BookingsAndPending(items: s.items, onOpen: (r) => showVendorRequestDetailSheet(context, ref, r)),
            ),
            const SizedBox(height: 24),
            Text(
              'UNAVAILABLE PERIODS',
              style: context.eosText.labelMedium?.copyWith(color: EosColors.champagne),
            ),
            const SizedBox(height: 8),
            if (snap.blocks.where(_isUnavailableOverlay).isEmpty)
              const Text('No personal blackout or vacation blocks.', style: TextStyle(color: Colors.white70))
            else
              for (final b in snap.blocks.where(_isUnavailableOverlay))
                Card(
                  color: Colors.white.withValues(alpha: 0.04),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.block, color: Colors.redAccent),
                          title: Text(
                            b.kind == 'vacation' ? 'UNAVAILABLE · Vacation' : 'UNAVAILABLE · Blocked',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              formatDateTimeWindow(b.startsAt, b.endsAt),
                              if (b.reason != null && b.reason!.trim().isNotEmpty) b.reason!,
                            ].join('\n'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        if (b.isManualBlackout)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                            child: Row(
                              children: [
                                TextButton(
                                  onPressed: () => _openBlockDates(context, ref, existing: b),
                                  child: const Text('Edit'),
                                ),
                                TextButton(
                                  onPressed: () => _confirmUnblock(context, ref, b),
                                  child: const Text('Unblock'),
                                ),
                              ],
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

  bool _isUnavailableOverlay(VendorCalendarBlock b) =>
      b.kind == 'blackout' || b.kind == 'vacation';

  Future<void> _openBlockDates(BuildContext context, WidgetRef ref, {VendorCalendarBlock? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF241B3F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _BlockDatesSheet(vendorId: vendorId, existing: existing),
    );
    if (saved == true) {
      await _refresh(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing == null
                  ? 'Dates blocked. You are unavailable for that period.'
                  : 'Blocked dates updated.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmUnblock(BuildContext context, WidgetRef ref, VendorCalendarBlock block) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unblock this date?'),
        content: Text(
          [
            formatLongDate(block.startsAt),
            if (block.reason != null && block.reason!.trim().isNotEmpty) block.reason!,
          ].join('\n'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unblock')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(vendorCrmApiProvider).deleteBlock(vendorId, block.id);
      await _refresh(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date unblocked.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _BookingsAndPending extends StatelessWidget {
  const _BookingsAndPending({required this.items, required this.onOpen});

  final List<VendorRequest> items;
  final ValueChanged<VendorRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    final booked = items.where((r) => r.isConfirmedBooking).toList()
      ..sort((a, b) => a.scheduleStartsAt.compareTo(b.scheduleStartsAt));
    final pending = items.where((r) => r.isAwaitingVendor).toList()
      ..sort((a, b) => a.scheduleStartsAt.compareTo(b.scheduleStartsAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (booked.isEmpty)
          const Text('No confirmed bookings yet.', style: TextStyle(color: Colors.white70))
        else
          ..._groupedSchedule(context, booked, confirmed: true),
        const SizedBox(height: 24),
        Text(
          'PENDING — NOT CONFIRMED',
          style: context.eosText.labelMedium?.copyWith(color: EosColors.champagne),
        ),
        const SizedBox(height: 8),
        const Text(
          'These requests do not block availability until you accept.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (pending.isEmpty)
          const Text('No pending requests.', style: TextStyle(color: Colors.white70))
        else
          for (final r in pending) _RequestTile(request: r, confirmed: false, onTap: () => onOpen(r)),
      ],
    );
  }

  List<Widget> _groupedSchedule(BuildContext context, List<VendorRequest> booked, {required bool confirmed}) {
    final widgets = <Widget>[];
    String? lastMonth;
    DateTime? lastDay;
    for (final r in booked) {
      final start = r.scheduleStartsAt;
      final month = formatMonthHeading(start);
      if (month != lastMonth) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(month, style: context.eosText.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        ));
        lastMonth = month;
      }
      final dayKey = DateTime(start.year, start.month, start.day);
      if (lastDay == null || lastDay != dayKey) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            formatDayHeading(start),
            style: const TextStyle(color: EosColors.champagne, fontWeight: FontWeight.w700, letterSpacing: 0.4),
          ),
        ));
        widgets.add(const Divider(color: Colors.white24, height: 12));
        lastDay = dayKey;
      }
      widgets.add(_RequestTile(request: r, confirmed: confirmed, onTap: () => onOpen(r)));
    }
    return widgets;
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request, required this.confirmed, required this.onTap});

  final VendorRequest request;
  final bool confirmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = request.scheduleStartsAt;
    final end = request.scheduleEndsAt;
    return Card(
      color: Colors.white.withValues(alpha: 0.04),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          confirmed ? Icons.event_available : Icons.hourglass_empty,
          color: confirmed ? EosColors.champagne : Colors.white70,
        ),
        title: Text(request.eventTitle ?? 'Event', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            request.serviceLabel ?? 'Service',
            formatDateTimeWindow(start, end),
            confirmed ? 'BOOKED — CONFIRMED' : 'PENDING — NOT CONFIRMED',
            if (request.organizerName != null && request.organizerName!.trim().isNotEmpty)
              'Organizer: ${request.organizerName}',
          ].join('\n'),
          style: const TextStyle(color: Colors.white70),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      ),
    );
  }
}

class _BlockDatesSheet extends ConsumerStatefulWidget {
  const _BlockDatesSheet({required this.vendorId, this.existing});

  final String vendorId;
  final VendorCalendarBlock? existing;

  @override
  ConsumerState<_BlockDatesSheet> createState() => _BlockDatesSheetState();
}

class _BlockDatesSheetState extends ConsumerState<_BlockDatesSheet> {
  static const _reasons = [
    'Personal commitment',
    'Vacation',
    'Unavailable',
  ];

  late String _reason;
  late DateTime _from;
  late DateTime _to;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _from = DateTime(existing.startsAt.year, existing.startsAt.month, existing.startsAt.day);
      _to = DateTime(existing.endsAt.year, existing.endsAt.month, existing.endsAt.day);
      final reason = existing.reason?.trim();
      _reason = (reason != null && reason.isNotEmpty) ? reason : _reasons.first;
    } else {
      _reason = _reasons.first;
      _from = DateTime.now();
      _to = DateTime.now();
    }
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      _from = _dateOnly(picked);
      if (_to.isBefore(_from)) _to = _from;
    });
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to.isBefore(_from) ? _from : _to,
      firstDate: _from,
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() => _to = _dateOnly(picked));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final startsAt = _from;
      final endsAt = DateTime(_to.year, _to.month, _to.day, 23, 59, 59);
      if (widget.existing != null) {
        await ref.read(vendorCrmApiProvider).updateBlock(
              widget.vendorId,
              widget.existing!.id,
              startsAt: startsAt,
              endsAt: endsAt,
              reason: _reason,
            );
      } else {
        await ref.read(vendorCrmApiProvider).addBlackout(widget.vendorId, startsAt, endsAt, _reason);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'BLOCK DATES' : 'EDIT BLOCK',
            style: context.eosText.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Marks you unavailable for new requests in this window. Confirmed bookings stay on the event/request record.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Reason',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _reason,
                isExpanded: true,
                dropdownColor: const Color(0xFF241B3F),
                items: [
                  for (final r in {
                    ..._reasons,
                    if (!_reasons.contains(_reason)) _reason,
                  })
                    DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(color: Colors.white))),
                ],
                onChanged: _saving ? null : (v) => setState(() => _reason = v ?? _reason),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('From', style: TextStyle(color: Colors.white70)),
            subtitle: Text(formatLongDate(_from), style: const TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.calendar_today, color: Colors.white70),
            onTap: _saving ? null : _pickFrom,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('To', style: TextStyle(color: Colors.white70)),
            subtitle: Text(formatLongDate(_to), style: const TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.calendar_today, color: Colors.white70),
            onTap: _saving ? null : _pickTo,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context, false),
                  child: const Text('CANCEL'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving ? 'Saving…' : (widget.existing == null ? 'BLOCK DATES' : 'SAVE'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
