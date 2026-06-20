import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Param,
  Post,
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

  @Get('ticket-orders/:orderId')
  async getTicketOrder(
    @Param('orderId') orderId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.orders.getOrderById(actor!.tenantId, orderId);
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
}
