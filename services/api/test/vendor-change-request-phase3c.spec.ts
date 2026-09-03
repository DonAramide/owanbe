import {
  CHANGE_REQUEST_TYPES,
  CHANGE_REQUEST_STATUSES,
} from '../src/modules/vendor-operations/vendor-change-request.service';

describe('Phase 3C change request domain', () => {
  it('supports only approved structured types (no ADD_SERVICE, no chat)', () => {
    expect([...CHANGE_REQUEST_TYPES]).toEqual([
      'ADD_CAPABILITY',
      'REMOVE_CAPABILITY',
      'CHANGE_DATE',
      'CHANGE_TIME',
      'CHANGE_VENUE',
      'SPECIAL_REQUIREMENT',
    ]);
    expect(CHANGE_REQUEST_TYPES).not.toContain('ADD_SERVICE');
    expect(CHANGE_REQUEST_TYPES).not.toContain('CHAT');
  });

  it('uses clear status lifecycle', () => {
    expect([...CHANGE_REQUEST_STATUSES]).toEqual([
      'pending',
      'accepted',
      'declined',
      'cancelled',
      'expired',
    ]);
  });
});
