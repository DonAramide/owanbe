-- Rentals & Event Equipment marketplace categories
BEGIN;

INSERT INTO tenant_vendor_categories (tenant_id, slug, label, icon_key, sort_order, is_active)
SELECT t.id, v.slug, v.label, v.icon_key, v.sort_order, true
FROM tenants t
CROSS JOIN (
  VALUES
    ('rentals-equipment', 'Rentals & Event Equipment', 'inventory_2', 60),
    ('chairs', 'Chairs', 'chair', 61),
    ('tables', 'Tables', 'table_restaurant', 62),
    ('canopies', 'Canopies', 'umbrella', 63),
    ('tents', 'Tents', 'cabin', 64),
    ('stage-platforms', 'Stage Platforms', 'foundation', 65),
    ('led-screens', 'LED Screens', 'tv', 66),
    ('sound-systems', 'Sound Systems', 'speaker', 67),
    ('lighting-systems', 'Lighting Systems', 'lightbulb', 68),
    ('generators', 'Generators', 'bolt', 69),
    ('mobile-toilets', 'Mobile Toilets', 'wc', 70),
    ('cooling-fans', 'Cooling Fans', 'mode_fan', 71),
    ('air-conditioners', 'Air Conditioners', 'ac_unit', 72),
    ('dance-floors', 'Dance Floors', 'grid_on', 73),
    ('cutlery-crockery', 'Cutlery & Crockery', 'restaurant', 74),
    ('thrones-vip-seating', 'Thrones & VIP Seating', 'king_bed', 75),
    ('backdrops', 'Backdrops', 'wallpaper', 76),
    ('photo-booths', 'Photo Booths', 'photo_camera', 77),
    ('event-equipment', 'Event Equipment', 'construction', 78)
) AS v(slug, label, icon_key, sort_order)
ON CONFLICT (tenant_id, slug) DO UPDATE
  SET label = EXCLUDED.label,
      icon_key = EXCLUDED.icon_key,
      is_active = true;

COMMIT;
