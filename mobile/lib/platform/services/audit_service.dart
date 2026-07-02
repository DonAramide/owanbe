import 'service_context.dart';

class AuditEvent {
  const AuditEvent({
    required this.userId,
    required this.tenantId,
    required this.workspaceId,
    required this.timestamp,
    required this.correlationId,
    required this.operation,
    required this.result,
  });

  final String userId;
  final String tenantId;
  final String workspaceId;
  final DateTime timestamp;
  final String correlationId;
  final String operation;
  final String result;
}

class AuditService {
  AuditService._();
  static final AuditService instance = AuditService._();

  final List<AuditEvent> _logs = [];
  List<AuditEvent> get logs => List.unmodifiable(_logs);

  Future<void> log({
    required ServiceContext context,
    required String operation,
    required String result,
  }) async {
    final event = AuditEvent(
      userId: context.userContext?.userId ?? 'anonymous',
      tenantId: context.tenantId,
      workspaceId: context.workspaceId,
      timestamp: DateTime.now(),
      correlationId: context.correlationId,
      operation: operation,
      result: result,
    );
    _logs.add(event);
  }
}
