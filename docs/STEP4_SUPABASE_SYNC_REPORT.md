# STEP 4 — Supabase Auth SMTP Deployment

**Mode:** Deployment only  
**Date:** 2026-07-17  
**Scope:** Point Supabase Auth emails at Zoho SMTP (Enterprise Email credentials)  
**Rules honored:** No application code changes; no auth/email redesign  

---

## API startup verification

| Check | Result |
|-------|--------|
| API reachable | ✓ `GET /health` → **200** |
| Database | ✓ `ok` |
| Enterprise Email / notifications | ✓ `enterprise_email` — provider(s) enabled |
| Readiness | ✓ `ready: true` |
| Default provider | ✓ `Zoho Production` (`416782f0-1ecd-4766-a3ca-a398995d889d`) |
| Secrets decrypt | ✓ `secretsDecryptOk: true` |
| Blockers | ✓ `[]` |

API was already running; no restart required for this verification.

---

## Automatic sync capability

| Requirement | Status |
|-------------|--------|
| `SUPABASE_ACCESS_TOKEN` | **Missing** (not set in `services/api/.env`) |
| `SUPABASE_PROJECT_REF` | **Missing** as explicit env (but **derivable** from `SUPABASE_URL`) |
| `SUPABASE_URL` | ✓ Set → project ref **`iozdkiwcwblydsomxhxa`** |
| Management API configured | **false** |
| Sync enabled | **false** |

### Sync status API evidence

`GET /v1/super-admin/email-infrastructure/supabase-sync/status` → **200**

```json
{
  "managementApiConfigured": false,
  "syncEnabled": false,
  "syncDisabledReason": "SUPABASE_ACCESS_TOKEN is not configured. Set an Owner/Administrator PAT and restart the API, or configure Auth SMTP in the Supabase Dashboard.",
  "canSyncProgrammatically": true,
  "requires": ["SUPABASE_ACCESS_TOKEN", "SUPABASE_PROJECT_REF (or SUPABASE_URL)"],
  "requiresRole": "Owner or Administrator personal access token"
}
```

**Decision:** Automatic sync is **not available** until `SUPABASE_ACCESS_TOKEN` is provisioned. Per deployment rules: **no workaround code; stop for operator action.**

---

## SMTP synchronization status

| Action | Status |
|--------|--------|
| Sync Default Provider → Supabase Auth | **Not executed** (blocked by missing PAT) |
| Auth SMTP Host / Port / Encryption applied | ✗ Not verified via Management API |
| Auth SMTP Username / Sender applied | ✗ Not verified via Management API |

---

## What is missing (exact)

### Environment variable

**`SUPABASE_ACCESS_TOKEN`**

| Detail | Value |
|--------|--------|
| Where to obtain | [Supabase Dashboard → Account → Access Tokens](https://supabase.com/dashboard/account/tokens) |
| Required role | **Owner** or **Administrator** (Developer PAT may get HTTP 403) |
| Where to configure | `services/api/.env` as `SUPABASE_ACCESS_TOKEN=<pat>` |
| Optional companion | `SUPABASE_PROJECT_REF=iozdkiwcwblydsomxhxa` (or keep relying on `SUPABASE_URL`) |
| After setting | Restart the Nest API, then run **Sync to Supabase** in Super Admin → Enterprise Email, **or** `POST /v1/super-admin/email-infrastructure/supabase-sync` |

Do **not** commit the PAT. Do **not** paste it into chat if avoidable.

### Alternate path (no PAT)

Configure Auth SMTP entirely in the **Supabase Dashboard** (see below). Automatic sync remains optional forever if Dashboard is used.

---

## Remaining manual steps

### Option A — Dashboard (works now, no API change)

1. Open project **`iozdkiwcwblydsomxhxa`**:  
   https://supabase.com/dashboard/project/iozdkiwcwblydsomxhxa/auth/smtp  
   (or **Authentication → Emails / SMTP** depending on Dashboard UI)
2. Enable **Custom SMTP**.
3. Enter (match Enterprise Email Zoho Production):

| Field | Value |
|-------|--------|
| Host | `smtp.zoho.com` |
| Port | `587` |
| Username | `support@iips.app` |
| Password | Zoho **application-specific password** (same as Enterprise Email; enter without spaces) |
| Sender email | `support@iips.app` |
| Sender name | `Owanbe` |

4. Save.
5. Confirm Dashboard shows custom SMTP enabled.
6. (STEP 5) Raise Auth **email rate limits** — custom SMTP alone does not remove the default Auth rate limit.

### Option B — Management API sync (after PAT)

1. Create Owner/Admin PAT at https://supabase.com/dashboard/account/tokens  
2. Add to `services/api/.env`:  
   `SUPABASE_ACCESS_TOKEN=...`  
   optionally `SUPABASE_PROJECT_REF=iozdkiwcwblydsomxhxa`  
3. Restart API.  
4. Super Admin → Platform Admin → Enterprise Email → **Sync to Supabase** (or readiness sync endpoint).  
5. Confirm sync `ok: true`.

---

## Signup blocker assessment

| Question | Answer |
|----------|--------|
| Has “Supabase development rate limit reached” been removed by this step? | **No — not yet.** Auth SMTP is still on Supabase’s default / non-custom path until Option A or B is completed. |
| Will signup verification emails flow through Zoho after SMTP is configured? | **Yes** — once custom SMTP is saved in Auth (Dashboard or sync). |
| Is Gmail signup expected to work *right now*? | **Not yet.** Needs Auth custom SMTP **and** STEP 5 rate-limit review. |
| Does Enterprise Email (business mail) already use Zoho? | **Yes** (STEP 3 PASS). Auth mail is a separate control plane. |

---

## Supabase configuration status

| Item | Status |
|------|--------|
| Project ref known | ✓ `iozdkiwcwblydsomxhxa` |
| Custom Auth SMTP confirmed | ✗ Not confirmed (no PAT; Dashboard not completed in this session) |
| Enterprise Email remains healthy | ✓ |
| Readiness still PASS | ✓ |

---

## Final verdict

**MANUAL CONFIGURATION REQUIRED**

Blocking item: **`SUPABASE_ACCESS_TOKEN` missing** (or Dashboard Auth SMTP not yet applied by operator).

---

**STOP** — Do not proceed to STEP 5 until Auth SMTP is configured and this step is re-verified.
