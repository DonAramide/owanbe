import '../../../core/api/vendors_api.dart';
import '../i_marketplace_repository.dart';

class MarketplaceRepositoryImpl implements IMarketplaceRepository {
  const MarketplaceRepositoryImpl(this._api);
  final VendorsApi _api;

  @override
  Future<List<MarketplaceVendor>> listVendors({String? category, String? city}) => _api.listCatalog(query: category, city: city);
  @override
  Future<MarketplaceVendor?> getVendor(String vendorId) async {
    return _api.getVendor(vendorId);
  }
}
