import type { OwanbeRole } from '../../common/types/jwt-user';

export type WorkspaceCode = 'client' | 'organizer' | 'vendor';
export type WorkspaceStatus = 'not_activated' | 'in_progress' | 'active' | 'suspended';

export interface WorkspaceStateDto {
  workspace: WorkspaceCode;
  status: WorkspaceStatus;
  profileCompletionPct: number;
  onboardingStep: string | null;
  activatedAt: string | null;
}

const WORKSPACE_ROLE: Record<WorkspaceCode, OwanbeRole[]> = {
  client: ['client'],
  organizer: ['organizer'],
  vendor: ['vendor', 'vendor_pending'],
};

export function workspaceFromRoleCode(role: OwanbeRole): WorkspaceCode | null {
  if (role === 'client') return 'client';
  if (role === 'organizer') return 'organizer';
  if (role === 'vendor' || role === 'vendor_pending') return 'vendor';
  return null;
}

export function hasWorkspaceRole(roles: OwanbeRole[], workspace: WorkspaceCode): boolean {
  const codes = WORKSPACE_ROLE[workspace];
  return roles.some((r) => codes.includes(r));
}

export function workspacePortalCode(workspace: WorkspaceCode): WorkspaceCode {
  return workspace;
}

export function workspacePrimaryRole(workspace: WorkspaceCode): OwanbeRole {
  switch (workspace) {
    case 'client':
      return 'client';
    case 'organizer':
      return 'organizer';
    case 'vendor':
      return 'vendor';
    default:
      return 'client';
  }
}

export function deriveWorkspaceStatus(input: {
  workspace: WorkspaceCode;
  roles: OwanbeRole[];
  userStatus: string;
  onboardingStep: string | null;
  profileCompletionPct: number;
  activatedAt: Date | null;
  userOnboardingComplete: boolean;
}): WorkspaceStateDto {
  if (input.userStatus !== 'active') {
    return {
      workspace: input.workspace,
      status: 'suspended',
      profileCompletionPct: input.profileCompletionPct,
      onboardingStep: input.onboardingStep,
      activatedAt: input.activatedAt?.toISOString() ?? null,
    };
  }

  const hasRole = hasWorkspaceRole(input.roles, input.workspace);

  if (hasRole && (input.activatedAt || input.onboardingStep === 'complete' || input.userOnboardingComplete)) {
    return {
      workspace: input.workspace,
      status: 'active',
      profileCompletionPct: Math.max(input.profileCompletionPct, 100),
      onboardingStep: input.onboardingStep ?? 'complete',
      activatedAt: input.activatedAt?.toISOString() ?? null,
    };
  }

  if (
    hasRole ||
    (input.onboardingStep && input.onboardingStep !== 'not_started') ||
    input.profileCompletionPct > 0
  ) {
    return {
      workspace: input.workspace,
      status: 'in_progress',
      profileCompletionPct: input.profileCompletionPct,
      onboardingStep: input.onboardingStep,
      activatedAt: input.activatedAt?.toISOString() ?? null,
    };
  }

  return {
    workspace: input.workspace,
    status: 'not_activated',
    profileCompletionPct: 0,
    onboardingStep: null,
    activatedAt: null,
  };
}
