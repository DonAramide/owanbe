import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../models/vendor_models.dart';
import '../providers/vendor_providers.dart';
import '../providers/vendor_intelligence_engine.dart';
import '../widgets/vendor_shared.dart';
import '../../../platform/procurement/procurement_models.dart';
import '../../../platform/procurement/procurement_engine.dart';
import '../../../platform/procurement/contract_generator.dart';

class VendorDashboardScreen extends ConsumerStatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  ConsumerState<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends ConsumerState<VendorDashboardScreen> {
  late Timer _timer;
  int _secondsLeft = 14400; // 4 hours countdown for today's event setup

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSecs) {
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final intel = ref.watch(vendorIntelligenceProvider);
    final profile = ref.watch(vendorProfileProvider);
    final tabController = ref.read(vendorShellTabProvider.notifier);

    return Scaffold(
      backgroundColor: EosColors.plumDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Business Profile block
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to Vendor OS',
                      style: context.eosText.labelMedium?.copyWith(color: Colors.white70),
                    ),
                    Text(
                      profile.businessName,
                      style: context.eosText.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                EosVendorTierChip(tier: profile.tier),
              ],
            ),
            const SizedBox(height: 20),

            // AI Insights Banner Section (BI)
            _buildBInsights(intel.insights),
            const SizedBox(height: 20),

            // 1. Executive Metrics Ribbon
            _buildExecutiveRibbon(intel, tabController),
            const SizedBox(height: 24),

            // 2. Today's Operations Center
            _buildTodayOperationsCenter(tabController),
            const SizedBox(height: 24),

            // Responsive Layout: Left Operations / Right CRM & Communication details
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: isWide ? 7 : 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 3. Negotiation Center
                          _buildNegotiationCenter(intel.negotiations),
                          const SizedBox(height: 24),

                          // 4. Contract Command Center
                          _buildContractCommandCenter(intel.contracts, tabController),
                          const SizedBox(height: 24),

                          // 5. Escrow & Finance Milestone visualization
                          _buildEscrowMilestoneVisualizer(intel),
                          const SizedBox(height: 24),

                          // 6. Deliverables & Inventory panel
                          _buildDeliverablesAndInventoryPanel(),
                        ],
                      ),
                    ),
                    if (isWide) const SizedBox(width: 24),
                    if (isWide)
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 7. Conversations Hub
                            _buildConversationsHub(tabController),
                            const SizedBox(height: 24),

                            // 8. CRM segmentation
                            _buildCrmSegmentation(intel.crmClients),
                            const SizedBox(height: 24),

                            // 9. Team Operations assignment checks
                            _buildTeamOperations(intel.team, tabController),
                            const SizedBox(height: 24),

                            // 10. Unified Notifications Center
                            _buildNotificationsCenter(intel.notifications, tabController),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),

            // Mobile-fallback layout for Right Column sections
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth <= 900) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildConversationsHub(tabController),
                      const SizedBox(height: 24),
                      _buildCrmSegmentation(intel.crmClients),
                      const SizedBox(height: 24),
                      _buildTeamOperations(intel.team, tabController),
                      const SizedBox(height: 24),
                      _buildNotificationsCenter(intel.notifications, tabController),
                    ],
                  );
                }
                return const SizedBox();
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // AI-generated Business Intelligence Insights Ribbon
  Widget _buildBInsights(List<IntelligenceInsight> insights) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EosColors.plumDark.withOpacity(0.4),
        border: Border.all(color: EosColors.champagne.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: EosColors.champagne, size: 20),
              const SizedBox(width: 8),
              Text(
                'VENDOR INTELLIGENCE LOG',
                style: context.eosText.labelSmall?.copyWith(
                  color: EosColors.champagne,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final ins in insights)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                children: [
                  Icon(
                    ins.type == 'warning'
                        ? Icons.warning_amber_rounded
                        : ins.type == 'success'
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                    color: ins.type == 'warning'
                        ? Colors.amber
                        : ins.type == 'success'
                            ? Colors.greenAccent
                            : Colors.blueAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ins.message,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Executive Metric Ribbon Layout
  Widget _buildExecutiveRibbon(IntelligenceState state, VendorShellTabController tabController) {
    final List<Map<String, dynamic>> metricItems = [
      {
        'label': 'Business Health',
        'value': '${state.healthScore}%',
        'icon': Icons.insights,
        'action': () => tabController.select(6), // Analytics tab
      },
      {
        'label': 'Performance Score',
        'value': '${state.performanceScore}',
        'icon': Icons.star,
        'action': () => tabController.select(6), // Analytics tab
      },
      {
        'label': 'SLA Compliance',
        'value': '${state.slaCompliance}%',
        'icon': Icons.assignment_turned_in,
        'action': () => tabController.select(1), // Events list
      },
      {
        'label': 'Available Balance',
        'value': '₦${(state.availableBalanceMinor / 100).toStringAsFixed(0)}',
        'icon': Icons.account_balance_wallet,
        'action': () => tabController.select(4), // Wallet tab
      },
      {
        'label': 'Locked Escrow',
        'value': '₦${(state.escrowBalanceMinor / 100).toStringAsFixed(0)}',
        'icon': Icons.lock_outline,
        'action': () => tabController.select(4), // Wallet tab
      },
      {
        'label': 'Active Contracts',
        'value': '${state.contracts.length}',
        'icon': Icons.handshake,
        'action': () => tabController.select(3), // Orders/Contracts tab
      },
      {
        'label': 'Active Negotiations',
        'value': '${state.negotiations.where((n) => n.status.startsWith('pending')).length}',
        'icon': Icons.question_answer_outlined,
        'action': () => tabController.select(3), // Orders/Contracts tab
      },
      {
        'label': 'Monthly Revenue',
        'value': '₦${(state.monthlyRevenueMinor / 100).toStringAsFixed(0)}',
        'icon': Icons.trending_up,
        'action': () => tabController.select(6), // Analytics
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: metricItems.map((m) {
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: InkWell(
              onTap: m['action'] as VoidCallback,
              child: Card(
                color: Colors.white.withOpacity(0.04),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Row(
                    children: [
                      Icon(m['icon'] as IconData, color: EosColors.champagne, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['label'] as String,
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                          Text(
                            m['value'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Today's Operations Center
  Widget _buildTodayOperationsCenter(VendorShellTabController tabController) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TODAY'S OPERATIONS CENTER",
                style: context.eosText.titleMedium?.copyWith(
                  color: EosColors.champagne,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(_secondsLeft),
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Event', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    Text(
                      'Wale & Shade Wedding Feast',
                      style: context.eosText.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: EosColors.champagne, size: 16),
                        SizedBox(width: 4),
                        Text('Lagos Oriental Hotel, Grand Ballroom', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.people_outline, color: EosColors.champagne, size: 16),
                        SizedBox(width: 4),
                        Text('Crew Assigned: 4 Catering staff', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Setup Progress', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  const SizedBox(height: 4),
                  CircularProgressIndicator(
                    value: 0.75,
                    backgroundColor: Colors.white10,
                    color: EosColors.champagne,
                  ),
                  const SizedBox(height: 4),
                  const Text('75% Setup Ready', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => tabController.select(1), // Open Events list/Workspace tab
                icon: const Icon(Icons.celebration, size: 16, color: EosColors.plumDark),
                label: const Text('Open Event Workspace', style: TextStyle(color: EosColors.plumDark, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: EosColors.champagne),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  bool c1 = true;
                  bool c2 = true;
                  bool c3 = false;
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (ctx) => StatefulBuilder(
                      builder: (context, setStateSheet) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          color: EosColors.plumDark,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "TODAY'S SETUP CHECKLIST",
                                style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 12),
                              CheckboxListTile(
                                value: c1,
                                onChanged: (v) => setStateSheet(() => c1 = v ?? false),
                                title: const Text('Confirm menu item ingredients', style: TextStyle(color: Colors.white)),
                                controlAffinity: ListTileControlAffinity.leading,
                                activeColor: EosColors.champagne,
                                checkColor: EosColors.plumDark,
                              ),
                              CheckboxListTile(
                                value: c2,
                                onChanged: (v) => setStateSheet(() => c2 = v ?? false),
                                title: const Text('Ensure wait staff checked-in', style: TextStyle(color: Colors.white)),
                                controlAffinity: ListTileControlAffinity.leading,
                                activeColor: EosColors.champagne,
                                checkColor: EosColors.plumDark,
                              ),
                              CheckboxListTile(
                                value: c3,
                                onChanged: (v) => setStateSheet(() => c3 = v ?? false),
                                title: const Text('Set up dinner table arrangement', style: TextStyle(color: Colors.white)),
                                controlAffinity: ListTileControlAffinity.leading,
                                activeColor: EosColors.champagne,
                                checkColor: EosColors.plumDark,
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                  );
                },
                icon: const Icon(Icons.checklist, size: 16, color: Colors.white),
                label: const Text('View Checklist', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white30)),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  double progress = 0.0;
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogCtx) => StatefulBuilder(
                      builder: (context, setDialogState) {
                        Timer.run(() {
                          if (progress == 0.0) {
                            Timer.periodic(const Duration(milliseconds: 100), (t) {
                              if (progress < 1.0) {
                                setDialogState(() {
                                  progress += 0.05;
                                  if (progress >= 1.0) {
                                    progress = 1.0;
                                    t.cancel();
                                    Future.delayed(const Duration(milliseconds: 400), () {
                                      Navigator.pop(dialogCtx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('File uploaded successfully to Contabo storage bucket!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    });
                                  }
                                });
                              }
                            });
                          }
                        });
                        return AlertDialog(
                          backgroundColor: EosColors.plumDark,
                          title: const Text('Uploading setup photos', style: TextStyle(color: Colors.white)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=500&auto=format&fit=crop',
                                  height: 120,
                                  width: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 120,
                                    width: 200,
                                    color: Colors.white10,
                                    child: const Icon(Icons.image, color: Colors.white30, size: 40),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text('Connecting to Contabo storage bucket...', style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 16),
                              LinearProgressIndicator(value: progress, color: const Color(0xFFF59E0B)),
                              const SizedBox(height: 8),
                              Text('${(progress * 100).toStringAsFixed(0)}% completed', style: const TextStyle(color: Colors.white60)),
                            ],
                          ),
                        );
                      }
                    ),
                  );
                },
                icon: const Icon(Icons.photo_camera_outlined, size: 16, color: Colors.white),
                label: const Text('Upload Setup Photos', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white30)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Negotiation Center
  Widget _buildNegotiationCenter(List<NegotiationItem> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NEGOTIATION COMMAND CENTER',
                style: context.eosText.titleMedium?.copyWith(
                  color: EosColors.champagne,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(Icons.gavel_outlined, color: EosColors.champagne),
            ],
          ),
          const SizedBox(height: 16),
          for (final n in items.where((element) => element.status.startsWith('pending')))
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                border: Border.all(color: Colors.white10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(n.clientName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: n.status == 'pending_vendor'
                              ? Colors.amber.withOpacity(0.2)
                              : Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          n.status == 'pending_vendor' ? 'Requires Action' : 'Pending Client Response',
                          style: TextStyle(
                            color: n.status == 'pending_vendor' ? Colors.amber : Colors.blue,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Event: ${n.eventName}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('Service: ${n.serviceType}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Original Quote: ₦${(n.originalQuoteMinor / 100).toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('Counter Quote: ₦${(n.counterQuoteMinor / 100).toStringAsFixed(0)}',
                          style: const TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  if (n.status == 'pending_vendor') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _showVendorSignatureDialog(context, n);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Accept Quote', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              ref.read(vendorIntelligenceProvider.notifier).rejectNegotiation(n.id);
                            },
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                            child: const Text('Decline', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _openDirectChat(context, n.clientName),
                          icon: const Icon(Icons.chat_outlined, color: EosColors.champagne),
                          tooltip: 'Chat with Client',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _triggerVoipCall(context, n.clientName),
                          icon: const Icon(Icons.phone_in_talk, color: Colors.greenAccent),
                          tooltip: 'VoIP Call with Client',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _triggerVoipCall(BuildContext context, String clientName) {
    showDialog<void>(
      context: context,
      builder: (callCtx) => AlertDialog(
        backgroundColor: EosColors.plumDark,
        title: Row(
          children: [
            const Icon(Icons.contact_phone, color: EosColors.champagne),
            const SizedBox(width: 8),
            Text('VoIP Call to $clientName', style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Connecting secure VoIP Call to client...', style: TextStyle(color: Colors.white70)),
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

  // Contract Command Center
  Widget _buildContractCommandCenter(List<ContractItem> contracts, VendorShellTabController tabController) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CONTRACT COMMAND CENTER',
                style: context.eosText.titleMedium?.copyWith(
                  color: EosColors.champagne,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(Icons.feed_outlined, color: EosColors.champagne),
            ],
          ),
          const SizedBox(height: 16),
          for (final c in contracts)
            InkWell(
              onTap: () => tabController.select(3), // Navigate to Orders/Contracts tab
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  border: Border.all(color: Colors.white10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(c.eventName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text(
                          'Total Value: ₦${(c.totalValueMinor / 100).toStringAsFixed(0)}',
                          style: const TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Client: ${c.clientName}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('Obligations: ${c.obligations}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Milestones Status:', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        Text('${(c.milestoneProgress * 100).toStringAsFixed(0)}% Approved', style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: c.milestoneProgress,
                      backgroundColor: Colors.white10,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Escrow & Finance Center Milestone Map
  Widget _buildEscrowMilestoneVisualizer(IntelligenceState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ESCROW MILESTONE TIMELINE (COMMERCE360)',
                style: context.eosText.titleMedium?.copyWith(
                  color: EosColors.champagne,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(Icons.account_balance_outlined, color: EosColors.champagne),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMilestoneNode('Contract Signed', true),
                _buildMilestoneArrow(true),
                _buildMilestoneNode('Deposit Received', true),
                _buildMilestoneArrow(true),
                _buildMilestoneNode('Escrow Funded', true),
                _buildMilestoneArrow(true),
                _buildMilestoneNode('Milestone Approved', true),
                _buildMilestoneArrow(false),
                _buildMilestoneNode('Release Requested', false),
                _buildMilestoneArrow(false),
                _buildMilestoneNode('Funds Released', false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneNode(String label, bool completed) {
    return Column(
      children: [
        Icon(
          completed ? Icons.check_circle : Icons.radio_button_off,
          color: completed ? Colors.green : Colors.white30,
          size: 24,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: completed ? Colors.white : Colors.white54,
            fontSize: 10,
            fontWeight: completed ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneArrow(bool completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Icon(
        Icons.chevron_right,
        color: completed ? Colors.green : Colors.white12,
        size: 16,
      ),
    );
  }

  // Deliverables and Inventory Catalog summaries
  Widget _buildDeliverablesAndInventoryPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INVENTORY & DELIVERABLES STATUS',
            style: context.eosText.titleMedium?.copyWith(
              color: EosColors.champagne,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const ListTile(
            leading: Icon(Icons.dining_outlined, color: EosColors.champagne),
            title: Text('Catering setup & Hot warmers', style: TextStyle(color: Colors.white)),
            subtitle: Text('Delivered and checked in by crew at Lagos Oriental'),
            trailing: Text('COMPLETED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const ListTile(
            leading: Icon(Icons.camera_alt_outlined, color: EosColors.champagne),
            title: Text('Photographer raw memory card catalog', style: TextStyle(color: Colors.white)),
            subtitle: Text('Waiting for upload to Digital Asset Management (DAM)'),
            trailing: Text('PENDING', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // Conversations Hub
  Widget _buildConversationsHub(VendorShellTabController tabController) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CONVERSATIONS HUB',
                style: context.eosText.titleMedium?.copyWith(
                  color: EosColors.champagne,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(Icons.chat_bubble_outline, color: EosColors.champagne),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const CircleAvatar(backgroundColor: EosColors.plum, child: Text('O', style: TextStyle(color: Colors.white))),
            title: const Text('Segun (Organizer)', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Typing...', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () => context.push('/vendor/crm'),
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Text('S', style: TextStyle(color: Colors.white))),
            title: const Text('Platform Support Agent', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Your suspension check has been resolved', style: TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () => context.push('/vendor/crm'),
          ),
        ],
      ),
    );
  }

  // CRM Segmentation
  Widget _buildCrmSegmentation(List<CrmClient> clients) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ORGANIZER CRM METRICS',
                style: context.eosText.titleMedium?.copyWith(
                  color: EosColors.champagne,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(Icons.people_outline, color: EosColors.champagne),
            ],
          ),
          const SizedBox(height: 16),
          for (final c in clients)
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text('Events Booked: ${c.eventsBooked}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
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
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Team Operations
  Widget _buildTeamOperations(List<TeamMember> team, VendorShellTabController tabController) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TEAM OPERATIONS & ASSIGNMENTS',
                style: context.eosText.titleMedium?.copyWith(
                  color: EosColors.champagne,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_calendar_outlined, color: EosColors.champagne, size: 20),
                onPressed: () => tabController.select(1), // Go to Events crew setup
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final member in team)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge, color: EosColors.champagne),
              title: Text(member.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text('Assigned: ${member.assignment}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              trailing: Text('Checked In: ${member.checkInTime}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
              onTap: () => tabController.select(1), // Crew workspace in Events
            ),
        ],
      ),
    );
  }

  // Unified Notifications Center
  Widget _buildNotificationsCenter(List<String> notifications, VendorShellTabController tabController) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NOTIFICATIONS CENTER',
                style: context.eosText.titleMedium?.copyWith(
                  color: EosColors.champagne,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.done_all, color: EosColors.champagne, size: 20),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All notifications cleared.')));
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final note in notifications)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notifications_active_outlined, color: EosColors.champagne, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showVendorSignatureDialog(BuildContext context, NegotiationItem item) {
    final proposal = ContractProposal(
      id: 'con_90214',
      organizerId: 'org_01',
      vendorId: 'vend_1',
      eventId: 'evt_wedding_01',
      requirements: 'Provision of full buffet catering services for 300 guests, including servers and dinnerware.',
      totalAmountMinor: item.counterQuoteMinor,
      milestones: [
        ContractMilestone(id: 'm1', title: 'Onboarding Deposit', amountMinor: (item.counterQuoteMinor * 0.4).round(), status: MilestoneStatus.pending, description: 'Initial mobilization payment'),
        ContractMilestone(id: 'm2', title: 'Post-event Release', amountMinor: (item.counterQuoteMinor * 0.6).round(), status: MilestoneStatus.pending, description: 'Final quality clearance check'),
      ],
      signatures: [
        ContractSignature(signerId: 'org_01', role: 'organizer', signedAt: DateTime.now().subtract(const Duration(hours: 1)), signatureHash: 'sha256_091824102_org_sig_hash'),
      ],
      state: ProcurementState.proposed,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

    final contractText = ContractGenerator.generateLegalDocument(proposal);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EosColors.plumDark,
        title: const Text('Confirm Agreement & Sign Contract', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LEGAL AGREEMENT DOCUMENT:', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold, fontSize: 11)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.white10,
                child: Text(
                  contractText,
                  style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 10),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Dual Signatures Verification Status:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('• Organizer: SIGNED (sha256_091824102_org_sig_hash)\n• Vendor: NOT SIGNED', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(vendorIntelligenceProvider.notifier).acceptNegotiation(item.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Contract signed digitally as SERVICE PROVIDER! Locked in Commerce360 Escrow.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Execute Digital Signature'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }
}
