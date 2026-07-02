import '../../features/vendor/models/vendor_models.dart';
import '../bootstrap/platform_event_bus.dart';
import '../events/platform_domain_events.dart';
import '../repositories/i_vendor_repository.dart';
import 'audit_service.dart';
import 'service_context.dart';
import 'service_result.dart';
import 'transaction_scope.dart';

abstract interface class IVendorService {
  Future<ServiceResult<List<VendorEventParticipation>>> listParticipations(ServiceContext ctx);
  Future<ServiceResult<List<VendorOrder>>> listOrders(ServiceContext ctx);
  Future<ServiceResult<List<VendorCatalogItem>>> listCatalog(ServiceContext ctx);
  Future<ServiceResult<VendorProfile>> getProfile(ServiceContext ctx);
  Future<ServiceResult<bool>> submitOnboarding(ServiceContext ctx, Map<String, dynamic> data);
  Future<ServiceResult<bool>> approvePortfolio(ServiceContext ctx, String vendorId);
  Future<ServiceResult<bool>> updatePerformanceMetrics(ServiceContext ctx, String vendorId);
}

class VendorService implements IVendorService {
  const VendorService(this._repository);
  final IVendorRepository _repository;
  static const _scope = TransactionScope();

  @override
  Future<ServiceResult<List<VendorEventParticipation>>> listParticipations(ServiceContext ctx) async {
    try {
      return ServiceResult.success(await _repository.listParticipations());
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  @override
  Future<ServiceResult<List<VendorOrder>>> listOrders(ServiceContext ctx) async {
    try {
      return ServiceResult.success(await _repository.listOrders());
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  @override
  Future<ServiceResult<List<VendorCatalogItem>>> listCatalog(ServiceContext ctx) async {
    try {
      return ServiceResult.success(await _repository.listCatalog());
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  @override
  Future<ServiceResult<VendorProfile>> getProfile(ServiceContext ctx) async {
    try {
      return ServiceResult.success(await _repository.getProfile());
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  @override
  Future<ServiceResult<bool>> submitOnboarding(ServiceContext ctx, Map<String, dynamic> data) async {
    return _scope.execute(() async {
      try {
        await AuditService.instance.log(context: ctx, operation: 'VendorOnboardingSubmit', result: 'success');
        PlatformEventBus.instance.fire(VendorOnboarded(vendorId: ctx.userContext?.userId ?? '', tenantId: ctx.tenantId));
        return ServiceResult.success(true);
      } catch (e) {
        return ServiceResult.failure(e.toString());
      }
    });
  }

  @override
  Future<ServiceResult<bool>> approvePortfolio(ServiceContext ctx, String vendorId) async {
    if (!ctx.permissions.contains('admin')) {
      return ServiceResult.authorizationFailure('Admin privileges required');
    }
    return _scope.execute(() async {
      try {
        await AuditService.instance.log(context: ctx, operation: 'VendorPortfolioApproval', result: 'success');
        PlatformEventBus.instance.fire(VendorPortfolioApproved(vendorId: vendorId, tenantId: ctx.tenantId, approvedBy: ctx.userContext?.userId ?? ''));
        return ServiceResult.success(true);
      } catch (e) {
        return ServiceResult.failure(e.toString());
      }
    });
  }

  @override
  Future<ServiceResult<bool>> updatePerformanceMetrics(ServiceContext ctx, String vendorId) async {
    return ServiceResult.success(true);
  }
}
