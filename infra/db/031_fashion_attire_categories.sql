-- Phase 2C correction — Fashion & Attire marketplace categories
BEGIN;

INSERT INTO tenant_vendor_categories (tenant_id, slug, label, icon_key, sort_order, is_active)
SELECT t.id, v.slug, v.label, v.icon_key, v.sort_order, true
FROM tenants t
CROSS JOIN (
  VALUES
    ('fashion-attire', 'Fashion & Attire', 'checkroom', 50),
    ('aso-ebi', 'Aso-Ebi', 'style', 51),
    ('traditional-wear', 'Traditional Wear', 'dry_cleaning', 52),
    ('wedding-gowns', 'Wedding Gowns', 'favorite_border', 53),
    ('bridesmaid-dresses', 'Bridesmaid Dresses', 'groups', 54),
    ('suits', 'Suits', 'business_center', 55),
    ('gele', 'Gele', 'face_retouching_natural', 56),
    ('fashion-accessories', 'Accessories', 'diamond', 57),
    ('tailoring', 'Tailoring', 'content_cut', 58)
) AS v(slug, label, icon_key, sort_order)
ON CONFLICT (tenant_id, slug) DO UPDATE
  SET label = EXCLUDED.label,
      icon_key = EXCLUDED.icon_key,
      is_active = true;

COMMIT;
