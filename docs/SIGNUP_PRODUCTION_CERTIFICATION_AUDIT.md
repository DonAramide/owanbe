# Unified Identity — Signup Production Certification Audit

**Sprint type:** Read-only audit (certification prep)  
**Date:** 2026-07-16  
**Status:** Complete — **STOP** (no implementation)  
**Related:**
- [`PRODUCTION_EMAIL_IDENTITY_RECOMMENDATION.md`](PRODUCTION_EMAIL_IDENTITY_RECOMMENDATION.md)
- [`UNIFIED_IDENTITY_PRODUCT_ARCHITECTURE.md`](UNIFIED_IDENTITY_PRODUCT_ARCHITECTURE.md)
- Device RCA: `email_address_invalid` for `@owanbe.dev` signup

---

## Executive summary

Owanbe’s Flutter signup path does **not** apply domain allow/deny rules. It forwards the trimmed email to **Supabase Auth (`signUp`)**. Acceptance of Gmail/Yahoo/business domains is therefore **entirely determined by Supabase Auth** (format checks + mailer deliverability validation when confirmation email is sent).

`@owanbe.dev` is **development seed infrastructure only**. It cannot be used for public signup because the domain is **NXDOMAIN**. Production users must use real, deliverable emails they control.

---

# 1. Signup Validation Audit

## Flow (production path)

```
UniversalAuthScreen._submitEmail
  → empty check only (email/password non-empty)
  → AuthNotifier.signUpUniversalWithEmail
       email: email.trim()
       password: password.trim()
       data: { display_name }
  → Supabase.instance.client.auth.signUp(...)
  → (on success + session) completeUniversalAuth → ensure-user / GET me
```

**Owanbe Nest API is not consulted until after Supabase auth succeeds.**

## Client-side validation (Flutter)

| Check | Present? | Location | Effect |
|-------|----------|----------|--------|
| Non-empty email/password | Yes | `universal_auth_screen.dart` ~79–81 | Blocks submit if empty |
| Format regex | **No** | — | — |
| Domain allow-list | **No** | — | — |
| Domain deny-list | **No** | — | — |
| Disposable-email block | **No** | — | — |
| `TextFormField.validator` | **No** | Email uses `EosTextField` without validator | — |
| Zero-width / BOM strip | Sign-**in** only | `auth_notifier._normalizeEmail` | Signup uses `.trim()` only (no lowercasing) |
| Password strength | **No** (client) | — | Supabase may enforce server-side |

## Supabase Auth validation (authoritative for signup)

| Stage | Behavior | Error if fail |
|-------|----------|---------------|
| `validateEmail` | Format via `checkmail.ValidateFormat`; length ≤ 255; lowercases | `validation_failed` |
| Signup + confirm email required | `sendConfirmation` → mailer `validateclient` | `email_address_invalid` |
| AuthorizedAddresses (if configured) | Allow-list of exact emails | `email_address_not_authorized` |
| Rate limits | Email send / request quotas | `429` / over_email |

**Evidence:** Device failure for `winchester@owanbe.dev` returned `email_address_invalid` from `GoTrueClient.signUp` — matching mailer validation, not Flutter.

## Backend (Nest) validation after auth

| Endpoint / service | Email rules | Differs from Supabase? |
|--------------------|-------------|------------------------|
| `WorkspaceService.ensureUser` | Requires non-empty JWT email | Presence only — **no format/domain rules** |
| `AuthSignupService.completeSignup` (legacy portal) | Requires email; uniqueness by `email_normalized` | Duplicate / portal mismatch — **not format** |
| `PortalLookupDto.email` | `@IsString` `@IsNotEmpty` only | **No `@IsEmail`** |
| `IdentityService.normalizeEmail` | `trim` + `toLowerCase` + must contain `@` | Guest ticket lookup — **not signup gate** |

**Conclusion:** Backend does **not** re-validate email format for universal signup. It trusts the JWT subject’s email after Supabase authentication.

---

# 2. Email Acceptance Matrix

Legend (for **public signup** via Universal Auth → Supabase):

| Symbol | Meaning |
|--------|---------|
| **ACCEPT*** | Accepted by Owanbe Flutter (no reject); final accept depends on Supabase deliverability |
| **REJECT (Supabase)** | Evidenced or strongly indicated rejection by GoTrue |
| **UNKNOWN** | Not live-tested on this project in this audit |
| **N/A** | Not a signup path / future |

