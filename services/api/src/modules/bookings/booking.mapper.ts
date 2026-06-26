import type { BookingRow } from '../../ownership/booking-access.service';

export function mapBookingToApi(r: BookingRow & {
  package_name?: string;
  client_name?: string;
  event_id?: string;
  event_title?: string;
}) {
  return {
    id: r.id,
    tenantId: r.tenant_id,
    clientUserId: r.client_user_id,
    vendorId: r.vendor_id,
    packageId: r.package_id,
    status: r.status,
    currency: r.currency,
    guestCount: r.guest_count,
    eventStartsAt: r.event_starts_at.toISOString(),
    eventEndsAt: r.event_ends_at ? r.event_ends_at.toISOString() : null,
    locationText: r.location_text,
    clientNotes: r.client_notes,
    subtotalMinor: Number(r.subtotal_minor),
    platformFeeMinor: Number(r.platform_fee_minor),
    totalMinor: Number(r.total_minor),
    version: r.version,
    createdAt: r.created_at.toISOString(),
    packageName: r.package_name ?? null,
    clientName: r.client_name ?? null,
    eventId: r.event_id ?? null,
    eventTitle: r.event_title ?? null,
  };
}
