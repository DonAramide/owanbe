import {
  BadRequestException,
  Injectable,
  Inject,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { EnvVars } from '../../config/env.schema';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from '../events/events-access.service';
import { NotificationService } from '../../integrations/notifications/notification.service';
import { EmailService } from '../../integrations/email-infrastructure/email.service';
import { MessagingProvidersService } from '../../integrations/hub/messaging-providers.service';

export type AudienceSegment =
  | 'all_guests'
  | 'rsvp_confirmed'
  | 'rsvp_pending'
  | 'rsvp_declined'
  | 'ticket_buyers'
  | 'attendees_checked_in';

export type MarketingChannel = 'email' | 'sms' | 'whatsapp';

type AudienceMember = {
  recipient: string;
  displayName: string;
  sourceKind: 'guest' | 'buyer' | 'attendee' | 'unknown';
  sourceId: string | null;
};

/**
 * Phase 26 — Marketing consumer layer.
 * Audiences are read models over guests/buyers/entitlements.
 * Delivery goes only through NotificationService / messaging adapters.
 */
@Injectable()
export class OrganizerMarketingService {
  private readonly logger = new Logger(OrganizerMarketingService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
    private readonly notifications: NotificationService,
    private readonly email: EmailService,
    private readonly messaging: MessagingProvidersService,
    private readonly config: ConfigService<EnvVars, true>,
  ) {}

  async channelAvailability(tenantId?: string) {
    const emailOk = await this.email.hasConfiguredProvider();
    const smsDb = await this.messaging.resolveActive('sms', tenantId);
    const smsEnv = !!(this.config.get('TWILIO_ACCOUNT_SID', { infer: true }) ?? '').trim();
    const wa = await this.messaging.resolveActive('whatsapp', tenantId);
    return {
      email: {
        available: emailOk,
        reason: emailOk ? null : 'Configure Super Admin → Enterprise Email',
      },
      sms: {
        available: !!(smsDb || smsEnv),
        reason: smsDb || smsEnv ? null : 'Configure Twilio SMS (messaging provider or TWILIO_* env)',
      },
      whatsapp: {
        available: !!wa,
        reason: wa ? null : 'WhatsApp foundation — credentials not configured',
      },
    };
  }

  async listAudienceSegments() {
    return [
      { id: 'all_guests', label: 'All guests', source: 'event_guests' },
      { id: 'rsvp_confirmed', label: 'RSVP confirmed', source: 'event_guests' },
      { id: 'rsvp_pending', label: 'RSVP pending / invited', source: 'event_guests' },
      { id: 'rsvp_declined', label: 'RSVP declined', source: 'event_guests' },
      { id: 'ticket_buyers', label: 'Ticket buyers', source: 'ticket_orders' },
      { id: 'attendees_checked_in', label: 'Checked-in attendees', source: 'ticket_entitlements' },
    ];
  }

  async previewAudience(
    actor: CommerceActor,
    params: { eventId: string; segment: AudienceSegment; channel: MarketingChannel },
  ) {
    await this.access.assertEventCapability(
      actor.tenantId,
      actor.userId,
      params.eventId,
      'marketing.manage',
    );
    const members = await this.resolveAudience(
      actor.tenantId,
      params.eventId,
      params.segment,
      params.channel,
    );
    return {
      segment: params.segment,
      channel: params.channel,
      count: members.length,
      sample: members.slice(0, 25),
    };
  }

  async listCampaigns(actor: CommerceActor, eventId?: string) {
    const organizerId = await this.access.resolveOrganizerId(actor.tenantId, actor.userId);
    await this.access.assertOrgCapability(
      actor.tenantId,
      actor.userId,
      organizerId,
      'marketing.manage',
    );
    if (eventId) {
      await this.access.assertEventCapability(
        actor.tenantId,
        actor.userId,
        eventId,
        'marketing.manage',
      );
    }
    const { rows } = await this.pool.query(
      `SELECT c.*, e.title AS event_title
       FROM marketing_campaigns c
       LEFT JOIN events e ON e.id = c.event_id
       WHERE c.tenant_id = $1 AND c.organizer_id = $2
         AND ($3::uuid IS NULL OR c.event_id = $3::uuid)
       ORDER BY c.created_at DESC
       LIMIT 100`,
      [actor.tenantId, organizerId, eventId ?? null],
    );
    return { organizerId, items: rows.map((r) => this.mapCampaign(r)) };
  }

  async getCampaign(actor: CommerceActor, campaignId: string) {
    const campaign = await this.loadCampaign(actor, campaignId);
    const engagement = await this.engagementForCampaign(campaign.id);
    const conversion = await this.conversionForCampaign(actor, campaign);
    const { rows: recipients } = await this.pool.query(
      `SELECT id, recipient, display_name, source_kind, delivery_status, notification_id, created_at
       FROM marketing_campaign_recipients
       WHERE campaign_id = $1::uuid
       ORDER BY created_at DESC
       LIMIT 100`,
      [campaignId],
    );
    return {
      campaign,
      engagement,
      conversion,
      recipients: recipients.map((r) => ({
        id: r.id,
        recipient: r.recipient,
        displayName: r.display_name,
        sourceKind: r.source_kind,
        deliveryStatus: r.delivery_status,
        notificationId: r.notification_id,
        createdAt: r.created_at,
      })),
    };
  }

  async createCampaign(
    actor: CommerceActor,
    body: {
      eventId?: string;
      name: string;
      channel?: MarketingChannel;
      audienceSegment?: AudienceSegment;
      subject?: string;
      body?: string;
    },
  ) {
    const organizerId = await this.access.resolveOrganizerId(actor.tenantId, actor.userId);
    await this.access.assertOrgCapability(
      actor.tenantId,
      actor.userId,
      organizerId,
      'marketing.manage',
    );
    let eventId: string | null = null;
    if (body.eventId) {
      const event = await this.access.assertEventCapability(
        actor.tenantId,
        actor.userId,
        body.eventId,
        'marketing.manage',
      );
      eventId = event.id;
    }
    const channel = (body.channel ?? 'email') as MarketingChannel;
    if (!['email', 'sms', 'whatsapp'].includes(channel)) {
      throw new BadRequestException('channel must be email, sms, or whatsapp');
    }
    const segment = (body.audienceSegment ?? 'all_guests') as AudienceSegment;
    const name = (body.name ?? '').trim();
    if (!name) throw new BadRequestException('name required');

    const { rows } = await this.pool.query(
      `INSERT INTO marketing_campaigns
         (tenant_id, organizer_id, event_id, name, channel, audience_segment, subject, body, created_by)
       VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, $6, $7, $8, $9::uuid)
       RETURNING *`,
      [
        actor.tenantId,
        organizerId,
        eventId,
        name,
        channel,
        segment,
        body.subject ?? null,
        body.body ?? '',
        actor.userId,
      ],
    );
    return this.mapCampaign(rows[0]);
  }

  async sendCampaign(actor: CommerceActor, campaignId: string) {
    const campaign = await this.loadCampaign(actor, campaignId);
    if (campaign.status === 'sending') {
      throw new BadRequestException('Campaign already sending');
    }
    if (!campaign.eventId) {
      throw new BadRequestException('Campaign requires an event for audience resolution');
    }

    const availability = await this.channelAvailability(actor.tenantId);
    const ch = campaign.channel as MarketingChannel;
    if (!availability[ch]?.available) {
      throw new BadRequestException({
        code: 'CHANNEL_UNAVAILABLE',
        message: availability[ch]?.reason ?? `${ch} unavailable`,
      });
    }

    const members = await this.resolveAudience(
      actor.tenantId,
      campaign.eventId,
      campaign.audienceSegment as AudienceSegment,
      ch,
    );
    if (!members.length) {
      throw new BadRequestException('Audience resolved to zero recipients for this channel');
    }

    const capped = members.slice(0, 200);
    await this.pool.query(
      `UPDATE marketing_campaigns
       SET status = 'sending', recipient_count = $2, updated_at = now(), last_error = NULL
       WHERE id = $1::uuid`,
      [campaignId, capped.length],
    );

    let sent = 0;
    let failed = 0;
    let skipped = 0;

    for (const m of capped) {
      try {
        const result = await this.deliverOne(actor.tenantId, campaign, m);
        await this.pool.query(
          `INSERT INTO marketing_campaign_recipients
             (campaign_id, tenant_id, recipient, display_name, source_kind, source_id, notification_id, delivery_status)
           VALUES ($1::uuid, $2::uuid, $3, $4, $5, $6, $7, $8)`,
          [
            campaignId,
            actor.tenantId,
            m.recipient,
            m.displayName,
            m.sourceKind,
            m.sourceId,
            result.deliveryId ?? null,
            result.ok ? 'sent' : 'failed',
          ],
        );
        if (result.ok) sent += 1;
        else failed += 1;
      } catch (err) {
        failed += 1;
        this.logger.warn(`Campaign recipient failed: ${(err as Error).message}`);
      }
    }
    skipped = Math.max(0, members.length - capped.length);

    const finalStatus = failed > 0 && sent === 0 ? 'failed' : 'sent';
    await this.pool.query(
      `UPDATE marketing_campaigns
       SET status = $2, sent_count = $3, failed_count = $4, skipped_count = $5,
           sent_at = now(), updated_at = now(),
           last_error = CASE WHEN $4 > 0 THEN 'Some deliveries failed — see recipients' ELSE NULL END
       WHERE id = $1::uuid`,
      [campaignId, finalStatus, sent, failed, skipped],
    );

    return this.getCampaign(actor, campaignId);
  }

  async marketingReportCsv(actor: CommerceActor, eventId?: string) {
    const { items } = await this.listCampaigns(actor, eventId);
    const lines = [
      'campaign_id,name,event_id,status,channel,audience_segment,recipients,sent,failed,skipped,sent_at',
      ...items.map((c) =>
        [
          c.id,
          this.csv(c.name),
          c.eventId ?? '',
          c.status,
          c.channel,
          c.audienceSegment,
          c.recipientCount,
          c.sentCount,
          c.failedCount,
          c.skippedCount,
          c.sentAt ?? '',
        ].join(','),
      ),
    ];
    const stamp = new Date().toISOString().slice(0, 10);
    return {
      filename: `marketing-campaigns-${stamp}.csv`,
      contentType: 'text/csv; charset=utf-8',
      body: lines.join('\n'),
    };
  }

  private async deliverOne(
    tenantId: string,
    campaign: ReturnType<OrganizerMarketingService['mapCampaign']>,
    member: AudienceMember,
  ): Promise<{ ok: boolean; deliveryId?: string; reason?: string }> {
    if (campaign.channel === 'whatsapp') {
      const result = await this.messaging.sendWhatsApp({
        tenantId,
        to: member.recipient,
        body: campaign.body || campaign.name,
      });
      return { ok: result.ok, deliveryId: result.externalId, reason: result.reason };
    }

    const channel = campaign.channel === 'sms' ? 'sms' : 'email';
    return this.notifications.send({
      tenantId,
      channel,
      template: 'marketing_campaign',
      recipient: member.recipient,
      subject: campaign.subject ?? campaign.name,
      body:
        campaign.body ||
        `<p>${campaign.name}</p><p>You are receiving this message about an Owambe event.</p>`,
      metadata: {
        campaignId: campaign.id,
        source: 'marketing',
        audienceSegment: campaign.audienceSegment,
        eventId: campaign.eventId,
      },
    });
  }

  private async resolveAudience(
    tenantId: string,
    eventKey: string,
    segment: AudienceSegment,
    channel: MarketingChannel,
  ): Promise<AudienceMember[]> {
    const event = await this.access.resolveEventRow(tenantId, eventKey);
    const eventId = event.id;
    const preferPhone = channel === 'sms' || channel === 'whatsapp';

    if (
      segment === 'all_guests' ||
      segment === 'rsvp_confirmed' ||
      segment === 'rsvp_pending' ||
      segment === 'rsvp_declined'
    ) {
      let rsvpFilter = '';
      if (segment === 'rsvp_confirmed') rsvpFilter = `AND g.rsvp_status::text = 'confirmed'`;
      if (segment === 'rsvp_declined') rsvpFilter = `AND g.rsvp_status::text = 'declined'`;
      if (segment === 'rsvp_pending') {
        rsvpFilter = `AND g.rsvp_status::text IN ('invited', 'pending')`;
      }
      const { rows } = await this.pool.query<{
        id: string;
        name: string;
        email: string | null;
        phone_e164: string | null;
      }>(
        `SELECT g.id::text, g.name, g.email, g.phone_e164
         FROM event_guests g
         WHERE g.tenant_id = $1 AND g.event_id = $2
         ${rsvpFilter}
         ORDER BY g.created_at DESC
         LIMIT 500`,
        [tenantId, eventId],
      );
      return this.dedupeMembers(
        rows.map((r) => {
          const recipient = preferPhone
            ? (r.phone_e164 || r.email || '').trim()
            : (r.email || r.phone_e164 || '').trim();
          return {
            recipient,
            displayName: r.name,
            sourceKind: 'guest' as const,
            sourceId: r.id,
          };
        }),
      );
    }

    if (segment === 'ticket_buyers') {
      const { rows } = await this.pool.query<{
        order_id: string;
        email: string | null;
        name: string | null;
      }>(
        `SELECT o.id::text AS order_id, u.email, COALESCE(u.display_name, u.email) AS name
         FROM ticket_orders o
         LEFT JOIN users u ON u.id = o.buyer_user_id
         WHERE o.tenant_id = $1 AND o.event_id = $2
           AND o.status::text IN ('fulfilled', 'confirmed')
         ORDER BY o.created_at DESC
         LIMIT 500`,
        [tenantId, eventId],
      );
      if (preferPhone) {
        // Buyers are email-primary; SMS/WhatsApp unavailable for buyer segment without phone
        return [];
      }
      return this.dedupeMembers(
        rows
          .filter((r) => (r.email ?? '').trim())
          .map((r) => ({
            recipient: (r.email ?? '').trim(),
            displayName: (r.name ?? r.email ?? 'Buyer').trim(),
            sourceKind: 'buyer' as const,
            sourceId: r.order_id,
          })),
      );
    }

    if (segment === 'attendees_checked_in') {
      const { rows } = await this.pool.query<{
        entitlement_id: string;
        email: string | null;
        name: string | null;
      }>(
        `SELECT te.id::text AS entitlement_id, u.email, COALESCE(u.display_name, u.email) AS name
         FROM ticket_entitlements te
         LEFT JOIN users u ON u.id = te.holder_user_id
         WHERE te.tenant_id = $1 AND te.event_id = $2
           AND te.status::text = 'checked_in'
         ORDER BY te.checked_in_at DESC NULLS LAST, te.issued_at DESC
         LIMIT 500`,
        [tenantId, eventId],
      );
      if (preferPhone) return [];
      return this.dedupeMembers(
        rows
          .filter((r) => (r.email ?? '').trim())
          .map((r) => ({
            recipient: (r.email ?? '').trim(),
            displayName: (r.name ?? r.email ?? 'Attendee').trim(),
            sourceKind: 'attendee' as const,
            sourceId: r.entitlement_id,
          })),
      );
    }

    throw new BadRequestException(`Unknown audience segment: ${segment}`);
  }

  private dedupeMembers(members: AudienceMember[]): AudienceMember[] {
    const seen = new Set<string>();
    const out: AudienceMember[] = [];
    for (const m of members) {
      const key = m.recipient.toLowerCase();
      if (!key || seen.has(key)) continue;
      seen.add(key);
      out.push(m);
    }
    return out;
  }

  private async engagementForCampaign(campaignId: string) {
    const { rows } = await this.pool.query<{ status: string; n: string }>(
      `SELECT delivery_status AS status, COUNT(*)::text AS n
       FROM marketing_campaign_recipients
       WHERE campaign_id = $1::uuid
       GROUP BY delivery_status`,
      [campaignId],
    );
    const byStatus = Object.fromEntries(rows.map((r) => [r.status, parseInt(r.n, 10)]));

    // Reuse notification_deliveries when metadata.campaignId present
    const { rows: nd } = await this.pool.query<{ status: string; n: string }>(
      `SELECT status, COUNT(*)::text AS n
       FROM notification_deliveries
       WHERE metadata->>'campaignId' = $1
       GROUP BY status`,
      [campaignId],
    ).catch(() => ({ rows: [] as { status: string; n: string }[] }));

    return {
      recipientByStatus: byStatus,
      notificationByStatus: Object.fromEntries(nd.map((r) => [r.status, parseInt(r.n, 10)])),
      sent: (byStatus.sent ?? 0) + (byStatus.delivered ?? 0),
      failed: byStatus.failed ?? 0,
      queued: byStatus.queued ?? 0,
    };
  }

  private async conversionForCampaign(
    actor: CommerceActor,
    campaign: ReturnType<OrganizerMarketingService['mapCampaign']>,
  ) {
    if (!campaign.eventId || !campaign.sentAt) {
      return {
        available: false,
        reason: 'Conversion available after campaign send on an event',
        ticketsSoldAfter: null,
        rsvpConfirmedAfter: null,
        note: 'Read-only window after send — not attributed causation',
      };
    }

    const { rows: tickets } = await this.pool.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n
       FROM ticket_entitlements te
       WHERE te.tenant_id = $1 AND te.event_id = $2
         AND te.status::text IN ('issued', 'checked_in')
         AND te.issued_at >= $3::timestamptz`,
      [actor.tenantId, campaign.eventId, campaign.sentAt],
    );
    const { rows: rsvps } = await this.pool.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n
       FROM event_guests g
       WHERE g.tenant_id = $1 AND g.event_id = $2
         AND g.rsvp_status::text = 'confirmed'
         AND g.updated_at >= $3::timestamptz`,
      [actor.tenantId, campaign.eventId, campaign.sentAt],
    );

    return {
      available: true,
      reason: null,
      ticketsSoldAfter: parseInt(tickets[0]?.n ?? '0', 10),
      rsvpConfirmedAfter: parseInt(rsvps[0]?.n ?? '0', 10),
      windowStart: campaign.sentAt,
      note: 'Post-send activity on the same event (correlation, not multi-touch attribution)',
      monetarySource: 'not_applicable',
    };
  }

  private async loadCampaign(actor: CommerceActor, campaignId: string) {
    const organizerId = await this.access.resolveOrganizerId(actor.tenantId, actor.userId);
    await this.access.assertOrgCapability(
      actor.tenantId,
      actor.userId,
      organizerId,
      'marketing.manage',
    );
    const { rows } = await this.pool.query(
      `SELECT c.*, e.title AS event_title
       FROM marketing_campaigns c
       LEFT JOIN events e ON e.id = c.event_id
       WHERE c.id = $1::uuid AND c.tenant_id = $2 AND c.organizer_id = $3`,
      [campaignId, actor.tenantId, organizerId],
    );
    if (!rows[0]) throw new NotFoundException('Campaign not found');
    return this.mapCampaign(rows[0]);
  }

  private mapCampaign(r: Record<string, unknown>) {
    return {
      id: r.id as string,
      tenantId: r.tenant_id as string,
      organizerId: r.organizer_id as string,
      eventId: (r.event_id as string | null) ?? null,
      eventTitle: (r.event_title as string | null) ?? null,
      name: r.name as string,
      status: r.status as string,
      channel: r.channel as string,
      audienceSegment: r.audience_segment as string,
      subject: (r.subject as string | null) ?? null,
      body: (r.body as string) ?? '',
      recipientCount: Number(r.recipient_count ?? 0),
      sentCount: Number(r.sent_count ?? 0),
      failedCount: Number(r.failed_count ?? 0),
      skippedCount: Number(r.skipped_count ?? 0),
      lastError: (r.last_error as string | null) ?? null,
      sentAt: r.sent_at ? new Date(r.sent_at as string).toISOString() : null,
      createdAt: r.created_at ? new Date(r.created_at as string).toISOString() : null,
      updatedAt: r.updated_at ? new Date(r.updated_at as string).toISOString() : null,
    };
  }

  private csv(value: string): string {
    if (value.includes(',') || value.includes('"') || value.includes('\n')) {
      return `"${value.replace(/"/g, '""')}"`;
    }
    return value;
  }
}
