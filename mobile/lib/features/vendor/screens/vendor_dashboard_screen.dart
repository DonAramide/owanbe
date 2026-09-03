import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../eos/eos.dart';
import '../../../core/providers/silent_refresh.dart';
import '../models/vendor_models.dart';
import '../providers/vendor_providers.dart';
import '../providers/vendor_intelligence_engine.dart';
import '../providers/vendor_inbox_integration.dart';
import '../providers/vendor_event_workspace_nav.dart';
import '../vendor_os_demo_mode.dart';
import '../widgets/vendor_empty_state.dart';
import '../widgets/vendor_incoming_requests_panel.dart';
import 'vendor_event_360_workspace_screen.dart';
import '../../../portals/customer/models/vendor_crm_models.dart';
import '../../../portals/customer/providers/vendor_crm_providers.dart';

class VendorDashboardScreen extends ConsumerStatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  ConsumerState<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends ConsumerState<VendorDashboardScreen> {
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    if (VendorOsDemoMode.isEnabled) {
      _secondsLeft = 14400;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _secondsLeft > 0) {
          setState(() {
            _secondsLeft--;
          });
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshVendorCrm(ref);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
    final inboxAsync = ref.watch(vendorInboxSnapshotProvider);
    final notifications = inboxAsync.maybeWhen(
      data: vendorInboxNotifications,
      orElse: () => <String>[],
    );
    final insights = inboxAsync.maybeWhen(
      data: vendorInboxInsights,
      orElse: () => <IntelligenceInsight>[],
    );
    final pendingRequestCount = inboxAsync.maybeWhen(
      data: (snap) => snap.stats.newCount + snap.stats.negotiating,
      orElse: () => 0,
    );
    final mergedIntel = intel.copyWith(
      notifications: notifications,
      insights: insights.isEmpty
          ? [
              IntelligenceInsight(
                message: inboxAsync.isLoading
                    ? 'Loading CRM inbox…'
                    : 'No pending vendor requests.',
                type: 'info',
                timestamp: DateTime.now(),
              ),
            ]
          : insights,
    );

    final profile = ref.watch(vendorProfileProvider);
    final tabController = ref.read(vendorShellTabProvider.notifier);

    return Scaffold(
      backgroundColor: EosColors.plumDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Business Profile block — authenticated vendor only
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
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
                ),
                if (profile.tier.trim().isNotEmpty) EosVendorTierChip(tier: profile.tier),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => context.push('/vendor/services'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: EosColors.champagne.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: EosColors.champagne.withValues(alpha: 0.35)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.home_repair_service_outlined, color: EosColors.champagne),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SERVICES & AVAILABILITY',
                            style: TextStyle(
                              color: EosColors.champagne,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Turn services on/off, declare what you provide, and see booked dates.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => context.push('/vendor/offerings'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: EosColors.champagne),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MY SERVICES & RENTAL PACKAGES',
                            style: TextStyle(
                              color: EosColors.champagne,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Service blueprints and rental packages from Super Admin catalogues.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => context.push('/vendors?vendorBuyer=1'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.storefront_outlined, color: EosColors.champagne),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MARKETPLACE',
                            style: TextStyle(
                              color: EosColors.champagne,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Find services and rental packages for events you are on.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => context.push('/vendor/calendar'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, color: EosColors.champagne),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MY SCHEDULE',
                            style: TextStyle(
                              color: EosColors.champagne,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Upcoming bookings, pending requests, and BLOCK DATES.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // AI Insights Banner Section (BI)
            _buildBInsights(mergedIntel.insights),
            const SizedBox(height: 20),

            // 1. Executive Metrics Ribbon
            _buildExecutiveRibbon(mergedIntel, tabController, pendingRequestCount: pendingRequestCount),
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
                          // 3. Incoming Requests (live CRM)
                          inboxAsync.whenStable(
                            data: (snap) => VendorIncomingRequestsPanel(snapshot: snap),
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => VendorEmptyState(
                              message: 'Could not load incoming requests: $e',
                              icon: Icons.error_outline,
                              compact: true,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 4. Contract Command Center
                          _buildContractCommandCenter(mergedIntel.contracts, tabController),
                          const SizedBox(height: 24),

                          // 5. Escrow & Finance Milestone visualization
                          _buildEscrowMilestoneVisualizer(mergedIntel),
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
                            _buildCrmSegmentation(mergedIntel.crmClients),
                            const SizedBox(height: 24),

                            // 9. Team Operations assignment checks
                            _buildTeamOperations(mergedIntel.team, tabController),
                            const SizedBox(height: 24),

                            // 10. Unified Notifications Center
                            _buildNotificationsCenter(mergedIntel.notifications, tabController),
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
                      _buildCrmSegmentation(mergedIntel.crmClients),
                      const SizedBox(height: 24),
                      _buildTeamOperations(mergedIntel.team, tabController),
                      const SizedBox(height: 24),
                      _buildNotificationsCenter(mergedIntel.notifications, tabController),
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

  // Executive Metric Ribbon Layout — N/A or ₦0 when no real activity
  Widget _buildExecutiveRibbon(
    IntelligenceState state,
    VendorShellTabController tabController, {
    required int pendingRequestCount,
  }) {
    final wallet = ref.watch(vendorWalletProvider).valueOrNull;
    final availableMinor = wallet?.availableMinor ?? state.availableBalanceMinor;
    final pendingMinor = wallet?.pendingMinor ?? state.escrowBalanceMinor;
    final revenueMinor = wallet?.totalEarnedMinor ?? state.monthlyRevenueMinor;
    final na = !state.metricsAvailable;
    final List<Map<String, dynamic>> metricItems = [
      {
        'label': 'Business Health',
        'value': na ? 'N/A' : '${state.healthScore}%',
        'icon': Icons.insights,
        'action': () => tabController.select(6),
      },
      {
        'label': 'Performance Score',
        'value': na ? 'N/A' : '${state.performanceScore}',
        'icon': Icons.star,
        'action': () => tabController.select(6),
      },
      {
        'label': 'SLA Compliance',
        'value': na ? 'N/A' : '${state.slaCompliance}%',
        'icon': Icons.assignment_turned_in,
        'action': () => tabController.select(1),
      },
      {
        'label': 'Available Balance',
        'value': '₦${(availableMinor / 100).toStringAsFixed(2)}',
        'icon': Icons.account_balance_wallet,
        'action': () => tabController.select(4),
      },
      {
        'label': 'Locked Escrow',
        'value': '₦${(pendingMinor / 100).toStringAsFixed(2)}',
        'icon': Icons.lock_outline,
        'action': () => tabController.select(4),
      },
      {
        'label': 'Active Contracts',
        'value': '${state.contracts.length}',
        'icon': Icons.handshake,
        'action': () => tabController.select(3),
      },
      {
        'label': 'Pending Requests',
        'value': '$pendingRequestCount',
        'icon': Icons.inbox_outlined,
        'action': () => tabController.select(0),
      },
      {
        'label': 'Monthly Revenue',
        'value': '₦${(revenueMinor / 100).toStringAsFixed(2)}',
        'icon': Icons.trending_up,
        'action': () => tabController.select(6),
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

  // Today's Operations Center — live events only; never invent a wedding
  Widget _buildTodayOperationsCenter(VendorShellTabController tabController) {
    final liveParts = ref.watch(vendorParticipationsProvider).valueOrNull ?? const [];
    final active = liveParts
        .where(
          (p) =>
              p.status == VendorParticipationStatus.confirmed ||
              p.status == VendorParticipationStatus.live,
        )
        .toList();
    final showDemoOps = VendorOsDemoMode.isEnabled;

    if (!showDemoOps && active.isEmpty) {
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
              "TODAY'S OPERATIONS CENTER",
              style: context.eosText.titleMedium?.copyWith(
                color: EosColors.champagne,
                fontWeight: FontWeight.bold,
              ),
            ),
            const VendorEmptyState(
              message: "You don't have any active events.",
              icon: Icons.event_busy_outlined,
              compact: true,
            ),
          ],
        ),
      );
    }

    if (!showDemoOps && active.isNotEmpty) {
      final event = active.first;
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
              "TODAY'S OPERATIONS CENTER",
              style: context.eosText.titleMedium?.copyWith(
                color: EosColors.champagne,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Current Event', style: TextStyle(color: Colors.white60, fontSize: 11)),
            Text(
              event.eventTitle,
              style: context.eosText.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: EosColors.champagne, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    [event.venue, event.city].where((s) => s.trim().isNotEmpty).join(' · '),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final resolved = await resolveVendorRequestIdForWorkspace(
                  context,
                  ref,
                  eventKey: event.eventId,
                  eventUuid: event.eventUuid,
                  eventTitle: event.eventTitle,
                );
                ref.read(vendorEventWorkspaceNavProvider.notifier).open(
                      eventId: event.eventId,
                      eventUuid: event.eventUuid,
                      requestId: resolved,
                      initialTabIndex: 0,
                    );
                tabController.select(1);
              },
              icon: const Icon(Icons.celebration, size: 16, color: EosColors.plumDark),
              label: const Text(
                'Open Event Workspace',
                style: TextStyle(color: EosColors.plumDark, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: EosColors.champagne),
            ),
          ],
        ),
      );
    }

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
          if (contracts.isEmpty)
            const VendorEmptyState(
              message: 'No contracts yet.',
              icon: Icons.feed_outlined,
              compact: true,
            )
          else
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
          if (!VendorOsDemoMode.isEnabled)
            const VendorEmptyState(
              message: 'No deliverables yet.',
              icon: Icons.inventory_2_outlined,
              compact: true,
            )
          else ...[
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
        ],
      ),
    );
  }

  // Conversations Hub — live shared Vendor Request threads (event-isolated)
  Widget _buildConversationsHub(VendorShellTabController tabController) {
    final inbox = ref.watch(vendorInboxSnapshotProvider);
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
              IconButton(
                tooltip: 'Open CRM inbox',
                icon: const Icon(Icons.chat_bubble_outline, color: EosColors.champagne),
                onPressed: () => context.push('/vendor/crm'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          inbox.whenStable(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (e, _) => Text('$e', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            data: (snap) {
              final items = snap.items
                  .where((r) => !['declined', 'cancelled'].contains(r.stage))
                  .toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
              if (items.isEmpty) {
                return const VendorEmptyState(
                  message: 'No conversations yet. Marketplace requests appear here after an organizer invites you.',
                  icon: Icons.chat_bubble_outline,
                  compact: true,
                );
              }
              return Column(
                children: [
                  for (final r in items.take(6))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: EosColors.plum,
                        child: Text(
                          ((r.displayBuyerName).trim().isEmpty
                                  ? 'O'
                                  : r.displayBuyerName.trim()[0])
                              .toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        r.eventTitle ?? 'Event',
                        style: const TextStyle(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          r.displayBuyerName,
                          r.serviceLabel ?? 'Service',
                          if (r.serviceCode != null && r.serviceCode!.isNotEmpty) r.serviceCode!,
                          vendorCrmStageLabels[r.stage] ?? r.stage,
                        ].join(' · '),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (r.unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: EosColors.champagne,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${r.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const Icon(Icons.chevron_right, color: Colors.white54),
                        ],
                      ),
                      onTap: () {
                        // Canonical path: Events shell tab → Event Ops workspace.
                        // Do NOT push GoRouter `/vendor/events` (route does not exist).
                        ref.read(vendorEventWorkspaceNavProvider.notifier).open(
                              eventId: r.eventExternalRef ?? r.eventId,
                              eventUuid: r.eventId,
                              requestId: r.id,
                              initialTabIndex: 3, // Conversation
                            );
                        tabController.select(1);
                      },
                    ),
                ],
              );
            },
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
          if (clients.isEmpty)
            const VendorEmptyState(
              message: 'No CRM clients yet.',
              icon: Icons.people_outline,
              compact: true,
            )
          else
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
          if (team.isEmpty)
            const VendorEmptyState(
              message: 'No team assignments yet.',
              icon: Icons.badge_outlined,
              compact: true,
            )
          else
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
          if (notifications.isEmpty)
            const VendorEmptyState(
              message: 'No notifications yet.',
              icon: Icons.notifications_none_outlined,
              compact: true,
            )
          else
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
}
