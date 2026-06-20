import {
  computeFeeReversalMinor,
  computePlatformFeeMinor,
  FINANCE_POLICY_DEFAULTS,
} from '../src/modules/commerce/commerce.types';

describe('commerce.types finance policy helpers', () => {
  it('uses approved MVP default bps constants', () => {
    expect(FINANCE_POLICY_DEFAULTS.ticketPlatformFeeBps).toBe(500);
    expect(FINANCE_POLICY_DEFAULTS.vendorPlatformFeeBps).toBe(1000);
    expect(FINANCE_POLICY_DEFAULTS.escrowReleaseDelayHours).toBe(48);
  });

  it('computes ticket platform fee at 5%', () => {
    expect(computePlatformFeeMinor(10_000_00, 500)).toBe(500_00);
  });

  it('computes vendor platform fee at 10%', () => {
    expect(computePlatformFeeMinor(50_000_00, 1000)).toBe(5_000_00);
  });

  it('reverses full platform fee on full refund', () => {
    expect(computeFeeReversalMinor(10_000_00, 10_000_00, 500_00)).toBe(500_00);
  });

  it('reverses proportional platform fee on partial refund', () => {
    expect(computeFeeReversalMinor(2_500_00, 10_000_00, 500_00)).toBe(125_00);
  });
});
