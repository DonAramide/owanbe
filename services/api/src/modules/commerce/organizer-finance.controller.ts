import { Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { OrganizerFinanceService } from './organizer-finance.service';
import { OrganizerPayoutService } from './organizer-payout.service';
import { CommerceAuthGuard } from './commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from './commerce-auth.service';

@Controller()
@Public()
@UseGuards(CommerceAuthGuard)
export class OrganizerFinanceController {
  constructor(
    private readonly finance: OrganizerFinanceService,
    private readonly payouts: OrganizerPayoutService,
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