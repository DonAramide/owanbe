# Email Production Deployment Checklist

Use this before allowing real customer email signup.

---

## Encryption

- [ ] `EMAIL_SECRETS_ENCRYPTION_KEY` set in API environment (32+ characters or 64-char hex)
- [ ] API starts successfully (refuses boot if key missing)
- [ ] Key stored only in secrets manager / server env — not committed to git

## SMTP provider (Enterprise Email)

- [ ] Super Admin → Platform Admin → **Enterprise Email**
- [ ] SMTP provider configured (e.g. Zoho: `smtp.zoho.com:587` STARTTLS)
- [ ] Username + password saved (password never returned by API)
- [ ] Provider **enabled**
- [ ] Provider marked **default**
- [ ] `GET /v1/super-admin/email-infrastructure/readiness` → `ready: true`
- [ ] **Test connection** successful
- [ ] **Send test email** received in a real inbox

## Supabase Auth SMTP (signup / password reset)

- [ ] `SUPABASE_ACCESS_TOKEN` set (Owner/Administrator PAT) **or** Auth SMTP set manually in Dashboard
- [ ] `SUPABASE_PROJECT_REF` set (or derived from `SUPABASE_URL`)
- [ ] **Sync default → Supabase Auth** completed **or** Dashboard SMTP verified
- [ ] Supabase Dashboard → Authentication → **Rate Limits** reviewed / raised for email
- [ ] Test signup with a real Gmail (or other deliverable) address
- [ ] Confirmation email received (if confirm-email enabled)

## Business mail smoke

- [ ] `PUBLIC_APP_BASE_URL` set to the user-facing app origin (not `PUBLIC_API_BASE_URL`) so invitation RSVP links are correct
- [ ] Event invitation email (when applicable) — HTML invitation with Accept/Decline deep links
- [ ] Ticket confirmation / resend (when applicable)

## Sign-off

- [ ] Ready for real customer signup

**Date:** _______________  
**Operator:** _______________  
