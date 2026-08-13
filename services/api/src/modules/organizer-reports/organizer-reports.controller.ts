import { Controller, Get, Param, Query, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { CommerceAuthGuard } from '../commerce/commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from '../commerce/commerce-auth.service';
import { OrganizerReportsService } from './organizer-reports.service';
import { DomainEventsService } from '../domain-events/domain-events.service';
import { DOMAIN_EVENTS } from '../domain-events/domain-event.types';
import { EventsAccessService } from '../events/events-access.service';

@Controller()
@Public()
@UseGuards(CommerceAuthGuard)
export class OrganizerReportsController {
  constructor(
    private readonly reports: OrganizerReportsService,
    private readonly domainEvents: DomainEventsService,
    private readonly access: EventsAccessService,
  ) {}

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('events/:eventId/reports/catalog')
  async eventCatalog(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    await this.access.assertEventCapability(actor!.tenantId, actor!.userId, eventId, 'reports.read');
    return { items: this.reports.catalogForEvent() };
  }

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('organizers/me/reports/catalog')
  async portfolioCatalog(@CommerceActorParam() actor: CommerceActor) {
    const organizerId = await this.access.resolveOrganizerId(actor!.tenantId, actor!.userId);
    await this.access.assertOrgCapability(actor!.tenantId, actor!.userId, organizerId, 'reports.read');
    return { items: this.reports.catalogPortfolio() };
  }

  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Get('events/:eventId/reports/export/:pack')
  async exportEventPack(
    @Param('eventId') eventId: string,
    @Param('pack') pack: string,
    @CommerceActorParam() actor: CommerceActor,
    @Query('format') format?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('ticketType') ticketType?: string,
    @Query('vendorId') vendorId?: string,
    @Query('vendorStage') vendorStage?: string,
    @Query('guestStatus') guestStatus?: string,
    @Query('days') days?: string,
    @Res() res?: Response,
  ) {
    await this.access.assertEventCapability(actor!.tenantId, actor!.userId, eventId, 'reports.read');
    const out = await this.reports.exportEventPack(
      actor!,
      eventId,
      pack,
      format === 'xlsx' ? 'xlsx' : 'csv',
      {
        from,
        to,
        ticketType,
        vendorId,
        vendorStage,
        guestStatus,
        days: days ? parseInt(days, 10) || undefined : undefined,
      },
    );
    try {
      const organizerId = await this.access.resolveOrganizerId(actor!.tenantId, actor!.userId);
      this.domainEvents.emit(DOMAIN_EVENTS.REPORT_GENERATED, {
        tenantId: actor!.tenantId,
        organizerId,
        eventId,
        entityId: out.filename,
        actorUserId: actor!.userId,
        data: { pack, filename: out.filename, summary: `Report generated: ${pack}` },
      });
    } catch {
      /* non-blocking */
    }
    res!.setHeader('Content-Type', out.contentType);
    res!.setHeader('Content-Disposition', `attachment; filename="${out.filename}"`);
    return res!.send(out.body);
  }

  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Get('organizers/me/reports/export/portfolio')
  async exportPortfolio(
    @CommerceActorParam() actor: CommerceActor,
    @Query('format') format?: string,
    @Query('pack') pack?: string,
    @Res() res?: Response,
  ) {
    const organizerId = await this.access.resolveOrganizerId(actor!.tenantId, actor!.userId);
    await this.access.assertOrgCapability(actor!.tenantId, actor!.userId, organizerId, 'reports.read');
    const out =
      pack === 'marketing'
        ? await this.reports.exportMarketingPortfolio(actor!)
        : await this.reports.exportPortfolio(actor!, format === 'xlsx' ? 'xlsx' : 'csv');
    try {
      this.domainEvents.emit(DOMAIN_EVENTS.REPORT_GENERATED, {
        tenantId: actor!.tenantId,
        organizerId,
        entityId: out.filename,
        actorUserId: actor!.userId,
        data: {
          pack: pack === 'marketing' ? 'marketing' : 'portfolio',
          filename: out.filename,
          summary: 'Portfolio report generated',
        },
      });
    } catch {
      /* non-blocking */
    }
    res!.setHeader('Content-Type', out.contentType);
    res!.setHeader('Content-Disposition', `attachment; filename="${out.filename}"`);
    return res!.send(out.body);
  }
}
