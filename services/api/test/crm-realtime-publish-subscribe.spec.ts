import { EventEmitter } from 'events';
import { crmUserChannel } from '../src/integrations/realtime/crm-realtime.types';

/**
 * Simulates CrmRealtimeBroadcastService local delivery path used by SSE subscribe().
 */
class FakeCrmBus {
  private readonly bus = new EventEmitter();
  subscribe(tenantId: string, userId: string, listener: (e: unknown) => void) {
    const channel = crmUserChannel(tenantId, userId);
    this.bus.on(channel, listener);
    return () => this.bus.off(channel, listener);
  }
  publishToUser(recipientUserId: string, envelope: { tenantId: string }) {
    this.bus.emit(crmUserChannel(envelope.tenantId, recipientUserId), envelope);
  }
}

describe('CRM realtime publish → subscribe', () => {
  it('vendor receives incoming after organizer create signal', () => {
    const bus = new FakeCrmBus();
    const received: unknown[] = [];
    const unsub = bus.subscribe('t1', 'vendor-user', (e) => received.push(e));
    bus.publishToUser('vendor-user', {
      tenantId: 't1',
      type: 'vendor_request_incoming',
      resource: { type: 'vendor_request', id: 'r1' },
      dedupeKey: 'vendor_request:r1:new',
    } as never);
    expect(received).toHaveLength(1);
    unsub();
  });

  it('organizer receives update after vendor accept signal', () => {
    const bus = new FakeCrmBus();
    const received: Array<{ type?: string }> = [];
    bus.subscribe('t1', 'org-user', (e) => received.push(e as { type?: string }));
    bus.publishToUser('org-user', {
      tenantId: 't1',
      type: 'vendor_request_update',
      resource: { type: 'vendor_request', id: 'r1' },
      dedupeKey: 'vendor_request:r1:accepted:vendor',
    } as never);
    expect(received[0]?.type).toBe('vendor_request_update');
  });

  it('wrong vendor receives nothing', () => {
    const bus = new FakeCrmBus();
    const received: unknown[] = [];
    bus.subscribe('t1', 'vendor-b', (e) => received.push(e));
    bus.publishToUser('vendor-a', {
      tenantId: 't1',
      type: 'vendor_request_incoming',
    } as never);
    expect(received).toHaveLength(0);
  });
});
