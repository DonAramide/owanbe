import '../auth/user_role.dart';

/// Owanbe 2.0 workspace activation state.
enum WorkspaceStatus {
  notActivated,
  inProgress,
  active,
  suspended;

  static WorkspaceStatus fromApi(String? value) => switch (value) {
        'not_activated' => WorkspaceStatus.notActivated,
        'in_progress' => WorkspaceStatus.inProgress,
        'active' => WorkspaceStatus.active,
        'suspended' => WorkspaceStatus.suspended,
        _ => WorkspaceStatus.notActivated,
      };

  String get apiValue => switch (this) {
        WorkspaceStatus.notActivated => 'not_activated',
        WorkspaceStatus.inProgress => 'in_progress',
        WorkspaceStatus.active => 'active',
        WorkspaceStatus.suspended => 'suspended',
      };
}

enum ExperienceWorkspace {
  attendee,
  organizer,
  vendor;

  UserRole get userRole => switch (this) {
        ExperienceWorkspace.attendee => UserRole.client,
        ExperienceWorkspace.organizer => UserRole.organizer,
        ExperienceWorkspace.vendor => UserRole.vendor,
      };

  String get apiCode => switch (this) {
        ExperienceWorkspace.attendee => 'client',
        ExperienceWorkspace.organizer => 'organizer',
        ExperienceWorkspace.vendor => 'vendor',
      };

  static ExperienceWorkspace? fromApiCode(String? code) => switch (code) {
        'client' => ExperienceWorkspace.attendee,
        'organizer' => ExperienceWorkspace.organizer,
        'vendor' => ExperienceWorkspace.vendor,
        _ => null,
      };

  static ExperienceWorkspace? fromUserRole(UserRole role) => switch (role) {
        UserRole.client => ExperienceWorkspace.attendee,
        UserRole.organizer => ExperienceWorkspace.organizer,
        UserRole.vendor => ExperienceWorkspace.vendor,
        _ => null,
      };

  String get title => switch (this) {
        ExperienceWorkspace.attendee => 'Attendee',
        ExperienceWorkspace.organizer => 'Organizer',
        ExperienceWorkspace.vendor => 'Vendor',
      };

  String get subtitle => switch (this) {
        ExperienceWorkspace.attendee =>
          'Discover events, buy tickets, manage RSVPs, and check in seamlessly.',
        ExperienceWorkspace.organizer =>
          'Create events, sell tickets, manage guests and vendors, and grow your brand.',
        ExperienceWorkspace.vendor =>
          'Receive bookings, showcase services, manage availability, and track earnings.',
      };

  List<String> get highlights => switch (this) {
        ExperienceWorkspace.attendee => [
            'Discover events',
            'Buy tickets',
            'Manage tickets',
            'RSVP',
            'View invitations',
            'Check in to events',
          ],
        ExperienceWorkspace.organizer => [
            'Create events',
            'Sell tickets',
            'Manage guests',
            'Manage vendors',
            'Track sales',
            'View analytics',
            'Build your event brand',
          ],
        ExperienceWorkspace.vendor => [
            'Receive bookings',
            'Showcase services',
            'Manage availability',
            'Communicate with organizers',
            'Track earnings',
            'Build your reputation',
          ],
      };
}

class WorkspaceState {
  const WorkspaceState({
    required this.workspace,
    required this.status,
    this.profileCompletionPct = 0,
    this.onboardingStep,
    this.activatedAt,
  });

  final ExperienceWorkspace workspace;
  final WorkspaceStatus status;
  final int profileCompletionPct;
  final String? onboardingStep;
  final DateTime? activatedAt;

  bool get isActive => status == WorkspaceStatus.active;
  bool get canOpen => isActive;
  bool get needsActivation => status == WorkspaceStatus.notActivated;
  bool get needsContinue => status == WorkspaceStatus.inProgress;

  factory WorkspaceState.fromJson(Map<String, dynamic> json) {
    final ws = ExperienceWorkspace.fromApiCode(json['workspace'] as String?) ??
        ExperienceWorkspace.attendee;
    return WorkspaceState(
      workspace: ws,
      status: WorkspaceStatus.fromApi(json['status'] as String?),
      profileCompletionPct: (json['profileCompletionPct'] as num?)?.toInt() ?? 0,
      onboardingStep: json['onboardingStep'] as String?,
      activatedAt: json['activatedAt'] != null
          ? DateTime.tryParse(json['activatedAt'] as String)
          : null,
    );
  }
}
