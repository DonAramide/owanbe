import 'dart:async';
import 'dart:convert';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'owanbe_api_auth.dart';

/// Phase 3A CRM realtime envelope (signal only — REST remains authoritative).
class CrmRealtimeEnvelope {
  const CrmRealtimeEnvelope({
    required this.eventId,
    required this.type,
    required this.tenantId,
    required this.resourceType,
    required this.resourceId,
    required this.updatedAt,
    required this.dedupeKey,
    required this.occurredAt,
    this.revision,
    this.metaEventId,
    this.metaVendorId,
    this.metaStage,
  });

  final String eventId;
  final String type;
  final String tenantId;
  final String resourceType;
  final String resourceId;
  final DateTime updatedAt;
  final String dedupeKey;
  final DateTime occurredAt;
  final String? revision;
  final String? metaEventId;
  final String? metaVendorId;
  final String? metaStage;

  factory CrmRealtimeEnvelope.fromJson(Map<String, dynamic> json) {
    final resource = json['resource'];
    final resourceMap = resource is Map ? Map<String, dynamic>.from(resource) : <String, dynamic>{};
    final meta = json['meta'];
    final metaMap = meta is Map ? Map<String, dynamic>.from(meta) : <String, dynamic>{};
    return CrmRealtimeEnvelope(
      eventId: (json['eventId'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      tenantId: (json['tenantId'] ?? '').toString(),
      resourceType: (resourceMap['type'] ?? 'vendor_request').toString(),
      resourceId: (resourceMap['id'] ?? '').toString(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? DateTime.now().toUtc(),
      dedupeKey: (json['dedupeKey'] ?? '').toString(),
      occurredAt: DateTime.tryParse((json['occurredAt'] ?? '').toString()) ?? DateTime.now().toUtc(),
      revision: json['revision']?.toString(),
      metaEventId: metaMap['eventId']?.toString(),
      metaVendorId: metaMap['vendorId']?.toString(),
      metaStage: metaMap['stage']?.toString(),
    );
  }
}

/// Thin SSE client for GET /v1/me/crm/stream.
/// Does not hold CRM state — callers refresh existing Riverpod providers.
class CrmSseClient {
  CrmSseClient({
    http.Client? httpClient,
    this.onEvent,
    this.onReconnectRefresh,
    this.onLog,
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final void Function(CrmRealtimeEnvelope event)? onEvent;
  /// Mandatory REST recovery after reconnect.
  final Future<void> Function()? onReconnectRefresh;
  final void Function(String metric, Map<String, String> fields)? onLog;

  StreamSubscription<List<int>>? _sub;
  bool _stopped = true;
  bool _connecting = false;
  int _backoffMs = 1000;
  static const _maxBackoffMs = 30000;

  bool get isActive => !_stopped;

  Future<void> start() async {
    if (!_stopped && (_connecting || _sub != null)) return;
    _stopped = false;
    await _connectLoop();
  }

  Future<void> stop() async {
    _stopped = true;
    await _sub?.cancel();
    _sub = null;
    _connecting = false;
  }

  Future<void> _connectLoop() async {
    while (!_stopped) {
      try {
        await _openOnce();
        _backoffMs = 1000;
      } catch (e) {
        onLog?.call('crm_sse_disconnect', {'error': e.toString()});
      }
      if (_stopped) break;
      onLog?.call('crm_realtime_reconnect', {'backoffMs': '$_backoffMs'});
      try {
        await onReconnectRefresh?.call();
        onLog?.call('crm_rest_recovery_refresh', {});
      } catch (_) {}
      await Future<void>.delayed(Duration(milliseconds: _backoffMs));
      _backoffMs = (_backoffMs * 2).clamp(1000, _maxBackoffMs);
    }
  }

  Future<void> _openOnce() async {
    if (_connecting) return;
    _connecting = true;
    try {
      final headers = await OwambeApiAuth.authorizedHeaders(
        tenantId: OwambeApiAuth.resolveTenantId(),
        json: false,
      );
      headers['Accept'] = 'text/event-stream';
      final base = OwambeApiAuth.resolveApiBase();
      final uri = Uri.parse('$base/me/crm/stream');
      final request = http.Request('GET', uri);
      request.headers.addAll(headers);
      final response = await _http.send(request);
      if (response.statusCode == 503 || response.statusCode == 404) {
        onLog?.call('crm_sse_subscription_denied', {
          'status': '${response.statusCode}',
        });
        // Feature disabled — stop quietly; polling continues.
        _stopped = true;
        return;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        onLog?.call('crm_sse_auth_fail', {'status': '${response.statusCode}'});
        _stopped = true;
        return;
      }
      if (response.statusCode >= 400) {
        throw Exception('CRM SSE HTTP ${response.statusCode}');
      }
      onLog?.call('crm_sse_connect', {});
      var buffer = '';
      final completer = Completer<void>();
      _sub = response.stream.listen(
        (bytes) {
          buffer += utf8.decode(bytes, allowMalformed: true);
          while (true) {
            final sep = buffer.indexOf('\n\n');
            if (sep < 0) break;
            final frame = buffer.substring(0, sep);
            buffer = buffer.substring(sep + 2);
            _handleFrame(frame);
          }
        },
        onError: (Object e, StackTrace st) {
          if (!completer.isCompleted) completer.completeError(e, st);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );
      await completer.future;
    } finally {
      await _sub?.cancel();
      _sub = null;
      _connecting = false;
    }
  }

  void _handleFrame(String frame) {
    final dataLines = frame
        .split('\n')
        .where((l) => l.startsWith('data:'))
        .map((l) => l.substring(5).trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (dataLines.isEmpty) return;
    try {
      final json = jsonDecode(dataLines.join('\n'));
      if (json is! Map<String, dynamic>) return;
      final type = (json['type'] ?? '').toString();
      if (type == 'connected' || type == 'ping') return;
      if ((json['eventId'] ?? '').toString().isEmpty) return;
      onEvent?.call(CrmRealtimeEnvelope.fromJson(json));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CRM SSE frame parse skip: $e');
      }
    }
  }
}

/// Session-scoped LRU for eventId + dedupeKey.
class CrmRealtimeDedupeCache {
  CrmRealtimeDedupeCache({this.capacity = 200});

  final int capacity;
  final LinkedHashMap<String, DateTime> _seen = LinkedHashMap();

  /// Returns true if this is a new event (should process).
  bool claim(String eventId, String dedupeKey) {
    final keys = <String>[
      if (eventId.isNotEmpty) 'id:$eventId',
      if (dedupeKey.isNotEmpty) 'dk:$dedupeKey',
    ];
    if (keys.isEmpty) return true;
    for (final k in keys) {
      if (_seen.containsKey(k)) return false;
    }
    for (final k in keys) {
      _seen[k] = DateTime.now().toUtc();
    }
    while (_seen.length > capacity) {
      _seen.remove(_seen.keys.first);
    }
    return true;
  }
}
