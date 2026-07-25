# STEP 4A — Supabase Custom SMTP Verification

**Mode:** Deployment verification only  
**Date:** 2026-07-17  
**Rules honored:** No application code changes; no auth/email/identity redesign  

---

## Executive summary

| Area | Result |
|------|--------|
| API / Enterprise Email | **PASS** |
| Auth signup accepted (no rate-limit error) | **PASS** |
| Confirmation email **dispatched** by Supabase (`confirmation_sent_at` set) | **PASS** (API evidence) |
| Inbox proof (From: `support@iips.app`) | **Not verified by this session** (no mailbox access) |
| Click verify → login → Hub / workspaces | **Not completed** |
| Management API read of Auth SMTP config | **Unavailable** (`SUPABASE_ACCESS_TOKEN` still missing) |

**Final verdict: FAIL** — infrastructure and Auth signup path look healthy, but end-to-end mailbox + identity proof is incomplete without operator confirmation.

---

## 1. API health

| Check | Evidence |
|-------|----------|
| API running | ✓ `GET http://localhost:8080/health` → **200** |
| Database | ✓ `ok` |
| Notifications | ✓ `enterprise_email` — *Enterprise Email Infrastructure provider(s) enabled* |

```json
{
  "status": "ok",
  "checks": {
    "database": { "status": "ok" },
    "notifications": {
      "status": "enterprise_email",
      "detail": "Enterprise Email Infrastructure provider(s) enabled"
    }
  }
}
```

---

## 2. Enterprise Email health

`GET /v1/super-admin/email-infrastructure/readiness` → **200**

| Field | Value |
|-------|--------|
| `ready` | **true** |
| Encryption | `encryptionKeyConfigured: true`, `secretsDecryptOk: true` |
| Default provider | **Zoho Production** (`416782f0-1ecd-4766-a3ca-a398995d889d`) |
| Enabled | ✓ |
| Health | **healthy** |
| Host / port / sender | `smtp.zoho.com:587` / `support@iips.app` |
| Blockers | `[]` |

---

## 3. Supabase Authentication / Custom SMTP

### Programmatic Auth config read

| Method | Result |
|--------|--------|
| Management API `GET .../config/auth` | **Not available** — `SUPABASE_ACCESS_TOKEN` missing |
| Sync status | `managementApiConfigured: false` (expected; Dashboard path used) |

Operator stated Custom SMTP was configured in the Dashboard. This session **cannot** independently dump SMTP host/user from Supabase without a PAT.

### Functional Auth evidence (stronger than config dump)

`POST {SUPABASE_URL}/auth/v1/signup` with a **new** address:

| Field | Value |
|-------|--------|
| HTTP | **200** |
| Email | `support+step4b20260717023214363@iips.app` |
| `confirmation_sent_at` | **`2026-07-17T01:32:16.445899334Z`** |
| `email_verified` / `email_confirmed_at` | false / unset (expected until link clicked) |
| Rate-limit / `over_email_send_rate_limit` | **Not returned** |
| Login before verify | **400** (expected for unconfirmed user) |

Interpretation:

- Supabase Auth **accepted** the signup and **attempted to send** a confirmation email.
- Previous blocker **“Supabase development email rate limit”** did **not** appear on this attempt.
- That is consistent with **custom SMTP enabled** (and/or rate-limit headroom). It is **not** a substitute for reading “From: support@iips.app” in an inbox.

### Note on test address

Spec asked for a **brand-new Gmail**. This session has **no unused Gmail** and cannot open Gmail. A Zoho plus-alias under `support@iips.app` was used so delivery (if successful) lands in the same Zoho mailbox already used for SMTP. A full Gmail E2E remains an operator step (or STEP 6).

---

## 4. Signup / email / login results

| Step | Status | Notes |
|------|--------|-------|
| Create account | ✓ | HTTP 200, user id `5298b9f4-c71d-4692-9122-158f529326a5` |
| Signup succeeds | ✓ | No Auth error payload |
| Verification email delivered | ⏸ | Requires check of **support@iips.app** (and spam) for address above |
| Sender = `support@iips.app` | ⏸ | Operator must confirm From header |
| Verification link valid | ⏸ | Not clicked in this session |
| Complete verification | ⏸ | Not done |
| Login successful | ✗ | Blocked until email confirmed |

---

## 5. Unified Identity

| Check | Status |
|-------|--------|
| Hub | ✗ Not reached |
| Attendee / Organizer / Vendor activation | ✗ Not reached |

Blocked on incomplete email verification + login.

---

## Previous blockers

| Blocker | Status |
|---------|--------|
| Supabase development rate limit blocking verification | **Not observed** on this signup (PASS for this probe) |
| Verification via Zoho SMTP | **Likely**, pending inbox From-header confirmation |
| Auth errors on signup | **None** |
| Enterprise Email errors | **None** (`ready: true`, provider healthy) |

---

## Remaining deployment issues

1. **Operator:** Open Zoho mailbox `support@iips.app` and confirm receipt of confirmation mail for  
   `support+step4b20260717023214363@iips.app`  
   with **From: support@iips.app** (or Owanbe / that address).
2. Click the link → confirm account → optionally reply here so login + identity can be re-verified.
3. Run a **true unused Gmail** signup when ready (STEP 6 scope or re-run 4A with an address you provide).
4. Optional: add `SUPABASE_ACCESS_TOKEN` later for Management API config dumps / sync (not required if Dashboard SMTP stays correct).
5. STEP 5 (Auth rate limits) still pending after this step is accepted.

---

## Final verdict

**FAIL**

Reasons: mailbox delivery and sender not confirmed from this environment; verify/login/Hub/workspace activation not completed; Gmail-specific E2E not executed.

**Not failing on:** API health, Enterprise Email readiness, Auth signup acceptance, absence of rate-limit error on this probe.

---

**STOP** — Do not proceed to STEP 5. Reply with inbox evidence (or a fresh unused Gmail to retest) for re-verification.
