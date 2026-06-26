# Phase 41 — Staging Database Report

**Generated:** 2026-06-26T11:42:08.590Z  
**Result:** PASS

{
  "applied": [],
  "skipped": [
    {
      "id": "034",
      "reason": "already in schema_migrations"
    },
    {
      "id": "035",
      "reason": "already in schema_migrations"
    },
    {
      "id": "036",
      "reason": "already in schema_migrations"
    },
    {
      "id": "037",
      "reason": "already in schema_migrations"
    },
    {
      "id": "038",
      "reason": "already in schema_migrations"
    }
  ],
  "failed": [],
  "validation": [
    {
      "id": "034",
      "tables": {
        "event_seating_layouts": true,
        "event_seating_tables": true,
        "event_seating_assignments": true
      },
      "ok": true
    },
    {
      "id": "035",
      "tables": {
        "event_program_items": true,
        "event_activity_log": true,
        "event_program_reminders": true
      },
      "ok": true
    },
    {
      "id": "036",
      "tables": {
        "vendor_event_requests": true,
        "vendor_request_stage_history": true
      },
      "ok": true
    },
    {
      "id": "037",
      "tables": {
        "vendor_availability_settings": true,
        "vendor_calendar_blocks": true
      },
      "ok": true
    },
    {
      "id": "038",
      "tables": {
        "event_guests": true,
        "event_invitations": true,
        "event_invitation_tokens": true
      },
      "ok": true
    }
  ],
  "history": [
    {
      "id": "034",
      "filename": "034_event_seating.sql",
      "applied_at": "2026-06-24T16:08:29.684Z"
    },
    {
      "id": "035",
      "filename": "035_event_programs.sql",
      "applied_at": "2026-06-24T16:08:29.856Z"
    },
    {
      "id": "036",
      "filename": "036_vendor_crm.sql",
      "applied_at": "2026-06-24T16:11:13.406Z"
    },
    {
      "id": "037",
      "filename": "037_vendor_calendar.sql",
      "applied_at": "2026-06-24T16:10:05.926Z"
    },
    {
      "id": "038",
      "filename": "038_event_guests_invitations.sql",
      "applied_at": "2026-06-24T16:10:05.934Z"
    }
  ],
  "result": "PASS"
}
