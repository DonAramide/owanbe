# SUPABASE CONNECTIVITY HARDENING REPORT

**Date:** 2026-07-19  
**Scope:** Customer Flutter + Admin Flutter — configuration & connectivity reliability only  
**Final Verdict:** **PASS**

---

## Objective

Permanently harden the Supabase connectivity pipeline so configuration errors and network failures are detected immediately with clear diagnostics — without redesigning Authentication, Unified Identity, or Customer/Admin separation.

---

## 1. Configuration Audit

### Before

| Entry point | Bootstrap path | Config load |
|---|---|---|
| `main.dart` (Customer) | `bootstrapSupabase()` in `lib/supabase/bootstrap.dart` | Duplicated dotenv + initialize |
| `main_customer.dart` | `SharedBootstrap.initSharedPlatform()` | Duplicated dotenv + initialize |
| `main_admin.dart` | `SharedBootstrap.initSharedPlatform()` | Duplicated dotenv + initialize |

- Two independent copies of Supabase init logic could diverge.
- Validation was limited to “URL/anon non-empty”.
- Invalid config threw in `main()` with no user-facing diagnostic UI.

### After — Single authoritative source

| Item | Source of truth |
|---|---|
| Env asset | `mobile/assets/env/supabase.env` |
| Load + validate | `SupabaseConfig.load()` / `parseAndValidate()` |
| Client init | `SupabaseBootstrap.ensureInitialized()` → `bootstrapSupabase()` |
| Customer (`main.dart`) | Calls `bootstrapSupabase()` |
| Customer (`main_customer.dart`) | `bootstrapCustomer()` → `SharedBootstrap` → `bootstrapSupabase()` |
| Admin (`main_admin.dart`) | `bootstrapAdmin()` → `SharedBootstrap` → `bootstrapSupabase()` |

**Confirmed runtime URL (both binaries):**  
`https://iozdkiwcwblydsomxhxa.supabase.co`

There is one load path; Customer and Admin cannot diverge on `SUPABASE_URL`.

### Validation rules (fail closed)

At load time the app now requires:

- `SUPABASE_URL` present  
- `SUPABASE_ANON_KEY` present  
- No whitespace in either value  
- Valid HTTPS URI  
- Valid hostname  
- Host matches `<project-ref>.supabase.co` (project ref shape)  
- Anon JWT `ref` claim matches URL project ref (when JWT is decodable)

On failure: boot does **not** continue; `SupabaseBootstrapFailureApp` shows the exact cause.

---

## 2. Connectivity Audit

New module: `lib/supabase/supabase_connectivity.dart` (+ platform DNS via conditional import).

Startup probe order:

1. **Internet** — DNS of `one.one.one.one` (IO platforms; skipped on web stub)  
2. **DNS** — lookup of configured Supabase host  
3. **HTTPS** — `GET {SUPABASE_URL}/auth/v1/health` with anon key  

Failure kinds (never collapsed to a single “Failed host lookup”):

| Kind | User-facing title |
|---|---|
| Invalid configuration | Supabase configuration is invalid. |
| Internet unavailable | No Internet Connection |
| DNS failure | Supabase host could not be resolved. |
| TLS failure | Supabase TLS connection failed. |
| Timeout / Supabase down | Authentication service is temporarily unavailable. |

Technical exceptions are logged in debug (`technicalDetail`); UI shows typed copy.

Live health probe for the configured project returned **HTTP 200** on `GET /auth/v1/health` with the anon key during this hardening pass.

---

## 3. Startup Validation

`AppBootstrapNotifier` now:

1. Confirms `SupabaseConfig.current` is loaded  
2. Runs `SupabaseConnectivity.verify`  
3. Only then resolves session and navigates to login / hub / walkthrough  

New boot phase: `AppBootPhase.connectivityBlocked`  
Diagnostics route: `/diagnostics/supabase` (`ExperienceRoutes.supabaseDiagnostics`)

Retry: diagnostics screen → `retryConnectivity()` → continues to normal signed-out destination when healthy.

Wired for:

- `main.dart`  
- `main_customer.dart`  
- `main_admin.dart`  

via shared `BootstrapScope` + shared Supabase bootstrap.

---

## 4. Authentication Error Handling

`formatAuthError` now:

- Maps `SupabaseConfigException` → diagnostic titles  
- Classifies network/`AuthException` wrappers via `SupabaseConnectivity.classifyNetworkError`  
- Preserves existing credential, rate-limit, email-confirm, and API-sync messaging  

Examples users now see instead of raw socket text:

- “No Internet Connection”  
- “Supabase host could not be resolved.”  
- “Supabase configuration is invalid.”  
- “Authentication service is temporarily unavailable.”

---

## 5. Customer / Admin Compatibility

| Check | Result |
|---|---|
| Same env asset | PASS |
| Same `SupabaseBootstrap.ensureInitialized()` | PASS |
| Admin login path `/auth/admin` unchanged | PASS |
| Customer login path `/auth` unchanged | PASS |
| Entrypoint role gates unchanged | PASS |
| Unified Identity providers untouched | PASS |

---

## 6. Regression Audit

Intentionally **not** modified:

- Unified Identity model / sync  
- Customer Hub product flows  
- Organizer / Attendee / Vendor workspaces  
- Admin Control Tower dashboard logic  
- Auth product design (separate Customer vs Admin entry UIs preserved)

Changed only:

- Config load/validation  
- Startup connectivity gate  
- Diagnostics UI + route  
- Auth **network** error classification  

Automated: `flutter test test/supabase_config_test.dart` — **5/5 passed**  
Static: `dart analyze` on touched bootstrap/config modules — **no errors**

---

## Files Added / Updated

**Added**

- `mobile/lib/supabase/supabase_config.dart`  
- `mobile/lib/supabase/supabase_diagnostic.dart`  
- `mobile/lib/supabase/supabase_connectivity.dart`  
- `mobile/lib/supabase/supabase_dns_lookup.dart` (+ `_io` / `_stub`)  
- `mobile/lib/features/public/screens/supabase_diagnostics_screen.dart`  
- `mobile/lib/features/public/screens/supabase_diagnostics_route.dart`  
- `mobile/test/supabase_config_test.dart`  

**Updated**

- `mobile/lib/supabase/bootstrap.dart`  
- `mobile/lib/platform/bootstrap/bootstrap.dart`  
- `mobile/lib/core/bootstrap/app_boot_state.dart`  
- `mobile/lib/core/bootstrap/app_bootstrap.dart`  
- `mobile/lib/main.dart` / `main_customer.dart` / `main_admin.dart`  
- `mobile/lib/features/auth/auth_error_messages.dart`  
- `mobile/lib/auth/auth_notifier.dart` (config source only)  
- `mobile/lib/router/experience_routes.dart` / `app_router.dart` / `portal_routes.dart`  

---

## Final Verdict

**PASS**

Supabase configuration is single-sourced and validated; Customer and Admin share the same client bootstrap; startup blocks on clear diagnostics for config/DNS/internet/TLS/service failures; auth network errors are classified for users without changing identity or portal architecture.

---

**STOP** — awaiting approval before any unrelated work.
