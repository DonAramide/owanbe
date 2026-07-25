# STEP 3 — Zoho SMTP Configuration

**Mode:** Deployment only  
**Date:** 2026-07-16  
**Scope:** Configure first production SMTP provider (Zoho)  

---

## Summary

Zoho application-specific password was generated in Zoho Mail (app name: **Owanbe**). Initial verification showed **no provider persisted** in the API database (`email_providers` count = 0) — the Super Admin UI save did not reach the running API.

Configuration was then applied via the **Super Admin Enterprise Email API** using the provided app-specific password (not logged, not committed). All automated checks passed.

---

## Provider configuration status

| Item | Status | Evidence |
|------|--------|----------|
| Provider saved | ✓ | `Zoho Production` (`zoho_smtp`) |
| Provider ID | ✓ | `416782f0-1ecd-4766-a3ca-a398995d889d` |
| Password encrypted at rest | ✓ | `password_ciphertext` present (len 58); not returned in API response |
| Enabled | ✓ | `enabled: true` |
| Default provider | ✓ | `is_default: true`, `isDefault: true` |
| Host / port / TLS | ✓ | `smtp.zoho.com:587`, `starttls` |
| Username / sender | ✓ | `support@iips.app` / sender name `Owanbe` |

---

## Connection test result

**HTTP 201**

```json
{ "ok": true }
```

Provider health after test: **`healthy`**

---

## Test email result

**HTTP 201**

```json
{
  "ok": true,
  "providerId": "416782f0-1ecd-4766-a3ca-a398995d889d",
  "providerName": "Zoho Production",
  "providerType": "zoho_smtp",
  "externalId": "<84333613-5b47-db3d-32e1-ab3e0addeba8@iips.app>"
}
```

Test sent to: `support@iips.app` — confirm receipt in that mailbox.

---

## Post-configuration verification

### Enterprise Email readiness

**Before:** `ready: false` — blocker: `No SMTP provider configured`  
**After:** `ready: true` — all blockers cleared

```json
{
  "ready": true,
  "encryptionKeyConfigured": true,
  "providerCount": 1,
  "enabledProviderCount": 1,
  "hasDefaultProvider": true,
  "defaultProviderId": "416782f0-1ecd-4766-a3ca-a398995d889d",
  "defaultProviderName": "Zoho Production",
  "secretsDecryptOk": true,
  "providerValid": true,
  "blockers": []
}
```

### Health notifications

**Before:** `log_only` — *Configure Super Admin → Enterprise Email Infrastructure*  
**After:** `enterprise_email` — *Enterprise Email Infrastructure provider(s) enabled*

### SMTP operational

✓ Connection verified  
✓ Test email accepted by Zoho SMTP  

---

## Root cause note (UI vs API)

The Zoho app password was created correctly, but the first manual UI attempt did **not** persist a row in `email_providers`. Likely causes to watch on device:

- Mobile API base unreachable from the device (`OWANBE_API_BASE=http://127.0.0.1:8080/v1` requires `adb reverse` on USB or PC Wi‑Fi IP on a physical phone)
- Save error snackbar may have been missed

The provider is now present in the database and visible via Super Admin → Enterprise Email on refresh.

---

## Remaining blockers (for later steps)

| Blocker | Step |
|---------|------|
| Supabase Auth SMTP not yet synced | STEP 4 |
| `SUPABASE_ACCESS_TOKEN` not configured (Management API sync disabled) | STEP 4 |
| Auth rate limits not yet raised | STEP 5 |
| Real Gmail signup journey not yet run | STEP 6 |

Business email (Nest `EmailService`) is **operational**. Auth verification emails still use Supabase SMTP until STEP 4.

---

## Final verdict

**PASS**

---

**STOP** — Awaiting approval before STEP 4 (Supabase Auth SMTP).
