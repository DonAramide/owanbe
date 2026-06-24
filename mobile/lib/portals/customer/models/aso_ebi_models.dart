// Aso-Ebi models — Phase 2C.

const asoEbiPackageTypes = ['fabric_only', 'fabric_cap', 'premium'];

const asoEbiPackageLabels = <String, String>{
  'fabric_only': 'Fabric only',
  'fabric_cap': 'Fabric + cap',
  'premium': 'Premium package',
};

const asoEbiDefaultSizes = ['S', 'M', 'L', 'XL', 'XXL'];

class AsoEbiPackage {
  const AsoEbiPackage({required this.packageType, required this.priceMinor});

  final String packageType;
  final int priceMinor;

  String get label => asoEbiPackageLabels[packageType] ?? packageType;

  factory AsoEbiPackage.fromJson(Map<String, dynamic> json) {
    return AsoEbiPackage(
      packageType: (json['packageType'] ?? '').toString(),
      priceMinor: (json['priceMinor'] as num?)?.toInt() ?? 0,
    );
  }
}

class AsoEbiInventoryItem {
  const AsoEbiInventoryItem({
    required this.packageType,
    required this.size,
    required this.available,
    required this.reserved,
    required this.collected,
  });

  final String packageType;
  final String size;
  final int available;
  final int reserved;
  final int collected;

  factory AsoEbiInventoryItem.fromJson(Map<String, dynamic> json) {
    return AsoEbiInventoryItem(
      packageType: (json['packageType'] ?? '').toString(),
      size: (json['size'] ?? '').toString(),
      available: (json['available'] as num?)?.toInt() ?? 0,
      reserved: (json['reserved'] as num?)?.toInt() ?? 0,
      collected: (json['collected'] as num?)?.toInt() ?? 0,
    );
  }
}

class AsoEbiFabric {
  const AsoEbiFabric({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.description,
    required this.active,
    required this.sortOrder,
    required this.packages,
    required this.inventory,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final String description;
  final bool active;
  final int sortOrder;
  final List<AsoEbiPackage> packages;
  final List<AsoEbiInventoryItem> inventory;

  AsoEbiPackage? packageOf(String type) {
    for (final p in packages) {
      if (p.packageType == type) return p;
    }
    return null;
  }

  List<String> availableSizes(String packageType) {
    return inventory
        .where((i) => i.packageType == packageType && i.available > 0)
        .map((i) => i.size)
        .toList();
  }

  factory AsoEbiFabric.fromJson(Map<String, dynamic> json) {
    return AsoEbiFabric(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      photoUrl: json['photoUrl'] as String?,
      description: (json['description'] ?? '').toString(),
      active: json['active'] != false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      packages: (json['packages'] as List<dynamic>? ?? [])
          .map((e) => AsoEbiPackage.fromJson(e as Map<String, dynamic>))
          .toList(),
      inventory: (json['inventory'] as List<dynamic>? ?? [])
          .map((e) => AsoEbiInventoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AsoEbiDashboard {
  const AsoEbiDashboard({
    required this.totalSales,
    required this.revenueMinor,
    required this.outstandingPickup,
    required this.pendingPayment,
  });

  final int totalSales;
  final int revenueMinor;
  final int outstandingPickup;
  final int pendingPayment;

  factory AsoEbiDashboard.fromJson(Map<String, dynamic> json) {
    return AsoEbiDashboard(
      totalSales: (json['totalSales'] as num?)?.toInt() ?? 0,
      revenueMinor: (json['revenueMinor'] as num?)?.toInt() ?? 0,
      outstandingPickup: (json['outstandingPickup'] as num?)?.toInt() ?? 0,
      pendingPayment: (json['pendingPayment'] as num?)?.toInt() ?? 0,
    );
  }
}

class AsoEbiReservation {
  const AsoEbiReservation({
    required this.id,
    required this.fabricId,
    required this.fabricName,
    required this.packageType,
    required this.size,
    required this.guestName,
    this.guestEmail,
    required this.priceMinor,
    required this.paymentStatus,
    required this.fulfillmentStatus,
    required this.reservedAt,
    this.paidAt,
    this.collectedAt,
  });

  final String id;
  final String fabricId;
  final String fabricName;
  final String packageType;
  final String size;
  final String guestName;
  final String? guestEmail;
  final int priceMinor;
  final String paymentStatus;
  final String fulfillmentStatus;
  final DateTime reservedAt;
  final DateTime? paidAt;
  final DateTime? collectedAt;

  String get packageLabel => asoEbiPackageLabels[packageType] ?? packageType;
  bool get isPaid => paymentStatus == 'paid';
  bool get isCollected => fulfillmentStatus == 'collected';
  bool get isCancelled => fulfillmentStatus == 'cancelled';

  factory AsoEbiReservation.fromJson(Map<String, dynamic> json) {
    return AsoEbiReservation(
      id: (json['id'] ?? '').toString(),
      fabricId: (json['fabricId'] ?? '').toString(),
      fabricName: (json['fabricName'] ?? '').toString(),
      packageType: (json['packageType'] ?? '').toString(),
      size: (json['size'] ?? '').toString(),
      guestName: (json['guestName'] ?? '').toString(),
      guestEmail: json['guestEmail'] as String?,
      priceMinor: (json['priceMinor'] as num?)?.toInt() ?? 0,
      paymentStatus: (json['paymentStatus'] ?? 'pending').toString(),
      fulfillmentStatus: (json['fulfillmentStatus'] ?? 'reserved').toString(),
      reservedAt: DateTime.tryParse((json['reservedAt'] ?? '').toString()) ?? DateTime.now(),
      paidAt: json['paidAt'] != null ? DateTime.tryParse(json['paidAt'].toString()) : null,
      collectedAt: json['collectedAt'] != null ? DateTime.tryParse(json['collectedAt'].toString()) : null,
    );
  }
}

class AsoEbiPublicSnapshot {
  const AsoEbiPublicSnapshot({required this.fabrics});

  final List<AsoEbiFabric> fabrics;

  factory AsoEbiPublicSnapshot.fromJson(Map<String, dynamic> json) {
    return AsoEbiPublicSnapshot(
      fabrics: (json['fabrics'] as List<dynamic>? ?? [])
          .map((e) => AsoEbiFabric.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AsoEbiManageSnapshot {
  const AsoEbiManageSnapshot({
    required this.dashboard,
    required this.fabrics,
    required this.reservations,
  });

  final AsoEbiDashboard dashboard;
  final List<AsoEbiFabric> fabrics;
  final List<AsoEbiReservation> reservations;

  factory AsoEbiManageSnapshot.fromJson(Map<String, dynamic> json) {
    return AsoEbiManageSnapshot(
      dashboard: AsoEbiDashboard.fromJson(json['dashboard'] as Map<String, dynamic>? ?? const {}),
      fabrics: (json['fabrics'] as List<dynamic>? ?? [])
          .map((e) => AsoEbiFabric.fromJson(e as Map<String, dynamic>))
          .toList(),
      reservations: (json['reservations'] as List<dynamic>? ?? [])
          .map((e) => AsoEbiReservation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
