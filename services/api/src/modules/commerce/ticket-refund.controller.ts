import { Controller, Get, Param, Post, Body, Query, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Roles } from '../../common/decorators/roles.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { ADMIN_FINANCE_ROLES } from '../../common/permission-matrix';
import { TicketRefundService, type TicketRefundAction } from './ticket-refund.service';
import { CommerceAuthGuard } from './commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from './commerce-auth.service';
import { Public } from '../../common/decorators/public.decorator';

@Controller()
export class TicketRefundController {
  constructor(private readonly refunds: TicketRefundService) {}

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Throttle({ strict: { limit: 20, ttl: 60_000 } })
  @Post('ticket-orders/:orderId/refunds')
  async requestRefund(
    @Param('orderId') orderId: string,
    @Body() body: { amountMinor: string; reason: string },
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.refunds.createCase(actor!, orderId, body.amountMinor, body.reason ?? '');
  }

  @Roles(...ADMIN_FINANCE_ROLES)
  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('admin/finance/ticket-refunds')
  async listQueue(@TenantId() tenantId: string, @Query('status') status?: string) {
    return this.refunds.listQueue(tenantId, status);
  }

  @Roles(...ADMIN_FINANCE_ROLES)
  @Get('admin/finance/ticket-refunds/:caseId')
  async getCase(@TenantId() tenantId: string, @Param('caseId') caseId: string) {
    return this.refunds.getCase(tenantId, caseId);
  }

  @Roles(...ADMIN_FINANCE_ROLES)
  @Throttle({ strict: { limit: 40, ttl: 60_000 } })
  @Post('admin/finance/ticket-refunds/:caseId/:action')
  async action(
    @TenantId() tenantId: string,
    @Param('caseId') caseId: string,
    @Param('action') action: TicketRefundAction,
    @Body() body: { note?: string },
  ) {
    return this.refunds.adminAction(tenantId, caseId, action, body?.note);
  }
}
