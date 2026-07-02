import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ai_platform_engine.dart';
import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';

class CopilotWorkspaceScreen extends ConsumerStatefulWidget {
  const CopilotWorkspaceScreen({super.key});

  @override
  ConsumerState<CopilotWorkspaceScreen> createState() => _CopilotWorkspaceScreenState();
}

class _CopilotWorkspaceScreenState extends ConsumerState<CopilotWorkspaceScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, String>> _searchResults = [];

  late TabController _copilotTabsController;

  @override
  void initState() {
    super.initState();
    _copilotTabsController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _copilotTabsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(aiPlatformEngineProvider);
    final briefing = engine.briefing.generateBriefing();
    final filteredRecs = engine.getFilteredRecommendations();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Morning Executive Briefing Console
        _buildExecutiveBriefing(briefing),
        const SizedBox(height: 24),

        // Ask Owambe NLP Semantic Search Bar
        _buildSemanticSearch(engine),
        const SizedBox(height: 24),

        TabBar(
          controller: _copilotTabsController,
          tabs: const [
            Tab(text: 'Recommendations & Decisions'),
            Tab(text: 'Metric Predictions'),
            Tab(text: 'Detected Anomalies'),
            Tab(text: 'Knowledge Graph'),
            Tab(text: 'Automation Advisor'),
          ],
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 600,
          child: TabBarView(
            controller: _copilotTabsController,
            children: [
              // Tab 1: Recommendations
              _buildRecommendationsTab(engine, filteredRecs),

              // Tab 2: Predictions
              _buildPredictionsTab(engine),

              // Tab 3: Anomalies
              _buildAnomaliesTab(engine),

              // Tab 4: Knowledge Graph
              _buildKnowledgeGraphTab(engine),

              // Tab 5: Automation Advisor
              _buildAutomationAdvisorTab(engine),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExecutiveBriefing(Map<String, dynamic> briefing) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Executive Platform Morning Briefing Digest', style: context.eosText.headlineMedium),
                    const SizedBox(height: 4),
                    Text('Aggregated Decision Intelligence operations summary', style: context.eosText.bodySmall),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.greenAccent),
                  ),
                  child: Text(
                    'Health Index: ${briefing['healthScore']}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildBriefingItem('Financial Outlook', briefing['revenueGrowth'], briefing['commerceSummary'], Colors.green),
                _buildBriefingItem('Security Posture', briefing['riskLevel'], briefing['securitySummary'], Colors.red),
                _buildBriefingItem('Workflow Operations', 'Optimal', briefing['operationsSummary'], Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBriefingItem(String section, String stats, String details, Color color) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(section, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(stats, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Text(details, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSemanticSearch(AiPlatformEngine engine) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ask Owambe AI Semantic Search Console', style: context.eosText.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _searchResults = engine.searchEngine.search(val);
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Enter NLP query e.g. "Show pending vendors", "Why did refunds increase"',
                      prefixIcon: Icon(Icons.psychology),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Resolved semantic entities results:', style: context.eosText.bodySmall),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length,
                itemBuilder: (context, idx) {
                  final res = _searchResults[idx];
                  return ListTile(
                    leading: const Icon(Icons.link, color: Colors.blue),
                    title: Text(res['label']!),
                    subtitle: Text('Type: ${res['type']} | Context: ${res['snippet']}'),
                    trailing: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Redirecting to deep-link: ${res['link']}')),
                        );
                      },
                      child: const Text('Go to Workspace'),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsTab(AiPlatformEngine engine, List<AiRecommendation> recs) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prescriptive AI Decision Recommendations (Explainable AI)', style: context.eosText.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: recs.length,
                itemBuilder: (context, idx) {
                  final rec = recs[idx];
                  final isExecuted = rec.status == 'executed';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.eosColors.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          rec.category == 'security'
                              ? Icons.security
                              : (rec.category == 'commerce' ? Icons.payments : Icons.settings),
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(rec.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(
                                    'Confidence: ${(rec.confidenceScore * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(rec.reasoning),
                              const SizedBox(height: 8),
                              Text('• Impact: ${rec.businessImpact}'),
                              Text('• Required permission: ${rec.requiredPermission}'),
                              const SizedBox(height: 8),
                              Text(
                                'Next suggested workflow: ${rec.suggestedAction}',
                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueAccent),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed: isExecuted
                                  ? null
                                  : () {
                                      engine.executeDecision(rec.id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Decision trigger sent to Workflow Engine for approval.')),
                                      );
                                    },
                              child: Text(isExecuted ? 'Approved/Sent' : 'Execute'),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: isExecuted ? null : () => engine.dismissDecision(rec.id),
                              child: const Text('Dismiss'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionsTab(AiPlatformEngine engine) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Metric Forecast Predictions & Demand Curves', style: context.eosText.titleMedium),
            const SizedBox(height: 12),
            for (final pred in engine.predictions)
              ListTile(
                leading: const Icon(Icons.trending_up, color: Colors.green),
                title: Text('Key: ${pred.metricKey.toUpperCase()}'),
                subtitle: Text('Target Date: ${pred.targetDate.toString().split(' ').first}'),
                trailing: Text(
                  'Forecast: ${pred.forecastValue}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnomaliesTab(AiPlatformEngine engine) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Operational Anomaly Event Feeds', style: context.eosText.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: engine.anomalies.length,
                itemBuilder: (context, idx) {
                  final anom = engine.anomalies[idx];
                  return ListTile(
                    leading: Icon(
                      Icons.warning,
                      color: anom.severity == 'high' ? Colors.red : Colors.orange,
                    ),
                    title: Text(anom.description),
                    subtitle: Text('Source: ${anom.sourceEngine} | Time: ${anom.createdAt.toString().split('.').first}'),
                    trailing: EosFinanceChip(
                      label: anom.severity.toUpperCase(),
                      compact: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKnowledgeGraphTab(AiPlatformEngine engine) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enterprise Knowledge Graph Mappings', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: engine.knowledge.knowledgeGraph.keys.map((node) {
                  final children = engine.knowledge.knowledgeGraph[node]!;
                  return Container(
                    width: 260,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.eosColors.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(node, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Graph Links: ${children.join(' → ')}', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomationAdvisorTab(AiPlatformEngine engine) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Automation Advisor Optimization suggestions', style: context.eosText.titleMedium),
            const SizedBox(height: 16),
            for (final opp in engine.advisor.getAutomationOpportunities())
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                title: Text(opp),
              ),
          ],
        ),
      ),
    );
  }
}
