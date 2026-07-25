# Shared Profile Infrastructure — Deliverable

**Status:** Complete (infrastructure only)  
**Stop:** No Attendee / Organizer / Vendor profile fields or screens were added.

---

## Goal

Reusable profile architecture for:

- Global User Profile (existing editor now consumes this)
- Future Attendee / Organizer / Vendor profiles

Profiles remain **independent models**. This package does not merge them.

---

## Package root

`mobile/lib/profile/`

Barrel: `mobile/lib/profile/profile.dart`

---

## Files added

### Models
| File | Purpose |
|------|---------|
| `models/profile_avatar_value.dart` | Avatar preview / dirty / remove state |
| `models/profile_social_link_defs.dart` | Canonical social link field defs |

### Validation
| File | Purpose |
|------|---------|
| `validation/profile_validators.dart` | Required, max length, URL, social, interests |

### Repository / services
| File | Purpose |
|------|---------|
| `repository/profile_repository.dart` | Abstract repo + avatar resolve; marker types per layer |
| `repository/profile_media_uploader.dart` | Shared avatar upload via `MediaApi` |
| `repository/global_profile_repository.dart` | Global Hub persistence (`PATCH /me/profile`) |

### Controllers
| File | Purpose |
|------|---------|
| `controllers/profile_edit_controller.dart` | Save / cancel / dirty / loading / error / success |

### Shared widgets
| File | Purpose |
|------|---------|
| `widgets/profile_edit_layout.dart` | Header, Save, Cancel, loading, error, dirty, discard dialog, sheet helper |
| `widgets/profile_avatar_editor.dart` | Upload / replace / remove / preview |
| `widgets/profile_text_field.dart` | Text field + validation |
| `widgets/profile_text_area.dart` | Multiline text |
| `widgets/profile_chip_selector.dart` | Multi-select chips |
| `widgets/profile_social_links_form.dart` | Social links block |
| `widgets/profile_validation_message.dart` | Inline error message |

### Refactored consumer (no new fields)
| File | Change |
|------|--------|
| `features/home/widgets/hub_global_profile_edit_sheet.dart` | Rewired to shared infra |

---

## Shared components

- **Layout:** `ProfileEditLayout` + `showProfileEditSheet` + `showDiscardChangesDialog`
- **Avatar:** `ProfileAvatarEditor` + `ProfileAvatarValue`
- **Forms:** text, textarea, chip selector, social links, validation message
- **Save behaviour:** `ProfileEditController` (`runSave`, dirty flag, unsaved warning via `PopScope` / Cancel)

---

## Shared validation (`ProfileValidators`)

- Required / optional max length
- Display name, bio, occupation, company helpers
- Optional HTTP(S) URL
- Interests count/label limits
- Social links map validation

---

## Repository structure

```
ProfileRepository (abstract)
├── resolveAvatar(...)           shared upload/clear
├── GlobalProfileRepository      marker
│   └── GlobalProfileRepositoryImpl  → IdentityApi.updateGlobalProfile
├── AttendeeProfileRepository    marker only (no fields)
├── OrganizerProfileRepository   marker only (no fields)
└── VendorProfileRepository      marker only (no fields)
```

Networking stays on existing APIs (`IdentityApi`, `MediaApi`). No duplicate HTTP clients.

---

## Explicitly not done

- No attendee / organizer / vendor profile fields
- No auth / RBAC / routing changes
- No UI redesign outside shared chrome
- No workspace profile screens
