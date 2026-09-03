-- Phase 070 — Admin capability tier: core | optional
-- Additive metadata only. Does not create a second catalogue.
-- Vendor custom_extras (069) left in place unused; no data rewrite of requests.

BEGIN;

-- Annotate known optional/additional keys; everything else defaults to core in app code.
UPDATE tenant_vendor_categories
SET metadata = jsonb_set(
  COALESCE(metadata, '{}'::jsonb),
  '{capabilities}',
  (
    SELECT COALESCE(jsonb_agg(
      CASE
        WHEN lower(COALESCE(c->>'key', '')) IN (
          'lighting', 'generator', 'stage', 'led_screen', 'karaoke',
          'photo_booth', 'smoke_machine', 'ac', 'drone', 'backdrop',
          'florals', 'draping', 'bar_setup', 'glassware', 'coolers'
        )
        THEN c || jsonb_build_object('tier', 'optional')
        ELSE c || jsonb_build_object('tier', COALESCE(NULLIF(c->>'tier', ''), 'core'))
      END
      ORDER BY ord
    ), '[]'::jsonb)
    FROM jsonb_array_elements(COALESCE(metadata->'capabilities', '[]'::jsonb))
      WITH ORDINALITY AS t(c, ord)
  )
)
WHERE jsonb_typeof(metadata->'capabilities') = 'array'
  AND jsonb_array_length(COALESCE(metadata->'capabilities', '[]'::jsonb)) > 0;

COMMIT;
