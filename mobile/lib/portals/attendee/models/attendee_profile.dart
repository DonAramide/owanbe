/// Attendee workspace profile model — independent of Global User Profile.
class AttendeeProfile {
  const AttendeeProfile({
    required this.userId,
    this.preferredDisplayName,
    this.preferredEventCategories = const [],
    this.interests = const [],
    this.accessibilityRequirements,
    this.dietaryPreferences,
    this.emergencyContactName,
    this.emergencyContactRelationship,
    this.emergencyContactPhone,
    this.notifyEmail = true,
    this.notifySms = false,
    this.notifyPush = true,
    this.privacyShowToOrganizers = true,
    this.privacyShowToAttendees = false,
    this.onboardingStep = 'not_started',
    this.activatedAt,
  });

  final String userId;
  final String? preferredDisplayName;
  final List<String> preferredEventCategories;
  final List<String> interests;
  final String? accessibilityRequirements;
  final String? dietaryPreferences;
  final String? emergencyContactName;
  final String? emergencyContactRelationship;
  final String? emergencyContactPhone;
  final bool notifyEmail;
  final bool notifySms;
  final bool notifyPush;
  final bool privacyShowToOrganizers;
  final bool privacyShowToAttendees;
  final String onboardingStep;
  final DateTime? activatedAt;

  factory AttendeeProfile.fromJson(Map<String, dynamic> json) {
    return AttendeeProfile(
      userId: json['userId'] as String? ?? '',
      preferredDisplayName: json['preferredDisplayName'] as String?,
      preferredEventCategories: _stringList(json['preferredEventCategories']),
      interests: _stringList(json['interests']),
      accessibilityRequirements: json['accessibilityRequirements'] as String?,
      dietaryPreferences: json['dietaryPreferences'] as String?,
      emergencyContactName: json['emergencyContactName'] as String?,
      emergencyContactRelationship: json['emergencyContactRelationship'] as String?,
      emergencyContactPhone: json['emergencyContactPhone'] as String?,
      notifyEmail: json['notifyEmail'] as bool? ?? true,
      notifySms: json['notifySms'] as bool? ?? false,
      notifyPush: json['notifyPush'] as bool? ?? true,
      privacyShowToOrganizers: json['privacyShowToOrganizers'] as bool? ?? true,
      privacyShowToAttendees: json['privacyShowToAttendees'] as bool? ?? false,
      onboardingStep: json['onboardingStep'] as String? ?? 'not_started',
      activatedAt: json['activatedAt'] != null
          ? DateTime.tryParse(json['activatedAt'] as String)
          : null,
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  }
}

class AttendeeProfileUpdate {
  const AttendeeProfileUpdate({
    this.preferredDisplayName,
    this.preferredEventCategories,
    this.interests,
    this.accessibilityRequirements,
    this.dietaryPreferences,
    this.emergencyContactName,
    this.emergencyContactRelationship,
    this.emergencyContactPhone,
    this.notifyEmail,
    this.notifySms,
    this.notifyPush,
    this.privacyShowToOrganizers,
    this.privacyShowToAttendees,
  });

  final String? preferredDisplayName;
  final List<String>? preferredEventCategories;
  final List<String>? interests;
  final String? accessibilityRequirements;
  final String? dietaryPreferences;
  final String? emergencyContactName;
  final String? emergencyContactRelationship;
  final String? emergencyContactPhone;
  final bool? notifyEmail;
  final bool? notifySms;
  final bool? notifyPush;
  final bool? privacyShowToOrganizers;
  final bool? privacyShowToAttendees;

  Map<String, dynamic> toJson() => {
        if (preferredDisplayName != null) 'preferredDisplayName': preferredDisplayName,
        if (preferredEventCategories != null)
          'preferredEventCategories': preferredEventCategories,
        if (interests != null) 'interests': interests,
        if (accessibilityRequirements != null)
          'accessibilityRequirements': accessibilityRequirements,
        if (dietaryPreferences != null) 'dietaryPreferences': dietaryPreferences,
        if (emergencyContactName != null) 'emergencyContactName': emergencyContactName,
        if (emergencyContactRelationship != null)
          'emergencyContactRelationship': emergencyContactRelationship,
        if (emergencyContactPhone != null) 'emergencyContactPhone': emergencyContactPhone,
        if (notifyEmail != null) 'notifyEmail': notifyEmail,
        if (notifySms != null) 'notifySms': notifySms,
        if (notifyPush != null) 'notifyPush': notifyPush,
        if (privacyShowToOrganizers != null)
          'privacyShowToOrganizers': privacyShowToOrganizers,
        if (privacyShowToAttendees != null) 'privacyShowToAttendees': privacyShowToAttendees,
      };
}
