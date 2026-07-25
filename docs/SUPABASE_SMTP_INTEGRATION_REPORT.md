# Supabase SMTP Integration Report

**Sprint:** Enterprise Email Infrastructure  
**Date:** 2026-07-16  
**Question:** Can Enterprise Email Infrastructure synchronize SMTP into Supabase Auth programmatically?

---

## Verdict

**YES — optionally, via the Supabase Management API.**

It is **not** automatic. Auth SMTP remains a **separate control plane** from Owanbe business email unless an administrator explicitly syncs (or configures the Dashboard).

---

## Evidence

Official Supabase docs (`Send emails with custom SMTP`) document:

```http
PATCH https://api.supabase.com/v1/projects/{PROJECT_REF}/config/auth
Authorization: Bearer {SUPABASE_ACCESS_TOKEN}
```

Body fields include: `smtp_host`, `smtp_port`, `smtp_user`, `smtp_pass`, `smtp_admin_email`, `smtp_sender_name`, plus mailer flags.

**Privilege requirement:** Owner or Administrator personal access token. Developer-role PATs may receive **HTTP 403** (documented platform issue).

After custom SMTP is enabled, Supabase still applies Auth **rate limits** (Dashboard → Authentication → Rate Limits). Raising limits is a separate Dashboard (or Management API) step.

---

## What Owanbe implements

| Capability | Status |
|------------|--------|
| `GET /v1/super-admin/email-infrastructure/supabase-sync/status` | Reports whether Management API env is configured |
| `POST /v1/super-admin/email-infrastructure/supabase-sync` | Pushes **default SMTP-style** provider credentials to Auth |
| Env `SUPABASE_ACCESS_TOKEN` | PAT (never commit) |
| Env `SUPABASE_PROJECT_REF` | Or derived from `SUPABASE_URL` |

**Cannot sync:** API-key-only providers (SendGrid, Resend, Mailgun, Postmark) — Supabase Auth expects SMTP credentials. Use SMTP credentials from those vendors if available, or configure Auth SMTP manually.

---

## Two systems (do not merge)

```
┌─────────────────────────────────────┐
│  Supabase Authentication SMTP       │
│  - Signup verification              │
│  - Password reset                   │
│  - Magic links                      │
│  - Email change verification        │
│  Config: Dashboard OR Management API│
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  Owanbe Enterprise Email            │
│  - Event invitations                │
│  - Ticket / QR receipts             │
│  - Finance alerts                   │
│  - Vendor notifications (when email)│
│  - Test emails                      │
│  Config: Super Admin module (DB)    │
└─────────────────────────────────────┘
```

**Do not** route Auth emails through Nest `EmailService` — that would redesign authentication (out of scope).

---

## Administrator runbook

### Option A — Dashboard only (always available)

1. Supabase → Authentication → SMTP  
2. Enter Zoho (or other) host/port/user/pass/sender  
3. Raise Rate Limits for email  

### Option B — Sync from Owanbe

1. Configure Zoho (or SMTP) provider in **Super Admin → Enterprise Email**  
2. Set `EMAIL_SECRETS_ENCRYPTION_KEY` on API  
3. Set `SUPABASE_ACCESS_TOKEN` (Owner/Admin) + project ref  
4. Click **Sync default → Supabase Auth** (or `POST .../supabase-sync`)  
5. Raise Auth rate limits in Dashboard  

### Recommended production

- **Same SMTP provider** (e.g. Zoho) for both systems for brand consistency  
- Business mail: Enterprise Email DB  
- Auth mail: synced or Dashboard  
- Never store SMTP passwords in `.env` for business mail  

---

## Limitation summary

| Limitation | Impact |
|------------|--------|
| Sync requires Management API PAT with Admin/Owner | Ops must provision token |
| Auth rate limits independent of Zoho quotas | Must raise in Dashboard after custom SMTP |
| API-only providers not pushable as Auth SMTP | Use SMTP credentials or Dashboard |
| Sync is opt-in, not continuous | Re-sync after credential rotation |
