# Vendor Services & Availability — Unexpected null fix

**Date:** 2026-08-18  
**Scope:** Vendor Services & Availability screen runtime crash only

---

## 1. Exact root cause

The screen wrapped its scaffold in `Theme(data: ThemeData.dark()...)`.

`ThemeData.dark()` does **not** include the EOS `EosTokens` theme extension.

Widgets on this path call:

```dart
Theme.of(this).extension<EosTokens>()!  // eos_context.dart — `context.eos`
```

That bang (`!`) throws **Unexpected null value** as soon as `EosSurfaceCard` or `VendorServiceCapabilityEditor` reads `context.eos.spacing`.

This is the same class of bug already documented on Event 360:

> Do NOT wrap with ThemeData.dark() — that strips EosTokens and crashes any widget using context.eos / EosSurfaceCard.

### Exact null field

| Item | Value |
|------|--------|
| Null | `ThemeData.extension<EosTokens>()` |
| Expression | `Theme.of(context).extension<EosTokens>()!` |
| Dart “field” | not a service DTO field — **theme extension `EosTokens`** |
| File | `mobile/lib/eos/extensions/eos_context.dart` line 6 (accessor) |
| Crash site | `VendorServicesAvailabilityScreen` Theme wrap + `EosSurfaceCard` / editor `context.eos.spacing` |

This is **not** `service.name`, `service.price`, `availability.startTime`, or another vendor DTO field. Profile/service JSON mapping already treats those as optional with defaults.

### Classification

**C / D hybrid:** UI incorrectly replaced the app theme (mapping/theme type), making a required theme object null. API/DB data was not the missing field.

---

## 2. API / model mismatch

None for this crash.

| Layer | Status |
|-------|--------|
| `VendorWorkspaceProfile.fromJson` | `services` defaults to `[]` |
| `VendorServiceEntity.fromJson` | `id`/`serviceKey`/`serviceName` default to `''`; `capabilities` default to `[]` |
| `VendorServiceCapability.fromJson` | `key`/`label` default to `''`; `provided` defaults to `false` |
| Empty new vendor | editor already shows “No bookable services yet…” |
| Existing vendor with services | cards render once EOS tokens are present |

Existing vs new vendor **data shapes are compatible**. New vendors with no `vendor_services` rows get an empty list, not a null crash.

---

## 3. UI failure

```
Vendor Dashboard → Services & Availability
  VendorServicesAvailabilityScreen
    Theme(ThemeData.dark())   ← strips EosTokens
      VendorServiceCapabilityEditor
        EosSurfaceCard → context.eos → extension<EosTokens>()! → THROW
      Upcoming bookings ListTiles (siblings still build after error recovery)
```

---

## 4. ListTile warning

**Independent / secondary.** Flutter 3.44 debug check:

`ListTile background color or ink splashes may be invisible`

Cause: `SwitchListTile` / `CheckboxListTile` sit inside `EosSurfaceCard`’s `DecoratedBox` (background color) without their own `Material`. Ink paints on the nearest `Material` (Scaffold), so the card decoration hides splashes.

This is **not** the Unexpected null. Left unchanged (no unrelated ListTile restyle).

---

## 5. Minimum fix

Remove the `ThemeData.dark()` wrap. Keep `Scaffold(backgroundColor: EosColors.plumDark)` so the parent `EosTheme` (with `EosTokens`) remains.

Same pattern as `vendor_event_360_workspace_screen.dart`.

---

## 6. Files changed

| File | Change |
|------|--------|
| `mobile/lib/features/vendor/screens/vendor_services_availability_screen.dart` | Remove `ThemeData.dark()` wrap |
| `mobile/test/features/vendor/vendor_services_availability_null_test.dart` | Regression: ThemeData.dark() null, empty vendor, populated vendor |
| `docs/VENDOR_SERVICES_AVAILABILITY_NULL_FIX_REPORT.md` | This report |

Untouched: Vendor Identity, Profile API, auth, RBAC, marketplace, pricing, CRM, messaging, polling.

---

## 7. Tests

| Test | Result |
|------|--------|
| `ThemeData.dark()` makes `extension<EosTokens>()` null | covered |
| Empty services (new vendor) — no Unexpected null | covered |
| Existing Catering service renders | covered |
| ListTile FlutterError is not treated as Unexpected null | covered |
| `flutter analyze` on changed Dart | **No issues** |
| `vendor_services_availability_null_test.dart` | **Passed** |

Manual: open Services & Availability from Vendor Dashboard on Chrome after a full hot restart (`R`). Hot reload can keep the old `ThemeData.dark()` wrap.

---

## 8. Existing / new vendor compatibility

Both use the same `VendorWorkspaceProfile.services` list. Empty → empty state. Populated → switches + capability checkboxes. No duplicate vendor rows. No identity change.

---

## 9. Architecture

Only the Services & Availability **theme wrapper** was removed. No API, DB, or identity changes.

---

✅ **VENDOR SERVICES & AVAILABILITY NULL FIXED**
