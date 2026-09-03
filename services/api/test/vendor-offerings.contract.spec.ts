import { parseBusinessCapabilityKey } from '../src/modules/event-config/vendor-taxonomy.util';

describe('vendor offerings phase 2 contracts', () => {
  it('keeps service and rental capabilities independent (both allowed)', () => {
    const keys = ['SERVICE_PROVIDER', 'RENTAL_PROVIDER'].map(parseBusinessCapabilityKey);
    expect(keys).toEqual(['SERVICE_PROVIDER', 'RENTAL_PROVIDER']);
  });

  it('rejects a second vendor identity key', () => {
    expect(parseBusinessCapabilityKey('SERVICE_VENDOR')).toBeNull();
    expect(parseBusinessCapabilityKey('RENTAL_VENDOR')).toBeNull();
  });
});
