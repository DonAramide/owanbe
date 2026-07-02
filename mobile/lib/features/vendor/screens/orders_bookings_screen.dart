import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/persistence_providers.dart';
import '../../../core/api/vendor_bookings_api.dart';
import '../../../eos/eos.dart';
import '../models/vendor_models.dart';
import '../providers/vendor_providers.dart';
import '../widgets/vendor_shared.dart';

enum OmsViewMode { kanban, list, calendar, order360 }

class OrdersBookingsScreen extends ConsumerStatefulWidget {
  const OrdersBookingsScreen({super.key});

  @override
  ConsumerState<OrdersBookingsScreen> createState() => _OrdersBookingsScreenState();
}

class _OrdersBookingsScreenState extends ConsumerState<OrdersBookingsScreen> {
  OmsViewMode _viewMode = OmsViewMode.list;
  String? _selectedOrderId;

  // Filters
  String _activeSectionFilter = 'All';

  // State mock data for Order Management System
  final List<Map<String, dynamic>> _mockOmsOrders = [
    {
      'id': 'ord_101',
      'customerName': 'Segun Adebayo',
      'eventTitle': 'Segun & Funke Traditional Wedding',
      'packageName': 'Premium Wedding Catering Combo',
      'priceMinor': 120000000,
      'status': 'Fulfilling',
      'escrowStatus': 'Funded',
      'negotiationStatus': 'Accepted',
      'deliverableProgress': 0.8,
      'disputed': false,
      'refundRequested': false,
    },
    {
      'id': 'ord_102',
      'customerName': 'Amina Bello',
      'eventTitle': 'Amins Golden Jubilee',
      'packageName': 'Compact DJ Rig & Lights',
      'priceMinor': 45000000,
      'status': 'Negotiation',
      'escrowStatus': 'Pending Fund',
      'negotiationStatus': 'Pending Vendor Response',
      'deliverableProgress': 0.0,
      'disputed': true,
      'refundRequested': true,
    },
  ];

  final List<String> _bulkSelected = [];

  void _toggleBulkSelect(String orderId) {
    setState(() {
      if (_bulkSelected.contains(orderId)) {
        _bulkSelected.remove(orderId);
      } else {
        _bulkSelected.add(orderId);
      }
    });
  }

