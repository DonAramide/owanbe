/// Maps to platform roles (admin, client, vendor). One app, role from session after login.
enum UserRole {
  client,
  vendor,
  admin,
}

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.client => 'Client',
        UserRole.vendor => 'Vendor',
        UserRole.admin => 'Admin',
      };
}
