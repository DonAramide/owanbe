// Rental equipment models.

class RentalCatalogItem {
  const RentalCatalogItem({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.categorySlug,
    required this.name,
    required this.description,
    this.photoUrl,
    required this.totalQuantity,
    required this.availableQuantity,
    required this.reservedQuantity,
    required this.rentalFeeMinor,
    required this.depositMinor,
    required this.active,
  });

  final String id;
  final String vendorId;
  final String vendorName;
  final String categorySlug;
  final String name;
  final String description;
  final String? photoUrl;
  final int totalQuantity;
  final int availableQuantity;
  final int reservedQuantity;
  final int rentalFeeMinor;
  final int depositMinor;
  final bool active;

  factory RentalCatalogItem.fromJson(Map<String, dynamic> json) {
    return RentalCatalogItem(
      id: (json['id'] ?? '').toString(),
      vendorId: (json['vendorId'] ?? '').toString(),
      vendorName: (json['vendorName'] ?? '').toString(),
      categorySlug: (json['categorySlug'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      photoUrl: json['photoUrl'] as String?,
      totalQuantity: (json['totalQuantity'] as num?)?.toInt() ?? 0,
      availableQuantity: (json['availableQuantity'] as num?)?.toInt() ?? 0,
      reservedQuantity: (json['reservedQuantity'] as num?)?.toInt() ?? 0,
      rentalFeeMinor: (json['rentalFeeMinor'] as num?)?.toInt() ?? 0,
      depositMinor: (json['depositMinor'] as num?)?.toInt() ?? 0,
      active: json['active'] != false,
    );
  }
}

class RentalBooking {
  const RentalBooking({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.vendorId,
    required this.vendorName,
    required this.catalogItemId,
    required this.itemName,
    required this.categorySlug,
    required this.requesterName,
    required this.quantityRequested,
    this.quantityApproved,
    this.counterQuantity,
    required this.status,
    required this.rentalFeeMinor,
    required this.depositMinor,
    this.deliveryDate,
    this.pickupDate,
    this.deliveryAddress,
    this.damageNotes,
    this.deliveredAt,
    this.returnedAt,
    required this.createdAt,
  });

  final String id;
  final String eventId;
  final String eventTitle;
  final String vendorId;
  final String vendorName;
  final String catalogItemId;
  final String itemName;
  final String categorySlug;
  final String requesterName;
  final int quantityRequested;
  final int? quantityApproved;
  final int? counterQuantity;
  final String status;
  final int rentalFeeMinor;
  final int depositMinor;
  final String? deliveryDate;
  final String? pickupDate;
  final String? deliveryAddress;
  final String? damageNotes;
  final String? deliveredAt;
  final String? returnedAt;
  final DateTime createdAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isCountered => status == 'countered';
  bool get isDelivered => status == 'delivered';
  bool get isReturned => status == 'returned';

  factory RentalBooking.fromJson(Map<String, dynamic> json) {
    return RentalBooking(
      id: (json['id'] ?? '').toString(),
      eventId: (json['eventId'] ?? '').toString(),
      eventTitle: (json['eventTitle'] ?? '').toString(),
      vendorId: (json['vendorId'] ?? '').toString(),
      vendorName: (json['vendorName'] ?? '').toString(),
      catalogItemId: (json['catalogItemId'] ?? '').toString(),
      itemName: (json['itemName'] ?? '').toString(),
      categorySlug: (json['categorySlug'] ?? '').toString(),
      requesterName: (json['requesterName'] ?? '').toString(),
      quantityRequested: (json['quantityRequested'] as num?)?.toInt() ?? 0,
      quantityApproved: (json['quantityApproved'] as num?)?.toInt(),
      counterQuantity: (json['counterQuantity'] as num?)?.toInt(),
      status: (json['status'] ?? 'pending').toString(),
      rentalFeeMinor: (json['rentalFeeMinor'] as num?)?.toInt() ?? 0,
      depositMinor: (json['depositMinor'] as num?)?.toInt() ?? 0,
      deliveryDate: json['deliveryDate'] as String?,
      pickupDate: json['pickupDate'] as String?,
      deliveryAddress: json['deliveryAddress'] as String?,
      damageNotes: json['damageNotes'] as String?,
      deliveredAt: json['deliveredAt'] as String?,
      returnedAt: json['returnedAt'] as String?,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class RentalBlackout {
  const RentalBlackout({required this.id, this.catalogItemId, required this.blackoutDate, this.reason});

  final String id;
  final String? catalogItemId;
  final String blackoutDate;
  final String? reason;

  factory RentalBlackout.fromJson(Map<String, dynamic> json) {
    return RentalBlackout(
      id: (json['id'] ?? '').toString(),
      catalogItemId: json['catalogItemId'] as String?,
      blackoutDate: (json['blackoutDate'] ?? '').toString(),
      reason: json['reason'] as String?,
    );
  }
}
