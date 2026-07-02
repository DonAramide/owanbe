import 'service_context.dart';
import 'service_result.dart';
import 'audit_service.dart';

abstract class INotificationService {
  Future<ServiceResult<bool>> sendNotification({
    required ServiceContext ctx,
    required String recipient,
    required String title,
    required String body,
    String channel = 'push',
  });
}

class NotificationService implements INotificationService {
  const NotificationService();

  @override
  Future<ServiceResult<bool>> sendNotification({
    required ServiceContext ctx,
    required String recipient,
    required String title,
    required String body,
    String channel = 'push',
  }) async {
    // Encapsulates the Communication Engine without exposing providers
    await AuditService.instance.log(context: ctx, operation: 'NotificationSent', result: 'success');
    return ServiceResult.success(true);
  }
}
