import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../eos/eos.dart';
import '../../../portals/customer/models/vendor_crm_models.dart';
import '../../../portals/customer/widgets/vendor_crm/vendor_stage_badge.dart';
import '../widgets/vendor_request_detail_sheet.dart';
import 'vendor_empty_state.dart';

/// Live incoming vendor requests with stage + service filters.
class VendorIncomingRequestsPanel extends ConsumerStatefulWidget {
  const VendorIncomingRequestsPanel({super.key, required this.snapshot});

  final VendorCrmSnapshot snapshot;

  @override
  ConsumerState<VendorIncomingRequestsPanel> createState() =>
      _VendorIncomingRequestsPanelState();
}

class _VendorIncomingRequestsPanelState extends ConsumerState<VendorIncomingRequestsPanel> {
  String _stageFilter = 'all';
  String _serviceFilter = 'all';

  static const _stageOptions = <(String, String)>[
    ('all', 'All'),
    ('pending', 'Pending'),
    ('accepted', 'Accepted'),
    ('completed', 'Completed'),
    ('declined', 'Declined'),
  ];

  List<VendorRequest> get _filtered {
    var items = [...widget.snapshot.items];
    switch (_stageFilter) {
      case 'pending':
        items = items.where((r) => r.stage == 'new' || r.stage == 'negotiating').toList();
      case 'accepted':
        items = items
            .where((r) => ['accepted', 'scheduled', 'arrived'].contains(r.stage))
            .toList();
      case 'completed':
        items = items.where((r) => r.stage == 'completed').toList();
      case 'declined':
        items = items.where((r) => r.stage == 'declined' || r.stage == 'cancelled').toList();
      default:
        break;
    }
    if (_serviceFilter != 'all') {
      items = items.where((r) {
        final label = (r.serviceLabel ?? '').toLowerCase().trim();
        return label == _serviceFilter.toLowerCase() ||
            (r.serviceKey ?? '').toLowerCase() ==
                _serviceFilter.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      }).toList();
    }
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  List<String> get _serviceLabels {
    final labels = <String>{};
    for (final r in widget.snapshot.items) {
      final s = r.serviceLabel?.trim();
      if (s != null && s.isNotEmpty) labels.add(s);
    }
    return labels.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.snapshot.stats.newCount + widget.snapshot.stats.negotiating;
    final active = widget.snapshot.stats.accepted +
        widget.snapshot.stats.scheduled +
        widget.snapshot.stats.arrived;
    final completed = widget.snapshot.stats.completed;
    final items = _filtered;
    final services = _serviceLabels;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INCOMING REQUESTS',
            style: context.eosText.titleMedium?.copyWith(
              color: EosColors.champagne,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _kpi('Pending', pending),
              _kpi('Active', active),
              _kpi('Completed', completed),
              _kpi('Total', widget.snapshot.stats.total),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (id, label) in _stageOptions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _stageFilter == id,
                      onSelected: (_) => setState(() => _stageFilter = id),
                    ),
                  ),
              ],
            ),
          ),
          if (services.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All services'),
                      selected: _serviceFilter == 'all',
                      onSelected: (_) => setState(() => _serviceFilter = 'all'),
                    ),
                  ),
                  for (final s in services)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: _serviceFilter == s,
                        onSelected: (_) => setState(() => _serviceFilter = s),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (items.isEmpty)
            const VendorEmptyState(
              message: 'No requests in this filter.',
              icon: Icons.inbox_outlined,
              compact: true,
            )
          else
            for (final r in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RequestCard(
                  request: r,
                  onView: () => showVendorRequestDetailSheet(context, ref, r),
                ),
              ),
        ],
      ),
    );
  }

  Widget _kpi(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onView});

  final VendorRequest request;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final price = request.vendorPayoutMinor;
    final payoutLabel = request.isAwaitingVendor ? 'Your payout' : 'Agreed payout';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.eventTitle ?? 'Event',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              VendorStageBadge(stage: request.stage, forVendor: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Organizer: ${request.displayBuyerName}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          if (['accepted', 'scheduled', 'arrived'].contains(request.stage))
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Change requests · open detail to review Accept / Decline',
                style: TextStyle(color: EosColors.champagne, fontSize: 11),
              ),
            ),
          Text(
            'Service: ${request.serviceLabel ?? 'Service'}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (request.eventStartsAt != null)
            Text(
              'Date: ${_fmtDate(request.eventStartsAt!)}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          if (request.eventLocation != null && request.eventLocation!.isNotEmpty)
            Text(
              'Location: ${request.eventLocation}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          if (request.expectedAttendees != null)
            Text(
              'Expected attendees: ${request.expectedAttendees}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          if (price != null && price > 0)
            Text(
              '$payoutLabel: ${formatRevenue(price)}',
              style: const TextStyle(color: EosColors.champagne, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          if (request.selectedCapabilities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Requested: ${request.selectedCapabilities.map((c) => c.label).join(', ')}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          if (request.message.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Message: ${request.message}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onView,
              child: const Text('View Request'),
            ),
          ),
        ],
      ),
    );
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
}

