# Production Email Identity — Architectural Recommendation

**Document type:** Design recommendation only  
**Status:** Advisory — **no implementation in this sprint**  
**Date:** 2026-07-16  
**Inputs:**
- Root-cause analysis: `email_address_invalid` for `*@owanbe.dev` (GoTrue mailer DNS validation; `owanbe.dev` = NXDOMAIN)
- [`UNIFIED_IDENTITY_PRODUCT_ARCHITECTURE.md`](UNIFIED_IDENTITY_PRODUCT_ARCHITECTURE.md)
- [`UNIFIED_IDENTITY_PHASE1_CERTIFICATION.md`](UNIFIED_IDENTITY_PHASE1_CERTIFICATION.md)

---

## Investigation

### What failed (evidenced)

| Fact | Evidence |
|------|----------|
| Client signup of `winchester@owanbe.dev` returned `email_address_invalid` | Device log → `GoTrueClient.signUp` |
| Failure is Supabase Auth mailer validation, not Owanbe Flutter validators | Error code/message match GoTrue `sendEmail` → `validateclient` |
| `owanbe.dev` has no public DNS (NXDOMAIN for MX/A/NS) | Cloudflare DoH Status 3 |
| Seeded `@owanbe.dev` users were inserted via SQL into `auth.users`, not public signup | `scripts/supabase/seed-dev-auth-users.sql` |
| Unified Identity model is one human → one auth subject → one email | Product architecture north star |

### Design implication

Production identity must use **emails that real mail systems can deliver to** (resolvable domains). Dev-only domains that do not exist in DNS are incompatible with hosted Supabase signup when confirmation email + email validation are active.

---

## Industry comparison

### How major consumer / SaaS products handle user emails

| Product | User email model | Platform-owned mailbox required? |
|---------|------------------|-----------------------------------|
| **Uber** | Personal or work email the user already owns | No |
| **Airbnb** | Personal or work email | No |
| **Stripe** | Work / personal email for dashboard login | No (Stripe does not force `@stripe.com` for customers) |
| **Paystack** | Merchant’s own email | No |
| **Flutterwave** | Merchant’s own email | No |
| **Facebook / Meta** | Personal email (or phone) | No |
| **LinkedIn** | Personal or work email | No |
| **Google** | Google Account (often `@gmail.com` or Workspace domain the **user/org** owns) | Customers are not required to use Google-owned domains they don’t control; Google accounts are identity providers, not “you must use @google.com as a customer of Google Ads/Cloud” |

### Pattern (industry standard)

1. **The email is the user’s identifier and recovery channel**, not a product brand mailbox.
2. Users sign up with **any address they control** that the auth provider accepts (format + deliverability).
3. The product may send mail **from** `@company.com` / `@company.app` (transactional: receipts, magic links, invites).
4. The product almost never requires customers to **own an inbox at** `@company.com`.
5. Internal / QA accounts may use company domains or dedicated test domains — **separate from customer production policy**.

### Distinction that matters

| Role of domain | Example | Who owns the inbox? |
|----------------|---------|---------------------|
| **From / Reply-To (product)** | `noreply@owanbe.com`, `support@owanbe.app` | Owanbe |
| **Login identity (customer)** | `john@gmail.com`, `ada@acme.ng` | Customer |
| **Dev / seed fixture** | `attendee@owanbe.dev` (SQL-seeded) | Engineering / CI |

Mixing these roles caused the current confusion: treating `@owanbe.dev` as if it were a customer-facing signup domain.

---

## Answers to the decision questions

### 1. Should production users sign up with ANY valid email?

**Recommendation: Yes — any email the auth provider accepts as deliverable.**

That includes:

- `john@gmail.com`
- `john@yahoo.com`
- `john@icloud.com`
- `john@outlook.com`
- `john@company.com` (any company domain with real DNS/MX)

**Constraints (provider / platform, not Owanbe branding):**

- Must pass format validation
- Must pass deliverability checks when email confirmation is enabled (resolvable domain, not blocked example/test hosts)
- Must be unique per auth subject (one email → one Owanbe account under Unified Identity)

Owanbe should **not** invent a closed email namespace for customers.

---

### 2. Should Owanbe ever require `@owanbe.com` or `@owanbe.dev`?

**Recommendation: No.**

| Domain | Require for customers? | Why |
|--------|------------------------|-----|
| `@owanbe.dev` | **Never** | Not a resolvable public domain (NXDOMAIN); unsuitable for hosted signup; not a customer mailbox |
| `@owanbe.com` / `@owanbe.app` / `@owanbe.africa` | **Never for customer login identity** | Customers do not receive or control inboxes at Owanbe’s domain unless Owanbe runs a full mail hosting product (out of scope). Forcing brand domains would block normal users, break recovery, and contradict industry practice |

**When Owanbe *uses* its own domains:**

- Transactional **From** addresses
- Staff / support aliases
- Optional employee SSO later (`@owanbe.com` for employees only — not for end customers)

---

### 3. What format do production SaaS products normally use?

**Customers authenticate with emails they already own.**

Platforms:

- Store that email as the account key
- Send verification / password reset / notifications **to** that address
- Send those messages **from** a verified product domain

They do **not** force `user@uber.com`-style customer identities.

---

