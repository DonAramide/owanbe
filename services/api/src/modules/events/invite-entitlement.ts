/**
 * Issue complimentary ticket entitlements for confirmed invitation RSVPs (Phase 15).
 * Reuses ticket_orders / ticket_order_lines / ticket_entitlements — no schema redesign.
 */
import { randomBytes } from 'crypto';
import type { PoolClient } from 'pg';

export type InviteEntitlementResult = {
  entitlementId: string;
  ticketCode: string;
  orderId: string;
};

export async function issueInvitationEntitlement(
  client: PoolClient,
  opts: {
    tenantId: string;
    eventId: string;
    organizerId: string;
    guestId: string;
    holderUserId: string;
    guestName: string;
    eventTitle: string;
  },
): Promise<InviteEntitlementResult | null> {
  const existing = await client.query<{ entitlement_ref: string | null }>(
    `SELECT entitlement_ref FROM event_guests
     WHERE id = $1 AND tenant_id = $2 FOR UPDATE`,
    [opts.guestId, opts.tenantId],
  );
  const ref = existing.rows[0]?.entitlement_ref;
  if (ref) {
    const ent = await client.query<{ id: string; ticket_code: string; ticket_order_id: string }>(
      `SELECT id, ticket_code, ticket_order_id FROM ticket_entitlements
       WHERE tenant_id = $1 AND id::text = $2 LIMIT 1`,
      [opts.tenantId, ref],
    );
    if (ent.rows[0]) {
      return {
        entitlementId: ent.rows[0].id,
        ticketCode: ent.rows[0].ticket_code,
        orderId: ent.rows[0].ticket_order_id,
      };
    }
  }

  // Idempotent: already issued for this guest via metadata on an order.
  const prior = await client.query<{
    id: string;
    ticket_code: string;
    ticket_order_id: string;
  }>(
    `SELECT te.id, te.ticket_code, te.ticket_order_id
     FROM ticket_entitlements te
     INNER JOIN ticket_orders o ON o.id = te.ticket_order_id
     WHERE te.tenant_id = $1 AND te.event_id = $2 AND te.holder_user_id = $3
       AND (o.metadata->>'invitationGuestId') = $4
     LIMIT 1`,
    [opts.tenantId, opts.eventId, opts.holderUserId, opts.guestId],
  );
  if (prior.rows[0]) {
    await client.query(
      `UPDATE event_guests SET entitlement_ref = $3, updated_at = now()
       WHERE id = $1 AND tenant_id = $2`,
      [opts.guestId, opts.tenantId, prior.rows[0].id],
    );
    return {
      entitlementId: prior.rows[0].id,
      ticketCode: prior.rows[0].ticket_code,
      orderId: prior.rows[0].ticket_order_id,
    };
  }

  const idem = `invite_${opts.guestId}_${opts.holderUserId}`;
  const existingOrder = await client.query<{ id: string }>(
    `SELECT id FROM ticket_orders WHERE tenant_id = $1 AND idempotency_key = $2`,
    [opts.tenantId, idem],
  );
  let orderId = existingOrder.rows[0]?.id;
  if (!orderId) {
    const ins = await client.query<{ id: string }>(
      `INSERT INTO ticket_orders (
         tenant_id, organizer_id, event_id, buyer_user_id, status, currency,
         subtotal_minor, platform_fee_minor, total_minor, idempotency_key, metadata,
         completed_at
       ) VALUES ($1, $2, $3, $4, 'fulfilled', 'NGN', 0, 0, 0, $5, $6::jsonb, now())
       RETURNING id`,
      [
        opts.tenantId,
        opts.organizerId,
        opts.eventId,
        opts.holderUserId,
        idem,
        JSON.stringify({
          freeOrder: true,
          invitationGuestId: opts.guestId,
          source: 'invitation',
          guestName: opts.guestName,
          eventTitle: opts.eventTitle,
        }),
      ],
    );
    orderId = ins.rows[0]!.id;
    await client.query(
      `INSERT INTO ticket_order_lines (
         tenant_id, ticket_order_id, tier_id, tier_name, tier_type,
         unit_price_minor, quantity, line_subtotal_minor, currency
       ) VALUES ($1, $2, $3, $4, 'complimentary', 0, 1, 0, 'NGN')`,
      [opts.tenantId, orderId, `invite_${opts.guestId}`, 'Invitation'],
    );
  }

  const line = await client.query<{ id: string }>(
    `SELECT id FROM ticket_order_lines WHERE ticket_order_id = $1 AND tenant_id = $2 LIMIT 1`,
    [orderId, opts.tenantId],
  );
  const lineId = line.rows[0]?.id;
  if (!lineId) return null;

  const existingEnt = await client.query<{ id: string; ticket_code: string }>(
    `SELECT id, ticket_code FROM ticket_entitlements
     WHERE tenant_id = $1 AND ticket_order_id = $2 LIMIT 1`,
    [opts.tenantId, orderId],
  );
  if (existingEnt.rows[0]) {
    await client.query(
      `UPDATE event_guests SET entitlement_ref = $3, updated_at = now()
       WHERE id = $1 AND tenant_id = $2`,
      [opts.guestId, opts.tenantId, existingEnt.rows[0].id],
    );
    return {
      entitlementId: existingEnt.rows[0].id,
      ticketCode: existingEnt.rows[0].ticket_code,
      orderId,
    };
  }

  const ticketCode = `INV-${randomBytes(6).toString('hex').toUpperCase()}`;
  const qrPayload = `OWANBE:${opts.eventId}:invitation:${ticketCode}`;
  const entIns = await client.query<{ id: string }>(
    `INSERT INTO ticket_entitlements (
       tenant_id, ticket_order_id, ticket_order_line_id, event_id, holder_user_id,
       ticket_code, status, metadata
     ) VALUES ($1, $2, $3, $4, $5, $6, 'issued', $7::jsonb)
     RETURNING id`,
    [
      opts.tenantId,
      orderId,
      lineId,
      opts.eventId,
      opts.holderUserId,
      ticketCode,
      JSON.stringify({
        qr_payload: qrPayload,
        tier_name: 'Invitation',
        source: 'invitation',
        guestId: opts.guestId,
        guestName: opts.guestName,
      }),
    ],
  );
  const entitlementId = entIns.rows[0]!.id;
  await client.query(
    `UPDATE event_guests
     SET entitlement_ref = $3,
         metadata = COALESCE(metadata, '{}'::jsonb) || $4::jsonb,
         updated_at = now()
     WHERE id = $1 AND tenant_id = $2`,
    [
      opts.guestId,
      opts.tenantId,
      entitlementId,
      JSON.stringify({ pendingEntitlement: false, entitlementIssuedAt: new Date().toISOString() }),
    ],
  );

  return { entitlementId, ticketCode, orderId };
}

export async function resolveUserIdByEmail(
  client: PoolClient,
  tenantId: string,
  email: string | null | undefined,
): Promise<string | null> {
  const normalized = (email ?? '').trim().toLowerCase();
  if (!normalized.includes('@')) return null;
  const { rows } = await client.query<{ id: string }>(
    `SELECT id FROM users WHERE tenant_id = $1 AND lower(email) = $2 LIMIT 1`,
    [tenantId, normalized],
  );
  return rows[0]?.id ?? null;
}
