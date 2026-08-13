# PHASE 22 — ORGANIZATION & TEAM MANAGEMENT — SCOPE DEFINITION & GAP ANALYSIS

**Date:** 2026-08-01  
**Method:** Architecture-derived (Phases 11–21 + live code audit) — not feature-wishlist  
**Constraint:** Scope definition only — **no implementation**, no application code changes beyond this document  
**Stabilization Mode:** Phases **14–19** architecture-frozen pending integrated Live QA — consume only  
**Business Operations Layer:** Phases **19–25** form one integrated layer; do not redesign completed earlier work; **one integrated Live QA after Phase 25**  
**Identity rule:** Do **not** redesign Authentication, portal RBAC, or experience Workspace Switching. Organization Management **consumes** existing identity infrastructure.

---

## 1. Executive verdict

| Dimension | Finding |
|-----------|---------|
| **Prior phase outcome** | Organizer can run the full event business loop through Reporting (21); Marketing (20) remains planned |
| **Proposed domain** | Organization & Team Management — **correct next Organizer capability** |
| **Prior roadmap** | Reporting (21) → **Organization & Team (22)** → later Business Ops (23–25) |
| **Natural Phase 22** | Move from single-owner organizer to **org + team** with roles that gate access to existing Event Workspace / Business Operations |
| **IA** | Primary = Organizer **Organization / Team** surface (home hub or workspace Administration); secondary = profile editor reuse; deep-link Event Workspace / Ops / Finance — do not fork them |
| **Overall** | **✅ Phase 22 Scope Defined** |

Nothing else should precede Organization & Team in the Organizer lifecycle. Integrations, advanced Marketing, or notification preference suites do not unblock multi-person event operations. Guest/vendor **Invitations** (Phase 15 / CRM) are **not** team invites — do not conflate them.

**Implementation gate (not a scope blocker):** Expanding access beyond `organizers.owner_user_id` touches frozen access resolvers (`EventsAccessService` and finance/ops ownership joins). **Before coding Phase 22, obtain explicit approval** for a controlled **extension** (owner OR active org member) modeled after `vendor_users` — not a redesign of Auth/RBAC/workflows. See §9–§10.

---

## 2. Business flow review — next missing capability

```
Create (12) → Operate (13–16) → Finance (17) → Analytics (18)
  → Vendor CRM (19) → Marketing (20) → Reporting (21)
  → ??? Scale the organization that runs the business
```

| After Phase 21 | Organizer can… | Still missing |
|----------------|----------------|---------------|
| Run & report an event | Operate alone as `owner_user_id` | Hire **staff** (door, finance viewer, ops lead) without sharing the owner login |
| Profile / branding | Edit org name, logo, cover | Org preferences + team directory |
| Portal RBAC | Hold `organizer` platform role | **Org-scoped** roles (admin / editor / door / finance-read) |
| Experience switcher | Client ↔ Organizer ↔ Vendor | **Not** multi-org membership; still single effective organizer |
| Audit | Platform admin audit log | Organizer-visible **team activity** for membership/role changes |

**Next missing organizational capability:** Organizer-facing **Organization & Team Management** — answer “who is on this org, what may they do, and which events/workspace can they enter?” by composing Identity, portal RBAC, and a new membership layer — without inventing a second auth system.

---

## 3. Phase definition

### Official Phase Name

**Phase 22 — Organization & Team Management**

### Business Goal

Enable an organizer organization to manage its **profile, staff, and org-scoped access** so multiple people can safely run Business Operations on shared events — without sharing the owner account.

### Technical Goal

Introduce a thin **Organization membership & org-role layer** that:

1. **Consumes** Universal Identity, `organizers` / `organizer_profiles`, portal `user_roles`, and experience workspace APIs.  
2. **Mirrors** the proven `vendor_users` ownership pattern (`VendorAccessService`) for organizers.  
3. **Extends** (with approval) organizer access resolution from owner-only → owner **or** active member.  
4. **Surfaces** Team / Organization UI on Organizer home / Administration — never forks Event Ops, Finance, or Analytics.

### Primary User Journeys

| ID | Journey |
|----|---------|
| J1 | Owner opens **Organization** and edits profile / branding (reuse existing profile APIs) |
| J2 | Owner invites a teammate by email → pending membership → accept activates access |
| J3 | Owner assigns an **org role** (e.g. Admin, Editor, Door Staff, Finance Viewer) |
| J4 | Teammate switches to Organizer experience and sees permitted events / workspace modules |
| J5 | Owner revokes or suspends a member; access ends on next authz check |
| J6 | Owner views **team activity** (invite / role change / revoke) — org-scoped audit, not platform admin redesign |
| J7 | Door staff opens Event Ops / check-in only (permission-gated); finance tabs Unavailable without finance-read |

