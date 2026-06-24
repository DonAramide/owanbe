import { Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CommerceAuthGuard } from '../commerce/commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from '../commerce/commerce-auth.service';
import { RentalsService } from './rentals.service';

@Controller()
export class RentalsController {
  constructor(private readonly rentals: RentalsService) {}

  @Public()
  @Throttle({ public: { limit: 300, ttl: 60_000 } })
  @Get('rentals/catalog')
  async catalog(@TenantId() tenantId: string, @Query('category') category?: string) {
    return this.rentals.listMarketplaceCatalog(tenantId, category);
  }

  @Public()
  @Throttle({ public: { limit: 300, ttl: 60_000 } })
  @Get('rentals/catalog/:itemId/availability')
  async availability(
    @TenantId() tenantId: string,
    @Param('itemId') itemId: string,
    @Query('from') from: string,
    @Query('to') to: string,
  ) {
    return this.rentals.getItemAvailability(tenantId, itemId, from, to);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('vendors/:vendorId/rentals/inventory')
  async vendorInventory(@Param('vendorId') vendorId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.rentals.listVendorInventory(actor!, vendorId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendors/:vendorId/rentals/inventory')
  async createInventory(
    @Param('vendorId') vendorId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.rentals.createInventoryItem(actor!, vendorId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Patch('vendors/:vendorId/rentals/inventory/:itemId')
  async patchInventory(
    @Param('vendorId') vendorId: string,
    @Param('itemId') itemId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.rentals.patchInventoryItem(actor!, vendorId, itemId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('vendors/:vendorId/rentals/blackouts')
  async listBlackouts(@Param('vendorId') vendorId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.rentals.listBlackouts(actor!, vendorId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendors/:vendorId/rentals/blackouts')
  async addBlackout(
    @Param('vendorId') vendorId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.rentals.addBlackout(actor!, vendorId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('vendors/:vendorId/rentals/bookings')
  async vendorBookings(@Param('vendorId') vendorId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.rentals.listVendorBookings(actor!, vendorId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendors/:vendorId/rentals/bookings/:bookingId/approve')
  async approve(
    @Param('vendorId') vendorId: string,
    @Param('bookingId') bookingId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    const qty = body.quantity != null ? Number(body.quantity) : undefined;
    return this.rentals.approveBooking(actor!, vendorId, bookingId, qty);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendors/:vendorId/rentals/bookings/:bookingId/counter')
  async counter(
    @Param('vendorId') vendorId: string,
    @Param('bookingId') bookingId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.rentals.counterBooking(actor!, vendorId, bookingId, Number(body.counterQuantity ?? 0));
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendors/:vendorId/rentals/bookings/:bookingId/decline')
  async decline(
    @Param('vendorId') vendorId: string,
    @Param('bookingId') bookingId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.rentals.declineBooking(actor!, vendorId, bookingId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendors/:vendorId/rentals/bookings/:bookingId/deliver')
  async deliver(
    @Param('vendorId') vendorId: string,
    @Param('bookingId') bookingId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.rentals.markDelivered(actor!, vendorId, bookingId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendors/:vendorId/rentals/bookings/:bookingId/return')
  async returnItem(
    @Param('vendorId') vendorId: string,
    @Param('bookingId') bookingId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.rentals.markReturned(actor!, vendorId, bookingId, body.damageNotes as string | undefined);
  }

  @Public()
  @Throttle({ public: { limit: 300, ttl: 60_000 } })
  @Get('events/:eventId/rentals')
  async eventRentals(
    @TenantId() tenantId: string,
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor | null,
  ) {
    return this.rentals.listEventRentals(tenantId, eventId, actor ?? undefined);
  }

  @Public()
  @Throttle({ public: { limit: 30, ttl: 60_000 } })
  @Post('events/:eventId/rentals/bookings')
  async createBooking(
    @TenantId() tenantId: string,
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor | null,
  ) {
    return this.rentals.createBooking(tenantId, eventId, body, actor?.userId);
  }
}
