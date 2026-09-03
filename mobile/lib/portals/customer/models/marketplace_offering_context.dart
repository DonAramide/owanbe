/// Marketplace buyer vs seller from existing offering ownership.
/// Marketplace is not a source of truth; [offeringVendorId] is [vendors.id].
bool isMarketplaceOwnOffering({
  required String offeringVendorId,
  String? currentVendorId,
}) {
  final mine = currentVendorId?.trim() ?? '';
  if (mine.isEmpty) return false;
  return offeringVendorId.trim() == mine;
}