### Success Criteria

- [ ] Organization profile/branding remains single source (`organizer_profiles`) — no duplicate profile store  
- [ ] Team directory lists members with status + org role  
- [ ] Invite / accept / revoke flows work end-to-end  
- [ ] Access checks allow members per approved org-role matrix (not owner-login sharing)  
- [ ] Auth, portal RBAC seed, and experience Workspace Switcher **unchanged in design**  
- [ ] Guest invitations and Vendor CRM invites remain separate products  
- [ ] Departments / multi-org switching deferred or Unavailable unless approved  
- [ ] Frozen event workflows untouched except approved access-resolver extension  

### Why this naturally follows Phase 21

Reporting closes **accountability** (evidence of what happened). Organization & Team opens **delegation** (who may operate and see that evidence). Staff access is the next Business Ops need after a solo owner can already run and export the business.

---

## 4. Feature breakdown (audit)

| Capability | Classification | Evidence | Phase 22 stance |
|------------|----------------|----------|-----------------|
| **Organization Profile** | **Fully Implemented** | `organizer_profiles`, `GET/PUT me/organizer-profile`, Flutter profile edit sheet | **Consume / surface** in Org hub |
| **Organization Settings** | **Partially Implemented** | Profile fields exist; no dedicated org-settings entity; Event Settings tab is event-scoped stubs | P1 thin preferences on profile; do not invent parallel settings DB |
| **Organization Branding** | **Partially Implemented** | `logo_url`, `cover_image_url`, socials on profile; event website branding separate | **Reuse profile branding**; do not merge with event website |
| **Team Members** | **Not Implemented** | No `organizer_users` / members table; access = `owner_user_id` only | **P0** membership table + directory |
| **Invitations** (team) | **Not Implemented** | Phase 15 = **guest** invites; vendor invite ≠ staff | **P0** team invite flow (distinct from guest/vendor) |
| **Departments** | **Not Implemented** | Workflow JSON stub only (`assignment: department`) | **Defer / out** |
| **Roles** (org-scoped) | **Not Implemented** (portal roles exist) | Platform `organizer` role via `user_roles`; no org staff roles | **P0** org roles mapped onto existing permission checks |
| **Permissions** | **Partially Implemented** | Phase-8 `PermissionsService` / matrix / guards — portal-level | **Consume**; add org-role → capability map; do not replace matrix |
| **Workspace Access** | **Fully Implemented** (experience) / **Not** (org) | `me/workspaces`, Workspace Switcher = Client/Organizer/Vendor | Consume experience switcher; org access = membership, not new switcher |
| **Activity Log** | **Backend Only** | `audit_log` + admin/super-admin UIs | **P1** org-scoped membership audit view (read/filter); do not redesign AuditModule |
| **Audit Trail** | **Backend Only** | Same as above | Reuse `AuditLogService.logAction` for team mutations |
| **Organization Preferences** | **Not Implemented** | — | Soft P2 on profile |
| **Multi-event Ownership** | **Fully Implemented** | Many `events` per `organizer_id` | Consume as-is |
| **Multi-organization Membership** | **Not Implemented** | Schema allows multiple `organizers` per owner; runtime `LIMIT 1` | **Defer** — single active org per user unless separately approved |
| **Staff Directory** | **Not Implemented** | — | **P0** with Team Members |

---

## 5. Existing implementation (keep / consume)

### NestJS / DB

| Asset | Role |
|-------|------|
| `organizers` (`owner_user_id`) | Canonical org business row |
| `organizer_profiles` | Profile + branding |
| `OrganizerProfileService` / Identity controller | Profile CRUD |
| `IdentityService.upsertOrganizerProfile` / signup ensure | Org bootstrap |
| `WorkspaceService` / `WorkspaceController` | Experience activation & listing |
| `RolesGuard`, `PermissionsGuard`, `permission-matrix`, `PermissionsService` | Portal RBAC |
| `user_roles` / `role_permissions` | Platform role grants |
| `AuditLogService` / `audit_log` | Mutation audit writes |
| `VendorAccessService` + `vendor_users` | **Pattern to mirror** for organizer staff |
| `EventsAccessService.resolveOrganizerId` | Current owner-only choke point |
| Platform Admin organizers APIs | Suspend/reactivate orgs — admin only |

### Flutter

