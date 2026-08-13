import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { CreateTicketOrderDto } from './dto/create-ticket-order.dto';
import { TicketOrdersService } from './ticket-orders.service';
import { TicketPaymentsService } from './ticket-payments.service';
import { TicketEntitlementsService } from './ticket-entitlements.service';
import { OrganizerTicketSalesService } from './organizer-ticket-sales.service';
import { CommerceAuthGuard } from './commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from './commerce-auth.service';

@Controller()
@Public()
@UseGuards(CommerceAuthGuard)
export class TicketCommerceController {
  constructor(
    private readonly orders: TicketOrdersService,
    private readonly payments: TicketPaymentsService,
    private readonly entitlements: TicketEntitlementsService,
    private readonly sales: OrganizerTicketSalesService,
  ) {}

  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  @HttpCode(201)
  @Post('events/:eventId/ticket-orders')
  async createTicketOrder(
    @Param('eventId') eventId: string,
    @Body() dto: CreateTicketOrderDto,
    @CommerceActorParam() actor: CommerceActor,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
    @CurrentUser() _user?: JwtUser,
  ) {
    return this.orders.createOrder(eventId, dto, actor!, idempotencyKey);
  }

  @Get('me/ticket-orders')
  async myTicketOrders(@CommerceActorParam() actor: CommerceActor) {
    return this.orders.listOrdersForBuyer(actor!.tenantId, actor!.userId);
  }

  @Get('ticket-orders/:orderId')
  async getTicketOrder(
    @Param('orderId') orderId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.orders.getOrderForBuyer(actor!.tenantId, actor!.userId, orderId);
  }

  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  @HttpCode(201)
  @Post('ticket-orders/:orderId/payments')
  async createTicketPayment(
    @Param('orderId') orderId: string,
    @CommerceActorParam() actor: CommerceActor,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
  ) {
    return this.payments.createPayment(actor!.tenantId, orderId, idempotencyKey);
  }

  @Get('me/ticket-entitlements')
  async myEntitlements(@CommerceActorParam() actor: CommerceActor) {
    const items = await this.entitlements.listForUser(actor!.tenantId, actor!.userId);
    return { items };
  }

  @Get('me/ticket-entitlements/:entitlementId')
  async myEntitlement(
    @Param('entitlementId') entitlementId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.entitlements.getForUser(actor!.tenantId, actor!.userId, entitlementId);
  }

  @Post('ticket-entitlements/:entitlementId/resend')
  async resendTicket(
    @Param('entitlementId') entitlementId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.entitlements.resendTicket(actor!.tenantId, actor!.userId, entitlementId);
  }

  @Post('ticket-orders/release-abandoned')
  async releaseAbandoned(@CommerceActorParam() actor: CommerceActor) {
    return this.orders.releaseAbandonedOrders(actor!.tenantId);
  }

  // —— Organizer sales visibility (Phase 14/17) ——

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('events/:eventId/ticket-orders')
  async listEventTicketOrders(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
    @Query('limit') limit?: string,
  ) {
    const n = parseInt(limit ?? '100', 10) || 100;
    return this.sales.listOrders(actor!, eventId, n);
  }

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('events/:eventId/ticket-orders/:orderId')
  async getEventTicketOrder(
    @Param('eventId') eventId: string,
    @Param('orderId') orderId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.sales.getOrder(actor!, eventId, orderId);
  }

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('events/:eventId/ticket-buyers')
  async listEventTicketBuyers(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
    @Query('limit') limit?: string,
  ) {
    const n = parseInt(limit ?? '200', 10) || 200;
    return this.sales.listBuyers(actor!, eventId, n);
  }

  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @Get('events/:eventId/ticket-sales-summary')
  async eventTicketSalesSummary(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.sales.salesDashboard(actor!, eventId);
  }
}
