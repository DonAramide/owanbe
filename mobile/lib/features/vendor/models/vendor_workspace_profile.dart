/// Vendor workspace profile — independent of Global / Attendee / Organizer profiles.
class VendorWorkspaceProfile {
  const VendorWorkspaceProfile({
    required this.userId,
    this.vendorId,
    this.businessName = '',
    this.category = '',
    this.subcategory,
    this.yearsOfExperience,
    this.businessDescription,
    this.servicesOffered = const [],
    this.services = const [],
    this.serviceAreas = const [],
    this.portfolioImages = const [],
    this.portfolioVideos = const [],
    this.portfolioWebsite,
    this.startingPrice,
    this.priceRange,
    this.teamSize,
    this.maxEventCapacity,
    this.availableForBookings = true,
    this.advanceBookingNotice,
    this.businessAddress,
    this.city,
    this.state,
    this.country,
    this.contactPhone,
    this.contactEmail,
    this.verificationDocuments = const [],
    this.businessRegistrationNumber,
    this.taxId,
    this.socialLinks = const {},
    this.logoUrl,
    this.coverImageUrl,
    this.onboardingStep = 'not_started',
  });

  final String userId;
  final String? vendorId;
  final String businessName;
  final String category;
  final String? subcategory;
  final int? yearsOfExperience;
  final String? businessDescription;
  final List<String> servicesOffered;
  /// First-class vendor_services entities (additive).
  final List<VendorServiceEntity> services;
  final List<String> serviceAreas;
  final List<String> portfolioImages;
  final List<String> portfolioVideos;
  final String? portfolioWebsite;
  final String? startingPrice;
  final String? priceRange;
  final int? teamSize;
  final int? maxEventCapacity;
  final bool availableForBookings;
  final String? advanceBookingNotice;
  final String? businessAddress;
  final String? city;
  final String? state;
  final String? country;
  final String? contactPhone;
  final String? contactEmail;
  final List<VendorVerificationDocument> verificationDocuments;
  final String? businessRegistrationNumber;
  final String? taxId;
  final Map<String, String> socialLinks;
  final String? logoUrl;
  final String? coverImageUrl;
  final String onboardingStep;

  factory VendorWorkspaceProfile.fromJson(Map<String, dynamic> json) {
    return VendorWorkspaceProfile(
      userId: json['userId'] as String? ?? '',
      vendorId: json['vendorId'] as String?,
      businessName: json['businessName'] as String? ?? '',
      category: json['category'] as String? ?? '',
      subcategory: json['subcategory'] as String?,
      yearsOfExperience: (json['yearsOfExperience'] as num?)?.toInt(),
      businessDescription: (json['businessDescription'] as String?) ?? (json['bio'] as String?),
      servicesOffered: _stringList(json['servicesOffered']),
      services: _services(json['services']),
      serviceAreas: _stringList(json['serviceAreas']),
      portfolioImages: _stringList(json['portfolioImages']),
      portfolioVideos: _stringList(json['portfolioVideos']),
      portfolioWebsite: json['portfolioWebsite'] as String?,
      startingPrice: json['startingPrice'] as String?,
      priceRange: json['priceRange'] as String?,
      teamSize: (json['teamSize'] as num?)?.toInt(),
      maxEventCapacity: (json['maxEventCapacity'] as num?)?.toInt(),
      availableForBookings: json['availableForBookings'] as bool? ?? true,
      advanceBookingNotice: json['advanceBookingNotice'] as String?,
      businessAddress: json['businessAddress'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      contactPhone: json['contactPhone'] as String?,
      contactEmail: json['contactEmail'] as String?,
      verificationDocuments: _docs(json['verificationDocuments']),
      businessRegistrationNumber: json['businessRegistrationNumber'] as String?,
      taxId: json['taxId'] as String?,
      socialLinks: _stringMap(json['socialLinks']),
      logoUrl: json['logoUrl'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      onboardingStep: json['onboardingStep'] as String? ?? 'not_started',
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  }

  static Map<String, String> _stringMap(dynamic raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.key.toString().trim().isNotEmpty && '${e.value}'.trim().isNotEmpty)
          e.key.toString(): e.value.toString(),
    };
  }

  static List<VendorVerificationDocument> _docs(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) {
          if (e is String) return VendorVerificationDocument(url: e);
          if (e is Map) {
            return VendorVerificationDocument(
              url: e['url']?.toString() ?? '',
              name: e['name']?.toString(),
              uploadedAt: e['uploadedAt']?.toString(),
            );
          }
          return null;
        })
        .whereType<VendorVerificationDocument>()
        .where((d) => d.url.trim().isNotEmpty)
        .toList();
  }

  static List<VendorServiceEntity> _services(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => VendorServiceEntity.fromJson(Map<String, dynamic>.from(e)))
        .where((s) => s.id.trim().isNotEmpty)
        .toList();
  }
}

class VendorServiceEntity {
  const VendorServiceEntity({
    required this.id,
    required this.serviceKey,
    required this.serviceName,
    this.serviceCode,
    this.status = 'active',
  });