| Asset | Role |
|-------|------|
| `organizer_profile_edit_sheet.dart` | Profile/branding editor |
| `organizer_onboarding_screen.dart` | Org name capture |
| `workspace_switcher.dart` / identity providers | Experience switching |
| `settings_tab_v3.dart` | Event settings (not org team) — leave as event IA |
| Organizer home / dashboard | Host for Org/Team entry |

---

## 6. Missing implementation

| Gap | Priority | Notes |
|-----|----------|-------|
| `organizer_members` (or `organizer_users`) table + status | **P0** | Mirror `vendor_users` |
| Team invite / accept / revoke APIs | **P0** | Distinct from guest invitations |
| Org roles + capability map | **P0** | e.g. `org_admin`, `org_editor`, `door_staff`, `finance_viewer` |
| Approved access-resolver extension | **P0** | Owner OR active member (+ role gates) |
| Team directory UI | **P0** | Organizer portal |
| Organization hub (profile + team) | **P0–P1** | Reuse profile sheet |
| Org-scoped activity feed | **P1** | Filter audit / dedicated membership events |
| Org preferences polish | **P2** | On existing profile |
| Departments | **Out** | — |
| Multi-org switcher | **Out / defer** | Avoid until approved |
| Redesign Auth / portal RBAC / experience switcher | **Forbidden** | — |

---

## 7. Hidden / mock / backend-only

| Item | Classification | Evidence |
|------|----------------|----------|
| Platform audit timeline | **Backend Only** (+ admin UI) | Admin/super-admin screens; not organizer |
| Event Settings “Guest/Vendor permissions” tiles | **Frontend Only / stub** | `settings_tab_v3.dart` — event IA, not org RBAC |
| `vendor_users` staff model | **Implemented but Hidden** (vendors) | Exists for vendors; unused pattern for organizers |
| Multiple organizers per `owner_user_id` | **Backend possible / Hidden** | No UNIQUE on owner; resolvers force `LIMIT 1` |
| Workflow “department” assignment | **Frontend/DB stub** | Enterprise workflows JSON |

---

## 8. Reuse analysis (do not duplicate)

| Domain | Reuse | Do not |
|--------|-------|--------|
| **Authentication** | JWT, `ensure-user`, session | Second login / org SSO product in Phase 22 |
| **Portal RBAC** | `RolesGuard`, `PermissionsService`, role activate | Parallel permission tables that ignore Phase-8 |
| **Workspace Switching** | Experience workspaces API + Flutter switcher | Multi-org switcher clone of experience switcher |
| **Organizer Profile** | Profile service + edit sheet | Second “org profile” entity |
| **Organization Models** | `organizers` + `organizer_profiles` | New `organizations` table duplicating organizers |
| **Audit Logs** | `AuditLogService` | New audit warehouse |
| **Notifications** | Existing `NotificationService` for invite emails/in-app | New messaging stack |
| **Vendor staff pattern** | `vendor_users` + `VendorAccessService` | Invent unrelated membership semantics |
| **Event ownership** | `events.organizer_id` | Per-event owner fork |
| **Guest / Vendor invites** | Keep separate modules | Reuse invitation tokens as staff auth |

**Proposed membership pattern (for approval):**

```
organizers.owner_user_id          → org owner (unchanged)
organizer_members (new)           → user_id, organizer_id, org_role, status
EventsAccessService (extend)      → owner OR active member
Capability checks                 → org_role → allow Ops / Finance / etc.
```

---

## 9. Dependencies

| Dependency | Relationship |
|------------|--------------|
| **Authentication / Identity** | **Hard** — consume only |
| **Workspace (experience)** | **Hard** — teammate must activate Organizer experience |
| **Portal RBAC** | **Hard** — members need `organizer` (or equivalent) platform role via existing activate path |
| **Event Ownership** | **Hard** — events stay on `organizer_id`; membership grants access to that org’s events |
| **Access resolver extension** | **Hard gate** — requires explicit approval before implementation (touches frozen consumers) |
| **Vendor CRM** | Soft — no redesign; team ≠ vendors |
| **Finance / Reporting / Ops** | Soft consumers — role gates may hide tabs; do not rewrite modules |
| **NotificationService** | Soft — invite delivery |

### Dependency requiring approval (STOP before code)

| Change | Why | Risk if skipped |
|--------|-----|-----------------|
| Extend `EventsAccessService` (+ finance/ops ownership joins) to accept **active org members** | Today every frozen Organizer API is owner-only; team access cannot work otherwise | Either Phase 22 is UI-only fiction, or we force password sharing |

