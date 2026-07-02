import '../../features/vendor/models/vendor_models.dart';

abstract interface class IVendorRepository {
  Future<List<VendorEventParticipation>> listParticipations();
  Future<List<VendorOrder>> listOrders();
  Future<List<VendorCatalogItem>> listCatalog();
  Future<VendorProfile> getProfile();
}
