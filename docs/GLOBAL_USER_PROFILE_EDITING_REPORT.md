# Global User Profile Editing — Implementation Report

**Status:** Complete (additive only)  
**Scope:** Hub Profile (`HomeProfileTab`) global edit — avatar, personal, professional, interests, social links  
**Stop:** Workspace-specific profile editing NOT started

---

## Confirmation (architecture)

| Concern | Status |
|---------|--------|
| Authentication | Unchanged |
| RBAC / roles activation | Unchanged |
| Workspace architecture | Unchanged |
| Attendee / Organizer / Vendor modules | Untouched |
| Implementation | Additive only |

Four profile layers remain independent. This task only extends **Global User Profile** on `users`.

---

## Files changed

### Database
- `infra/db/049_global_user_profile.sql` **(new)**

### API
- `services/api/src/modules/users/dto/update-global-profile.dto.ts` **(new)**
- `services/api/src/modules/users/users.service.ts` — extend `GET /auth/me` + `updateGlobalProfile`
- `services/api/src/modules/users/workspace.controller.ts` — add `PATCH /me/profile`

### Flutter
- `mobile/lib/core/api/identity_api.dart` — parse profile fields; `updateGlobalProfile`
- `mobile/lib/identity/user_identity.dart` — global profile fields on identity
- `mobile/lib/identity/identity_provider.dart` — prefer API `avatarUrl`
- `mobile/lib/features/home/widgets/home_profile_tab.dart` — Edit Profile + summary
- `mobile/lib/features/home/widgets/hub_global_profile_edit_sheet.dart` **(new)**

---

## Schema changes (`049_global_user_profile.sql`)

Added to **`users` only** (IF NOT EXISTS):

| Column | Type | Notes |
|--------|------|--------|
| `first_name` | TEXT | |
| `last_name` | TEXT | |
| `avatar_url` | TEXT | Public media URL |
| `bio` | TEXT | |
| `occupation` | TEXT | |
| `company` | TEXT | |
| `interests` | JSONB default `[]` | Global interests array — **not** `attendee_profiles.interests` |
| `social_links` | JSONB default `{}` | Keys: instagram, twitter, linkedin, facebook, tiktok, youtube, website |

No changes to `attendee_profiles`, `organizer_profiles`, or `vendor_profiles`.

**Apply migration** on your Owambe Postgres before using Edit Profile.

---

## API

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/auth/me` | Extended response with global profile fields |
| `PATCH` | `/me/profile` | Update global Hub profile (additive) |

`PATCH /me/profile` body (all optional):

```json
{
  "firstName": "string",
  "lastName": "string",
  "displayName": "string",
  "avatarUrl": "string|null",
  "bio": "string",
  "occupation": "string",
  "company": "string",
  "interests": ["Music", "Weddings"],
  "socialLinks": {
    "instagram": "",
    "twitter": "",
    "linkedin": "",
    "facebook": "",
    "tiktok": "",
    "youtube": "",
    "website": ""
  }
}
```

Avatar upload reuses existing `POST /media/presign` + `PUT` upload with `purpose: "avatar"`, then persists `publicUrl` via `PATCH /me/profile`.

---

## UI

- **Edit Profile** button on Hub Profile card
- Modal bottom sheet (`HubGlobalProfileEditSheet`) using EOS components
- Supports: upload / replace / remove avatar; names; bio; occupation; company; multi-select interests; optional social URLs

---

## Validation rules

| Field | Rule |
|-------|------|
| firstName / lastName | max 80 |
| displayName | required on save (client); max 120 |
| bio | max 1000 |
| occupation / company | max 120 |
| interests | max 24 items; each max 48 chars |
| social URLs | empty allowed; otherwise http/https |
| avatarUrl | max 2048; null clears |

---

## Migration details

1. Run `infra/db/049_global_user_profile.sql` against Owambe Postgres.
2. Restart / hot-reload Nest API (`npm run start:dev`).
3. Hot-restart Flutter app.
4. Hub → Profile → **Edit Profile**.