This is an **access extension**, not a workflow redesign — still **must be approved** under Stabilization Mode.

---

## 10. Risks

| Risk | Mitigation |
|------|------------|
| Redesigning Auth / RBAC / Workspace Switcher | Hard forbid; consume APIs |
| Conflating guest invites with team invites | Separate routes/UI; naming “Team invite” |
| Expanding access without role gates | Org-role matrix; door staff ≠ finance |
| Multi-org scope creep | Defer; keep `LIMIT 1` active org unless approved |
| Departments / HR suite | Out of Phase 22 |
| Silent owner-only checks left in some services | Inventory all `owner_user_id` joins; extend consistently after approval |
| Marketing (20) unfinished | Independent — does not block Team |
| Treating vendor_users as organizer staff | Mirror pattern in **new** organizer membership table |

---

## 11. Implementation effort

| Module | Effort | Notes |
|--------|--------|-------|
| Membership schema + CRUD APIs | **Medium** | Mirror vendor_users |
| Team invite accept/revoke + notifications | **Medium** | |
| Org-role → capability map | **Medium** | |
| Access resolver extension (approved) | **Medium** | Touches many ownership queries |
| Organization / Team Flutter hub | **Medium** | Reuse profile editor |
| Org activity feed | **Small–Medium** | Audit filter |
| Departments / multi-org switcher | **Large** | **Defer** |

**Overall Phase 22 (P0–P1):** **Medium–Large**  
**With departments + multi-org:** **Large** — do not default into scope  

---

## 12. Completion Sprint roadmap (proposed)

### Sprint A — Foundation (after access-extension approval)

1. Approve access-resolver extension design (owner OR member).  
2. Add `organizer_members` (+ org_role, status) migration.  
3. Membership list / invite / accept / revoke APIs.  
4. Extend `EventsAccessService` (and critical finance/ops ownership checks) consistently.

### Sprint B — Roles & UI (P0)

5. Org-role capability map (Admin / Editor / Door / Finance Viewer).  
6. Organization hub: profile (reuse) + Team directory.  
7. Gate workspace modules by capability (Unavailable vs hide with reason).  
8. Audit log writes for membership mutations.

### Sprint C — Polish (P1–P2)

9. Org-scoped activity view for owners/admins.  
10. Preferences polish on profile.  
11. Explicit Unavailable for departments / multi-org.  
12. Regression: owner-only paths still work; frozen workflows unchanged.

---

## 13. Architecture question — canonical Organization Management lifecycle

```
Organization          (organizers + organizer_profiles)
        ↓
Team                  (organizer_members — invite / accept / revoke)
        ↓
Roles                 (org_role on membership — not a second Auth)
        ↓
Permissions           (org_role → capabilities; consume portal PermissionsService / guards)
        ↓
Workspace             (experience Workspace Switcher → Organizer; module gates)
        ↓
Events                (events.organizer_id; access via extended EventsAccessService)
        ↓
Business Operations   (Ops, Finance, Analytics, Vendor CRM, Marketing, Reporting — consume only)
```

### Modules reused at each step

| Step | Reused modules |
|------|----------------|
| **Organization** | `organizers`, `organizer_profiles`, `OrganizerProfileService`, Identity APIs, profile edit sheet |
| **Team** | New membership APIs; pattern from `vendor_users` / `VendorAccessService`; `NotificationService` for invites |
| **Roles** | Org-role enum on membership; **do not** replace `user_roles` portal roles |
| **Permissions** | `PermissionsGuard` / `PermissionsService` / permission-matrix; org capability map as thin overlay |
| **Workspace** | `WorkspaceService`, Flutter `WorkspaceSwitcher`, identity providers |
| **Events** | `EventsAccessService` (extended), existing event modules |
| **Business Operations** | Phases 16–21 surfaces — deep-link / gate only |

**Invariant:** One org business truth (`organizers`). One event ownership FK (`organizer_id`). Team membership grants access to that org — it does not create parallel events or parallel finance ledgers.

---

## 14. Out of scope (explicit)

- Redesigning Authentication, portal RBAC, or experience Workspace Switching  
- Departments / HR org chart  
- Multi-organization membership switcher (unless separately approved)  
- Merging guest invitations or Vendor CRM invites into team invites  
- Replacing Admin/Super-admin audit consoles  
- Rewriting Finance, Ops, Analytics, Vendor CRM, Reporting  
- Inventing business metrics or synthetic “staff productivity” scores  

---

## 15. Final result

**✅ Phase 22 Scope Defined**
