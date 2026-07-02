import 'service_context.dart';
import 'service_result.dart';
import 'audit_service.dart';

abstract class ICommerceService {
  Future<ServiceResult<bool>> processCheckout(ServiceContext ctx, double amount);
  Future<ServiceResult<bool>> processSettlement(ServiceContext ctx, String organizerId);
}

class CommerceService implements ICommerceService {
  const CommerceService();

  @override
  Future<ServiceResult<bool>> processCheckout(ServiceContext ctx, double amount) async {
    await AuditService.instance.log(context: ctx, operation: 'CheckoutProcess', result: 'success');
    return ServiceResult.success(true);
  }

  @override
  Future<ServiceResult<bool>> processSettlement(ServiceContext ctx, String organizerId) async {
    if (!ctx.permissions.contains('admin')) {
      return ServiceResult.authorizationFailure('Admin privileges required');
    }
    await AuditService.instance.log(context: ctx, operation: 'SettlementProcess', result: 'success');
    return ServiceResult.success(true);
  }
}
