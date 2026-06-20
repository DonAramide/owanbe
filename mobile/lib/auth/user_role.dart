/// Platform roles — organizer operates events; client is attendee-facing.
enum UserRole {
  client,
  organizer,
  vendor,
  admin,
  superAdmin,
}

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.client => 'Attendee',
        UserRole.organizer => 'Organizer',
        UserRole.vendor => 'Vendor',
        UserRole.admin => 'Admin',
        UserRole.superAdmin => 'Control Tower',
      };
}