  void _triggerBulkAction(String action) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action "$action" triggered on ${_bulkSelected.length} items.')));
    setState(() {
      _bulkSelected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedOrderId != null) {
      final selectedData = _mockOmsOrders.firstWhere((o) => o['id'] == _selectedOrderId);
      return _Order360Workspace(
        orderId: _selectedOrderId!,
        orderData: selectedData,
        onBack: () => setState(() => _selectedOrderId = null),
      );
    }

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1333),
        cardColor: const Color(0xFF241B3F),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1333),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Order Management System (OMS)',
            style: context.eosText.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            SegmentedButton<OmsViewMode>(
              segments: const [
                ButtonSegment(value: OmsViewMode.list, icon: Icon(Icons.list, size: 18), label: Text('List')),
                ButtonSegment(value: OmsViewMode.kanban, icon: Icon(Icons.view_kanban_outlined, size: 18), label: Text('Kanban')),
                ButtonSegment(value: OmsViewMode.calendar, icon: Icon(Icons.calendar_today_outlined, size: 18), label: Text('Schedule')),
              ],
              selected: {_viewMode},
              onSelectionChanged: (s) => setState(() => _viewMode = s.first),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterChips(),
              const SizedBox(height: 16),
              _buildBulkActionsBar(),
              const SizedBox(height: 16),
              SizedBox(
                height: MediaQuery.of(context).size.height - 280,
                child: _buildBodyForView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final sections = ['All', 'Incoming', 'Quotes', 'Negotiations', 'Bookings', 'Contracts', 'Escrow', 'Disputes'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sections.map((s) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(s, style: const TextStyle(color: Colors.white)),
              selected: _activeSectionFilter == s,
              selectedColor: const Color(0xFFF59E0B),
              checkmarkColor: const Color(0xFF1A1333),
              backgroundColor: const Color(0xFF241B3F),
              onSelected: (_) => setState(() => _activeSectionFilter = s),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBulkActionsBar() {
    if (_bulkSelected.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF241B3F),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${_bulkSelected.length} orders selected', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: () => _triggerBulkAction('Bulk Accept Quotes'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: const Color(0xFF1A1333)),
                child: const Text('Accept Quotes'),
              ),
              ElevatedButton(
                onPressed: () => _triggerBulkAction('Bulk Release Escrow'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: const Color(0xFF1A1333)),
                child: const Text('Release Escrow'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBodyForView() {
    final filtered = _getFilteredOrders();

    switch (_viewMode) {
      case OmsViewMode.kanban:
        return _buildKanbanView(filtered);
      case OmsViewMode.calendar:
        return _buildCalendarView(filtered);
      case OmsViewMode.list:
      default:
        return _buildListView(filtered);
    }
  }

  List<Map<String, dynamic>> _getFilteredOrders() {
    if (_activeSectionFilter == 'All') return _mockOmsOrders;
    return _mockOmsOrders.where((o) {
      final status = o['status'].toString().toLowerCase();
      final escrow = o['escrowStatus'].toString().toLowerCase();
      final disc = o['disputed'] as bool;

      if (_activeSectionFilter == 'Incoming' && status == 'incoming') return true;
      if (_activeSectionFilter == 'Quotes' && status == 'negotiation') return true;
      if (_activeSectionFilter == 'Negotiations' && status == 'negotiation') return true;
      if (_activeSectionFilter == 'Bookings' && status == 'fulfilling') return true;
      if (_activeSectionFilter == 'Contracts' && status == 'fulfilling') return true;
      if (_activeSectionFilter == 'Escrow' && escrow == 'funded') return true;
      if (_activeSectionFilter == 'Disputes' && disc) return true;

      return false;
    }).toList();
  }

  Widget _buildListView(List<Map<String, dynamic>> orders) {
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final o = orders[index];
        final isSelected = _bulkSelected.contains(o['id']);
        return Card(
          color: const Color(0xFF241B3F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleBulkSelect(o['id'] as String),
            ),
            title: Text(o['customerName'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text('Event: ${o['eventTitle']}\nPackage: ${o['packageName']}', style: const TextStyle(color: Colors.white70)),
            trailing: Text('₦${((o['priceMinor'] as int) / 100).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
            onTap: () {
              setState(() {
                _selectedOrderId = o['id'] as String;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildKanbanView(List<Map<String, dynamic>> orders) {
    final stages = ['Negotiation', 'Fulfilling', 'Completed'];
    return Row(
      children: stages.map((stage) {
        final stageOrders = orders.where((o) => o['status'].toString().toLowerCase() == stage.toLowerCase()).toList();
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF241B3F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(stage.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: stageOrders.length,
                    itemBuilder: (context, index) {
                      final o = stageOrders[index];
                      return Card(
                        color: const Color(0xFF2F2351),
                        child: ListTile(
                          title: Text(o['customerName'] as String, style: const TextStyle(color: Colors.white)),
                          subtitle: Text('₦${((o['priceMinor'] as int) / 100).toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70)),
                          onTap: () {
                            setState(() {
                              _selectedOrderId = o['id'] as String;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarView(List<Map<String, dynamic>> orders) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF241B3F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OMS AVAILABILITY SCHEDULER', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
          const SizedBox(height: 16),
          for (final o in orders)
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Color(0xFFF59E0B)),
              title: Text('Booking for ${o['customerName']}', style: const TextStyle(color: Colors.white)),
              subtitle: Text('Event: ${o['eventTitle']}', style: const TextStyle(color: Colors.white70)),
              trailing: const Text('CONFIRMED', style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold)),
              onTap: () {
                setState(() {
                  _selectedOrderId = o['id'] as String;
                });
              },
            ),
        ],
      ),
    );
  }
}

class _Order360Workspace extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  final VoidCallback onBack;

  const _Order360Workspace({
    required this.orderId,
    required this.orderData,
    required this.onBack,
  });

  @override
  State<_Order360Workspace> createState() => _Order360WorkspaceState();
}

class _Order360WorkspaceState extends State<_Order360Workspace> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _timeline = ['Order initialized', 'Payment verified'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1333),
        cardColor: const Color(0xFF241B3F),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1333),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Order360 Workspace', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('OMS ID: ${widget.orderId}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11)),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFF59E0B),
            labelColor: const Color(0xFFF59E0B),
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(text: 'Details'),
              Tab(text: 'Timeline'),
              Tab(text: 'Contract & Escrow'),
              Tab(text: 'Deliverables'),
              Tab(text: 'Refunds & Disputes'),
              Tab(text: 'Messages'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildDetailsTab(),
            _buildTimelineTab(),
            _buildEscrowTab(),
            _buildDeliverablesTab(),
            _buildDisputesTab(),
            _buildMessagesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF241B3F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.orderData['customerName'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                const SizedBox(height: 8),
                Text('Event: ${widget.orderData['eventTitle']}', style: const TextStyle(color: Colors.white70)),
                Text('Package: ${widget.orderData['packageName']}', style: const TextStyle(color: Colors.white70)),
                Text('Total Price: ₦${((widget.orderData['priceMinor'] as int) / 100).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in _timeline)
          ListTile(
            leading: const Icon(Icons.circle, size: 10, color: Color(0xFFF59E0B)),
            title: Text(entry, style: const TextStyle(color: Colors.white70)),
          ),
      ],
    );
  }

  Widget _buildEscrowTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF241B3F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Commerce360 Escrow State', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                const SizedBox(height: 8),
                Text('Escrow status: ${widget.orderData['escrowStatus']}', style: const TextStyle(color: Colors.white70)),
                Text('Negotiation: ${widget.orderData['negotiationStatus']}', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliverablesTab() {
    final progress = widget.orderData['deliverableProgress'] as double;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF241B3F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fulfillment Checklist (${(progress * 100).toStringAsFixed(0)}%)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress, color: const Color(0xFF22C55E), backgroundColor: Colors.white10),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisputesTab() {
    final disp = widget.orderData['disputed'] as bool;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF241B3F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dispute Filed: ${disp ? "YES" : "NO"}', style: TextStyle(color: disp ? const Color(0xFFEF4444) : const Color(0xFF22C55E), fontWeight: FontWeight.bold)),
                if (disp) ...[
                  const SizedBox(height: 8),
                  const Text('Reason: Client reported van arrival delay.', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _timeline.add('Dispute resolved amicably.');
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispute marked resolved.')));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: const Color(0xFF1A1333)),
                    child: const Text('Resolve Dispute'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(
          leading: CircleAvatar(backgroundColor: Color(0xFF2F2351), child: Text('C', style: TextStyle(color: Colors.white))),
          title: Text('Customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text('Please let me know if we need to adjust the setup timeline.', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}
