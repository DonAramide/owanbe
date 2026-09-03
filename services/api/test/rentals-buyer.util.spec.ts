import { isSelfRental, resolveRentalQuantity } from '../src/modules/rentals/rentals-buyer.util';

describe('vendor-as-buyer rentals', () => {
  it('rejects self-rental when buyer vendor equals provider', () => {
    expect(isSelfRental('v1', 'v1')).toBe(true);
    expect(isSelfRental('v1', 'v2')).toBe(false);
    expect(isSelfRental(null, 'v1')).toBe(false);
  });

  it('forces package quantity to one offering unit', () => {
    expect(resolveRentalQuantity(true, 5)).toBe(1);
    expect(resolveRentalQuantity(false, 3)).toBe(3);
    expect(resolveRentalQuantity(false, 0)).toBe(0);
  });
});
