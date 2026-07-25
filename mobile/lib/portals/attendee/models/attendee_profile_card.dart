/// Privacy-filtered attendee profile card (self or peer).
class AttendeeProfileCard {
  const AttendeeProfileCard({
    required this.userId,
    required this.visible,
    required this.isSelf,
    required this.displayName,
    this.preferredDisplayName,
    this.avatarUrl,
    this.bio,
    this.occupation,
    this.company,
    this.interests = const [],
    this.preferredEventCategories = const [],
    this.accessibilityRequirements,
    this.dietaryPreferences,
    this.socialLinks = const {},
    this.privacyShowToOrganizers = true,
    this.privacyShowToAttendees = false,
    this.visibilityReason,
  });

  final String userId;
  final bool visible;
  final bool isSelf;
  final String displayName;
  final String? preferredDisplayName;
  final String? avatarUrl;
  final String? bio;
  final String? occupation;
  final String? company;
  final List<String> interests;
  final List<String> preferredEventCategories;
  final String? accessibilityRequirements;
  final String? dietaryPreferences;
  final Map<String, String> socialLinks;
  final bool privacyShowToOrganizers;
  final bool privacyShowToAttendees;
  final String? visibilityReason;

  factory AttendeeProfileCard.fromJson(Map<String, dynamic> json) {
    final social = <String, String>{};
    final raw = json['socialLinks'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final v = e.value?.toString().trim() ?? '';
        if (v.isNotEmpty) social[e.key.toString()] = v;
      }
    }
    return AttendeeProfileCard(
      userId: json['userId'] as String? ?? '',
      visible: json['visible'] as bool? ?? false,
      isSelf: json['isSelf'] as bool? ?? false,
      displayName: json['displayName'] as String? ?? 'Attendee',
      preferredDisplayName: json['preferredDisplayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      occupation: json['occupation'] as String?,
      company: json['company'] as String?,
      interests: _strings(json['interests']),
      preferredEventCategories: _strings(json['preferredEventCategories']),
      accessibilityRequirements: json['accessibilityRequirements'] as String?,
      dietaryPreferences: json['dietaryPreferences'] as String?,
      socialLinks: social,
      privacyShowToOrganizers: json['privacyShowToOrganizers'] as bool? ?? true,
      privacyShowToAttendees: json['privacyShowToAttendees'] as bool? ?? false,
      visibilityReason: json['visibilityReason'] as String?,
    );
  }

  static List<String> _strings(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  }
}
