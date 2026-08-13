import { Body, Controller, Get, Param, Post, Query, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { OrganizerFinanceService } from './organizer-finance.service';
import { OrganizerPayoutService } from './organizer-payout.service';
import { TicketRefundService, type TicketRefundAction } from './ticket-refund.service';
import { FinanceExportService } from './finance-export.service';
import { CommerceAuthGuard } from './commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from './commerce-auth.service';

@Controller()
@Public()
@UseGuards(CommerceAuthGuard)
export class OrganizerFinanceController {
  constructor(
    private readonly finance: OrganizerFinanceService,
    private readonly payouts: OrganizerPayoutService,
    private readonly refunds: TicketRefundService,
    private readonly exports: FinanceExportService,
  ) {}

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('events/:eventId/finance/summary')
  async eventSummary(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.finance.getEventSummary(actor!, eventId);
  }

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('events/:eventId/finance/transactions')
  async eventTransactions(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
    @Query('limit') limit?: string,
  ) {
    const n = parseInt(limit ?? '100', 10) || 100;
    return this.finance.getEventTransactions(actor!, eventId, n);
  }

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('events/:eventId/finance/payouts')
  async eventPayouts(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.finance.listEventPayouts(actor!, eventId);
  }

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('events/:eventId/finance/refunds')
  async eventRefunds(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
    @Query('status') status?: string,
  ) {
    return this.refunds.listForEvent(actor!, eventId, status);
  }

  @Throttle({ strict: { limit: 40, ttl: 60_000 } })
  @Post('events/:eventId/finance/refunds')
  async createEventRefund(
    @Param('eventId') eventId: string,
    @Body() body: { ticketOrderId: string; amountMinor: string; reason?: string },
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.refunds.organizerCreateCase(
      actor!,
      eventId,
      body.ticketOrderId,
      body.amountMinor,
      body.reason ?? '',
    );
  }

  @Throttle({ strict: { limit: 40, ttl: 60_000 } })
  @Post('events/:eventId/finance/refunds/:caseId/:action')
  async actionEventRefund(
    @Param('eventId') eventId: string,
    @Param('caseId') caseId: string,
    @Param('action') action: TicketRefundAction,
    @Body() body: { note?: string },
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.refunds.organizerAction(actor!, eventId, caseId, action, body?.note);
  }

  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Get('events/:eventId/finance/export/:kind')
  async exportEventFinance(
    @Param('eventId') eventId: string,
    @Param('kind') kind: string,
    @CommerceActorParam() actor: CommerceActor,
    @Query('format') format?: string,
    @Res() res?: Response,
  ) {
    const out = await this.exports.exportForOrganizerEvent(
      actor!,
      eventId,
      kind,
      format === 'xlsx' ? 'xlsx' : 'csv',
    );
    res!.setHeader('Content-Type', out.contentType);
    res!.setHeader('Content-Disposition', `attachment; filename="${out.filename}"`);
    return res!.send(out.body);
  }

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('organizers/me/finance/hub')
  async organizerFinanceHub(@CommerceActorParam() actor: CommerceActor) {
    return this.finance.getOrganizerHub(actor!);
  }

  @Throttle({ strict: { limit: 40, ttl: 60_000 } })
  @Post('organizers/:organizerId/payouts')
  async requestPayout(
    @Param('organizerId') organizerId: string,
    @CommerceActorParam() actor: CommerceActor,
    @Query('amountMinor') amountMinor: string,
  ) {
    return this.payouts.requestPayout(actor!, organizerId, amountMinor);
  }
}
