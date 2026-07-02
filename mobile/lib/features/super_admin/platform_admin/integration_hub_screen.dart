import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/integration_engine.dart';
import '../../../eos/eos.dart';
import '../../../eos/layout/workspace/workspace_widgets.dart';

class IntegrationHubScreen extends ConsumerStatefulWidget {
  const IntegrationHubScreen({super.key});

  @override
  ConsumerState<IntegrationHubScreen> createState() => _IntegrationHubScreenState();
}

class _IntegrationHubScreenState extends ConsumerState<IntegrationHubScreen> with SingleTickerProviderStateMixin {
  final _webhookUrlController = TextEditingController(text: 'https://api.invify.com/hooks/owanbe');
  ApiKeyCredential? _generatedKey;
  late TabController _hubTabsController;

  @override
  void initState() {
    super.initState();
    _hubTabsController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _webhookUrlController.dispose();
    _hubTabsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(integrationEngineProvider);
    final stats = engine.monitoring.getOverallHealth(engine.integrations);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Executive Operations Header
        _buildExecutiveHeader(stats),
        const SizedBox(height: 24),

        TabBar(
          controller: _hubTabsController,
          tabs: const [
            Tab(text: 'Platform Registry'),
            Tab(text: 'API Gateway & SDKs'),
            Tab(text: 'Event Bus Broker'),
            Tab(text: 'Webhook Simulator'),
            Tab(text: 'Plugin Manager'),
          ],
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 600,
          child: TabBarView(
            controller: _hubTabsController,
            children: [
              // Tab 1: Platform Registry & Breakers
              _buildRegistryTab(engine),

              // Tab 2: API Gateway & SDKs
              _buildGatewayTab(engine),

              // Tab 3: Event Bus Broker
              _buildEventBusTab(engine),

              // Tab 4: Webhook Simulator
              _buildWebhookTab(engine),

              // Tab 5: Plugin Manager
              _buildPluginTab(engine),
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
            Text('Owambe Platform OS & Integration Hub', style: context.eosText.headlineMedium),
            const SizedBox(height: 4),
            Text('Enterprise Event Bus, OAuth Gateway proxies, plugin lifecycles, and third-party credential monitoring', style: context.eosText.bodySmall),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildHeaderStat('Gateway Latency', stats['gatewayLatency'], Icons.speed, Colors.green),
                _buildHeaderStat('Platform Health Score', '${stats['healthPercentage']}%', Icons.favorite, Colors.red),
                _buildHeaderStat('Active Connections', '${stats['activeSubscriptions']}', Icons.hub, Colors.blue),
                _buildHeaderStat('Daily API Traffic', stats['dailyVolume'], Icons.analytics, Colors.orange),
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

  Widget _buildRegistryTab(IntegrationEngine engine) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Integrations & Middleware Registry Services', style: context.eosText.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: engine.integrations.length,
                itemBuilder: (context, idx) {
                  final integration = engine.integrations[idx];
                  final isOffline = integration.circuitBreaker == 'open';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.eosColors.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.extension, color: isOffline ? Colors.red : Colors.green),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(integration.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('Latency: ${integration.metrics['latency']}ms | Health: ${integration.metrics['health']}%'),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            EosFinanceChip(
                              label: integration.circuitBreaker == 'closed' ? 'CLOSED (LIVE)' : 'OPEN (TRIPPED)',
                              compact: true,
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isOffline ? Colors.green : Colors.red,
                              ),
                              onPressed: () => engine.toggleBreaker(integration.key),
                              child: Text(isOffline ? 'Reset Breaker' : 'Trip Breaker'),
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

  Widget _buildGatewayTab(IntegrationEngine engine) {
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
                  Text('Gateway OAuth Credentials Generator', style: context.eosText.titleMedium),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.key),
                    label: const Text('Generate API Credentials'),
                    onPressed: () {
                      setState(() {
                        _generatedKey = engine.gateway.createKey(
                          'Developer Client Key',
                          ['events.read', 'marketplace.book'],
                        );
                      });
                    },
                  ),
                  if (_generatedKey != null) ...[
                    const Divider(height: 24),
                    Text('OAuth Client ID:', style: context.eosText.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text(_generatedKey!.clientId),
                    const SizedBox(height: 8),
                    Text('OAuth Client Secret (Copy):', style: context.eosText.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text(_generatedKey!.clientSecret),
                    const SizedBox(height: 8),
                    Text('Allowed Scopes: ${_generatedKey!.scopes.join(', ')}'),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: EosSurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Platform SDK Code Blueprint (Flutter Example)', style: context.eosText.titleMedium),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        engine.sdk.generateFlutterCode(_generatedKey?.clientSecret ?? 'your_api_key_placeholder'),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventBusTab(IntegrationEngine engine) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enterprise Event Bus Pub/Sub Monitoring Panel', style: context.eosText.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: engine.busEvents.length,
                itemBuilder: (context, idx) {
                  final event = engine.busEvents[idx];
                  return ListTile(
                    leading: const Icon(Icons.compare_arrows, color: Colors.blueAccent),
                    title: Text('Topic: ${event.topic}'),
                    subtitle: Text('Payload context: ${event.payload.toString()}'),
                    trailing: Text(event.publishedAt.toString().split(' ').last.split('.').first),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebhookTab(IntegrationEngine engine) {
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
                  Text('Webhook Dispatch Simulator', style: context.eosText.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _webhookUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Client Callback Target URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send_and_archive),
                    label: const Text('Simulate Success Event'),
                    onPressed: () {
                      engine.webhooks.dispatchWebhook(
                        _webhookUrlController.text,
                        'TicketPurchased',
                        {'amount': 15000, 'buyer': 'Adenike Adebayo'},
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.report_problem),
                    label: const Text('Simulate Delivery Failure'),
                    onPressed: () {
                      engine.webhooks.triggerSimulatedFailure(
                        _webhookUrlController.text,
                        'PaymentSucceeded',
                        {'error': 'Connection Timeout (504)'},
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
          child: EosSurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Webhook Timeline Queue logs', style: context.eosText.titleMedium),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: engine.webhookLogs.length,
                      itemBuilder: (context, idx) {
                        final log = engine.webhookLogs[idx];
                        final isFailure = log.status != 'success';
                        return ListTile(
                          leading: Icon(
                            isFailure ? Icons.error_outline : Icons.check_circle_outline,
                            color: isFailure ? Colors.red : Colors.green,
                          ),
                          title: Text('URL: ${log.targetUrl}'),
                          subtitle: Text('Event: ${log.topic} | Status: ${log.status.toUpperCase()}'),
                          trailing: isFailure
                              ? ElevatedButton(
                                  onPressed: () => engine.webhooks.executeRetry(log.id),
                                  child: const Text('Retry'),
                                )
                              : Text('Att: ${log.retryCount + 1}'),
                        );
                      },
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

  Widget _buildPluginTab(IntegrationEngine engine) {
    return EosSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plugin SDK Lifecycle Manifest Installer', style: context.eosText.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: engine.plugins.plugins.length,
                itemBuilder: (context, idx) {
                  final p = engine.plugins.plugins[idx];
                  return ListTile(
                    leading: const Icon(Icons.settings_input_composite, color: Colors.blue),
                    title: Text(p.label),
                    subtitle: Text('Manifest permissions: ${p.permissions}'),
                    trailing: Switch(
                      value: p.isInstalled,
                      onChanged: (val) {
                        if (val) {
                          engine.plugins.installPlugin(p);
                        } else {
                          engine.plugins.uninstallPlugin(p.key);
                        }
                      },
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
}
