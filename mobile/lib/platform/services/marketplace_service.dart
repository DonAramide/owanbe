import '../../core/api/vendors_api.dart';
import '../repositories/i_marketplace_repository.dart';
import 'service_context.dart';
import 'service_result.dart';

abstract interface class IMarketplaceService {
  Future<ServiceResult<List<MarketplaceVendor>>> listVendors(ServiceContext ctx, {String? category, String? city});
  Future<ServiceResult<MarketplaceVendor?>> getVendor(ServiceContext ctx, String vendorId);
  // Legacy compat
  Future<ServiceResult<bool>> searchVendors(ServiceContext ctx, Map<String, dynamic> filters);
  Future<ServiceResult<bool>> requestQuote(ServiceContext ctx, String vendorId, Map<String, dynamic> details);
  Future<ServiceResult<bool>> trackInteraction(ServiceContext ctx, String vendorId);
}

class MarketplaceService implements IMarketplaceService {
  const MarketplaceService(this._repository);
  final IMarketplaceRepository _repository;

  @override
  Future<ServiceResult<List<MarketplaceVendor>>> listVendors(ServiceContext ctx, {String? category, String? city}) async {
    try {
      return ServiceResult.success(await _repository.listVendors(category: category, city: city));
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  @override
  Future<ServiceResult<MarketplaceVendor?>> getVendor(ServiceContext ctx, String vendorId) async {
    try {
      return ServiceResult.success(await _repository.getVendor(vendorId));
    } catch (e) {
      return ServiceResult.failure(e.toString());
    }
  }

  @override
  Future<ServiceResult<bool>> searchVendors(ServiceContext ctx, Map<String, dynamic> filters) async => ServiceResult.success(true);
  @override
  Future<ServiceResult<bool>> requestQuote(ServiceContext ctx, String vendorId, Map<String, dynamic> details) async => ServiceResult.success(true);
  @override
  Future<ServiceResult<bool>> trackInteraction(ServiceContext ctx, String vendorId) async => ServiceResult.success(true);
}
