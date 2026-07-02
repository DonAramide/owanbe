import { Injectable, Inject, NotFoundException, ForbiddenException } from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from '../events/events-access.service';

export type NegotiationState =
  | 'created'
  | 'open'
  | 'negotiating'
  | 'counter_offer'
  | 'waiting_vendor_confirmation'
  | 'waiting_organizer_confirmation'
  | 'agreed'
  | 'payment_pending'
  | 'payment_received'
  | 'escrowed'
  | 'work_started'
  | 'completed'
  | 'closed';

const ALLOWED_TRANSITIONS: Record<NegotiationState, NegotiationState[]> = {
  created: ['open', 'closed'],
  open: ['negotiating', 'closed'],
  negotiating: ['counter_offer', 'waiting_vendor_confirmation', 'waiting_organizer_confirmation', 'closed'],
  counter_offer: ['negotiating', 'waiting_vendor_confirmation', 'waiting_organizer_confirmation', 'closed'],
  waiting_vendor_confirmation: ['agreed', 'negotiating', 'closed'],
  waiting_organizer_confirmation: ['agreed', 'negotiating', 'closed'],
  agreed: ['payment_pending', 'closed'],
  payment_pending: ['payment_received', 'closed'],
  payment_received: ['escrowed', 'closed'],
  escrowed: ['work_started', 'closed'],
  work_started: ['completed', 'closed'],
  completed: ['closed'],
  closed: [],
};

