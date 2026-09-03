/** Phase 3A CRM realtime envelope — signal only; REST remains authoritative. */
export type CrmRealtimeResource = {
  type: 'vendor_request' | 'vendor_change_request';
  id: string;
};

export type CrmRealtimeEnvelope = {
  eventId: string;
  type:
    | 'vendor_request_incoming'
    | 'vendor_request_update'
    | 'vendor_request_message'
    | 'vendor_service_complete'
    | 'vendor_change_request_created'
    | 'vendor_change_request_updated'
    | 'vendor_change_request_accepted'
    | 'vendor_change_request_declined'
    | 'vendor_change_request_cancelled'
    | string;
  tenantId: string;
  resource: CrmRealtimeResource;
  /** Optional monotonic hint (ISO updatedAt string or numeric revision). */
  revision: string | null;
  updatedAt: string;
  dedupeKey: string;
  occurredAt: string;
  /** Lightweight context — no message bodies / PII. */
  meta?: {
    eventId?: string;
    vendorId?: string;
    stage?: string;
    vendorRequestId?: string;
    changeType?: string;
  };
};

export function crmUserChannel(tenantId: string, userId: string): string {
  return `crm:${tenantId}:user:${userId}`;
}
