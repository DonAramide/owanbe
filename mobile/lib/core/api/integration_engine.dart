import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- DATA MODELS ---

class PlatformIntegration {
  final String key;
  final String label;
  final String category;
  String status; // 'active', 'degraded', 'offline'
  String circuitBreaker; // 'closed', 'open', 'half_open'
  final Map<String, dynamic> metrics;

  PlatformIntegration({
    required this.key,
    required this.label,
    required this.category,
    required this.status,
    required this.circuitBreaker,
    required this.metrics,
  });

  PlatformIntegration copyWith({
    String? status,
    String? circuitBreaker,
  }) {
    return PlatformIntegration(
      key: key,
      label: label,
      category: category,
      status: status ?? this.status,
      circuitBreaker: circuitBreaker ?? this.circuitBreaker,
      metrics: metrics,
    );
  }
}

class ApiKeyCredential {
  final String clientId;
  final String clientSecret;
  final List<String> scopes;
  final int rateLimit;

  ApiKeyCredential({
    required this.clientId,
    required this.clientSecret,
    required this.scopes,
    required this.rateLimit,
  });
}

class EventBusMessage {
  final String id;
  final String topic;
  final Map<String, dynamic> payload;
  final DateTime publishedAt;

  EventBusMessage({
    required this.id,
    required this.topic,
    required this.payload,
    required this.publishedAt,
  });
}

class WebhookDeliveryLog {
  final String id;
  final String targetUrl;
  final String topic;
  String status; // 'success', 'retry_pending', 'failed_dlq'
  final Map<String, dynamic> payload;
  int retryCount;
  final DateTime createdAt;

  WebhookDeliveryLog({
    required this.id,
    required this.targetUrl,
    required this.topic,
    required this.status,
    required this.payload,
    required this.retryCount,
    required this.createdAt,
  });
}

class PlatformPluginManifest {
  final String key;
  final String label;
  final String version;
  final List<String> permissions;
  bool isInstalled;

  PlatformPluginManifest({
    required this.key,
    required this.label,
    required this.version,
    required this.permissions,
    required this.isInstalled,
  });
}

// --- SUB-SERVICES ---

class ApiGateway {
  final List<ApiKeyCredential> _credentials = [];
  List<ApiKeyCredential> get credentials => List.unmodifiable(_credentials);

  ApiKeyCredential createKey(String label, List<String> scopes) {
    final key = ApiKeyCredential(
      clientId: 'cli_${DateTime.now().millisecondsSinceEpoch}',
      clientSecret: 'secret_${DateTime.now().millisecondsSinceEpoch * 2}',
      scopes: scopes,
      rateLimit: 120,
    );
    _credentials.add(key);
    return key;
  }
}

class EventBus {
  final List<EventBusMessage> _busLogs = [];
  List<EventBusMessage> get busLogs => List.unmodifiable(_busLogs);

  void publish(String topic, Map<String, dynamic> payload) {
    _busLogs.insert(
      0,
      EventBusMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        topic: topic,
        payload: payload,
        publishedAt: DateTime.now(),
      ),
    );
  }
}

class WebhookEngine {
  final List<WebhookDeliveryLog> _webhookLogs = [];
  List<WebhookDeliveryLog> get webhookLogs => List.unmodifiable(_webhookLogs);

  void dispatchWebhook(String url, String topic, Map<String, dynamic> payload) {
    _webhookLogs.insert(
      0,
      WebhookDeliveryLog(
        id: 'whl_${DateTime.now().millisecondsSinceEpoch}',
        targetUrl: url,
        topic: topic,
        status: 'success',
        payload: payload,
        retryCount: 0,
        createdAt: DateTime.now(),
      ),
    );
  }

  void triggerSimulatedFailure(String url, String topic, Map<String, dynamic> payload) {
    _webhookLogs.insert(
      0,
      WebhookDeliveryLog(
        id: 'whl_${DateTime.now().millisecondsSinceEpoch}',
        targetUrl: url,
        topic: topic,
        status: 'retry_pending',
        payload: payload,
        retryCount: 1,
        createdAt: DateTime.now(),
      ),
    );
  }

  void executeRetry(String id) {
    final idx = _webhookLogs.indexWhere((w) => w.id == id);
    if (idx != -1) {
      final log = _webhookLogs[idx];
      log.retryCount++;
      if (log.retryCount >= 5) {
        log.status = 'failed_dlq';
      } else {
        log.status = 'success';
      }
    }
  }
}