| Email class | Example | Flutter | Supabase (expected) | Notes |
|-------------|---------|---------|---------------------|-------|
| Gmail | `john@gmail.com` | ACCEPT* | ACCEPT* (if DNS/MX OK; short local-part &lt;6 may fail if extended validation on) | Industry default |
| Yahoo | `john@yahoo.com` | ACCEPT* | ACCEPT* | Allow-listed host in GoTrue for MX skip |
| Outlook/Hotmail | `john@outlook.com` / `@hotmail.com` | ACCEPT* | ACCEPT* | Allow-listed |
| iCloud | `john@icloud.com` | ACCEPT* | ACCEPT* | Allow-listed |
| Custom business | `ada@acme.ng` | ACCEPT* | ACCEPT* if domain has MX/A | Rejected if NXDOMAIN / no mail DNS |
| Educational | `student@university.edu` | ACCEPT* | ACCEPT* if DNS OK | Same as business |
| Plus-addressing | `user+test@gmail.com` | ACCEPT* | ACCEPT* (typical) | Not stripped by our signup path |
| Internationalized (IDN / Unicode local) | `用户@例子.中国` | ACCEPT* (no client reject) | **UNKNOWN** / often format-fail | Rely on Supabase `checkmail` |
| Disposable providers | `x@mailinator.com`, etc. | ACCEPT* | **UNKNOWN** | May fail if project uses blocked-MX / remote validator |
| Invalid / non-existent domains | `a@notarealdomainxyz.invalid` | ACCEPT* | **REJECT (Supabase)** | Static `.invalid` suffix and/or NXDOMAIN |
| Literal `example.com` | `you@example.com` | ACCEPT* | **REJECT (Supabase)** | In GoTrue `invalidHostMap` |
| `@owanbe.dev` | `winchester@owanbe.dev` | ACCEPT* | **REJECT (Supabase)** | **Evidenced** NXDOMAIN + `email_address_invalid` |
| Seed sign-**in** `@owanbe.dev` | `attendee@owanbe.dev` | N/A (sign-in) | Works if SQL-seeded | Bypassed signup |
| `@owanbe.com` (future) | `anyone@owanbe.com` | ACCEPT* | ACCEPT* **only if** domain registered + DNS/MX | Must not be required for customers |
| Empty / no `@` | `notaemail` | Empty blocked; no `@` still sent if non-empty | Format fail | Flutter does not require `@` |

\* Final production acceptance = Supabase project settings (confirm email, SMTP, rate limits, extended validation).

---

# 3. Answers to audit questions

### Q1 — Formats currently accepted?

**Owanbe app:** effectively **any non-empty string** as email (no domain filter).

**Effective production signup:** whatever **Supabase Auth** accepts — typically major providers and any domain with real DNS/MX; **not** `@owanbe.dev`, **not** RFC example/test hosts, **not** NXDOMAIN domains.

### Q2 — Flutter client-side email validation before Supabase?

**No meaningful validation** beyond non-empty trim. No regex gate.

### Q3 — Is Supabase the only component validating email addresses?

**For signup create-account: yes** (format + deliverability on mail send).

**After signup:** Nest only requires email present / unique / (legacy) portal rules — it does not re-check Gmail vs Yahoo vs domain existence.

### Q4 — Regex that could reject valid production emails?

**No signup regex.** The only nearby RegExp in auth is zero-width character stripping on **sign-in** normalization (`auth_notifier.dart` ~169–170), which does not reject valid emails.

### Q5 — Backend validation differing from Supabase?

**Yes, but orthogonal:** uniqueness, portal mismatch (legacy), EMAIL_REQUIRED. **No** parallel format/domain policy that would accept what Supabase rejects or reject what Supabase accepts for format/DNS.

### Q6 — What email format should Owanbe officially support in production?

Per [`PRODUCTION_EMAIL_IDENTITY_RECOMMENDATION.md`](PRODUCTION_EMAIL_IDENTITY_RECOMMENDATION.md):

> **Any deliverable email the user owns and can access**, accepted by Supabase Auth — personal (Gmail, Yahoo, Outlook, iCloud) or organization domains. Not `@owanbe.dev`. Not required to be `@owanbe.com`.

### Q7 — Change hint to “Use an email address you can access.”?

**Yes — recommended before production** (UX/copy only).

Current field hint is `you@example.com` (`universal_auth_screen.dart` ~211). Literally using that address would fail Supabase (`example.com` is a known invalid host in GoTrue). Debug copy also pushes `attendee@owanbe.dev`.

Preferred production copy:

- Hint / helper: **“Use an email address you can access.”**
- Avoid `example.com` and `@owanbe.dev` in production-facing UI.

(Debug-only seed pre-fill may remain behind `kDebugMode`.)

### Q8 — Remaining places assuming seed emails?