  final String id;
  final String serviceKey;
  final String serviceName;
  final String? serviceCode;
  final String status;

  factory VendorServiceEntity.fromJson(Map<String, dynamic> json) {
    return VendorServiceEntity(
      id: json['id'] as String? ?? '',
      serviceKey: json['serviceKey'] as String? ?? '',
      serviceName: json['serviceName'] as String? ?? '',
      serviceCode: json['serviceCode'] as String?,
      status: json['status'] as String? ?? 'active',
    );
  }
}

class VendorVerificationDocument {
  const VendorVerificationDocument({
    required this.url,
    this.name,
    this.uploadedAt,
  });

  final String url;
  final String? name;
  final String? uploadedAt;

  Map<String, dynamic> toJson() => {
        'url': url,
        if (name != null && name!.trim().isNotEmpty) 'name': name,
        if (uploadedAt != null && uploadedAt!.trim().isNotEmpty) 'uploadedAt': uploadedAt,
      };
}

class VendorWorkspaceProfileUpdate {
  const VendorWorkspaceProfileUpdate({
    this.businessName,
    this.category,
    this.subcategory,
    this.yearsOfExperience,
    this.businessDescription,
    this.servicesOffered,
    this.servicePrices,
    this.serviceAreas,
    this.portfolioImages,
    this.portfolioVideos,
    this.portfolioWebsite,
    this.startingPrice,
    this.priceRange,
    this.teamSize,
    this.maxEventCapacity,
    this.availableForBookings,
    this.advanceBookingNotice,
    this.businessAddress,
    this.city,
    this.state,
    this.country,
    this.contactPhone,
    this.contactEmail,
    this.verificationDocuments,
    this.businessRegistrationNumber,
    this.taxId,
    this.socialLinks,
    this.logoUrl,
    this.clearLogo = false,
    this.coverImageUrl,
    this.clearCoverImage = false,
  });

  final String? businessName;
  final String? category;
  final String? subcategory;
  final int? yearsOfExperience;
  final String? businessDescription;
  final List<String>? servicesOffered;
  /// Per-service vendor/base payouts in minor units → vendor_services.base_payout_minor.
  final List<Map<String, dynamic>>? servicePrices;
  final List<String>? serviceAreas;
  final List<String>? portfolioImages;
  final List<String>? portfolioVideos;
  final String? portfolioWebsite;
  final String? startingPrice;
  final String? priceRange;
  final int? teamSize;
  final int? maxEventCapacity;
  final bool? availableForBookings;
  final String? advanceBookingNotice;
  final String? businessAddress;
  final String? city;
  final String? state;
  final String? country;
  final String? contactPhone;
  final String? contactEmail;
  final List<VendorVerificationDocument>? verificationDocuments;
  final String? businessRegistrationNumber;
  final String? taxId;
  final Map<String, String>? socialLinks;
  final String? logoUrl;
  final bool clearLogo;
  final String? coverImageUrl;
  final bool clearCoverImage;

  Map<String, dynamic> toJson() => {
        if (businessName != null) 'businessName': businessName,
        if (category != null) 'category': category,
        if (subcategory != null) 'subcategory': subcategory,
        if (yearsOfExperience != null) 'yearsOfExperience': yearsOfExperience,
        if (businessDescription != null) 'businessDescription': businessDescription,
        if (servicesOffered != null) 'servicesOffered': servicesOffered,
        if (servicePrices != null) 'servicePrices': servicePrices,
        if (serviceAreas != null) 'serviceAreas': serviceAreas,
        if (portfolioImages != null) 'portfolioImages': portfolioImages,
        if (portfolioVideos != null) 'portfolioVideos': portfolioVideos,
        if (portfolioWebsite != null) 'portfolioWebsite': portfolioWebsite,
        if (startingPrice != null) 'startingPrice': startingPrice,
        if (priceRange != null) 'priceRange': priceRange,
        if (teamSize != null) 'teamSize': teamSize,
        if (maxEventCapacity != null) 'maxEventCapacity': maxEventCapacity,
        if (availableForBookings != null) 'availableForBookings': availableForBookings,
        if (advanceBookingNotice != null) 'advanceBookingNotice': advanceBookingNotice,
        if (businessAddress != null) 'businessAddress': businessAddress,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (country != null) 'country': country,
        if (contactPhone != null) 'contactPhone': contactPhone,
        if (contactEmail != null) 'contactEmail': contactEmail,
        if (verificationDocuments != null)
          'verificationDocuments': verificationDocuments!.map((d) => d.toJson()).toList(),
        if (businessRegistrationNumber != null)
          'businessRegistrationNumber': businessRegistrationNumber,
        if (taxId != null) 'taxId': taxId,
        if (socialLinks != null) 'socialLinks': socialLinks,
        if (clearLogo) 'logoUrl': null,
        if (!clearLogo && logoUrl != null) 'logoUrl': logoUrl,
        if (clearCoverImage) 'coverImageUrl': null,
        if (!clearCoverImage && coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      };
}
