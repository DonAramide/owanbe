# AUTH Entrypoint Alignment Report

**Date:** 2026-07-18  
**Type:** Architecture correction  
**Scope:** Separate Customer vs Admin Flutter login experiences; preserve Unified Identity  

---

## Final verdict

**PASS**

---

## Principle

| Shared (unchanged) | Separate (restored) |
|--------------------|---------------------|
| Supabase project | Login UI |
| Users / JWT / session model | Authorization gate per binary |
| One customer identity + Hub workspaces | Post-login landing page |

Unified Identity for **Attendee / Organizer / Vendor** on Customer Flutter is **unchanged**.

---

## Startup flow

### Customer Flutter (`main.dart` / `main_customer.dart`)

```
Splash → Customer Login (/auth) → Customer Hub (/hub)
       → Attendee / Organizer / Vendor (switch without logout)
```

- `SharedBootstrap.isAdmin = false`
- Walkthrough still applies when unsigned

### Admin Flutter (`main_admin.dart`)

```
Splash → Admin Login (/auth/admin) → Super Admin Dashboard (/super-admin)
```

- `SharedBootstrap.isAdmin = true`
- Walkthrough skipped
- Never lands on Customer Hub

---

## Routing changes

| Path | Customer binary | Admin binary |
|------|-----------------|--------------|
| `/auth` | `UniversalAuthScreen` (Customer Login) | Redirect → `/auth/admin` |
| `/auth/admin` | Redirect → `/auth` or Hub | `AdminAuthScreen` (Admin Login) |
| `/hub` | Customer Hub | Redirect → `/super-admin` |
| `/super-admin`, `/admin/*` | Redirect → Hub / `/auth` | Control Tower home |

Router: `app_router.dart` branches on `SharedBootstrap.isAdmin`.  
Legacy `/auth/attendee|organizer|vendor` still redirect to Customer `/auth` only.

---

## Bootstrap changes

| File | Change |
|------|--------|
| `app_bootstrap.dart` | Destination via `AppEntrypoint`; clears wrong-binary sessions |
| `main.dart` | Explicit `SharedBootstrap.isAdmin = false` |
| `main_admin.dart` | Already sets `isAdmin = true` + `BootstrapScope` |
| `app_entrypoint.dart` | **New** — role classification + destinations |

Wrong session on launch (e.g. customer JWT inside Admin Chrome): local sign-out → correct login screen.

---

## Authorization checks

| App | Rule | Message |
|-----|------|---------|
| Customer | Reject accounts with administration roles (`super_admin`, `platform_admin`, `admin_*`, ops/finance/support codes) | *This account is for the Administration Portal.* |
| Admin | Require administration role | *This account is not authorized for the Administration Portal.* |

Implemented in `AuthNotifier`:

- `signInUniversalWithEmail` → customer assert  
- `signInAdminWithEmail` → admin assert (**new**)  
- `signInWithEmail` / sign-up paths respect binary  

---

## Session flow

- Same Supabase Auth for both binaries.  
- Customer sessions navigate only within Customer Hub / workspaces.  
- Admin sessions navigate only within `/super-admin` (and `/admin/*`).  
- Cross-binary auto-open is prevented by bootstrap + router.

---

## Files touched

- `mobile/lib/auth/app_entrypoint.dart` *(new)*  
- `mobile/lib/features/auth/screens/admin_auth_screen.dart` *(new)*  
- `mobile/lib/auth/auth_notifier.dart`  
- `mobile/lib/core/bootstrap/app_bootstrap.dart`  
- `mobile/lib/router/app_router.dart`  
- `mobile/lib/router/experience_routes.dart`  
- `mobile/lib/identity/experience_navigation.dart`  
- `mobile/lib/features/auth/screens/universal_auth_screen.dart`  
- `mobile/lib/features/auth/enterprise_auth_shell.dart`  
- `mobile/lib/main.dart`  

---

## How to verify

**Customer**

```bash
flutter run -t lib/main.dart -d chrome
```

Expect: Splash → Customer Login → Hub (after customer login).

**Admin**

```bash
flutter run -t lib/main_admin.dart -d chrome --web-port=59158
```

Expect: Splash → **Control Tower** login → `/super-admin`.  
Sign in as `superadmin@owanbe.dev` (seed). Customer Gmail must be rejected on Admin login.

---

## Not changed

- Unified Identity model (one profile, multi-workspace)  
- Hub workspace activation / switching without logout  
- Supabase project or JWT scheme  
- Separate user databases (none introduced)
