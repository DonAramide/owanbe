import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../auth/auth_notifier.dart';
import '../../../auth/auth_session.dart';
import '../../../core/api/owambe_api_auth.dart';

class OrganizerAutomationApiException implements Exception {
  OrganizerAutomationApiException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => 'OrganizerAutomationApiException($code): $message';
}

class AutomationDefinition {
  const AutomationDefinition({
    required this.workflowKey,
    required this.label,
    required this.triggerKind,
    required this.enabled,
    this.triggerKey,
    this.scheduleExpr,
    this.scope,
  });

  final String workflowKey;
  final String label;
  final String triggerKind;
  final String? triggerKey;
  final String? scheduleExpr;
  final String? scope;
  final bool enabled;

  factory AutomationDefinition.fromJson(Map<String, dynamic> json) => AutomationDefinition(
        workflowKey: (json['workflowKey'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
        triggerKind: (json['triggerKind'] ?? '').toString(),
        triggerKey: json['triggerKey']?.toString(),
        scheduleExpr: json['scheduleExpr']?.toString(),
        scope: json['scope']?.toString(),
        enabled: json['enabled'] == true,
      );
}

class AutomationRun {
  const AutomationRun({
    required this.id,
    required this.workflowKey,
    required this.triggerKind,
    required this.triggerKey,
    required this.status,
    this.errorMessage,
    this.startedAt,
    this.finishedAt,
    this.actions = const [],
  });

  final String id;
  final String workflowKey;
  final String triggerKind;
  final String triggerKey;
  final String status;
  final String? errorMessage;
  final String? startedAt;
  final String? finishedAt;
  final List<Map<String, dynamic>> actions;

  factory AutomationRun.fromJson(Map<String, dynamic> json) => AutomationRun(
        id: (json['id'] ?? '').toString(),
        workflowKey: (json['workflowKey'] ?? '').toString(),
        triggerKind: (json['triggerKind'] ?? '').toString(),
        triggerKey: (json['triggerKey'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        errorMessage: json['errorMessage']?.toString(),
        startedAt: json['startedAt']?.toString(),
        finishedAt: json['finishedAt']?.toString(),
        actions: (json['actions'] as List<dynamic>? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
}

class OrganizerAutomationApi {
  OrganizerAutomationApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  String get _base => OwambeApiAuth.resolveApiBase();
  String get _tenantId => OwambeApiAuth.resolveTenantId();

  Future<Map<String, String>> _headers([AuthSession? session]) =>
      OwambeApiAuth.authorizedHeaders(tenantId: _tenantId);

  Uri _u(String path, [Map<String, String>? q]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$_base/$p').replace(queryParameters: q);
  }

  Never _throw(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) {
        throw OrganizerAutomationApiException(
          code: (body['code'] ?? 'HTTP_${res.statusCode}').toString(),
          message: (body['message'] ?? 'Request failed').toString(),
        );
      }
    } catch (e) {
      if (e is OrganizerAutomationApiException) rethrow;
    }
    throw OrganizerAutomationApiException(code: 'HTTP_${res.statusCode}', message: res.body);
  }

  Future<List<AutomationDefinition>> listDefinitions({AuthSession? session}) async {
    final res = await _http.get(_u('organizers/me/automations'), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .map((e) => AutomationDefinition.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AutomationRun>> listRuns({AuthSession? session}) async {
    final res = await _http.get(_u('organizers/me/automations/runs'), headers: await _headers(session));
    if (res.statusCode >= 400) _throw(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? [])
        .map((e) => AutomationRun.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setEnabled({
    required String workflowKey,
    required bool enabled,
    AuthSession? session,
  }) async {
    final res = await _http.post(
      _u('organizers/me/automations/$workflowKey/enabled'),
      headers: await _headers(session),
      body: jsonEncode({'enabled': enabled}),
    );
    if (res.statusCode >= 400) _throw(res);
  }

  Future<void> enqueueReminder({
    required String workflowKey,
    DateTime? runAt,
    AuthSession? session,
  }) async {
    final res = await _http.post(
      _u('organizers/me/automations/jobs'),
      headers: await _headers(session),
      body: jsonEncode({
        'workflowKey': workflowKey,
        'runAt': (runAt ?? DateTime.now().toUtc().add(const Duration(minutes: 1))).toIso8601String(),
        'dedupeKey': 'manual-$workflowKey-${DateTime.now().millisecondsSinceEpoch}',
      }),
    );
    if (res.statusCode >= 400) _throw(res);
  }
}

final organizerAutomationApiProvider =
    Provider<OrganizerAutomationApi>((ref) => OrganizerAutomationApi());

final organizerAutomationsProvider = FutureProvider.autoDispose<List<AutomationDefinition>>((ref) async {
  return ref.read(organizerAutomationApiProvider).listDefinitions(session: ref.watch(authSessionProvider));
});

final organizerAutomationRunsProvider = FutureProvider.autoDispose<List<AutomationRun>>((ref) async {
  return ref.read(organizerAutomationApiProvider).listRuns(session: ref.watch(authSessionProvider));
});
