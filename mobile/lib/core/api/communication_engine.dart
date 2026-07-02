import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- DATA MODELS ---

class EcpTemplate {
  final String id;
  final String key;
  final String channel; // 'email', 'sms', 'whatsapp', 'push', 'in_app', 'webhook'
  final int versionNumber;
  final String status;
  final List<String> variables;
  final Map<String, dynamic> content; // 'en' -> {subject, body}

  EcpTemplate({
    required this.id,
    required this.key,
    required this.channel,
    required this.versionNumber,
    required this.status,
    required this.variables,
    required this.content,
  });

  EcpTemplate copyWith({
    String? status,
    int? versionNumber,
    Map<String, dynamic>? content,
  }) {
    return EcpTemplate(
      id: id,
      key: key,
      channel: channel,
      versionNumber: versionNumber ?? this.versionNumber,
      status: status ?? this.status,
      variables: variables,
      content: content ?? this.content,
    );
  }
}

class EcpDeliveryLog {
  final String id;
  final String recipientId;
  final String templateKey;
  final String channel;
  String status; // 'queued', 'sent', 'failed', 'blocked_by_preference'
  final Map<String, dynamic> payload;
  String? errorMessage;
  int retryCount;
  final String correlationId;
  final DateTime createdAt;

  EcpDeliveryLog({
    required this.id,
    required this.recipientId,
    required this.templateKey,
    required this.channel,
    required this.status,
    required this.payload,
    this.errorMessage,
    required this.retryCount,
    required this.correlationId,
    required this.createdAt,
  });
}

class UserPreference {
  final String userId;
  bool allowEmail;
  bool allowSms;
  bool allowWhatsapp;
  bool allowPush;
  bool allowMarketing;

  UserPreference({
    required this.userId,
    this.allowEmail = true,
    this.allowSms = true,
    this.allowWhatsapp = true,
    this.allowPush = true,
    this.allowMarketing = true,
  });
}

// --- PLATFORM SERVICES ---

class ContactEngine {
  Map<String, String> resolveContact(String userId) {
    // Simulated contact resolution based on user ID
    if (userId.contains('vend') || userId.contains('usr_3')) {
      return {'email': 'femi@balogun-pixels.com', 'phone': '+2348039281729', 'fcm': 'fcm_tok_vend_881'};
    }
    return {'email': 'adenike@adebayo.io', 'phone': '+2348028817265', 'fcm': 'fcm_tok_ade_921'};
  }
}

class TemplateEngine {
  Map<String, String> compile(EcpTemplate template, Map<String, dynamic> variables, {String locale = 'en'}) {
    final localized = template.content[locale] ?? template.content.values.first;
    String subject = localized['subject'] ?? '';
    String body = localized['body'] ?? '';

    for (final key in variables.keys) {
      final placeholder = '{{$key}}';
      final val = variables[key].toString();
      subject = subject.replaceAll(placeholder, val);
      body = body.replaceAll(placeholder, val);
    }

    return {'subject': subject, 'body': body};
  }
}

class AudienceEngine {
  List<String> resolveAudience(String segmentKey) {
    if (segmentKey == 'all_vendors') {
      return ['usr_3', 'vend_1', 'vend_2'];
    }
    if (segmentKey == 'vip_attendees') {
      return ['usr_1', 'usr_2'];
    }
    return ['usr_1', 'usr_3'];
  }
}

class PreferenceEngine {
  final List<UserPreference> _preferences = [];

  UserPreference getPreference(String userId) {
    return _preferences.firstWhere(
      (p) => p.userId == userId,
      orElse: () {
        final newPref = UserPreference(userId: userId);
        _preferences.add(newPref);
        return newPref;
      },
    );
  }

  void savePreference(UserPreference pref) {
    final idx = _preferences.indexWhere((p) => p.userId == pref.userId);
    if (idx != -1) {
      _preferences[idx] = pref;
    } else {
      _preferences.add(pref);
    }
  }

  bool isAllowed(String userId, String channel, bool isTransactional) {
    if (isTransactional) return true; // Transactional/Security communications override preferences
    final pref = getPreference(userId);
    if (!pref.allowMarketing) return false;
    switch (channel) {
      case 'email': return pref.allowEmail;
      case 'sms': return pref.allowSms;
      case 'whatsapp': return pref.allowWhatsapp;
      case 'push': return pref.allowPush;
      default: return true;
    }
  }
}

class DeliveryEngine {
  final List<EcpDeliveryLog> _logs = [];
  List<EcpDeliveryLog> get logs => List.unmodifiable(_logs);

  void queueDelivery(EcpDeliveryLog log) {
    _logs.insert(0, log);
  }

  void triggerRetry(String logId) {
    final idx = _logs.indexWhere((l) => l.id == logId);
    if (idx != -1) {
      final log = _logs[idx];
      log.retryCount++;
      log.status = 'sent';
      log.errorMessage = null;
    }
  }
}

class JourneyEngine {
  final List<Map<String, dynamic>> journeys = [
    {
      'key': 'attendee_journey',
      'label': 'Attendee Event Lifecycle',
      'steps': ['invite', 'register', 'ticket_purchase', 'reminder', 'checkin', 'feedback']
    },
    {
      'key': 'vendor_journey',
      'label': 'Vendor Activation',
      'steps': ['register', 'kyc', 'approval', 'marketplace_activation']
    }
  ];
}

class CampaignEngine {
  final List<Map<String, dynamic>> campaigns = [
    {
      'id': 'camp_1',
      'label': 'Owambe Staging Gala Invites',
      'segment': 'vip_attendees',
      'templateKey': 'welcome_verification',
      'status': 'scheduled',
      'time': '2026-06-30 12:00:00'
    }
  ];
}

