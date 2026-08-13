export const DOMAIN_EVENTS = {
  TICKET_ISSUED: 'ticket.issued',
  RSVP_CHANGED: 'rsvp.changed',
  VENDOR_STAGE_CHANGED: 'vendor.stage_changed',
  REFUND_COMPLETED: 'refund.completed',
  REPORT_GENERATED: 'report.generated',
  SCHEDULE_TICK: 'schedule.tick',
} as const;

export type DomainEventName = (typeof DOMAIN_EVENTS)[keyof typeof DOMAIN_EVENTS];

export type DomainEventPayload = {
  tenantId: string;
  organizerId?: string | null;
  eventId?: string | null;
  entityId?: string | null;
  actorUserId?: string | null;
  data?: Record<string, unknown>;
  occurredAt?: string;
};

export type DomainEvent = {
  name: DomainEventName | string;
  payload: DomainEventPayload;
};
