import { isSelfServiceProcurement } from '../src/modules/vendor-operations/vendor-crm-buyer.util';

describe('vendor CRM buyer context', () => {
  it('rejects self-procurement', () => {
    expect(isSelfServiceProcurement('v1', 'v1')).toBe(true);
    expect(isSelfServiceProcurement('v1', 'v2')).toBe(false);
  });
});
