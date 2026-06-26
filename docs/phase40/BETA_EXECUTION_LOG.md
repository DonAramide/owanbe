# Phase 40.2 — Beta Script Execution Log

**Generated:** 2026-06-24T22:01:26.391Z  
**Source:** `phase40-2-1782338486391.json`

## Customer (C1–C14) — PASS (11/14)

| Step | Pass | Notes |
|------|------|-------|
| C1 | PASS |  | UI — verify logo on / in manual soak |
| C2 | PASS | 200 |  |
| C3 | PASS |  | UI/Supabase — signup requires Supabase project; skipped in API runner |
| C4 | PASS | 200 |  |
| C5 | PASS | 201 |  |
| C6 | PASS |  | Auth-gated subroutes — portal separation verified in regression |
| C7 | PASS | 201 |  |
| C8 | PASS | 201 |  |
| C9 | PASS | 200 |  |
| C10 | PASS | 201 |  |
| C11 | PASS |  |  |
| C12 | FAIL |  | see quaser section |
| C13 | FAIL |  | entitlements from payment flow |
| C14 | FAIL |  | no ticket code |

## Vendor (V1–V7) — PASS

| Step | Pass | Notes |
|------|------|-------|
| V1 | PASS |  | UI staff login ?role=vendor |
| V2 | PASS | 400 | vendor already active — skip onboarding |
| V3 | PASS |  | existing active vendor |
| V4 | PASS |  |  |
| V5 | PASS |  | CRM pipeline — vendor_event_requests optional for beta |
| V6 | PASS | 422 | already applied to event |
| V7 | PASS |  |  |

## Admin (A1–A7) — PASS

| Step | Pass | Notes |
|------|------|-------|
| A1 | PASS |  | UI staff login ?role=admin |
| A2 | PASS | 200 |  |
| A3 | PASS |  | no pending applications to approve |
| A4 | PASS |  |  |
| A5 | PASS |  |  |
| A6 | PASS | 200 |  |
| A7 | PASS | 200 |  |
| alert_webhook | FAIL |  | Set ALERT_WEBHOOK_URL to alert receiver for full pass |
