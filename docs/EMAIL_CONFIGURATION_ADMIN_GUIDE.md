# Email Configuration — Admin Guide

**Audience:** Super Admin / Platform Ops  
**Module:** Platform Administration → **Enterprise Email**

---

## What this controls

All **Owanbe business emails** (invitations, tickets, alerts, test messages).

It does **not** automatically control Supabase Auth signup/reset emails unless you use **Sync default → Supabase Auth**.

---

## First-time setup (Zoho)

1. Ensure migration `048_enterprise_email_infrastructure.sql` is applied.
2. Set API env `EMAIL_SECRETS_ENCRYPTION_KEY` to a long random secret (restart API).
3. Sign in as `super_admin`.
4. Open **Platform Admin → Enterprise Email**.
5. **Add provider**:
   - Type: `zoho_smtp`
   - Host: `smtp.zoho.com` (prefilled)
   - Port: `587`
   - TLS: `STARTTLS`
   - Username: your Zoho mailbox (e.g. support@…)
   - Password: Zoho app password / mailbox password
   - Sender name / Sender email
   - Enable + **Default**
6. **Test connection**
7. **Send test email** to your personal inbox
8. (Optional) Configure Supabase Auth SMTP — see sync section below

**Never** put Zoho passwords in `.env` or commit them to git.

---

## Provider types

Use the dropdown:

| Type | When to use |
|------|-------------|
| Zoho SMTP | Current production SMTP |
| Generic / Custom SMTP | Any SMTP host |
| Microsoft 365 / Google Workspace | Corporate mail |
| Amazon SES | High-volume SMTP |
| SendGrid / Mailgun / Postmark / Resend | API-key providers |

Switching providers later: add the new provider, mark default, disable the old one. **No app redeploy** required for business mail.

---

## Security rules

- Passwords / API keys are **write-only**. After save, the UI shows `password=set` / `apiKey=set` only.
- To rotate: Edit → enter new password → Save.
- Only `super_admin` role can call `/v1/super-admin/email-infrastructure/*`.

---

## Supabase Auth (signup / password reset)

### Dashboard

Authentication → SMTP → enter the same Zoho settings → raise rate limits.

### Sync from Owanbe

1. Set `SUPABASE_ACCESS_TOKEN` (Owner/Admin PAT from supabase.com/dashboard/account/tokens)
2. Ensure `SUPABASE_URL` or `SUPABASE_PROJECT_REF` is set
3. Click **Sync default → Supabase Auth**
4. Raise Auth rate limits in the Dashboard (critical — custom SMTP still has a low default cap)

---

## Troubleshooting

| Symptom | Action |
|---------|--------|
| Test connection fails | Verify host/port/TLS; Zoho often needs app password; port 587 → STARTTLS |
| Test email fails | Check sender domain authorization in Zoho; review `lastErrorMessage` on provider card |
| Signup still rate-limited | Auth SMTP not configured or Auth rate limits not raised |
| API 403 on sync | PAT must be Owner/Administrator |
| Emails log-only | No enabled default provider — configure Enterprise Email |

---

## API reference (Super Admin)

| Method | Path |
|--------|------|
| GET | `/v1/super-admin/email-infrastructure/providers` |
| POST | `/v1/super-admin/email-infrastructure/providers` |
| PATCH | `/v1/super-admin/email-infrastructure/providers/:id` |
| DELETE | `/v1/super-admin/email-infrastructure/providers/:id` |
| POST | `/v1/super-admin/email-infrastructure/providers/:id/set-default` |
| POST | `/v1/super-admin/email-infrastructure/providers/:id/test-connection` |
| POST | `/v1/super-admin/email-infrastructure/providers/:id/test-email` |
| GET | `/v1/super-admin/email-infrastructure/audit` |
| GET | `/v1/super-admin/email-infrastructure/supabase-sync/status` |
| POST | `/v1/super-admin/email-infrastructure/supabase-sync` |