**Yes.** Auth UX, error copy, MFA mocks, Super Admin demo data, vendor onboarding `devVendorId`, SQL seeds, and many docs/QA runbooks.

### Q9 — Complete inventory

See **§4 Dev Seed Reference Inventory** below.

### Q10 — What should change before production release?

See **§5 Production Recommendation** and **§6 Risk Assessment**.

---

# 4. Dev Seed Reference Inventory

## A. Universal Auth / signup UX (highest production impact)

| File | Reference | Role |
|------|-----------|------|
| `mobile/lib/features/auth/screens/universal_auth_screen.dart` | Pre-fill `attendee@owanbe.dev` / `123456` in `kDebugMode` | Debug convenience |
| same | Dev one-tap sign-in to `attendee@owanbe.dev` | Debug only |
| same | Copy: “Pre-filled with attendee@owanbe.dev / 123456” | Debug only |
| same | Hint `you@example.com` | **Ships in all builds** — bad literal example |
| `mobile/lib/features/auth/auth_error_messages.dart` | Steps mention `attendee@owanbe.dev` / `123456` (rate limit, invalid credentials, generic) | **Ships in all builds** if those errors fire |
| `mobile/lib/features/auth/enterprise_auth_shell.dart` | Default/hint `admin@owanbe.dev`; MFA QR with `admin@owanbe.dev` | Staff/enterprise auth shell |

## B. Identity / vendor coupling to seed IDs

| File | Reference | Role |
|------|-----------|------|
| `mobile/lib/core/api/onboarding_api.dart` | `devVendorId = 55555555-…` | Fixed seed vendor UUID |
| `mobile/lib/features/vendor/screens/vendor_onboarding_screen.dart` | Uses `OnboardingApi.devVendorId` | Vendor onboarding path |
| `mobile/lib/features/vendor/vendor_identity.dart` | `canonicalDevVendorId` + marketplace aliases | Regression / mock mapping |
| `mobile/lib/features/vendor/providers/vendor_providers.dart` | Falls back to canonicalDevVendorId when mock fallback on | Dev/mock |
| `mobile/lib/platform/identity/identity_mfa_provider.dart` | Hardcoded admin/organizer/vendor `@owanbe.dev`; synthesizes `$userId@owanbe.dev` | MFA mock / demo |

## C. Demo / placeholder UI (not signup gate)

| File | Reference |
|------|-----------|
| `mobile/lib/features/super_admin/user_360/user_360_workspace_screen.dart` | `adenike@owanbe.dev`, `user_*@owanbe.dev` |
| `mobile/lib/features/super_admin/commerce_360/commerce_360_workspace_screen.dart` | `finance@`, `client@owanbe.dev` |
| `mobile/lib/features/super_admin/*_360/*` | `oncall@`, `bi@`, `admin@*.owanbe.dev` |
| `mobile/lib/eos/layout/workspace/*.dart` | `finance@`, `bi@`, `contact@`, `adenike@owanbe.dev` |
| `mobile/lib/eos/security/security_engine.dart` | `secops@owanbe.dev` |
| `mobile/lib/portals/customer/workspace/event_workspace.dart` | `organizer@owanbe.dev` |

## D. Database / Supabase seed scripts

| File | Accounts |
|------|----------|
| `scripts/supabase/seed-dev-auth-users.sql` | attendee, organizer, vendor, admin, superadmin `@owanbe.dev` |
| `scripts/supabase/fix-attendee-roles.sql` | `attendee@owanbe.dev` |
| `scripts/supabase/repair-auth-null-columns.sql` | attendee, admin, superadmin |
| `infra/db/029_identity_dev_seed.sql` | Same five + `newguest@owanbe.dev` |
| `infra/db/021_phase5_dev_commerce_seed.sql` | `attendee@owanbe.dev` |
| `infra/db/023_phase6_admin_seed.sql` | `admin@owanbe.dev` |
| `infra/db/024_phase7_super_admin.sql` | `superadmin@owanbe.dev` |

## E. Tests

| File | Reference |
|------|-----------|
| `mobile/test/workspace_platform_test.dart` | `test@owanbe.dev` |

## F. Documentation / runbooks (non-runtime)

Multiple docs under `docs/` (identity architecture, RC validation, Vendor OS, beta scripts, v1.0.1 verification, etc.) document seed credentials. Inventory samples: `UNIFIED_IDENTITY_*`, `RC_*`, `VENDOR_OS_INTEGRATION_REPORT.md`, `phase40/BETA_TEST_SCRIPTS.md`, `v1.0.1-identity-verification-report.md`.

## G. Infra naming (not email identity)

