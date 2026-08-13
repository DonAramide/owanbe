/**
 * Shared SQL predicate: organizer owner OR active organization member.
 * Does not redesign access — extends owner-only checks backward-compatibly.
 */
export function sqlOrganizerOwnerOrMember(userParam: string, alias = 'o'): string {
  return `(${alias}.owner_user_id = ${userParam} OR EXISTS (
    SELECT 1 FROM organizer_members om
    WHERE om.organizer_id = ${alias}.id
      AND om.user_id = ${userParam}
      AND om.status = 'active'
  ))`;
}

export const ORG_ROLES = ['admin', 'manager', 'staff'] as const;
export type OrgMemberRole = (typeof ORG_ROLES)[number];

/** Capability overlay — consumes portal RBAC; does not replace it. */
export type OrgCapability =
  | 'team.manage'
  | 'org.settings'
  | 'events.write'
  | 'finance.read'
  | 'ops.door'
  | 'analytics.read'
  | 'reports.read'
  | 'vendors.read'
  | 'automations.read'
  | 'integrations.manage'
  | 'marketing.manage';

const ROLE_CAPABILITIES: Record<OrgMemberRole | 'owner', OrgCapability[]> = {
  owner: [
    'team.manage',
    'org.settings',
    'events.write',
    'finance.read',
    'ops.door',
    'analytics.read',
    'reports.read',
    'vendors.read',
    'automations.read',
    'integrations.manage',
    'marketing.manage',
  ],
  admin: [
    'team.manage',
    'org.settings',
    'events.write',
    'finance.read',
    'ops.door',
    'analytics.read',
    'reports.read',
    'vendors.read',
    'automations.read',
    'integrations.manage',
    'marketing.manage',
  ],
  manager: [
    'events.write',
    'finance.read',
    'ops.door',
    'analytics.read',
    'reports.read',
    'vendors.read',
    'automations.read',
    'marketing.manage',
  ],
  staff: ['ops.door', 'analytics.read', 'reports.read'],
};

export function capabilitiesForOrgRole(role: OrgMemberRole | 'owner'): OrgCapability[] {
  return ROLE_CAPABILITIES[role] ?? ROLE_CAPABILITIES.staff;
}

export function orgRoleHasCapability(
  role: OrgMemberRole | 'owner',
  capability: OrgCapability,
): boolean {
  return capabilitiesForOrgRole(role).includes(capability);
}
