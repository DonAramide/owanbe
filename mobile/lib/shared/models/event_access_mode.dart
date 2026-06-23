/// Core product rule: every event is either invitation-based or ticketed.
enum EventAccessMode {
  privateInvitation,
  publicTicketed,
}

extension EventAccessModeX on EventAccessMode {
  String get apiValue => switch (this) {
        EventAccessMode.privateInvitation => 'PRIVATE_INVITATION',
        EventAccessMode.publicTicketed => 'PUBLIC_TICKETED',
      };

  String get label => switch (this) {
        EventAccessMode.privateInvitation => 'Private celebration',
        EventAccessMode.publicTicketed => 'Public ticketed event',
      };

  bool get showsGuestMetrics => this == EventAccessMode.privateInvitation;

  bool get showsTicketMetrics => this == EventAccessMode.publicTicketed;

  static EventAccessMode fromApi(String? raw) {
    if (raw == 'PUBLIC_TICKETED') return EventAccessMode.publicTicketed;
    return EventAccessMode.privateInvitation;
  }

  static EventAccessMode fromCategoryAccessMode(String? raw) => fromApi(raw);
}
