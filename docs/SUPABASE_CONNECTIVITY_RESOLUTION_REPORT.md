# SUPABASE CONNECTIVITY ISSUE — RESOLUTION REPORT

**Date:** 2026-07-19  
**Status:** **RESOLVED**  
**Devices validated:** Samsung SM-T397U (physical Android 8.1)

---

## Root cause

Two independent failures stacked:

### 1. Device network (primary / immediate)

The tablet had **Wi‑Fi enabled but DISCONNECTED**:

- `Active default network: none`
- Saved SSID: `IIPS`
- Visible live SSID: `IIPS CPE_12AF49` (different network)
- Symptom in app: `SocketException: Failed host lookup: 'iozdkiwcwblydsomxhxa.supabase.co'`

Supabase URL/config were correct. The host resolves on the PC. The device simply had no working IP route/DNS until network was restored.

### 2. Release-ready Android permission (permanent code fix)

`INTERNET` (and `ACCESS_NETWORK_STATE`) lived only under `debug` / `profile` manifests, **not** in `main/AndroidManifest.xml`.

Release / non-debug packaging would ship without INTERNET permission → permanent DNS/network failure on physical devices.

---

## Fixes applied

| Fix | What |
|---|---|
| **Code** | Added `android.permission.INTERNET` + `ACCESS_NETWORK_STATE` to `mobile/android/app/src/main/AndroidManifest.xml` |
| **Runtime (validation)** | Restored device internet via USB reverse tether (gnirehtet) so Auth could be exercised without waiting on Wi‑Fi association |
| **Prior hardening (already accepted)** | Single Supabase config source, startup connectivity gate, typed diagnostics |

Operational note for day-to-day use: connect the tablet to a live Wi‑Fi SSID (currently `IIPS CPE_12AF49`). USB reverse tether is a lab/validation path, not a product dependency.

---

## Validation results

### Customer Flutter (`lib/main.dart`)

| Check | Result |
|---|---|
| Initialize Supabase | **PASS** (app reached Customer login) |
| Reach Auth endpoint | **PASS** (DNS resolved; sign-in completed) |
| Sign in (`attendee@owanbe.dev`) | **PASS** → **Owanbe Home** with Attendee / Organizer / Vendor workspaces |
| Unified Identity | **PASS** (home hub / workspace cards intact) |
| Customer entry UI | **PASS** (“One customer account for Attendee, Organizer, and Vendor”) |

### Admin Flutter (`lib/main_admin.dart`)

| Check | Result |
|---|---|
| Initialize Supabase | **PASS** (Admin login / Control Tower entry) |
| Reach Auth endpoint | **PASS** |
| Sign in (`superadmin@owanbe.dev`) | **PASS** → **Control Tower / Platform Command Center** |
| Admin separation | **PASS** (Admin login + Control Tower; not Customer Hub) |
| Unified Identity | **PASS** (same Supabase project / JWT; separate binary entry) |

### Host-side Auth confirmation

- Customer password grant: **OK**
- Admin (`superadmin@owanbe.dev`) password grant: **OK**
- API health `http://127.0.0.1:8080/health`: **200** (with `adb reverse`)

---

## Architecture preservation

Unchanged by this resolution:

- Unified Identity model / providers  
- Customer Hub product flows  
- Organizer / Attendee / Vendor workspaces  
- Customer vs Admin login separation (`/auth` vs `/auth/admin`)

Code delta for this fix: Android network permissions in main manifest (+ connectivity hardening already accepted).

---

## Final verdict

**RESOLVED**

Customer and Admin both initialize Supabase, reach Auth, and sign in successfully on the physical device once network is available. The permanent packaging bug (missing INTERNET on main) is fixed.
