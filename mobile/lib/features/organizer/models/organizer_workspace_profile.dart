/// Organizer workspace profile — independent of Global and Attendee profiles.
class OrganizerWorkspaceProfile {
  const OrganizerWorkspaceProfile({
    required this.userId,
    this.organizerId,
    this.organizerName = '',
    this.businessName = '',
    this.businessType,
    this.yearsOfExperience,
    this.bio,
    this.supportEmail,
    this.supportPhone,
    this.website,
    this.socialLinks = const {},
    this.businessAddress,
    this.city,
    this.state,
    this.country,
    this.registrationNumber,
    this.registrationAuthority,
    this.registrationCountry,
    this.taxId,
    this.taxAuthority,
    this.verificationStatus = 'pending',
    this.verificationDocuments = const [],
    this.logoUrl,
    this.coverImageUrl,
    this.onboardingStep = 'profile',
  });

  final String userId;
  final String? organizerId;
  final String organizerName;
  final String businessName;
  final String? businessType;
  final int? yearsOfExperience;
  final String? bio;
  final String? supportEmail;
  final String? supportPhone;
  final String? website;
  final Map<String, String> socialLinks;
  final String? businessAddress;
  final String? city;
  final String? state;
  final String? country;
  final String? registrationNumber;
  final String? registrationAuthority;
  final String? registrationCountry;
  final String? taxId;
  final String? taxAuthority;
  final String verificationStatus;
  final List<OrganizerVerificationDocument> verificationDocuments;
  final String? logoUrl;
  final String? coverImageUrl;
  final String onboardingStep;

  factory OrganizerWorkspaceProfile.fromJson(Map<String, dynamic> json) {
    return OrganizerWorkspaceProfile(
      userId: json['userId'] as String? ?? '',
      organizerId: json['organizerId'] as String?,
      organizerName: (json['organizerName'] as String?) ??
          (json['displayName'] as String?) ??
          '',
      businessName: (json['businessName'] as String?) ??
          (json['organizationName'] as String?) ??
          '',
      businessType: json['businessType'] as String?,
      yearsOfExperience: (json['yearsOfExperience'] as num?)?.toInt(),
      bio: json['bio'] as String?,
      supportEmail: json['supportEmail'] as String?,
      supportPhone: json['supportPhone'] as String?,
      website: json['website'] as String?,
      socialLinks: _stringMap(json['socialLinks']),
      businessAddress: json['businessAddress'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      registrationNumber: json['registrationNumber'] as String?,
      registrationAuthority: json['registrationAuthority'] as String?,
      registrationCountry: json['registrationCountry'] as String?,
      taxId: json['taxId'] as String?,
      taxAuthority: json['taxAuthority'] as String?,
      verificationStatus: json['verificationStatus'] as String? ?? 'pending',
      verificationDocuments: _docs(json['verificationDocuments']),
      logoUrl: json['logoUrl'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      onboardingStep: json['onboardingStep'] as String? ?? 'profile',
    );
  }

  static Map<String, String> _stringMap(dynamic raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.key.toString().trim().isNotEmpty && '${e.value}'.trim().isNotEmpty)
          e.key.toString(): e.value.toString(),
    };
  }

  static List<OrganizerVerificationDocument> _docs(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) {
          if (e is String) {
            return OrganizerVerificationDocument(url: e);
          }
          if (e is Map) {
            return OrganizerVerificationDocument(
              url: e['url']?.toString() ?? '',
              name: e['name']?.toString(),
              uploadedAt: e['uploadedAt']?.toString(),
            );
          }
          return null;
        })
        .whereType<OrganizerVerificationDocument>()
        .where((d) => d.url.trim().isNotEmpty)
        .toList();
  }
}

class OrganizerVerificationDocument {
  const OrganizerVerificationDocument({
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

class OrganizerWorkspaceProfileUpdate {
  const OrganizerWorkspaceProfileUpdate({
    this.organizerName,
    this.businessName,
    this.businessType,
    this.yearsOfExperience,
    this.bio,
    this.supportEmail,
    this.supportPhone,
    this.website,
    this.socialLinks,
    this.businessAddress,
    this.city,
    this.state,
    this.country,
    this.registrationNumber,
    this.registrationAuthority,
    this.registrationCountry,
    this.taxId,
    this.taxAuthority,
    this.verificationStatus,
    this.verificationDocuments,
    this.logoUrl,
    this.clearLogo = false,
    this.coverImageUrl,
    this.clearCoverImage = false,
  });

  final String? organizerName;
  final String? businessName;
  final String? businessType;
  final int? yearsOfExperience;
  final String? bio;
  final String? supportEmail;
  final String? supportPhone;
  final String? website;
  final Map<String, String>? socialLinks;
  final String? businessAddress;
  final String? city;
  final String? state;
  final String? country;
  final String? registrationNumber;
  final String? registrationAuthority;
  final String? registrationCountry;
  final String? taxId;
  final String? taxAuthority;
  final String? verificationStatus;
  final List<OrganizerVerificationDocument>? verificationDocuments;
  final String? logoUrl;
  final bool clearLogo;
  final String? coverImageUrl;
  final bool clearCoverImage;

  Map<String, dynamic> toJson() => {
        if (organizerName != null) 'organizerName': organizerName,
        if (businessName != null) 'businessName': businessName,
        if (businessType != null) 'businessType': businessType,
        if (yearsOfExperience != null) 'yearsOfExperience': yearsOfExperience,
        if (bio != null) 'bio': bio,
        if (supportEmail != null) 'supportEmail': supportEmail,
        if (supportPhone != null) 'supportPhone': supportPhone,
        if (website != null) 'website': website,
        if (socialLinks != null) 'socialLinks': socialLinks,
        if (businessAddress != null) 'businessAddress': businessAddress,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (country != null) 'country': country,
        if (registrationNumber != null) 'registrationNumber': registrationNumber,
        if (registrationAuthority != null) 'registrationAuthority': registrationAuthority,
        if (registrationCountry != null) 'registrationCountry': registrationCountry,
        if (taxId != null) 'taxId': taxId,
        if (taxAuthority != null) 'taxAuthority': taxAuthority,
        if (verificationStatus != null) 'verificationStatus': verificationStatus,
        if (verificationDocuments != null)
          'verificationDocuments': verificationDocuments!.map((d) => d.toJson()).toList(),
        if (clearLogo) 'logoUrl': null,
        if (!clearLogo && logoUrl != null) 'logoUrl': logoUrl,
        if (clearCoverImage) 'coverImageUrl': null,
        if (!clearCoverImage && coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      };
}