| File | Note |
|------|------|
| `mobile/docker-compose.prod.yml` | Hostnames `api.owanbe.dev` / `auth.owanbe.dev` — **service URLs**, not customer email domains |

---

# 5. Production Recommendation

## Official production email policy

1. Customers sign up with **any deliverable email they can access**.
2. Never require `@owanbe.dev` or `@owanbe.com` for customer login.
3. Keep `@owanbe.dev` seeds for **SQL/Admin-provisioned** QA and CI only.
4. Treat Supabase as the **sole format/deliverability authority** for signup until an explicit product policy (e.g. block disposables) is approved and implemented.

## Changes recommended before production release

*(Design list only — **do not implement in this audit**.)*

| Priority | Change | Why |
|----------|--------|-----|
| **P0** | Production UX copy: hint/helper → “Use an email address you can access.” Remove `you@example.com` as the primary hint | `example.com` is rejected by GoTrue; misleading |
| **P0** | Ensure production builds do not instruct users to use `@owanbe.dev` | Seeds are not public signup |
| **P0** | Gate or strip seed credentials from **release** error steps in `auth_error_messages.dart` (or wrap in `kDebugMode`) | Currently can surface in non-debug if those errors occur |
| **P1** | Keep `kDebugMode` one-tap / pre-fill for engineers; document “sign-in only, do not Create account with @owanbe.dev” | Prevents repeat of current failure mode |
| **P1** | QA runbook: Phase 1 / production signup tests use real Gmail (or company) emails | Aligns with certification |
| **P1** | Staging/prod: `ALLOW_MOCK_PERSISTENCE_FALLBACK=false` | Avoid silent seed vendor impersonation |
| **P2** | Map `email_address_invalid` to clearer UX (“Use a real email you can access”) | Current generic “Try again” |
| **P2** | Align signup email normalization with sign-in (lowercase) for consistency | Minor; Supabase lowercases server-side |
| **P3** | Super Admin / EOS placeholder `@owanbe.dev` contacts | Demo-only; low signup risk |
| **P3** | Vendor onboarding `devVendorId` cleanup | Vendor OS scope; not signup validation |

## Explicit non-goals (this audit)

- Do not delete seed accounts
- Do not change Supabase Auth settings in this sprint
- Do not add a custom Flutter domain allow-list that duplicates GoTrue
- Do not require `@owanbe.com` for customers

---

# 6. Risk Assessment

| Risk | Severity | Likelihood | Mitigation (future sprint) |
|------|----------|------------|----------------------------|
| Users try `@owanbe.dev` signup after seeing debug/docs | High | Medium (devs/QA; low for naive users if release strips copy) | Production copy + docs |
| Users try literal `you@example.com` from hint | Medium | Low–Medium | Change hint text |
| Seed emails appear in production error banners | Medium | Medium | `kDebugMode` / flavor-gate error steps |
| Mock fallback impersonates seed vendor in prod | High | Medium if env mis-set | Enforce `ALLOW_MOCK_PERSISTENCE_FALLBACK=false` |
| Email confirmation + default SMTP rate limits block real signups | High | Medium on free tier | Custom SMTP + rate limits before launch |
| Disposable / IDN emails inconsistent | Low–Medium | Unknown | Rely on Supabase; optional product policy later |
| Assuming Nest validates email like Supabase | Low | Process risk | Document sole authority = Supabase |
| Internationalization / plus-address edge cases | Low | Low | Monitor Supabase errors; no Flutter regex |

### Residual open items (cannot close without Dashboard access)

1. Exact hosted flags: `EmailValidationExtended`, validation service URL, AuthorizedAddresses, Autoconfirm.
2. Live A/B matrix for every provider on this project (prior probe hit HTTP 429).
3. Whether disposable domains are blocked via blocked-MX config.

---

## Certification checklist (signup readiness — audit view)

| Criterion | Status |
|-----------|--------|
| App does not block real provider emails via regex | **PASS** |
| Supabase is signup email authority | **PASS** (by design) |
| `@owanbe.dev` unsuitable for public signup | **PASS** (evidenced) |
| Production copy free of seed-email instructions | **FAIL** (error messages + example.com hint) |
| Debug seed UX isolated from release | **PARTIAL** (`kDebugMode` pre-fill OK; error strings not fully gated) |
| Official policy documented | **PASS** (this doc + prior recommendation) |

**Signup production certification (copy/ops): NOT YET READY** until P0 UX/copy items are addressed in an approved implementation sprint.

---

## STOP

This document is **audit and recommendation only**.

- No code modified  
- No Supabase modified  
- No authentication behavior changed  

Next step requires explicit approval to open a **copy / env / QA-runbook** implementation sprint (not Phase 2 identity features).
