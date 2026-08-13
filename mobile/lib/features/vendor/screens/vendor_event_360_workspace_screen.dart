import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/platform_message_guard.dart';
import '../../../eos/eos.dart';
import '../../../portals/customer/models/vendor_crm_models.dart';
import '../../../portals/customer/providers/vendor_crm_providers.dart';
import '../providers/vendor_event_workspace_nav.dart';
import '../providers/vendor_inbox_integration.dart';
import '../vendor_os_demo_mode.dart';
import '../widgets/vendor_empty_state.dart';
import '../../../platform/governance/governance_enforcement_engine.dart';

class VendorEvent360WorkspaceScreen extends ConsumerStatefulWidget {
  const VendorEvent360WorkspaceScreen({
    super.key,
    required this.eventId,
    required this.onBack,
    this.eventUuid,
    this.requestId,
    this.initialTabIndex,
  });

  final String eventId;
  final VoidCallback onBack;
  /// Canonical events.id UUID when known (matches vendor_event_requests.event_id).
  final String? eventUuid;
  /// Shared Vendor Request conversation identity (Event → Request → Conversation).
  final String? requestId;
  /// Optional initial tab (Conversation = 3).
  final int? initialTabIndex;

  @override
  ConsumerState<VendorEvent360WorkspaceScreen> createState() =>
      _VendorEvent360WorkspaceScreenState();
}