class PluginEngine {
  final List<PlatformPluginManifest> _plugins = [];
  List<PlatformPluginManifest> get plugins => List.unmodifiable(_plugins);

  PluginEngine() {
    _seedDefaultPlugins();
  }

  void _seedDefaultPlugins() {
    _plugins.addAll([
      PlatformPluginManifest(key: 'google_calendar', label: 'Google Calendar sync', version: '1.2.0', permissions: ['events.read'], isInstalled: true),
      PlatformPluginManifest(key: 'salesforce_crm', label: 'Salesforce CRM Lead integration', version: '2.1.0', permissions: ['organizers.read'], isInstalled: false),
    ]);
  }

  void installPlugin(PlatformPluginManifest manifest) {
    if (!_plugins.any((p) => p.key == manifest.key)) {
      _plugins.add(manifest);
    } else {
      final idx = _plugins.indexWhere((p) => p.key == manifest.key);
      _plugins[idx].isInstalled = true;
    }
  }

  void uninstallPlugin(String key) {
    final idx = _plugins.indexWhere((p) => p.key == key);
    if (idx != -1) {
      _plugins[idx].isInstalled = false;
    }
  }
}

class SdkEngine {
  String generateFlutterCode(String key) {
    return '''
import 'package:owanbe_sdk/owanbe_sdk.dart';

void main() async {
  final client = OwambeClient(
    clientId: 'your_client_id',
    apiKey: '$key',
  );
  
  // Fetch active event data timelines
  final events = await client.events.list();
  print(events.length);
}
''';
  }
}

class IntegrationMonitoringEngine {
  Map<String, dynamic> getOverallHealth(List<PlatformIntegration> list) {
    final total = list.length;
    final active = list.where((i) => i.status == 'active').length;
    return {
      'gatewayLatency': '138ms',
      'healthPercentage': total > 0 ? (active / total) * 100 : 100.0,
      'activeSubscriptions': 12,
      'dailyVolume': '482.4k requests',
    };
  }
}

// --- CENTRAL PLATFORM OS ENGINE ---

class IntegrationEngine extends ChangeNotifier {
  final List<PlatformIntegration> _integrations = [];

  // Sub-services
  final ApiGateway gateway = ApiGateway();
  final EventBus eventBus = EventBus();
  final WebhookEngine webhooks = WebhookEngine();
  final PluginEngine plugins = PluginEngine();
  final SdkEngine sdk = SdkEngine();
  final IntegrationMonitoringEngine monitoring = IntegrationMonitoringEngine();

  List<PlatformIntegration> get integrations => List.unmodifiable(_integrations);
  List<EventBusMessage> get busEvents => eventBus.busLogs;
  List<WebhookDeliveryLog> get webhookLogs => webhooks.webhookLogs;

  IntegrationEngine() {
    _seedDefaultIntegrations();
  }

  void _seedDefaultIntegrations() {
    _integrations.addAll([
      PlatformIntegration(key: 'stripe', label: 'Stripe Payments Gateway', category: 'payment', status: 'active', circuitBreaker: 'closed', metrics: {'latency': 142, 'health': 99.8}),
      PlatformIntegration(key: 'paystack', label: 'Paystack API Broker', category: 'payment', status: 'active', circuitBreaker: 'closed', metrics: {'latency': 95, 'health': 100.0}),
      PlatformIntegration(key: 'salesforce', label: 'Salesforce CRM Connector', category: 'crm', status: 'active', circuitBreaker: 'closed', metrics: {'latency': 280, 'health': 98.2}),
      PlatformIntegration(key: 'twilio', label: 'Twilio SMS & Messaging', category: 'messaging', status: 'active', circuitBreaker: 'closed', metrics: {'latency': 122, 'health': 99.2}),
    ]);
  }

  void toggleBreaker(String key) {
    final idx = _integrations.indexWhere((i) => i.key == key);
    if (idx != -1) {
      final prev = _integrations[idx];
      final newBreaker = prev.circuitBreaker == 'closed' ? 'open' : 'closed';
      final newStatus = newBreaker == 'open' ? 'offline' : 'active';
      _integrations[idx] = prev.copyWith(
        circuitBreaker: newBreaker,
        status: newStatus,
      );
      
      // Publish event to Event Bus
      eventBus.publish('IntegrationStateChanged', {
        'integrationKey': key,
        'previousBreakerState': prev.circuitBreaker,
        'currentBreakerState': newBreaker,
      });

      notifyListeners();
    }
  }
}

final integrationEngineProvider = ChangeNotifierProvider<IntegrationEngine>((ref) {
  return IntegrationEngine();
});
