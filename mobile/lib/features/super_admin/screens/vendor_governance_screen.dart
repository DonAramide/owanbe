import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';
import '../../../platform/governance/governance_models.dart';
import '../../../platform/governance/governance_engine.dart';

class VendorGovernanceScreen extends ConsumerStatefulWidget {
  const VendorGovernanceScreen({super.key});

  @override
  ConsumerState<VendorGovernanceScreen> createState() => _VendorGovernanceScreenState();
}

class _VendorGovernanceScreenState extends ConsumerState<VendorGovernanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _engine = GovernanceEngine();

  // Mock State
  final List<Map<String, dynamic>> _mockVendors = [
    {
      'id': 'v_01',
      'name': 'Gold Event Catering',
      'category': 'Catering',
      'status': VendorLifecycleState.active,
      'trustScore': 94,
      'riskScore': RiskLevel.low,
      'walletFrozen': false,
      'commsDisabled': false,
    },
    {
      'id': 'v_02',
      'name': 'Lumina Decor & Lights',
      'category': 'Decoration',
      'status': VendorLifecycleState.restricted,
      'trustScore': 68,
      'riskScore': RiskLevel.medium,
      'walletFrozen': true,
      'commsDisabled': false,
    },
    {
      'id': 'v_03',
      'name': 'Aso Ebi Premium Hub',
      'category': 'Fashion',
      'status': VendorLifecycleState.suspended,
      'trustScore': 35,
      'riskScore': RiskLevel.high,
      'walletFrozen': true,
      'commsDisabled': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        scaffoldBackgroundColor: const Color(0xFF161129),
        cardColor: const Color(0xFF221A3C),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF161129),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Vendor Governance OS',
            style: context.eosText.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: EosColors.champagne,
            labelColor: EosColors.champagne,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(text: 'Control Tower'),
              Tab(text: 'Lifecycle & KYC'),
              Tab(text: 'Policies & Comms'),
              Tab(text: 'Broadcasts'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildControlTowerTab(),
            _buildLifecycleTab(),
            _buildPoliciesTab(),
            _buildBroadcastsTab(),
          ],
        ),
      ),
    );
  }

  // 1. Control Tower Dashboard
  Widget _buildControlTowerTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Cards Grid
        GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: [
            _buildSummaryCard('Total Vendors', '1,248', Icons.people, Colors.blueAccent),
            _buildSummaryCard('KYC Pending', '14', Icons.assignment_late, Colors.amberAccent),
            _buildSummaryCard('Suspended', '8', Icons.block, Colors.redAccent),
            _buildSummaryCard('Avg Trust Score', '91.2%', Icons.favorite, Colors.greenAccent),
          ],
        ),
        const SizedBox(height: 24),

        // High Risk Watchlist
        const Text('HIGH RISK MONITOR & WATCHLIST', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 12),
        for (final v in _mockVendors.where((v) => v['riskScore'] == RiskLevel.high || v['riskScore'] == RiskLevel.medium))
          EosSurfaceCard(
            child: ListTile(
              leading: Icon(
                v['riskScore'] == RiskLevel.high ? Icons.warning_amber : Icons.info_outline,
                color: v['riskScore'] == RiskLevel.high ? Colors.redAccent : Colors.orangeAccent,
              ),
              title: Text(v['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('Category: ${v['category']} • Risk Index: ${v['riskScore'].toString().split('.').last.toUpperCase()}', style: const TextStyle(color: Colors.white70)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Trust: ${v['trustScore']}%',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // 2. Lifecycle & Compliance Documents
  Widget _buildLifecycleTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('COMPLIANCE INSPECTOR & ONBOARDING LIFECYCLE', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final v in _mockVendors)
          EosSurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(v['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: EosColors.plum,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          v['status'].toString().split('.').last.toUpperCase(),
                          style: const TextStyle(color: EosColors.champagne, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Verification ID: CAC-2026-90214\nDocuments Tracked: CAC Incorporation, NIN Certificate', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            v['status'] = VendorLifecycleState.active;
                          });
                          _engine.vendorGovernance.transitionVendorState(
                            vendorId: v['id'] as String,
                            adminUserId: 'admin_01',
                            targetState: VendorLifecycleState.active,
                            reason: 'KYC Document verification approved.',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vendor approved and marked Active.')),
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('Approve KYC', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            v['status'] = VendorLifecycleState.suspended;
                            v['commsDisabled'] = true;
                            v['walletFrozen'] = true;
                          });
                          _engine.vendorGovernance.transitionVendorState(
                            vendorId: v['id'] as String,
                            adminUserId: 'admin_01',
                            targetState: VendorLifecycleState.suspended,
                            reason: 'Manual suspension triggered by Risk Management.',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vendor suspended. Communication & Wallet frozen.')),
                          );
                        },
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                        child: const Text('Suspend Vendor', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // 3. Policies & Comms
  Widget _buildPoliciesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('CASCADING COMMUNICATION POLICY', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        EosSurfaceCard(
          child: Column(
            children: [
              CheckboxListTile(
                value: true,
                onChanged: (v) {},
                title: const Text('Enable Chat Messaging (Organizer ⇄ Vendor)', style: TextStyle(color: Colors.white)),
                activeColor: EosColors.champagne,
                checkColor: EosColors.plumDark,
              ),
              CheckboxListTile(
                value: true,
                onChanged: (v) {},
                title: const Text('Enable Voice Calling (VoIP System)', style: TextStyle(color: Colors.white)),
                activeColor: EosColors.champagne,
                checkColor: EosColors.plumDark,
              ),
              CheckboxListTile(
                value: false,
                onChanged: (v) {},
                title: const Text('Enable Screen Sharing (Platform Restrictive)', style: TextStyle(color: Colors.white)),
                activeColor: EosColors.champagne,
                checkColor: EosColors.plumDark,
              ),
              CheckboxListTile(
                value: true,
                onChanged: (v) {},
                title: const Text('Enforce Read Receipts & Presence Tracking', style: TextStyle(color: Colors.white)),
                activeColor: EosColors.champagne,
                checkColor: EosColors.plumDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 4. Broadcasts
  Widget _buildBroadcastsTab() {
    final msgController = TextEditingController();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('GOVERNANCE BROADCAST CENTER', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: msgController,
          decoration: const InputDecoration(
            hintText: 'Enter compliance announcement or policy alert message...',
            fillColor: Colors.white10,
            filled: true,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
          style: const TextStyle(color: Colors.white),
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            if (msgController.text.trim().isEmpty) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Broadcast queued successfully to all Photography & Catering vendor categories!'),
                backgroundColor: Colors.green,
              ),
            );
            msgController.clear();
          },
          icon: const Icon(Icons.send, color: Colors.white),
          label: const Text('Publish Broadcast Notification', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