class _VendorEvent360WorkspaceScreenState
    extends ConsumerState<VendorEvent360WorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _checkedIn = false;
  bool _setupStarted = false;
  double _setupProgress = 0.25;
  final List<String> _completedDeliverables = [];
  late final List<String> _damPhotos =
      VendorOsDemoMode.isEnabled ? ['Oriental_Setup_Morning.jpg'] : <String>[];
  late final List<String> _damDocuments =
      VendorOsDemoMode.isEnabled ? ['Service_Contract_Oriental.pdf'] : <String>[];
  late final List<String> _timelineEvents = VendorOsDemoMode.isEnabled
      ? [
          '08:30 AM - Event workspace initialized.',
          '09:00 AM - Kitchen preparation started at HQ.',
        ]
      : <String>[];
  final List<String> _incidentLog = [];
  final _messageController = TextEditingController();
  final _incidentController = TextEditingController();
  bool _sendingMessage = false;
  /// User-selected service request when opened without requestId and multiple exist.
  String? _selectedRequestId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTabIndex;
    _tabController = TabController(
      length: 14,
      vsync: this,
      initialIndex: (initial != null && initial >= 0 && initial < 14) ? initial : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _incidentController.dispose();
    super.dispose();
  }

  void _addTimelineEvent(String message) {
    final now = TimeOfDay.now();
    final stamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      _timelineEvents.insert(0, '$stamp - $message');
    });
  }

  /// Local panel — never depends on EosTokens (safe inside any Theme).
  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  String? get _resolvedRequestId {
    if (widget.requestId != null && widget.requestId!.isNotEmpty) return widget.requestId;
    if (_selectedRequestId != null && _selectedRequestId!.isNotEmpty) return _selectedRequestId;
    return null;
  }

  String? _effectiveRequestId(List<VendorRequest> items) {
    final explicit = _resolvedRequestId;
    if (explicit != null) return explicit;
    final matches = vendorRequestsForEventKey(
      items,
      eventKey: widget.eventId,
      eventUuid: widget.eventUuid,
    );
    if (matches.length == 1) return matches.first.id;
    return null;
  }

  VendorRequest? _activeRequest(List<VendorRequest> items, String? requestId) {
    if (requestId == null) return null;
    return findVendorRequestById(items, requestId);
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(vendorInboxSnapshotProvider);
    final items = inbox.valueOrNull?.items ?? const [];
    final requestId = _effectiveRequestId(items);
    final request = _activeRequest(items, requestId);
    final pendingChoices = requestId == null
        ? vendorRequestsForEventKey(
            items,
            eventKey: widget.eventId,
            eventUuid: widget.eventUuid,
          )
        : const <VendorRequest>[];

    if (requestId == null && pendingChoices.length > 1) {
      return Scaffold(
        backgroundColor: EosColors.plumDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: widget.onBack,
          ),
          title: const Text(
            'Select service request',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: _buildServiceRequestPicker(pendingChoices),
      );
    }

    // Do NOT wrap with ThemeData.dark() — that strips EosTokens and crashes
    // any widget using context.eos / EosSurfaceCard.
    return Scaffold(
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
            Text(
              'Event Operations Center',
              style: context.eosText.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              request?.eventTitle ?? 'Event ID: ${widget.eventId}',
              style: const TextStyle(color: EosColors.champagne, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (request?.serviceLabel != null)
              Text(
                '${request!.serviceLabel} · Request #${requestId!.substring(0, 8)}',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
          _buildOverviewTab(request),
          _buildTimelineTab(),
          _buildConversationTab(requestId),
          _buildContractTab(requestId),
          _buildEscrowTab(requestId),
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
    );
  }

  Widget _buildOperationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'OPERATIONAL CONTROLS',
                style: TextStyle(
                  color: EosColors.champagne,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _checkedIn
                          ? null
                          : () {
                              setState(() => _checkedIn = true);
                              _addTimelineEvent('Vendor crew checked in at venue.');
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _checkedIn ? Colors.grey : Colors.green,
                        foregroundColor: Colors.white,
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
                              setState(() => _setupStarted = true);
                              _addTimelineEvent('Setup process started.');
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _setupStarted ? Colors.purple : Colors.blue,
                        foregroundColor: Colors.white,
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
                    const Text(
                      'Setup Progression',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      '${(_setupProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: EosColors.champagne,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _setupProgress,
                  activeColor: EosColors.champagne,
                  onChanged: (v) => setState(() => _setupProgress = v),
                  onChangeEnd: (v) {
                    _addTimelineEvent(
                      'Setup progression updated to ${(v * 100).toStringAsFixed(0)}%.',
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _panel(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified, color: Colors.greenAccent),
                title: const Text(
                  'Request Milestone Approval',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Notify organizer to approve completed work',
                  style: TextStyle(color: Colors.white54),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  _addTimelineEvent('Milestone approval request sent to organizer.');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Milestone approval request sent.')),
                  );
                },
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_open, color: Colors.amberAccent),
                title: const Text(
                  'Request Escrow Release',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Trigger escrow release process',
                  style: TextStyle(color: Colors.white54),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  _addTimelineEvent('Escrow release request initiated.');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Escrow release request sent.')),
                  );
                },
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.report_problem, color: Colors.redAccent),
                title: const Text(
                  'Report Issue / Incident',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Log unexpected logistics or delays',
                  style: TextStyle(color: Colors.white54),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: _showReportIncidentSheet,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(VendorRequest? request) {
    if (request == null) {
      return const VendorEmptyState(
        message: 'Event details will appear when this booking has a live vendor request.',
        icon: Icons.event_note_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Event Details',
                style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(request.eventTitle ?? 'Event', style: const TextStyle(color: Colors.white70)),
              Text('Organizer: ${request.organizerName ?? '—'}', style: const TextStyle(color: Colors.white70)),
              Text('Service: ${request.serviceLabel ?? '—'}', style: const TextStyle(color: Colors.white70)),
              Text(
                'Booking: ${vendorCrmStageLabels[request.stage] ?? request.stage}',
                style: const TextStyle(color: Colors.white70),
              ),
              if (request.scheduledAt != null)
                Text('Scheduled: ${request.scheduledAt}', style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'EVENT TIMELINE LOGGER',
          style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_timelineEvents.isEmpty)
          const VendorEmptyState(
            message: 'No timeline activity yet.',
            icon: Icons.timeline,
            compact: true,
          )
        else
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

  Future<void> _sendConversationMessage(String requestId) async {
    if (_sendingMessage) return;
    final timeline = ref.read(vendorRequestTimelineProvider(requestId)).valueOrNull;
    final request = timeline?.request;
    if (request != null && !request.canMessage) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messaging opens after you accept this request')),
      );
      return;
    }
    if (!GovernanceEnforcementEngine.canMessage(widget.eventId)) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final blocked = PlatformMessageGuard.blockReason(text);
    if (blocked != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(blocked)));
      return;
    }

    setState(() => _sendingMessage = true);
    try {
      await ref.read(vendorCrmApiProvider).postMessage(requestId, message: text);
      refreshVendorCrm(ref);
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.contains('PLATFORM_BYPASS') || msg.contains('keep communication')
                  ? PlatformMessageGuard.keepInOwanbe
                  : 'Message failed: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  Widget _buildConversationTab(String? requestId) {
    if (requestId == null) {
      return const VendorEmptyState(
        message: 'No vendor request linked to this event yet. Accept a marketplace request to open the shared conversation.',
        icon: Icons.chat_bubble_outline,
      );
    }

    final timelineAsync = ref.watch(vendorRequestTimelineProvider(requestId));
    final requestStage = timelineAsync.valueOrNull?.request;
    final canMessage = requestStage?.canMessage == true &&
        GovernanceEnforcementEngine.canMessage(widget.eventId);

    return timelineAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => VendorEmptyState(message: 'Could not load conversation.\n$e', icon: Icons.error_outline),
      data: (timeline) {
        final request = timeline.request;
        final messages = timeline.conversationMessages;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.eventTitle ?? 'Event',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        request.serviceLabel ?? 'Service',
                        'Booking: ${vendorCrmStageLabels[request.stage] ?? request.stage}',
                      ].join(' · '),
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    Text(
                      'Organizer: ${request.organizerName ?? 'Organizer'}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Discuss service requirements only. Payment stays in Owanbe.',
                      style: TextStyle(color: EosColors.champagne, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: messages.isEmpty && request.message.trim().isEmpty
                  ? const VendorEmptyState(
                      message: 'No messages yet. Start the operational conversation.',
                      icon: Icons.chat_bubble_outline,
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (request.message.trim().isNotEmpty)
                          _messageBubble(
                            sender: 'Organizer',
                            text: request.message.trim(),
                            isMe: false,
                          ),
                        for (final m in messages)
                          if (m.note != null &&
                              m.note!.trim().isNotEmpty &&
                              m.note != 'Request created')
                            _messageBubble(
                              sender: m.actorType == 'vendor' ? 'Vendor' : 'Organizer',
                              text: m.note!.trim(),
                              isMe: m.actorType == 'vendor',
                            ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      enabled: canMessage && !_sendingMessage,
                      decoration: InputDecoration(
                        hintText: canMessage
                            ? 'Type operational message...'
                            : request.canMessage
                                ? 'Chat disabled by platform policy'
                                : 'Accept this request to start messaging',
                        hintStyle: const TextStyle(color: Colors.white38),
                        fillColor: Colors.white10,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendConversationMessage(requestId),
                    ),
                  ),
                  IconButton(
                    icon: _sendingMessage
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: EosColors.champagne),
                          )
                        : const Icon(Icons.send, color: EosColors.champagne),
                    onPressed: canMessage && !_sendingMessage
                        ? () => _sendConversationMessage(requestId)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _messageBubble({required String sender, required String text, required bool isMe}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isMe ? EosColors.plum : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sender,
              style: TextStyle(
                color: isMe ? EosColors.champagne : Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildContractTab(String? requestId) {
    if (requestId == null) {
      return const VendorEmptyState(message: 'No contracts yet.', icon: Icons.feed_outlined);
    }
    final timelineAsync = ref.watch(vendorRequestTimelineProvider(requestId));
    return timelineAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => VendorEmptyState(message: '$e', icon: Icons.error_outline),
      data: (timeline) {
        final r = timeline.request;
        final payout = r.vendorPayoutMinor ?? r.latestOfferMinor;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Service Contract',
                    style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Event: ${r.eventTitle ?? '—'}', style: const TextStyle(color: Colors.white70)),
                  Text('Service: ${r.serviceLabel ?? '—'}', style: const TextStyle(color: Colors.white70)),
                  Text(
                    'Status: ${vendorCrmContractLabels[timeline.contractStatus] ?? timeline.contractStatus}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    'Booking: ${vendorCrmStageLabels[r.stage] ?? r.stage}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (r.scheduledAt != null)
                    Text('Date/Time: ${r.scheduledAt}', style: const TextStyle(color: Colors.white70)),
                  if (payout != null)
                    Text(
                      'Agreed vendor payout: ${formatRevenue(payout)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'Contract terms are managed inside Owanbe. Completion confirmation releases escrow per platform rules.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEscrowTab(String? requestId) {
    if (requestId == null) {
      return const VendorEmptyState(message: 'No escrow activity yet.', icon: Icons.lock_outline);
    }
    final timelineAsync = ref.watch(vendorRequestTimelineProvider(requestId));
    return timelineAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => VendorEmptyState(message: '$e', icon: Icons.error_outline),
      data: (timeline) {
        final r = timeline.request;
        final status = timeline.escrowStatus;
        final payout = r.vendorPayoutMinor ?? r.latestOfferMinor;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Owanbe Escrow',
                    style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Service: ${r.serviceLabel ?? '—'}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (r.serviceCode != null && r.serviceCode!.isNotEmpty)
                    Text(
                      'Service Code: ${r.serviceCode}',
                      style: const TextStyle(color: EosColors.champagne),
                    ),
                  Text(
                    'Escrow State: ${vendorCrmEscrowLabels[status] ?? status.toUpperCase()}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (payout != null)
                    Text(
                      'Agreed Vendor Payout: ${formatRevenue(payout)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  if (r.fundingStatus == 'funded') ...[
                    const SizedBox(height: 8),
                    const Text('✓ Agreement Accepted', style: TextStyle(color: Colors.greenAccent)),
                    const Text('✓ Booking Funded', style: TextStyle(color: Colors.greenAccent)),
                    const Text('✓ Payout Secured', style: TextStyle(color: Colors.greenAccent)),
                    const SizedBox(height: 4),
                    const Text(
                      'Release: after organizer confirms completion',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const Text('Status: SECURED', style: TextStyle(color: EosColors.champagne)),
                  ],
                  if (r.fundingStatus == 'released')
                    const Text(
                      'Payout released to Vendor Wallet',
                      style: TextStyle(color: Colors.greenAccent),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'Organizer funds through the Owanbe wallet into escrow. Do not accept direct payment instructions in chat.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  if (['accepted', 'scheduled', 'arrived'].contains(r.stage) &&
                      r.fundingStatus == 'funded') ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () async {
                        try {
                          await ref.read(vendorCrmApiProvider).markComplete(r.id);
                          refreshVendorCrm(ref);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Service marked complete — awaiting organizer confirmation',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        }
                      },
                      child: const Text('Mark Service Complete'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeliverablesTab() {
    final list = VendorOsDemoMode.isEnabled
        ? ['Buffet Setup', 'Table centerpieces & Linens', 'Food Warmer systems']
        : <String>[];
    if (list.isEmpty) {
      return const VendorEmptyState(
        message: 'No deliverables yet.',
        icon: Icons.inventory_2_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final item in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _panel(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item, style: const TextStyle(color: Colors.white)),
                value: _completedDeliverables.contains(item),
                activeColor: EosColors.champagne,
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
          ),
      ],
    );
  }

  Widget _buildInventoryTab() {
    if (!VendorOsDemoMode.isEnabled) {
      return const VendorEmptyState(
        message: 'No inventory assigned yet.',
        icon: Icons.inventory_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _panel(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assigned Assets & Equipment',
                style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• 10 Chafing dishes (Assigned)', style: TextStyle(color: Colors.white70)),
              Text('• 1 Van transport container (Checked in)', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCrewTab() {
    if (!VendorOsDemoMode.isEnabled) {
      return const VendorEmptyState(
        message: 'No crew assignments yet.',
        icon: Icons.badge_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _panel(
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('C')),
            title: Text(
              'Chinedu Egwu (Kitchen Crew Lead)',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'GPS Status: Arrived at Oriental',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistsTab() {
    if (!VendorOsDemoMode.isEnabled) {
      return const VendorEmptyState(
        message: 'No checklists yet.',
        icon: Icons.checklist_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _panel(
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Pre-arrival checklist verification',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'All temperature checks passed',
              style: TextStyle(color: Colors.white54),
            ),
            trailing: Icon(Icons.check, color: Colors.green),
          ),
        ),
      ],
    );
  }

  Widget _buildIncidentLogTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(
          onPressed: _showReportIncidentSheet,
          style: ElevatedButton.styleFrom(
            backgroundColor: EosColors.champagne,
            foregroundColor: EosColors.plumDark,
          ),
          icon: const Icon(Icons.add),
          label: const Text('Log New Incident'),
        ),
        const SizedBox(height: 12),
        if (_incidentLog.isEmpty)
          const VendorEmptyState(
            message: 'No incidents logged.',
            icon: Icons.report_gmailerrorred_outlined,
            compact: true,
          )
        else
          for (final inc in _incidentLog)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _panel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.error_outline, color: Colors.redAccent),
                  title: Text(inc, style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildPhotosTab() {
    if (_damPhotos.isEmpty) {
      return const VendorEmptyState(
        message: 'No photos uploaded yet.',
        icon: Icons.photo_library_outlined,
      );
    }
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 3,
      children: [
        for (final p in _damPhotos)
          Card(
            color: Colors.white10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Icon(Icons.photo, size: 40, color: EosColors.champagne),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    color: Colors.black54,
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      p,
                      style: const TextStyle(fontSize: 9, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDocumentsTab() {
    if (_damDocuments.isEmpty) {
      return const VendorEmptyState(
        message: 'No documents yet.',
        icon: Icons.description_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final doc in _damDocuments)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _panel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description, color: EosColors.champagne),
                title: Text(doc, style: const TextStyle(color: Colors.white)),
                subtitle: const Text(
                  'Digital Asset Management (DAM) secure storage',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAuditTab() {
    if (!VendorOsDemoMode.isEnabled) {
      return const VendorEmptyState(
        message: 'No audit entries yet.',
        icon: Icons.security_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _panel(
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.security, color: EosColors.champagne),
            title: Text('Workspace Access Logged', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              'IP 192.168.1.5 checked setup metrics',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ),
      ],
    );
  }

  void _showReportIncidentSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: EosColors.plumDark,
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
            Text(
              'Report Incident',
              style: context.eosText.titleLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _incidentController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Describe layout or power delay issues...',
                hintStyle: TextStyle(color: Colors.white38),
                fillColor: Colors.white10,
                filled: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: EosColors.champagne,
                foregroundColor: EosColors.plumDark,
              ),
              onPressed: () {
                final txt = _incidentController.text.trim();
                if (txt.isEmpty) return;
                setState(() => _incidentLog.add(txt));
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

  Widget _buildServiceRequestPicker(List<VendorRequest> choices) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'This event has multiple service requests. Select one to open its workspace and conversation.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        for (final r in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              tileColor: Colors.white.withValues(alpha: 0.04),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white10),
              ),
              title: Text(
                r.serviceLabel ?? 'Service',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  r.eventTitle ?? 'Event',
                  vendorCrmStageLabels[r.stage] ?? r.stage,
                  if (r.displayAmountMinor != null) formatRevenue(r.displayAmountMinor!),
                ].join(' · '),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, color: EosColors.champagne),
              onTap: () => setState(() => _selectedRequestId = r.id),
            ),
          ),
      ],
    );
  }
}

/// Prompt vendor to pick a service-specific request when multiple exist for one event.
Future<VendorRequest?> showVendorServiceRequestPicker(
  BuildContext context, {
  required List<VendorRequest> requests,
  String? eventTitle,
}) {
  if (requests.isEmpty) return Future.value(null);
  if (requests.length == 1) return Future.value(requests.first);

  return showModalBottomSheet<VendorRequest>(
    context: context,
    backgroundColor: const Color(0xFF241B3F),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select service request',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (eventTitle != null && eventTitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(eventTitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
            const SizedBox(height: 8),
            const Text(
              'Each service has its own request thread. Choose which one to open.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),
            for (final r in requests)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  tileColor: Colors.white.withValues(alpha: 0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  title: Text(
                    r.serviceLabel ?? 'Service',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      vendorCrmStageLabels[r.stage] ?? r.stage,
                      if (r.displayAmountMinor != null) formatRevenue(r.displayAmountMinor!),
                    ].join(' · '),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: EosColors.champagne),
                  onTap: () => Navigator.pop(ctx, r),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Resolve and optionally prompt for a service-specific request id before opening Event 360.
Future<String?> resolveVendorRequestIdForWorkspace(
  BuildContext context,
  WidgetRef ref, {
  required String eventKey,
  String? eventUuid,
  String? requestId,
  String? eventTitle,
}) async {
  final inbox = ref.read(vendorInboxSnapshotProvider).valueOrNull;
  final items = inbox?.items ?? const [];
  final resolution = resolveVendorRequestSelection(
    items,
    eventKey: eventKey,
    eventUuid: eventUuid,
    requestId: requestId,
  );

  if (resolution.hasRequest) return resolution.requestId;
  if (!resolution.needsSelection) return null;

  final picked = await showVendorServiceRequestPicker(
    context,
    requests: resolution.choices,
    eventTitle: eventTitle ?? resolution.choices.first.eventTitle,
  );
  return picked?.id;
}