@Injectable()
export class VendorNegotiationsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
  ) {}

  validateTransition(current: NegotiationState, target: NegotiationState): void {
    const allowed = ALLOWED_TRANSITIONS[current] || [];
    if (!allowed.includes(target)) {
      throw new ForbiddenException({
        code: 'ILLEGAL_STATE_TRANSITION',
        message: `Illegal state transition from "${current}" to "${target}"`,
      });
    }
  }

  // Parses prices out of text messages
  parsePriceProposal(text: string): number | null {
    // 250k, ₦250,000, 250000
    const moneyRegex = /(?:₦|\b)(\d+[\d,]*)(?:\s*k|\b)/gi;
    const match = moneyRegex.exec(text);
    if (!match) return null;

    let valueStr = match[1]!.replace(/,/g, '');
    let value = parseFloat(valueStr);
    if (text.toLowerCase().includes(match[1]!.toLowerCase() + 'k')) {
      value = value * 1000;
    }
    return Math.round(value * 100); // return in minor units (kobo)
  }

  // Scans for fraud phrases like WhatsApp redirection or external bank transfers
  scanForFraud(text: string): { flagged: boolean; reason: string[] } {
    const fraudRegex = /(gtbank|opay|whatsapp|call me|bank transfer|send directly|whatsapp me)/i;
    const flagged = fraudRegex.test(text);
    return {
      flagged,
      reason: flagged ? ['Detected off-platform redirect request or custom banking terms'] : [],
    };
  }

  calculateAgreementConfidence(text: string, latestPrice: number | null): { confidence: number; reasons: string[] } {
    const reasons: string[] = [];
    let confidence = 0;

    if (latestPrice !== null) {
      confidence += 50;
      reasons.push('Valid price proposal detected');
    }

    const agreeKeywords = /(deal|agreed|accepted|okay|let's proceed|confirmed)/i;
    if (agreeKeywords.test(text)) {
      confidence += 48;
      reasons.push('Consensus confirmation phrase matched');
    }

    return { confidence, reasons };
  }

  async listForEvent(actor: CommerceActor, eventKey: string) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const { rows } = await this.pool.query<{
      id: string;
      vendor_id: string;
      state: string;
      risk_score: string;
      created_at: Date;
    }>(
      `SELECT id, vendor_id, state::text, risk_score::text, created_at
       FROM negotiation_sessions WHERE tenant_id = $1 AND event_id = $2 ORDER BY created_at DESC`,
      [actor.tenantId, event.id],
    );

    const items = [];
    for (const row of rows) {
      const offers = await this.loadOffers(row.id);
      items.push({
        id: row.id,
        vendorId: row.vendor_id,
        status: row.state,
        riskScore: row.risk_score,
        createdAt: row.created_at.toISOString(),
        offers,
      });
    }
    return { items };
  }

  async createRequest(actor: CommerceActor, eventKey: string, body: Record<string, unknown>) {
    const event = await this.access.assertOrganizerOwnsEvent(actor.tenantId, actor.userId, eventKey);
    const organizerId = await this.access.resolveOrganizerId(actor.tenantId, actor.userId);
    const vendorId = String(body.vendorId ?? '').trim();
    if (!vendorId) throw new NotFoundException({ code: 'VENDOR_REQUIRED' });
    const amountMinor = Number(body.amountMinor ?? '0');

    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO negotiation_sessions (tenant_id, event_id, vendor_id, organizer_id, state)
       VALUES ($1, $2, $3, $4, 'open') RETURNING id`,
      [actor.tenantId, event.id, vendorId, organizerId],
    );
    const sessionId = rows[0]!.id;

    await this.insertOffer(sessionId, 1, amountMinor, actor.userId, 'pending');
    await this.insertMessage(sessionId, actor.userId, vendorId, String(body.message ?? ''));

    return this.getNegotiation(actor.tenantId, sessionId);
  }

  async counterOffer(
    actor: CommerceActor,
    sessionId: string,
    body: Record<string, unknown>,
    actorType: 'organizer' | 'vendor',
  ) {
    const session = await this.getNegotiationRow(actor.tenantId, sessionId);
    this.validateTransition(session.state as NegotiationState, 'negotiating');

    const amountMinor = Number(body.amountMinor ?? '0');
    const msgText = String(body.message ?? '');

    // Auto-update to negotiating/counter_offer
    await this.pool.query(
      `UPDATE negotiation_sessions SET state = 'negotiating', updated_at = now() WHERE id = $1`,
      [sessionId],
    );

    // Save message with audit-trail features
    await this.insertMessage(sessionId, actor.userId, actor.userId, msgText);

    // Parse potential price/offers
    const parsedPrice = this.parsePriceProposal(msgText);
    const targetPrice = parsedPrice !== null ? parsedPrice : amountMinor;

    const { rows } = await this.pool.query<{ count: number }>(
      `SELECT count(*)::int FROM negotiation_offers WHERE session_id = $1`,
      [sessionId],
    );
    const nextVer = (rows[0]?.count ?? 0) + 1;

    await this.insertOffer(sessionId, nextVer, targetPrice, actor.userId, 'pending');

    return this.getNegotiation(actor.tenantId, sessionId);
  }

  async respondToOffer(
    actor: CommerceActor,
    sessionId: string,
    offerId: string,
    body: Record<string, unknown>,
  ) {
    const action = String(body.action ?? '');
    const session = await this.getNegotiationRow(actor.tenantId, sessionId);

    if (action === 'accept') {
      const nextState = actor.userId === session.organizer_id
        ? 'waiting_vendor_confirmation'
        : 'waiting_organizer_confirmation';
      
      this.validateTransition(session.state as NegotiationState, nextState);
      
      await this.pool.query(`UPDATE negotiation_offers SET status = 'accepted' WHERE id = $1`, [offerId]);
      await this.pool.query(
        `UPDATE negotiation_sessions SET state = $1::negotiation_session_state, updated_at = now() WHERE id = $2`,
        [nextState, sessionId],
      );
      
      // Track confirmation locks
      await this.pool.query(
        `INSERT INTO negotiation_confirmations (session_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
        [sessionId, actor.userId],
      );
    }
    
    return this.getNegotiation(actor.tenantId, sessionId);
  }

  private async getNegotiationRow(tenantId: string, id: string) {
    const { rows } = await this.pool.query<{ id: string; state: string; organizer_id: string; vendor_id: string }>(
      `SELECT id, state::text, organizer_id::text, vendor_id::text FROM negotiation_sessions WHERE tenant_id = $1 AND id = $2`,
      [tenantId, id],
    );
    if (!rows.length) throw new NotFoundException({ code: 'NEGOTIATION_NOT_FOUND' });
    return rows[0]!;
  }

  private async getNegotiation(tenantId: string, id: string) {
    const session = await this.getNegotiationRow(tenantId, id);
    const offers = await this.loadOffers(id);
    return { id: session.id, status: session.state, offers };
  }

  private async loadOffers(sessionId: string) {
    const { rows } = await this.pool.query<{
      id: string;
      offer_number: number;
      amount_minor: string;
      proposed_by: string;
      status: string;
      created_at: Date;
    }>(
      `SELECT id, offer_number, amount_minor::text, proposed_by::text, status, created_at
       FROM negotiation_offers WHERE session_id = $1 ORDER BY created_at ASC`,
      [sessionId],
    );
    return rows.map((o) => ({
      id: o.id,
      offerNumber: o.offer_number,
      amountMinor: o.amount_minor,
      proposedBy: o.proposed_by,
      status: o.status,
      createdAt: o.created_at.toISOString(),
    }));
  }

  private async insertOffer(
    sessionId: string,
    offerNumber: number,
    amountMinor: number,
    proposedBy: string,
    status: string,
  ) {
    await this.pool.query(
      `INSERT INTO negotiation_offers (session_id, offer_number, amount_minor, proposed_by, status)
       VALUES ($1, $2, $3::bigint, $4, $5)`,
      [sessionId, offerNumber, amountMinor, proposedBy, status],
    );
  }

  private async insertMessage(sessionId: string, senderId: string, receiverId: string, text: string) {
    const fraud = this.scanForFraud(text);
    if (fraud.flagged) {
      await this.pool.query(
        `UPDATE negotiation_sessions SET risk_score = 'high' WHERE id = $1`,
        [sessionId],
      );
    }

    await this.pool.query(
      `INSERT INTO negotiation_messages (session_id, sender_id, receiver_id, message_text, original_text)
       VALUES ($1, $2, $3, $4, $4)`,
      [sessionId, senderId, receiverId, text],
    );
  }
}
