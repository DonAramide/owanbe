import '../core/api/identity_api.dart';
import 'workspace_models.dart';

class OwanbeUserIdentity {
  const OwanbeUserIdentity({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.roles,
    required this.workspaces,
    this.avatarUrl,
    this.firstNameField,
    this.lastNameField,
    this.bio,
    this.occupation,
    this.company,
    this.interests = const [],
    this.socialLinks = const {},
    this.signupPortal,
    this.onboardingComplete = false,
    this.lastActiveWorkspace,
    this.identityVersion = '2.0',
  });

  final String userId;
  final String email;
  final String displayName;
  final String? avatarUrl;
  /// Explicit global first name (may differ from [firstName] derived from displayName).
  final String? firstNameField;
  final String? lastNameField;
  final String? bio;
  final String? occupation;
  final String? company;
  final List<String> interests;
  final Map<String, String> socialLinks;
  final List<String> roles;
  final List<WorkspaceState> workspaces;
  final String? signupPortal;
  final bool onboardingComplete;
  final String? lastActiveWorkspace;
  final String identityVersion;

  String get firstName {
    final explicit = firstNameField?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : displayName;
  }

  WorkspaceState workspaceState(ExperienceWorkspace ws) {
    return workspaces.firstWhere(
      (w) => w.workspace == ws,
      orElse: () => WorkspaceState(workspace: ws, status: WorkspaceStatus.notActivated),
    );
  }

  bool canAccess(ExperienceWorkspace ws) =>
      workspaceState(ws).status == WorkspaceStatus.active;

  /// User may open workspace routes while onboarding is in progress.
  bool canEnter(ExperienceWorkspace ws) {
    final status = workspaceState(ws).status;
    return status == WorkspaceStatus.active || status == WorkspaceStatus.inProgress;
  }

  ExperienceWorkspace? get suggestedWorkspace {
    final last = ExperienceWorkspace.fromApiCode(lastActiveWorkspace);
    if (last != null && canAccess(last)) return last;
    for (final ws in ExperienceWorkspace.values) {
      if (canAccess(ws)) return ws;
    }
    return null;
  }

  factory OwanbeUserIdentity.fromAuthMe(AuthMeResult me, {String? displayName, String? avatarUrl}) {
    return OwanbeUserIdentity(
      userId: me.userId,
      email: me.email,
      displayName: displayName ?? me.displayName ?? me.email.split('@').first,
      avatarUrl: me.avatarUrl ?? avatarUrl,
      firstNameField: me.firstName,
      lastNameField: me.lastName,
      bio: me.bio,
      occupation: me.occupation,
      company: me.company,
      interests: me.interests,
      socialLinks: me.socialLinks,
      roles: me.roles,
      workspaces: me.workspaces,
      signupPortal: me.signupPortal,
      onboardingComplete: me.onboardingComplete,
      lastActiveWorkspace: me.lastActiveWorkspace,
      identityVersion: me.identityVersion,
    );
  }
}