### 4. Should `@owanbe.dev` continue to exist?

**Recommendation: Yes — as an internal engineering fixture only.**

| Allowed use | Not allowed |
|-------------|-------------|
| Regression testing | Production customer signup |
| SQL / Admin-seeded accounts | Public “Create account” with `@owanbe.dev` |
| QA scripts that bypass public signup | Assuming DNS/mail delivery works |
| Automated isolation tests (`attendee@`, `organizer@`, `vendor@`) | Marketing or user-facing docs as a real address |
| Internal demos when seeds are pre-provisioned | Treating it as a real mailbox domain |

**Should production customers use it?** **No.**

Continue seeding via Admin/SQL (or service-role createUser) so seeds never depend on public GoTrue signup + DNS validation for a non-existent domain.

---

### 5. If Owanbe owns `@owanbe.com` / `@owanbe.app` / `@owanbe.africa`?

**Customers should continue using their own personal/company emails.**

Owned domains should be used for:

- Product website / deep links
- Transactional email From/Reply-To
- Support (`support@…`)
- Staff accounts / future SSO

**Not** for “every customer’s login must be `name@owanbe.com`.”

---

### 6. Recommended production strategy under Unified Identity

Unified Identity = **one human, one auth account, one email, multiple workspaces.**

```
Customer-owned email (Gmail, Outlook, company, …)
        │
        ▼
  One Supabase auth subject
        │
        ▼
  One Owanbe users row (platform profile)
        │
        ├── Attendee workspace
        ├── Organizer workspace
        └── Vendor workspace
```

| Rule | Production policy |
|------|-------------------|
| Signup email | Customer-owned, deliverable address |
| Workspace activation | Does **not** create a new email or auth account |
| Hub / logout | Same email throughout; logout leaves Owanbe, not a workspace |
| Brand domains | Outbound mail + web only |
| `@owanbe.dev` | Engineering seeds / CI only |

This matches Phase 1 certification: production must not require seed emails.

---

### 7. Signup UX / documentation clarity?

**Recommendation: yes — documentation and copy only (when an approved UX sprint allows). No auth/code changes in this document.**

Suggested clarity (future sprint; not implemented here):

| Surface | Guidance |
|---------|----------|
| Universal Auth signup | Prompt for “your email” — do not suggest `@owanbe.dev` |
| Debug pre-fill | Keep clearly labeled **Dev only**; never present as production guidance |
| Error messaging | When Supabase returns `email_address_invalid`, prefer “Use a real email you can access” over generic “try again” (if/when copy is updated) |
| QA runbooks | Brand-new account tests = Gmail/company email; seed accounts = sign-**in** only |
| Architecture docs | Explicit: `@owanbe.dev` ≠ production identity namespace |
| Manual Phase 1 checklist | Already says “any new email (not dev seeds)” — reinforce with “must be a real mailbox domain” |

No change to authentication providers, Supabase project, or application code is required **by this recommendation alone**.

---

## Recommended production strategy

1. Accept **any deliverable customer-owned email** for signup/sign-in.
2. Never require `@owanbe.*` for customer accounts.
3. Use owned domains only for **outbound** product email and corporate/staff use.
4. Keep one email ↔ one Unified Identity account for life of the human on the platform.
5. Deploy with email confirmation / SMTP configured so real addresses can verify (ops concern; out of scope here).

---

## Recommended development strategy

1. Preserve `@owanbe.dev` **seeds** via SQL/Admin for isolated role testing.
2. Do not rely on public signup for `@owanbe.dev` addresses.
3. Local/debug one-tap sign-in may keep seed emails; label as non-production.
4. Set `ALLOW_MOCK_PERSISTENCE_FALLBACK=false` in staging/production so identity resolution does not silently impersonate seed vendor IDs.
5. Optional later: introduce a **unified traveler** seed (architecture Phase D) still for QA only — not for customers.

---

## Recommended testing strategy

| Scenario | Email strategy |
|----------|----------------|
| Unified Identity manual E2E (new human) | Real address (`+` alias Gmail, etc.) |
| Organizer / Vendor / Attendee isolation CI | Existing `@owanbe.dev` seeds (sign-in) |
| Idempotent activation | Real new account or controlled API test user |
| CRM / Vendor OS contract tests | Seeds or traveler QA account |
| Production smoke | Real staff personal/work emails only |

---

## Final recommendation

| Decision | Answer |
|----------|--------|
| Production signup emails | **Any valid, deliverable, customer-owned email** |
| Require `@owanbe.com` / `@owanbe.dev` for customers | **No** |
| Industry alignment | Same as Uber, Airbnb, Stripe, Paystack, Flutterwave, Meta, LinkedIn — login = user’s email |
| `@owanbe.dev` | **Keep for seeds / QA / regression only** — never for production customers |
| Owned brand domains | **From-addresses and web**, not customer login namespaces |
| Unified Identity | One real email → one account → many workspaces |
| Immediate code/auth/Supabase changes | **None** — design recommendation only |

**One sentence:**  
Production Owanbe identity should bind to the user’s own email; `@owanbe.dev` remains an engineering fixture; brand domains send mail, they do not define customer inboxes.

---

**STOP.**

No authentication, Supabase, routing, or application code was modified to produce this document.
