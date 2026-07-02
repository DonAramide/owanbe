import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../providers/vendor_intelligence_engine.dart';

class VendorCrmScreen extends ConsumerStatefulWidget {
  const VendorCrmScreen({super.key});

  @override
  ConsumerState<VendorCrmScreen> createState() => _VendorCrmScreenState();
}

class _VendorCrmScreenState extends ConsumerState<VendorCrmScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _noteController = TextEditingController();

  final List<Map<String, dynamic>> _mockLeads = [
    {
      'id': 'lead_01',
      'name': 'Chika Daniel',
      'budgetMinor': 95000000,
      'service': 'Catering & Service Staff',
      'status': 'Hot Lead',
    },
    {
      'id': 'lead_02',
      'name': 'Bayo Coker',
      'budgetMinor': 45000000,
      'service': 'Sound system & DJ rig',
      'status': 'Cold Lead',
    },
  ];

  final List<String> _crmNotes = [
    'Called Segun to follow up on the menu adjustments.',
    'Amina requested custom lighting specifications.',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intel = ref.watch(vendorIntelligenceProvider);

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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Organizer CRM Workspace', style: context.eosText.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: EosColors.champagne,
            labelColor: EosColors.champagne,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(text: 'Clients Segment'),
              Tab(text: 'Leads & Pipeline'),
              Tab(text: 'Notes & Follow-ups'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildClientsTab(intel),
            _buildLeadsTab(),
            _buildNotesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildClientsTab(IntelligenceState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('ORGANIZER PROFILES & SEGMENTS', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final c in state.crmClients)
          Card(
            color: const Color(0xFF241B3F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.segment == 'VIP'
                              ? Colors.purple.withOpacity(0.2)
                              : c.segment == 'Returning'
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          c.segment,
                          style: TextStyle(
                            color: c.segment == 'VIP'
                                ? Colors.purpleAccent
                                : c.segment == 'Returning'
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Lifetime Spend: ₦${(c.lifetimeSpendMinor / 100).toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 2),
                  Text('Events Booked: ${c.eventsBooked}', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text('Latest Review: "${c.latestReview}"', style: const TextStyle(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLeadsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('INCOMING LEADS PIPELINE', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final l in _mockLeads)
          Card(
            color: const Color(0xFF241B3F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
            child: ListTile(
              title: Text(l['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              subtitle: Text('Budget: ₦${((l['budgetMinor'] as int) / 100).toStringAsFixed(0)} • Service: ${l['service']}', style: const TextStyle(color: Colors.white70)),
              trailing: Text(l['status'] as String, style: const TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
      ],
    );
  }

  Widget _buildNotesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('CRM NOTES & TIMELINE FOLLOW-UPS', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final note in _crmNotes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                const Icon(Icons.note_alt_outlined, color: EosColors.champagne, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(note, style: const TextStyle(color: Colors.white70))),
              ],
            ),
          ),
        const SizedBox(height: 24),
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(
            hintText: 'Add new client follow-up note...',
            fillColor: Colors.white10,
            filled: true,
          ),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            final text = _noteController.text.trim();
            if (text.isEmpty) return;
            setState(() {
              _crmNotes.add(text);
            });
            _noteController.clear();
          },
          child: const Text('Save Note'),
        ),
      ],
    );
  }
}