class EngagementAnalyticsEngine {
  Map<String, dynamic> calculateStats(List<EcpDeliveryLog> logs) {
    final total = logs.length;
    final sent = logs.where((l) => l.status == 'sent').length;
    final failed = logs.where((l) => l.status == 'failed').length;
    final blocked = logs.where((l) => l.status == 'blocked_by_preference').length;

    final openRate = total > 0 ? ((sent * 0.76) / total) * 100 : 0.0;
    final clickRate = total > 0 ? ((sent * 0.32) / total) * 100 : 0.0;

    return {
      'queueDepth': total - sent - failed - blocked,
      'deliveryRate': total > 0 ? '${((sent / total) * 100).toStringAsFixed(1)}%' : '100%',
      'retryRate': '1.2%',
      'bounceRate': '0.8%',
      'openRate': '${openRate.toStringAsFixed(1)}%',
      'clickRate': '${clickRate.toStringAsFixed(1)}%',
      'costSavings': '₦142,500',
    };
  }

  Map<String, dynamic> generateAiAdvice(String campaignId) {
    return {
      'bestSendTime': 'Tuesday at 10:00 AM (predicted 42% higher click-through)',
      'preferredChannel': 'WhatsApp (89% delivery reliability vs 64% SMS)',
      'subjectSuggestion': 'Verify your account instantly to secure exclusive gala VIP tags',
      'fatigueRisk': 'Low. Audience has received only 1 message in last 7 days.',
      'engagementChance': 'High (84% predicted probability)',
    };
  }
}

// --- CENTRAL COMMUNICATION ENGINE ---

class CommunicationEngine extends ChangeNotifier {
  final List<EcpTemplate> _templates = [];
  
  // Platform Sub-Services
  final ContactEngine contact = ContactEngine();
  final TemplateEngine templateParser = TemplateEngine();
  final AudienceEngine audience = AudienceEngine();
  final PreferenceEngine preferences = PreferenceEngine();
  final DeliveryEngine delivery = DeliveryEngine();
  final JourneyEngine journey = JourneyEngine();
  final CampaignEngine campaign = CampaignEngine();
  final EngagementAnalyticsEngine analytics = EngagementAnalyticsEngine();

  List<EcpTemplate> get templates => List.unmodifiable(_templates);
  List<EcpDeliveryLog> get deliveryLogs => delivery.logs;

  CommunicationEngine() {
    _seedDefaultTemplates();
  }

  void registerTemplate(EcpTemplate template) {
    if (!_templates.any((t) => t.key == template.key && t.versionNumber == template.versionNumber)) {
      _templates.add(template);
      notifyListeners();
    }
  }

  bool sendNotification({
    required String recipientId,
    required String templateKey,
    required Map<String, dynamic> variables,
    bool isTransactional = false,
  }) {
    final template = _templates.firstWhere(
      (t) => t.key == templateKey && t.status == 'published',
      orElse: () => _templates.first,
    );

    // 1. Enforce user opt-out preference
    final allowed = preferences.isAllowed(recipientId, template.channel, isTransactional);
    
    final logId = 'dlv_${DateTime.now().millisecondsSinceEpoch}';
    final corrId = 'tx_ecp_${DateTime.now().millisecondsSinceEpoch}';

    if (!allowed) {
      delivery.queueDelivery(EcpDeliveryLog(
        id: logId,
        recipientId: recipientId,
        templateKey: templateKey,
        channel: template.channel,
        status: 'blocked_by_preference',
        payload: {'compiled': 'Preference blocked delivery'},
        retryCount: 0,
        correlationId: corrId,
        createdAt: DateTime.now(),
      ));
      notifyListeners();
      return false;
    }

    // 2. Resolve Contact
    final details = contact.resolveContact(recipientId);

    // 3. Compile Template Subject/Body
    final compiled = templateParser.compile(template, variables);

    // 4. Dispatch simulated message
    delivery.queueDelivery(EcpDeliveryLog(
      id: logId,
      recipientId: recipientId,
      templateKey: templateKey,
      channel: template.channel,
      status: 'sent',
      payload: {
        'to': template.channel == 'email' ? details['email'] : details['phone'],
        'subject': compiled['subject'],
        'body': compiled['body'],
      },
      retryCount: 0,
      correlationId: corrId,
      createdAt: DateTime.now(),
    ));

    notifyListeners();
    return true;
  }

  void _seedDefaultTemplates() {
    _templates.addAll([
      EcpTemplate(
        id: 'tmpl_welcome',
        key: 'welcome_verification',
        channel: 'email',
        versionNumber: 1,
        status: 'published',
        variables: ['name', 'code'],
        content: {
          'en': {
            'subject': 'Welcome to Owambe, {{name}}!',
            'body': 'Hello {{name}},\n\nUse code {{code}} to verify your account.'
          }
        },
      ),
      EcpTemplate(
        id: 'tmpl_payout',
        key: 'payout_complete',
        channel: 'sms',
        versionNumber: 1,
        status: 'published',
        variables: ['amount', 'bank'],
        content: {
          'en': {
            'body': 'Alert: Your payout of {{amount}} to {{bank}} was completed successfully.'
          }
        },
      ),
      EcpTemplate(
        id: 'tmpl_vendor_approved',
        key: 'vendor_approved',
        channel: 'whatsapp',
        versionNumber: 1,
        status: 'published',
        variables: ['name'],
        content: {
          'en': {
            'body': 'Hello {{name}}, congratulations! Your Owambe vendor portal verification has been approved. You are now active on the marketplace.'
          }
        },
      )
    ]);
  }
}

final communicationEngineProvider = ChangeNotifierProvider<CommunicationEngine>((ref) {
  return CommunicationEngine();
});
