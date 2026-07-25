# Email Provider Architecture

**Sprint:** Enterprise Email Infrastructure  
**Status:** Implemented  
**Date:** 2026-07-16

---

## Principle

Business code never knows which email vendor is active.

```
BusinessService
    └── NotificationService.send({ channel: 'email', ... })
            └── EmailService.send(...)
                    └── resolveActiveProvider()   // DB: default + priority
                            └── deliverViaProvider(...)
                                    ├── SMTP transport (nodemailer)
                                    └── API transports (Resend, SendGrid, Mailgun, Postmark)
```

---

## Provider types (extensible)

| Type | Transport | Credentials |
|------|-----------|-------------|
| `generic_smtp` | SMTP | username + password |
| `zoho_smtp` | SMTP (preset host) | username + password |
| `microsoft_365` | SMTP | username + password |
| `google_workspace` | SMTP | username + password / app password |
| `amazon_ses` | SMTP | SMTP user + password |
| `custom_smtp` | SMTP | username + password |
| `sendgrid` | HTTPS API | API key |
| `mailgun` | HTTPS API | API key (+ `metadata.mailgunDomain`) |
| `postmark` | HTTPS API | Server token |
| `resend` | HTTPS API | API key |

Adding a new provider:

1. Extend `EmailProviderType` + DB check constraint (migration).
2. Implement send/verify branch in `email.transport.ts`.
3. Add label in `GET .../provider-types`.
4. **No** changes to invitation, ticket, or alert services.

---

## Resolution order

1. Tenant-scoped enabled provider (future multi-tenant) — highest `is_default`, then lowest `priority`
2. Platform-wide (`tenant_id IS NULL`) enabled provider — same ordering
3. If none → webhook fallback (`NOTIFICATION_WEBHOOK_URL`) → log-only

---

## Secrets

- Stored as AES-256-GCM ciphertext in `email_providers.password_ciphertext` / `api_key_ciphertext`
- Key: `EMAIL_SECRETS_ENCRYPTION_KEY` (platform secret — **not** SMTP password)
- Public API returns `hasPassword` / `hasApiKey` booleans only

---

## Separation from Auth email

| System | Owner | Purpose |
|--------|-------|---------|
| Enterprise Email Infrastructure | Owanbe Nest API | Business mail |
| Supabase Auth SMTP | Supabase GoTrue | Signup / reset / magic link |

See `SUPABASE_SMTP_INTEGRATION_REPORT.md`.
