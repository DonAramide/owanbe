import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/workflow_engine.dart';
import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';

class WorkflowStudioScreen extends ConsumerStatefulWidget {
  const WorkflowStudioScreen({super.key});

  @override
  ConsumerState<WorkflowStudioScreen> createState() => _WorkflowStudioScreenState();
}

class _WorkflowStudioScreenState extends ConsumerState<WorkflowStudioScreen> with SingleTickerProviderStateMixin {
  WorkflowDefinition? _selectedWorkflow;
  WorkflowInstance? _simulationInstance;
  late TabController _studioTabsController;

  // Simulator Context Mocks
  double _mockAmount = 1200000.00;
  bool _mockVendorVerified = true;
  bool _mockEscrowBalance = true;

  @override
  void initState() {
    super.initState();
    _studioTabsController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _studioTabsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(workflowEngineProvider);
    final stats = engine.analytics.calculateAnalytics(engine.instances, engine.stateMachine.history);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Executive Workflow Header
        _buildExecutiveHeader(stats),
        const SizedBox(height: 24),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Workflow Templates Library
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
                          Text('Workflow Library', style: context.eosText.titleMedium),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.blue),
                            onPressed: () => _showCreateWorkflowDialog(context, engine),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: engine.definitions.length,
                        itemBuilder: (context, idx) {
                          final def = engine.definitions[idx];
                          final active = _selectedWorkflow?.id == def.id;
                          return ListTile(
                            selected: active,
                            title: Text(def.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Key: ${def.key} | v${def.versionNumber}'),
                            trailing: EosFinanceChip(
                              label: def.status.toUpperCase(),
                              compact: true,
                            ),
                            onTap: () {
                              setState(() {
                                _selectedWorkflow = def;
                                _simulationInstance = null;
                              });
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),

            // Right Column: Workflow Designer Workspace 360
            Expanded(
              flex: 4,
              child: _selectedWorkflow == null
                  ? EosSurfaceCard(
                      child: Container(
                        height: 500,
                        alignment: Alignment.center,
                        child: const Text('Select a business process from the library to launch Studio Designer'),
                      ),
                    )
                  : _buildDesigner360(engine, _selectedWorkflow!, stats),
            ),
          ],
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
            Text('Enterprise Workflow & Process Platform', style: context.eosText.headlineMedium),
            const SizedBox(height: 4),
            Text('Configure approvals, SLAs, escalations, assignments, and notifications dynamically', style: context.eosText.bodySmall),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildHeaderStat('Active Processes', '${stats['totalWorkflows']}', Icons.account_tree, Colors.blue),
                _buildHeaderStat('Completed', '${stats['completedWorkflows']}', Icons.task_alt, Colors.green),
                _buildHeaderStat('SLA Violations', '${stats['slaViolations']}', Icons.alarm_off, Colors.red),
                _buildHeaderStat('Avg Duration', '${stats['averageApprovalTime']}', Icons.timer, Colors.orange),
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

  Widget _buildDesigner360(WorkflowEngine engine, WorkflowDefinition def, Map<String, dynamic> stats) {
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(def.label, style: context.eosText.titleLarge),
                    Text(def.description, style: context.eosText.bodySmall),
                  ],
                ),
                Text('Version ${def.versionNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          TabBar(
            controller: _studioTabsController,
            tabs: const [
              Tab(text: 'Visual Designer'),
              Tab(text: 'SLA & Automation'),
              Tab(text: 'Simulation Sandbox'),
              Tab(text: 'Analytics & AI Advisor'),
            ],
          ),
          Container(
            height: 400,
            padding: const EdgeInsets.all(16),
            child: TabBarView(
              controller: _studioTabsController,
              children: [
                // Visual Designer Tab (Visual graph state representation)
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Workflow State Transition Graph Map', style: context.eosText.titleSmall),
                      const SizedBox(height: 16),
                      Center(
                        child: Column(
                          children: def.states.keys.map((state) {
                            final label = def.states[state]['label'];
                            return Column(
                              children: [
                                Container(
                                  width: 220,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade900,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blueAccent),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                      Text('Key: $state', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_downward, color: Colors.blueAccent, size: 24),
                              ],
                            );
                          }).toList()..removeLast(),
                        ),
                      ),
                    ],
                  ),
                ),

                // SLA & Automation Configs Tab
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SLA Escalation Mapping Rules', style: context.eosText.titleSmall),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.alarm, color: Colors.blue),
                        title: const Text('Review SLA threshold'),
                        subtitle: const Text('Standard review states enforce 4 hours resolve timers.'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.warning, color: Colors.orange),
                        title: const Text('Escalation Protocol'),
                        subtitle: const Text('Breached task automatically switches ownership to supervisor role queue.'),
                      ),
                      const Divider(),
                      Text('Transition Automations Pipeline Actions', style: context.eosText.titleSmall),
                      const SizedBox(height: 8),
                      for (final tr in def.transitions)
                        ListTile(
                          dense: true,
                          title: Text('Transition: ${tr['trigger'].toUpperCase()} (${tr['from']} -> ${tr['to']})'),
                          subtitle: Text('Automation Pipeline actions: ${tr['actions']} | Assignment strategy: ${tr['assignment']}'),
                        ),
                    ],
                  ),
                ),

                // Simulation Sandbox Tab
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Interactive Transition Simulator Sandbox', style: context.eosText.titleSmall),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Spawn Simulation Instance'),
                        onPressed: () {
                          final inst = engine.startWorkflow(
                            workflowKey: def.key,
                            entityId: 'sim_entity_99',
                            context: {
                              'amount': _mockAmount,
                              'vendor_verified': _mockVendorVerified,
                              'escrow_balance': _mockEscrowBalance,
                            },
                          );
                          setState(() {
                            _simulationInstance = inst;
                          });
                        },
                      ),
                      if (_simulationInstance != null) ...[
                        const SizedBox(height: 12),
                        Text('Current Simulation State: ${_simulationInstance!.currentState.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Assigned To: ${_simulationInstance!.assignedTo ?? "Unassigned (System Routing Queue)"}'),
                        const SizedBox(height: 12),
                        Row(
                          children: def.transitions
                              .where((t) => t['from'] == _simulationInstance!.currentState)
                              .map((tr) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ElevatedButton(
                                onPressed: () {
                                  final success = engine.triggerTransition(
                                    instanceId: _simulationInstance!.id,
                                    trigger: tr['trigger'],
                                    performedBy: 'Simulation Administrator',
                                    reason: 'Sandbox testing run',
                                  );
                                  if (!success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Transition blocked by Guard Rules! Verify logic settings.')),
                                    );
                                  } else {
                                    setState(() {
                                      _simulationInstance = engine.instances.firstWhere((i) => i.id == _simulationInstance!.id);
                                    });
                                  }
                                },
                                child: Text('Trigger ${tr['trigger']}'),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Text('Configure Sandbox variables:', style: context.eosText.bodySmall),
                        Row(
                          children: [
                            Text('Vendor verified:'),
                            Switch(
                              value: _mockVendorVerified,
                              onChanged: (val) {
                                setState(() {
                                  _mockVendorVerified = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Analytics & AI Advisor Tab
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Workflow Performance Stats', style: context.eosText.titleSmall),
                      const SizedBox(height: 8),
                      Text('• Average Resolve Speed: ${stats['averageApprovalTime']}'),
                      Text('• SLA Breach rate: ${stats['slaViolations']} occurrences'),
                      Text('• System-wide Rejection rate: ${stats['rejectionRate']}'),
                      const Divider(),
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                          const SizedBox(width: 8),
                          Text('AI Advisor Insights & Optimizations', style: context.eosText.titleSmall),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Bottleneck Detection: ${engine.analytics.generateAiAdvice(def.key)['bottleneck']}'),
                      Text('Predicted Duration: ${engine.analytics.generateAiAdvice(def.key)['predictedCompletionTime']}'),
                      const SizedBox(height: 8),
                      Text('Automation Advice:'),
                      for (final suggestion in engine.analytics.generateAiAdvice(def.key)['automationOpportunities'] as List<String>)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb, size: 14, color: Colors.purple),
                              const SizedBox(width: 8),
                              Expanded(child: Text(suggestion)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateWorkflowDialog(BuildContext context, WorkflowEngine engine) {
    final keyCtrl = TextEditingController();
    final labelCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Configure Extensible Workflow'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyCtrl,
                decoration: const InputDecoration(labelText: 'Workflow Key (e.g. escrow_release)'),
              ),
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(labelText: 'Display Name (e.g. Payout Escrow Clearances)'),
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
                final label = labelCtrl.text.trim();
                if (key.isEmpty || label.isEmpty) return;

                engine.registerWorkflow(WorkflowDefinition(
                  id: 'wf_${DateTime.now().millisecondsSinceEpoch}',
                  key: key,
                  label: label,
                  description: 'Dynamic extensible process workflow',
                  versionNumber: 1,
                  status: 'published',
                  states: {
                    'draft': {'label': 'Draft'},
                    'approved': {'label': 'Approved'},
                  },
                  transitions: [],
                ));
                Navigator.of(context).pop();
              },
              child: const Text('Publish Workflow'),
            ),
          ],
        );
      },
    );
  }
}
