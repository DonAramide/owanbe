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
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openDirectChat(context, c.name),
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
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openDirectChat(context, l['name'] as String),
              child: ListTile(
                title: Text(l['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text('Budget: ₦${((l['budgetMinor'] as int) / 100).toStringAsFixed(0)} • Service: ${l['service']}', style: const TextStyle(color: Colors.white70)),
                trailing: Text(l['status'] as String, style: const TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
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

  void _openDirectChat(BuildContext context, String clientName) {
    final List<Map<String, String>> messages = [
      {'sender': 'client', 'text': 'Hi, regarding the counter-proposal... [Offer #1: ₦450,000]', 'time': '10:31 AM'},
      {'sender': 'vendor', 'text': 'Can we negotiate the price? [Offer #2: ₦400,000]', 'time': '10:34 AM'},
    ];

    bool isLocked = false;
    bool vendorConfirmed = false;
    bool clientConfirmed = false;
    bool showReview = false;
    bool showSummary = false;
    bool fraudFlagged = false;
    String? fraudText;

    final textController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161129),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateChat) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF161129),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: EosColors.plum,
                            child: Text(clientName[0], style: const TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(clientName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                isLocked ? 'Status: AGREED (Locked)' : 'Status: NEGOTIATING',
                                style: TextStyle(
                                  color: isLocked ? Colors.greenAccent : Colors.amberAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(showSummary ? Icons.analytics : Icons.analytics_outlined, color: EosColors.champagne),
                            tooltip: 'AI Summary Panel',
                            onPressed: () {
                              setStateChat(() {
                                showSummary = !showSummary;
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10),

                  // Collapsible AI Negotiation Summary
                  if (showSummary) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF241B3F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: EosColors.champagne.withOpacity(0.3)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI NEGOTIATION ANALYTICS SUMMARY', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold, fontSize: 12)),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Duration: 31 minutes', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text('Total Offers: 3', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Vendor Start: ₦450k', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text('Final Price: ₦425k', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Savings: ₦25,000 (12%)', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                              Text('Risk Score: LOW', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Sticky Best Offer Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E2254),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('CURRENT BEST OFFER', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold, fontSize: 11)),
                        Text('₦425,000', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),

                  // Messages stream
                  Expanded(
                    child: ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, idx) {
                        final msg = messages[idx];
                        final isMe = msg['sender'] == 'vendor';
                        final text = msg['text']!;
                        final hasOffer = text.contains('[Offer');

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: hasOffer
                                      ? const Color(0xFF3B2F63)
                                      : (isMe ? const Color(0xFFF59E0B) : const Color(0xFF241B3F)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: hasOffer ? Border.all(color: EosColors.champagne.withOpacity(0.5)) : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (hasOffer) ...[
                                      const Row(
                                        children: [
                                          Icon(Icons.gavel, color: EosColors.champagne, size: 14),
                                          SizedBox(width: 6),
                                          Text('OFFER CARD', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold, fontSize: 10)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      text,
                                      style: TextStyle(
                                        color: isMe && !hasOffer ? const Color(0xFF1A1333) : Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 6, right: 6, bottom: 6),
                                child: Text(
                                  '${msg['time'] ?? '10:40 AM'} • Delivered • Seen',
                                  style: const TextStyle(color: Colors.white30, fontSize: 9),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Fraud Alert Block
                  if (fraudFlagged) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: Text(
                        fraudText ?? '⚠️ Off-platform transaction keywords flagged! Always use Owanbe Escrow.',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],

                  // Agreement Review Screen Overlay
                  if (showReview) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E2254),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.greenAccent),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('AGREEMENT REVIEW & CONTRACT SIGNING', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          const Text('• Vendor: ABC Catering\n• Organizer: Wale Adebayo\n• Price: ₦425,000\n• Cancellation: 50% Refund, Commission Included', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    setStateChat(() {
                                      vendorConfirmed = true;
                                      if (clientConfirmed) {
                                        isLocked = true;
                                        showReview = false;
                                      }
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Vendor digital signature captured.')),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: vendorConfirmed ? Colors.grey : Colors.green),
                                  child: Text(vendorConfirmed ? 'Signed (Vendor)' : 'Sign Agreement', style: const TextStyle(fontSize: 11)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setStateChat(() {
                                      clientConfirmed = true;
                                      if (vendorConfirmed) {
                                        isLocked = true;
                                        showReview = false;
                                      }
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Organizer digital signature captured.')),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: EosColors.champagne)),
                                  child: Text(clientConfirmed ? 'Signed (Client)' : 'Sign (Client Mock)', style: const TextStyle(color: EosColors.champagne, fontSize: 11)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Locked Virtual Account Card
                  if (isLocked) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueAccent),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🔒 AGREEMENT IMMUTABLE & LOCKED', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          const Text('Owanbe Virtual Escrow Account generated for Client payment:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Bank: Owanbe Settlement Bank', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  Text('Account: 1234567890', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('Name: OWANBE ESCROW', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, color: EosColors.champagne),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Virtual account details copied to clipboard.')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Send text fields (Disabled if Locked)
                  if (!isLocked) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textController,
                            decoration: const InputDecoration(
                              hintText: 'Type message or counter price...',
                              fillColor: Color(0xFF241B3F),
                              filled: true,
                              border: OutlineInputBorder(borderSide: BorderSide.none),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send, color: Color(0xFFF59E0B)),
                          onPressed: () {
                            final text = textController.text.trim();
                            if (text.isEmpty) return;

                            setStateChat(() {
                              // Fraud scanning trigger
                              if (text.toLowerCase().contains('whatsapp') ||
                                  text.toLowerCase().contains('gtbank') ||
                                  text.toLowerCase().contains('opay') ||
                                  text.toLowerCase().contains('call me')) {
                                fraudFlagged = true;
                                fraudText = '⚠️ External payment / contact attempt blocked! Please use Owanbe Escrow.';
                                textController.clear();
                                return;
                              } else {
                                fraudFlagged = false;
                              }

                              // Price detection trigger
                              if (text.contains('425') || text.toLowerCase().contains('deal') || text.toLowerCase().contains('agree')) {
                                showReview = true;
                              }

                              messages.add({
                                'sender': 'vendor',
                                'text': text,
                                'time': '10:41 AM',
                              });
                            });
                            textController.clear();
                          },
                        ),
                      ],
                    ),
                  ] else ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Chat input frozen — Contract Agreement successfully signed.', style: TextStyle(color: Colors.white30, fontSize: 12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
