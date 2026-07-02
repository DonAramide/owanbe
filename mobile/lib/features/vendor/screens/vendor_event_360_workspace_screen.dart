import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../models/vendor_models.dart';
import '../providers/vendor_providers.dart';

class VendorEvent360WorkspaceScreen extends ConsumerStatefulWidget {
  const VendorEvent360WorkspaceScreen({
    super.key,
    required this.eventId,
    required this.onBack,
  });

  final String eventId;
  final VoidCallback onBack;

  @override
  ConsumerState<VendorEvent360WorkspaceScreen> createState() => _VendorEvent360WorkspaceScreenState();
}

class _VendorEvent360WorkspaceScreenState extends ConsumerState<VendorEvent360WorkspaceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Interactive Operations State
  bool _checkedIn = false;
  bool _setupStarted = false;
  double _setupProgress = 0.25;
  final List<String> _completedDeliverables = [];
  final List<String> _damPhotos = ['Oriental_Setup_Morning.jpg'];
  final List<String> _damDocuments = ['Service_Contract_Oriental.pdf'];
  final List<String> _timelineEvents = [
    '08:30 AM - Event workspace initialized.',
    '09:00 AM - Kitchen preparation started at HQ.',
  ];
  final List<String> _incidentLog = [];
  final List<Map<String, String>> _messages = [
    {'sender': 'Organizer', 'text': 'Hi, are you on track for the 10 AM arrival?'},
    {'sender': 'Vendor', 'text': 'Yes, team is currently loading the transport van.'},
  ];

  final _messageController = TextEditingController();
  final _incidentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 15, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _incidentController.dispose();
    super.dispose();
  }

  void _addTimelineEvent(String message) {
    setState(() {
      _timelineEvents.insert(0, '${TimeOfDay.now().format(context)} - $message');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        backgroundColor: EosColors.plumDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: widget.onBack,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Event Operations Center', style: context.eosText.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('Event ID: ${widget.eventId}', style: const TextStyle(color: EosColors.champagne, fontSize: 11)),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: EosColors.champagne,
            labelColor: EosColors.champagne,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(text: 'Operations'),
              Tab(text: 'Overview'),
              Tab(text: 'Timeline'),
              Tab(text: 'Conversation'),
              Tab(text: 'Negotiation'),
              Tab(text: 'Contract'),
              Tab(text: 'Escrow'),
              Tab(text: 'Deliverables'),
              Tab(text: 'Inventory'),
              Tab(text: 'Crew'),
              Tab(text: 'Checklists'),
              Tab(text: 'Incident Log'),
              Tab(text: 'Photos (DAM)'),
              Tab(text: 'Documents (DAM)'),
              Tab(text: 'Audit'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOperationsTab(),
            _buildOverviewTab(),
            _buildTimelineTab(),
            _buildConversationTab(),
            _buildNegotiationTab(),
            _buildContractTab(),
            _buildEscrowTab(),
            _buildDeliverablesTab(),
            _buildInventoryTab(),
            _buildCrewTab(),
            _buildChecklistsTab(),
            _buildIncidentLogTab(),
            _buildPhotosTab(),
            _buildDocumentsTab(),
            _buildAuditTab(),
          ],
        ),
      ),
    );
  }

  // 1. Operations Tab
  Widget _buildOperationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top Operations Board
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: EosColors.champagne.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('OPERATIONAL CONTROLS', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _checkedIn
                          ? null
                          : () {
                              setState(() {
                                _checkedIn = true;
                              });
                              _addTimelineEvent('Vendor crew checked in at Oriental Ballroom.');
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _checkedIn ? Colors.grey : Colors.green,
                      ),
                      icon: const Icon(Icons.location_on),
                      label: Text(_checkedIn ? 'Checked In' : 'Check In'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: !_checkedIn || _setupStarted
                          ? null
                          : () {
                              setState(() {
                                _setupStarted = true;
                              });
                              _addTimelineEvent('Catering decoration setup process started.');
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _setupStarted ? Colors.purple : Colors.blue,
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(_setupStarted ? 'Setup Started' : 'Start Setup'),
                    ),
                  ),
                ],
              ),
              if (_setupStarted) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Setup Progression', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('${(_setupProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _setupProgress,
                  onChanged: (v) {
                    setState(() {
                      _setupProgress = v;
                    });
                  },
                  onChangeEnd: (v) {
                    _addTimelineEvent('Setup progression level updated to ${(v * 100).toStringAsFixed(0)}%.');
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Actions
        EosSurfaceCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.verified, color: Colors.greenAccent),
                title: const Text('Request Milestone Approval'),
                subtitle: const Text('Notify organizer to approve completed buffet setup'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _addTimelineEvent('Milestone approval request sent to organizer.');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Milestone approval request sent.')));
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_open, color: Colors.amberAccent),
                title: const Text('Request Escrow Release'),
                subtitle: const Text('Trigger Commerce360 escrow release process'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _addTimelineEvent('Escrow release request initiated.');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escrow release request sent.')));
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.report_problem, color: Colors.redAccent),
                title: const Text('Report Issue / Incident'),
                subtitle: const Text('Log unexpected logistics or power delays'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showReportIncidentSheet(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 2. Overview Tab
  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EosSurfaceCard(
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Event Details', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Location: Lagos Oriental Hotel, Grand Ballroom'),
                Text('Date: July 2nd, 2026'),
                Text('Duration: 12:00 PM - 08:00 PM'),
                Text('Guest Capacity: 250 Guests'),
                Text('Client: Wale Adebayo'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 3. Timeline Tab
  Widget _buildTimelineTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('EVENT TIMELINE LOGGER', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final ev in _timelineEvents)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                const Icon(Icons.circle_notifications, color: EosColors.champagne, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(ev, style: const TextStyle(color: Colors.white70))),
              ],
            ),
          ),
      ],
    );
  }

  // 4. Conversation Tab
  Widget _buildConversationTab() {
    return Column(
      children: [
        // Pinned Message Panel
        Container(
          width: double.infinity,
          color: Colors.white.withOpacity(0.03),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(
            children: [
              Icon(Icons.push_pin, color: EosColors.champagne, size: 14),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PINNED: Oriental ballroom catering service starts exactly at 1:00 PM.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final msg = _messages[i];
              final isMe = msg['sender'] == 'Vendor';
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe ? EosColors.plum : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg['sender']!, style: TextStyle(color: isMe ? EosColors.champagne : Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(msg['text']!, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Send block with DAM and VoIP triggers
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file, color: EosColors.champagne),
                onPressed: () {
                  setState(() {
                    _damDocuments.add('Attached_Quotation_Revision.pdf');
                  });
                  _addTimelineEvent('Attached document to conversation (via DAM Framework).');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded via DAM.')));
                },
              ),
              IconButton(
                icon: const Icon(Icons.photo_library, color: EosColors.champagne),
                onPressed: () {
                  setState(() {
                    _damPhotos.add('Ballroom_Decoration_Check.jpg');
                  });
                  _addTimelineEvent('Uploaded photograph to conversation (via DAM Framework).');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo uploaded via DAM.')));
                },
              ),
              IconButton(
                icon: const Icon(Icons.phone_in_talk, color: Colors.greenAccent),
                onPressed: () {
                  // Simulate VoIP Call
                  showDialog<void>(
                    context: context,
                    builder: (callCtx) => AlertDialog(
                      backgroundColor: EosColors.plumDark,
                      title: const Row(
                        children: [
                          Icon(Icons.contact_phone, color: EosColors.champagne),
                          SizedBox(width: 8),
                          Text('VoIP Call', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Connecting VoIP Call to Organizer...', style: TextStyle(color: Colors.white70)),
                          SizedBox(height: 12),
                          CircularProgressIndicator(color: EosColors.champagne),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(callCtx),
                          child: const Text('Hang Up', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type operational message...',
                    fillColor: Colors.white10,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.mic, color: EosColors.champagne),
                onPressed: () {
                  setState(() {
                    _messages.add({'sender': 'Vendor', 'text': 'Voice Note (0:14) 🎙️'});
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Voice note recorded and uploaded to Contabo storage.')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.send, color: EosColors.champagne),
                onPressed: () {
                  final text = _messageController.text.trim();
                  if (text.isEmpty) return;
                  setState(() {
                    _messages.add({'sender': 'Vendor', 'text': text});
                  });
                  _messageController.clear();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 5. Negotiation Tab
  Widget _buildNegotiationTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EosSurfaceCard(
          child: const ListTile(
            title: Text('Setup Extension Proposal'),
            subtitle: Text('Proposed: ₦50,000 for extra setup hours'),
            trailing: Text('ACCEPTED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // 6. Contract Tab
  Widget _buildContractTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EosSurfaceCard(
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active Service SLA Agreement', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Contract Code: SLA-OR-09214'),
                Text('Obligation: Setup tables, plate foods, maintain cleanup during event.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 7. Escrow Tab
  Widget _buildEscrowTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EosSurfaceCard(
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Commerce360 Escrow Summary', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Escrow State: FUNDED'),
                Text('Locked Amount: ₦850,000.00'),
                Text('Pending Release: ₦0.00'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 8. Deliverables Tab
  Widget _buildDeliverablesTab() {
    final list = [
      'Buffet Setup',
      'Table centerpieces & Linens',
      'Food Warmer systems',
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final item in list)
          EosSurfaceCard(
            child: CheckboxListTile(
              title: Text(item),
              value: _completedDeliverables.contains(item),
              onChanged: (checked) {
                setState(() {
                  if (checked ?? false) {
                    _completedDeliverables.add(item);
                    _addTimelineEvent('Marked deliverable "$item" as complete.');
                  } else {
                    _completedDeliverables.remove(item);
                  }
                });
              },
            ),
          ),
      ],
    );
  }

  // 9. Inventory Tab
  Widget _buildInventoryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EosSurfaceCard(
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assigned Assets & Equipment', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('• 10 Chafing dishes (Assigned)'),
                Text('• 1 Van transport container (Checked in)'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 10. Crew Tab
  Widget _buildCrewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EosSurfaceCard(
          child: const ListTile(
            leading: CircleAvatar(child: Text('C')),
            title: Text('Chinedu Egwu (Kitchen Crew Lead)'),
            subtitle: Text('GPS Status: Arrived at Oriental'),
          ),
        ),
      ],
    );
  }

  // 11. Checklists Tab
  Widget _buildChecklistsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EosSurfaceCard(
          child: const ListTile(
            title: Text('Pre-arrival checklist verification'),
            subtitle: Text('All temperature checks passed'),
            trailing: Icon(Icons.check, color: Colors.green),
          ),
        ),
      ],
    );
  }

  // 12. Incident Log Tab
  Widget _buildIncidentLogTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(
          onPressed: () => _showReportIncidentSheet(),
          icon: const Icon(Icons.add),
          label: const Text('Log New Incident'),
        ),
        const SizedBox(height: 12),
        if (_incidentLog.isEmpty)
          const Text('No incidents logged.')
        else
          for (final inc in _incidentLog)
            EosSurfaceCard(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.redAccent),
                title: Text(inc),
              ),
            ),
      ],
    );
  }

  // 13. Photos Tab
  Widget _buildPhotosTab() {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 3,
      children: [
        for (final p in _damPhotos)
          Card(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Icon(Icons.photo, size: 40, color: EosColors.plum),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    color: Colors.black54,
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    child: Text(p, style: const TextStyle(fontSize: 9), textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 14. Documents Tab
  Widget _buildDocumentsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final doc in _damDocuments)
          Card(
            child: ListTile(
              leading: const Icon(Icons.description, color: EosColors.champagne),
              title: Text(doc),
              subtitle: const Text('Digital Asset Management (DAM) secure storage'),
            ),
          ),
      ],
    );
  }

  // 15. Audit Tab
  Widget _buildAuditTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EosSurfaceCard(
          child: const ListTile(
            leading: Icon(Icons.security, color: EosColors.champagne),
            title: Text('Workspace Access Logged'),
            subtitle: Text('IP 192.168.1.5 checked setup metrics'),
          ),
        ),
      ],
    );
  }

  // Helper dialog sheets
  void _showReportIncidentSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Report Incident', style: context.eosText.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _incidentController,
              decoration: const InputDecoration(
                hintText: 'Describe layout or power delay issues...',
                fillColor: Colors.white10,
                filled: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final txt = _incidentController.text.trim();
                if (txt.isEmpty) return;
                setState(() {
                  _incidentLog.add(txt);
                });
                _addTimelineEvent('Incident reported: "$txt".');
                _incidentController.clear();
                Navigator.pop(ctx);
              },
              child: const Text('Log Incident'),
            ),
          ],
        ),
      ),
    );
  }
}
