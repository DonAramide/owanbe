import '../../core/api/vendors_api.dart';

abstract interface class IMarketplaceRepository {
  Future<List<MarketplaceVendor>> listVendors({String? category, String? city});
  Future<MarketplaceVendor?> getVendor(String vendorId);
}
