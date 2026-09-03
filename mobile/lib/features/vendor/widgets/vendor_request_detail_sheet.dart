import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../portals/customer/models/vendor_change_request_models.dart';
import '../../../portals/customer/models/vendor_crm_models.dart';
import '../../../portals/customer/providers/vendor_crm_providers.dart';
import '../../../portals/customer/widgets/vendor_crm/vendor_change_requests_panel.dart';
import '../../../portals/customer/widgets/vendor_crm/vendor_stage_badge.dart';
import '../providers/vendor_inbox_integration.dart';

/// Vendor-side request detail with Accept / Decline (no negotiation).
Future<void> showVendorRequestDetailSheet(
  BuildContext context,
  WidgetRef ref,
  VendorRequest request,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF241B3F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _VendorRequestDetailSheet(request: request),
  );
}

class _VendorRequestDetailSheet extends ConsumerStatefulWidget {
  const _VendorRequestDetailSheet({required this.request});

  final VendorRequest request;

  @override
  ConsumerState<_VendorRequestDetailSheet> createState() => _VendorRequestDetailSheetState();
}

class _VendorRequestDetailSheetState extends ConsumerState<_VendorRequestDetailSheet> {
  var _busy = false;

  VendorRequest get request => widget.request;

  bool get canAct => request.isAwaitingVendor;

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payout = request.vendorPayoutMinor;
    final payoutLabel = request.isAwaitingVendor ? 'Your payout' : 'Agreed payout';
    final stageLabel = vendorCrmVendorStageLabels[request.stage] ?? request.stage;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Request detail',
                style: context.eosText.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _section('EVENT DETAILS'),
              _row('Event name', request.eventTitle ?? 'Event'),
              if (request.eventType != null && request.eventType!.isNotEmpty)
                _row('Event type', request.eventType!),
              if (request.eventStartsAt != null) _row('Event date', _fmtDate(request.eventStartsAt!)),
              if (request.eventStartsAt != null || request.eventEndsAt != null)
                _row(
                  'Start / end',
                  [
                    if (request.eventStartsAt != null) _fmtTime(request.eventStartsAt!),
                    if (request.eventEndsAt != null) _fmtTime(request.eventEndsAt!),
                  ].join(' – '),
                ),
              if (request.eventLocation != null && request.eventLocation!.isNotEmpty)
                _row('Location', request.eventLocation!),
              if (request.venueAddress != null && request.venueAddress!.isNotEmpty)
                _row('Address', request.venueAddress!),
              if (request.expectedAttendees != null)
                _row('Expected attendees', '${request.expectedAttendees}'),
              const SizedBox(height: 12),
              _section('SERVICE REQUEST'),
              _row('Organizer', request.organizerName ?? 'Organizer'),
              _row('Vendor', request.vendorName ?? 'Vendor'),
              _row('Service', request.serviceLabel ?? 'Service'),
              if (request.serviceCode != null && request.serviceCode!.isNotEmpty)
                _row('Service Code', request.serviceCode!),
              if (request.serviceKey != null && request.serviceKey!.isNotEmpty)
                _row('Service key', request.serviceKey!),
              if ((request.unreadCount) > 0)
                _row('Unread messages', '${request.unreadCount}'),
              if (request.fundingStatus == 'funded' || request.fundingStatus == 'released') ...[
                const SizedBox(height: 12),
                _section('PAYMENT'),
                if (payout != null && payout > 0) _row('Agreed Vendor Payout', formatRevenue(payout)),
                _row(
                  'Payment Status',
                  request.fundingStatus == 'released'
                      ? 'Released to wallet'
                      : 'SECURED — booking funded',
                ),
                if (request.fundingStatus == 'funded')
                  _row('Release Condition', 'Service completion confirmed'),
              ],
              if (request.requiredServices != null && request.requiredServices!.isNotEmpty)
                _row('Event services needed', request.requiredServices!.join(', ')),
              if (request.selectedCapabilities.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('REQUESTED CAPABILITIES', style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 4),
                for (final cap in request.selectedCapabilities)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('✓ ${cap.label}', style: const TextStyle(color: Colors.white)),
                  ),
              ],
              if (request.message.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Message', style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 4),
                Text(request.message, style: const TextStyle(color: Colors.white)),
              ],
              if (request.eventDescription != null && request.eventDescription!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Event notes', style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 4),
                Text(request.eventDescription!, style: const TextStyle(color: Colors.white70)),
              ],
              const SizedBox(height: 12),
              _section('PRICING'),
              if (payout != null && payout > 0) _row(payoutLabel, formatRevenue(payout)),
              const SizedBox(height: 12),
              _section('STATUS'),
              Row(
                children: [
                  Text('Status', style: const TextStyle(color: Colors.white54)),
                  const Spacer(),
                  VendorStageBadge(stage: request.stage, forVendor: true),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                stageLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.right,
              ),
              _row('Created', _fmt(request.createdAt)),
              if (vendorRequestAllowsChangeRequests(request.stage)) ...[
                const SizedBox(height: 16),
                _section('CHANGE REQUESTS'),
                const SizedBox(height: 4),
                Text(
                  'Organizer proposals to adjust this booking. Accepting applies the change; declining leaves the booking as-is.',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                VendorChangeRequestsPanel(
                  request: request,
                  role: ChangeRequestPanelRole.vendor,
                  onLight: false,
                  dense: true,
                ),
              ],
              const SizedBox(height: 20),
              if (canAct) ...[
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                            () => vendorAcceptRequest(ref, request),
                            'Request accepted',
                          ),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Accept'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                            () => vendorDeclineRequest(ref, request),
                            'Request declined',
                          ),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: const Text('Decline'),
                ),
              ] else if (request.canMessage) ...[
                Text(
                  'Request accepted — use Message on the dashboard for this service thread.',
                  style: const TextStyle(color: Colors.white54),
                ),
                if (['accepted', 'scheduled', 'arrived'].contains(request.stage) &&
                    request.fundingStatus == 'funded') ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              () async {
                                await ref.read(vendorCrmApiProvider).markComplete(request.id);
                                refreshVendorCrm(ref);
                              },
                              'Service marked complete — awaiting organizer confirmation',
                            ),
                    child: const Text('Mark Service Complete'),
                  ),
                ],
              ] else
                Text(
                  'No actions available for $stageLabel requests.',
                  style: const TextStyle(color: Colors.white54),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: EosColors.champagne,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.white54)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _fmtDate(DateTime dt) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final local = dt.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  String _fmtTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
