/// Formal application startup state machine (Owanbe 2.0).
enum AppBootPhase {
  /// Provider created; boot sequence not started.
  uninitialized,

  /// Boot sequence running (session + prefs + connectivity).
  initializing,

  /// Supabase session resolved (signed in or out).
  sessionResolved,

  /// Minimum brand display elapsed; safe to navigate.
  ready,

  /// Session exists but API unreachable — proceed with cached/offline session.
  offlineReady,

  /// Configuration or connectivity blocked — navigate to diagnostics.
  connectivityBlocked,

  /// Unrecoverable bootstrap failure.
  error,
}

/// Immutable boot snapshot exposed to splash and router.
class AppBootSnapshot {
  const AppBootSnapshot({
    required this.phase,
    this.isAuthenticated = false,
    this.showWalkthrough = true,
    this.destination,
    this.errorMessage,
    this.startedAt,
    this.connectivityTitle,
    this.connectivityMessage,
    this.connectivityKind,
    this.configuredUrl,
    this.technicalDetail,
  });

  final AppBootPhase phase;
  final bool isAuthenticated;
  final bool showWalkthrough;
  final String? destination;
  final String? errorMessage;
  final DateTime? startedAt;

  /// Structured connectivity / config diagnostics (when [phase] is blocked).
  final String? connectivityTitle;
  final String? connectivityMessage;
  final String? connectivityKind;
  final String? configuredUrl;
  final String? technicalDetail;

  bool get canNavigate =>
      phase == AppBootPhase.ready ||
      phase == AppBootPhase.offlineReady ||
      phase == AppBootPhase.connectivityBlocked;

  AppBootSnapshot copyWith({
    AppBootPhase? phase,
    bool? isAuthenticated,
    bool? showWalkthrough,
    String? destination,
    String? errorMessage,
    DateTime? startedAt,
    String? connectivityTitle,
    String? connectivityMessage,
    String? connectivityKind,
    String? configuredUrl,
    String? technicalDetail,
    bool clearConnectivity = false,
  }) {
    return AppBootSnapshot(
      phase: phase ?? this.phase,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      showWalkthrough: showWalkthrough ?? this.showWalkthrough,
      destination: destination ?? this.destination,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt ?? this.startedAt,
      connectivityTitle:
          clearConnectivity ? null : (connectivityTitle ?? this.connectivityTitle),
      connectivityMessage:
          clearConnectivity ? null : (connectivityMessage ?? this.connectivityMessage),
      connectivityKind:
          clearConnectivity ? null : (connectivityKind ?? this.connectivityKind),
      configuredUrl: clearConnectivity ? null : (configuredUrl ?? this.configuredUrl),
      technicalDetail:
          clearConnectivity ? null : (technicalDetail ?? this.technicalDetail),
    );
  }
}
