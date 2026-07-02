import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/communication_engine.dart';
import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';

class CommunicationCenterScreen extends ConsumerStatefulWidget {
  const CommunicationCenterScreen({super.key});

  @override
  ConsumerState<CommunicationCenterScreen> createState() => _CommunicationCenterScreenState();
}

class _CommunicationCenterScreenState extends ConsumerState<CommunicationCenterScreen> with SingleTickerProviderStateMixin {
  EcpTemplate? _selectedTemplate;
  String _selectedChannelFilter = 'all';
  late TabController _centerTabsController;

  // Template Variables Simulation Mocks
  final Map<String, dynamic> _mockVars = {
    'name': 'Adenike Adebayo',
    'code': '889102',
    'amount': '₦24,800,000.00',
    'bank': 'Access Bank Plc',
  };

  @override
  void initState() {
    super.initState();
    _centerTabsController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _centerTabsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(communicationEngineProvider);
    final stats = engine.analytics.calculateStats(engine.deliveryLogs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Operations Analytics Header
        _buildExecutiveHeader(stats),
        const SizedBox(height: 24),

        TabBar(
          controller: _centerTabsController,
          tabs: const [
            Tab(text: 'Templates 360'),
            Tab(text: 'Campaigns & Broadcasts'),
            Tab(text: 'Audience Builder'),
            Tab(text: 'Customer Journeys'),
            Tab(text: 'Delivery Log Queue'),
          ],
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 600,
          child: TabBarView(
            controller: _centerTabsController,
            children: [
              // Tab 1: Templates 360 Workspace
              _buildTemplatesWorkspace(engine),

              // Tab 2: Campaigns & Broadcasts
              _buildCampaignsWorkspace(engine),

              // Tab 3: Audience Builder
              _buildAudienceWorkspace(engine),

              // Tab 4: Customer Journeys
              _buildJourneysWorkspace(engine),

              // Tab 5: Delivery Log Queue
              _buildDeliveryLogsWorkspace(engine),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExecutiveHeader(Map<String, dynamic> stats) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enterprise Communication Control Center', style: context.eosText.headlineMedium),
            const SizedBox(height: 4),
            Text('Centralized dispatch hub for transactional templates, segmented marketing campaigns, and routing queues', style: context.eosText.bodySmall),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildHeaderStat('Delivery Rate', stats['deliveryRate'], Icons.task_alt, Colors.green),
                _buildHeaderStat('Open Rate', stats['openRate'], Icons.drafts, Colors.blue),
                _buildHeaderStat('Click Rate', stats['clickRate'], Icons.ads_click, Colors.purple),
                _buildHeaderStat('Operational Cost Savings', stats['costSavings'], Icons.monetization_on, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: context.eosColors.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: context.eosText.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(label, style: context.eosText.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesWorkspace(CommunicationEngine engine) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: EosSurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Message Templates', style: context.eosText.titleMedium),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: () => _showCreateTemplateDialog(context, engine),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: engine.templates.length,
                    itemBuilder: (context, idx) {
                      final tmpl = engine.templates[idx];
                      final active = _selectedTemplate?.id == tmpl.id;
                      return ListTile(
                        selected: active,
                        title: Text(tmpl.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Channel: ${tmpl.channel.toUpperCase()} | v${tmpl.versionNumber}'),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: () => setState(() => _selectedTemplate = tmpl),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: _selectedTemplate == null
              ? EosSurfaceCard(
                  child: Container(
                    height: 400,
                    alignment: Alignment.center,
                    child: const Text('Select a message template to configure variables and preview localization'),
                  ),
                )
              : EosSurfaceCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Template 360: ${_selectedTemplate!.key}', style: context.eosText.titleMedium),
                            EosFinanceChip(label: _selectedTemplate!.status.toUpperCase(), compact: true),
                          ],
                        ),
                        const Divider(height: 24),
                        Text('Supported Variables:', style: context.eosText.titleSmall),
                        Wrap(
                          spacing: 8,
                          children: _selectedTemplate!.variables.map((v) => Chip(label: Text(v))).toList(),
                        ),
                        const SizedBox(height: 16),
                        Text('Compiled Output Sandbox Previews:', style: context.eosText.titleSmall),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: context.eosColors.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Subject:', style: context.eosText.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                              Text(engine.templateParser.compile(_selectedTemplate!, _mockVars)['subject'] ?? 'N/A'),
                              const SizedBox(height: 8),
                              Text('Body Content:', style: context.eosText.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                              Text(engine.templateParser.compile(_selectedTemplate!, _mockVars)['body'] ?? ''),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCampaignsWorkspace(CommunicationEngine engine) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: EosSurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Campaign Programs', style: context.eosText.titleMedium),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: () => _showCreateCampaignDialog(context, engine),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final camp in engine.campaign.campaigns)
                    ListTile(
                      leading: const Icon(Icons.campaign, color: Colors.blue),
                      title: Text(camp['label']),
                      subtitle: Text('Segment: ${camp['segment']} | Template: ${camp['templateKey']}'),
                      trailing: EosFinanceChip(label: camp['status'].toUpperCase(), compact: true),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: EcpCampaignAdvisorCard(engine: engine),
        ),
      ],
    );
  }

  Widget _buildAudienceWorkspace(CommunicationEngine engine) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audience Query Segmentation Builder', style: context.eosText.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSegmentCard('All Active Vendors', 'Target: Registered vendor portal profiles', '3 Vendors', Icons.people),
                _buildSegmentCard('VIP Guest List', 'Target: VIP and early-bird ticket holders', '2 Customers', Icons.star),
                _buildSegmentCard('90-Day Inactive Users', 'Target: Users with stale logins activity logs', '0 Users', Icons.person_off),
              ],
            ),
            const Divider(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Add Segmentation Filter Rule'),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentCard(String title, String subtitle, String count, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: context.eosColors.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blueAccent),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 8),
            Text(count, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneysWorkspace(CommunicationEngine engine) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Visual Journey Builder & Automation Pipelines', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            for (final j in engine.journey.journeys)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(j['label'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: (j['steps'] as List<String>).map((step) {
                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade900,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(step, style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                              const Icon(Icons.arrow_right_alt, color: Colors.blueAccent),
                            ],
                          );
                        }).toList()..removeLast(),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryLogsWorkspace(CommunicationEngine engine) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Omnichannel Delivery Queue Log Ledger', style: context.eosText.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Recipient')),
                    DataColumn(label: Text('Template')),
                    DataColumn(label: Text('Channel')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Retries')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: engine.deliveryLogs.map((log) {
                    final isBlocked = log.status == 'blocked_by_preference';
                    return DataRow(cells: [
                      DataCell(Text(log.recipientId)),
                      DataCell(Text(log.templateKey)),
                      DataCell(Text(log.channel.toUpperCase())),
                      DataCell(EosFinanceChip(
                        label: log.status.toUpperCase(),
                        compact: true,
                      )),
                      DataCell(Text('${log.retryCount}/5')),
                      DataCell(
                        isBlocked
                            ? const Text('Opt-out Policy', style: TextStyle(color: Colors.grey, fontSize: 11))
                            : TextButton(
                                onPressed: () {
                                  engine.delivery.triggerRetry(log.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Dispatched retry event')),
                                  );
                                },
                                child: const Text('Retry'),
                              ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTemplateDialog(BuildContext context, CommunicationEngine engine) {
    final keyCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Configure Dynamic Template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyCtrl,
                decoration: const InputDecoration(labelText: 'Template Key'),
              ),
              TextField(
                controller: bodyCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Body template content (use {{name}} placeholders)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final key = keyCtrl.text.trim();
                final body = bodyCtrl.text.trim();
                if (key.isEmpty || body.isEmpty) return;

                engine.registerTemplate(EcpTemplate(
                  id: 'tmpl_${DateTime.now().millisecondsSinceEpoch}',
                  key: key,
                  channel: 'email',
                  versionNumber: 1,
                  status: 'published',
                  variables: ['name'],
                  content: {
                    'en': {'subject': 'Alert notification', 'body': body}
                  },
                ));
                Navigator.of(context).pop();
              },
              child: const Text('Publish Template'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateCampaignDialog(BuildContext context, CommunicationEngine engine) {
    // Campaign creation wizard dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Campaign Segment'),
        content: const Text('Create targeted broadcasts mapping saved Dynamic Audiences and template triggers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
}

class EcpCampaignAdvisorCard extends StatelessWidget {
  final CommunicationEngine engine;
  const EcpCampaignAdvisorCard({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final advice = engine.analytics.generateAiAdvice('camp_1');
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                SizedBox(width: 8),
                Text('AI Communication Advisor Insights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Divider(height: 24),
            Text('Recommended Send Window:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple.shade300)),
            Text(advice['bestSendTime']),
            const SizedBox(height: 16),
            Text('Optimized Channel Proposal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple.shade300)),
            Text(advice['preferredChannel']),
            const SizedBox(height: 16),
            Text('Subject Line Tuning Suggestions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple.shade300)),
            Text(advice['subjectSuggestion']),
            const SizedBox(height: 16),
            Text('Audience Exhaustion Factor:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple.shade300)),
            Text(advice['fatigueRisk']),
          ],
        ),
      ),
    );
  }
}
