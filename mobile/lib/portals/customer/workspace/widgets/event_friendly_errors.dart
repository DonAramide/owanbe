/// Human-friendly error copy for Event OS surfaces (Phase 42.4).
///
/// Never surface raw exceptions, stack traces, or API payloads in UI.
abstract final class EventFriendlyErrors {
  static const genericHeadline = 'Something went wrong';
  static const genericMessage =
      'We couldn\'t load this section right now. Check your connection and try again.';

  static const workspaceHeadline = 'Couldn\'t open your event';
  static const workspaceMessage =
      'Your celebration workspace didn\'t load. Pull to refresh or head back to My Events.';

  static String headlineFor(String moduleLabel) => 'Couldn\'t load $moduleLabel';

  static String messageFor(String moduleLabel) =>
      'We couldn\'t load $moduleLabel right now. Check your connection and try again.';

  static const actionFailedMessage = 'Something went wrong. Please try again.';
}
