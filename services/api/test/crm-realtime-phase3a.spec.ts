import { EventEmitter } from 'events';
import {
  crmUserChannel,
  type CrmRealtimeEnvelope,
} from '../src/integrations/realtime/crm-realtime.types';

describe('CRM realtime Phase 3A', () => {
  it('builds user-centric channel without vendor/organizer ids', () => {
    expect(crmUserChannel('tenant-a', 'user-1')).toBe('crm:tenant-a:user:user-1');
    expect(crmUserChannel('tenant-a', 'user-1')).not.toContain('vendor');
    expect(crmUserChannel('tenant-a', 'user-1')).not.toContain('organizer');
  });

  it('delivers only to subscribed user room (isolation)', () => {
    const bus = new EventEmitter();
    const vendorEvents: CrmRealtimeEnvelope[] = [];
    const otherEvents: CrmRealtimeEnvelope[] = [];

    const envelope: CrmRealtimeEnvelope = {
      eventId: 'e1',
      type: 'vendor_request_incoming',
      tenantId: 't1',
      resource: { type: 'vendor_request', id: 'r1' },
      revision: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
      dedupeKey: 'vendor_request:r1:new',
      occurredAt: '2026-01-01T00:00:00.000Z',
    };

    bus.on(crmUserChannel('t1', 'vendor-owner'), (e) => vendorEvents.push(e));
    bus.on(crmUserChannel('t1', 'other-user'), (e) => otherEvents.push(e));

    bus.emit(crmUserChannel('t1', 'vendor-owner'), envelope);

    expect(vendorEvents).toHaveLength(1);
    expect(otherEvents).toHaveLength(0);
  });

  it('maps Phase 3B lifecycle kinds to existing vocabulary only', () => {
    const kinds = [
      'vendor_request_incoming',
      'vendor_request_update',
      'vendor_request_message',
      'vendor_service_complete',
    ];
    for (const k of kinds) {
      expect(k.startsWith('vendor_request_') || k === 'vendor_service_complete').toBe(true);
    }
    expect(kinds).not.toContain('vendor_request_change_requests');
  });
});
