import {
  normalizeServiceKey,
  customerPriceFromVendorPayout,
  vendorPayoutFromCustomerPrice,
  resolveMarkupFromRules,
  type PricingRuleRow,
} from '../src/modules/vendor-operations/vendor-pricing.util';

describe('vendor pricing util', () => {
  it('normalizes service keys', () => {
    expect(normalizeServiceKey('Catering')).toBe('catering');
    expect(normalizeServiceKey('Small Chops')).toBe('small_chops');
    expect(normalizeServiceKey(null)).toBe('general');
  });

  it('applies 40% markup from vendor payout', () => {
    const split = customerPriceFromVendorPayout(50_000_00n, 4000);
    expect(split.customerPriceMinor).toBe(70_000_00n);
    expect(split.platformMarginMinor).toBe(20_000_00n);
  });

  it('back-calculates vendor payout from customer price', () => {
    const split = vendorPayoutFromCustomerPrice(70_000_00n, 4000);
    expect(split.vendorPayoutMinor).toBe(50_000_00n);
    expect(split.platformMarginMinor).toBe(20_000_00n);
  });
});

describe('resolveMarkupFromRules hierarchy', () => {
  const vendorA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const vendorB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

  const rules: PricingRuleRow[] = [
    { vendor_id: null, service_key: null, markup_bps: 4000, is_default: true },
    { vendor_id: null, service_key: 'catering', markup_bps: 3500, is_default: false },
    { vendor_id: vendorA, service_key: null, markup_bps: 2500, is_default: false },
    {
      vendor_id: vendorA,
      service_key: 'catering',
      markup_bps: 2000,
      is_default: false,
    },
  ];

  it('uses vendor + service override first', () => {
    const r = resolveMarkupFromRules(rules, 'Catering', vendorA);
    expect(r).toEqual({
      markupBps: 2000,
      resolvedFrom: 'vendor_service_override',
    });
  });

  it('uses vendor override when no vendor+service match', () => {
    const r = resolveMarkupFromRules(rules, 'photography', vendorA);
    expect(r).toEqual({
      markupBps: 2500,
      resolvedFrom: 'vendor_override',
    });
  });

  it('uses service category when no vendor override', () => {
    const r = resolveMarkupFromRules(rules, 'catering', vendorB);
    expect(r).toEqual({
      markupBps: 3500,
      resolvedFrom: 'service_category_rule',
    });
  });

  it('uses platform default when no service rule', () => {
    const r = resolveMarkupFromRules(rules, 'dj', vendorB);
    expect(r).toEqual({
      markupBps: 4000,
      resolvedFrom: 'platform_default_rule',
    });
  });

  it('falls back to 4000 bps when no rules', () => {
    const r = resolveMarkupFromRules([], 'catering', vendorA);
    expect(r).toEqual({
      markupBps: 4000,
      resolvedFrom: 'hardcoded_fallback_4000_bps',
    });
  });

  it('never prefers service over vendor+service', () => {
    const r = resolveMarkupFromRules(rules, 'catering', vendorA);
    expect(r.resolvedFrom).toBe('vendor_service_override');
    expect(r.markupBps).not.toBe(3500);
  });
});
