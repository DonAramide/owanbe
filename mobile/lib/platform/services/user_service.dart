import 'service_context.dart';
import 'service_result.dart';
import 'audit_service.dart';

abstract class IUserService {
  Future<ServiceResult<bool>> registerUser(ServiceContext ctx, String email, String password);
  Future<ServiceResult<bool>> updateProfile(ServiceContext ctx, Map<String, dynamic> profile);
  Future<ServiceResult<bool>> recoverAccount(ServiceContext ctx, String email);
  Future<ServiceResult<bool>> suspendAccount(ServiceContext ctx, String userId);
}

class UserService implements IUserService {
  const UserService();

  @override
  Future<ServiceResult<bool>> registerUser(ServiceContext ctx, String email, String password) async {
    await AuditService.instance.log(context: ctx, operation: 'UserRegistration', result: 'success');
    return ServiceResult.success(true);
  }

  @override
  Future<ServiceResult<bool>> updateProfile(ServiceContext ctx, Map<String, dynamic> profile) async {
    await AuditService.instance.log(context: ctx, operation: 'ProfileUpdate', result: 'success');
    return ServiceResult.success(true);
  }

  @override
  Future<ServiceResult<bool>> recoverAccount(ServiceContext ctx, String email) async {
    await AuditService.instance.log(context: ctx, operation: 'AccountRecoveryInitiated', result: 'success');
    return ServiceResult.success(true);
  }

  @override
  Future<ServiceResult<bool>> suspendAccount(ServiceContext ctx, String userId) async {
    if (!ctx.permissions.contains('admin')) {
      return ServiceResult.authorizationFailure('Admin privileges required');
    }
    await AuditService.instance.log(context: ctx, operation: 'AccountSuspension', result: 'success');
    return ServiceResult.success(true);
  }
}
