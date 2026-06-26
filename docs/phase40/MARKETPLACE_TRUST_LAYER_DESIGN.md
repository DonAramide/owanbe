# Phase 40 — Marketplace Trust Layer (Design Only)

**Status:** Design specification — **not implemented** (frozen per launch sprint).  
**Goal:** Increase conversion and reduce vendor risk for celebration bookings in West Africa.

---

## Problem

Customers choose vendors from marketplace listings with limited signals beyond category and static profile text. Vendors lack incentives for responsiveness and completion quality.

---

## Proposed trust primitives

### 1. Vendor reviews

**What:** Post-event written reviews from event organizers (clients), optionally verified ticket holders.

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID | |
| `tenant_id` | UUID | |
| `vendor_id` | UUID | |
| `event_id` | UUID | Must be completed event |
| `reviewer_user_id` | UUID | Organizer or entitled guest |
| `rating` | 1–5 | Overall |
| `title` | text | Optional |
| `body` | text | Max 2k chars |
| `status` | enum | `pending`, `published`, `hidden`, `flagged` |
| `created_at` | timestamptz | |

**Rules**

- One review per reviewer per vendor per event.
- Reviews publish only after event `status = completed` (or +24h after `ends_at`).
- Admin can hide/flag; vendor can reply once (future).

**API (future)**

- `POST /vendors/:id/reviews`
- `GET /vendors/:id/reviews?limit=20`
- `GET /vendors/:id/reviews/summary`

---

### 2. Ratings aggregate

**Materialized view:** `vendor_rating_summary`

| Column | Description |
|--------|-------------|
| `vendor_id` | PK |
| `rating_average` | Weighted mean, 1 decimal |
| `review_count` | Published only |
| `rating_distribution` | JSONB `{ "5": 12, "4": 3, ... }` |
| `last_review_at` | timestamptz |

**Display:** Marketplace cards, vendor detail header, AI planner recommendations.

**Anti-gaming:** Exclude reviews where reviewer has no `vendor_participation` or `booking` link to vendor for that event.

---

### 3. Completion badges

Earned badges stored in `vendor_badges` (vendor_id, badge_code, earned_at, metadata).

| Badge | Criteria | UI |
|-------|----------|-----|
| **Verified Partner** | Onboarding approved + KYC | Blue check |
| **Event Pro** | ≥10 completed events on platform | Gold ribbon |
| **On-Time Pro** | ≥95% bookings fulfilled without dispute (90d) | Clock icon |
| **Top Rated** | rating_average ≥ 4.7, review_count ≥ 15 | Star burst |

**Computation:** Nightly job from `bookings`, `disputes`, `vendor_applications`.

---

### 4. Response badges

Measure vendor responsiveness to CRM requests and marketplace inquiries.

| Badge | Criteria |
|-------|----------|
| **Quick Responder** | Median first response &lt; 4h (30d) |
| **Same-Day** | 80% requests first touch within 24h |

**Data source:** `vendor_crm_requests` timestamps (`created_at`, `first_response_at`) — already in vendor ops schema direction.

**Display:** Chip on marketplace card + vendor detail “Usually responds within X hours”.

---

## UI placement (Flutter)

```
MarketplaceVendorCard
├── rating_average + review_count (stars)
├── badges row (max 3 visible + overflow)
└── response_sla_label (optional)

MarketplaceVendorDetailScreen
├── Trust panel (reviews summary + badges)
├── Reviews tab (paginated list)
└── CTA unchanged (Request — no chat)
```

---

## Moderation & safety

- Report review flow → admin queue (reuse dispute/compliance patterns).
- Profanity filter on `body` (server-side).
- Vendor cannot delete reviews; may submit one public response.

---

## Migration sketch (future phase)

```sql
-- 039_marketplace_trust.sql (NOT APPLIED)
CREATE TABLE vendor_reviews (...);
CREATE TABLE vendor_badges (...);
CREATE MATERIALIZED VIEW vendor_rating_summary AS ...;
```

---

## Dependencies

- Reliable booking completion status (not mock `VendorStore` orders).
- Vendor CRM request timestamps populated from API.
- Admin moderation UI for flagged reviews.

---

## Out of scope (explicit)

- Contact import, EventBook, new AI features, new marketplace categories.
- In-app chat (removed from beta UI).

---

## Success metrics (post-launch)

- Marketplace CTR → vendor detail +5%
- Request → confirmed booking conversion +10%
- Dispute rate &lt; 2% of completed bookings
