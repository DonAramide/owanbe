import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CommerceAuthGuard } from '../commerce/commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from '../commerce/commerce-auth.service';
import { AttendeeEventServicesService } from './attendee-event-services.service';
import { RentalsService } from './rentals.service';

@Controller()
export class RentalsController {
  constructor(
    private readonly rentals: RentalsService,
    private readonly attendeeServices: AttendeeEventServicesService,
  ) {}

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
    const booking = await this.rentals.approveBooking(actor!, vendorId, bookingId, qty);
    await this.attendeeServices.notifyRequesterOfStatus(
      actor!.tenantId,
      bookingId,
      'service_booking_confirmed',
      'Booking confirmed',
      `${booking.itemName} was confirmed by the vendor.`,
    );
    return booking;
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
    const booking = await this.rentals.counterBooking(
      actor!,
      vendorId,
      bookingId,
      Number(body.counterQuantity ?? 0),
    );
    await this.attendeeServices.notifyRequesterOfStatus(
      actor!.tenantId,
      bookingId,
      'service_booking_updated',
      'Booking updated',
      `${booking.itemName} — vendor proposed a different quantity.`,
    );
    return booking;
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendors/:vendorId/rentals/bookings/:bookingId/decline')
  async decline(
    @Param('vendorId') vendorId: string,
    @Param('bookingId') bookingId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    const booking = await this.rentals.declineBooking(actor!, vendorId, bookingId);
    await this.attendeeServices.notifyRequesterOfStatus(
      actor!.tenantId,
      bookingId,
      'service_booking_cancelled',
      'Booking declined',
      `${booking.itemName} was declined by the vendor.`,
    );
    return booking;
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendors/:vendorId/rentals/bookings/:bookingId/deliver')
  async deliver(
    @Param('vendorId') vendorId: string,
    @Param('bookingId') bookingId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    const booking = await this.rentals.markDelivered(actor!, vendorId, bookingId);
    await this.attendeeServices.notifyRequesterOfStatus(
      actor!.tenantId,
      bookingId,
      'service_booking_updated',
      'Rental ready',
      `${booking.itemName} is ready / delivered.`,
    );
    return booking;
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
    const booking = await this.rentals.markReturned(
      actor!,
      vendorId,
      bookingId,
      body.damageNotes as string | undefined,
    );
    await this.attendeeServices.notifyRequesterOfStatus(
      actor!.tenantId,
      bookingId,
      'service_booking_completed',
      'Booking completed',
      `${booking.itemName} was marked returned / completed.`,
    );
    return booking;
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

  // —— Phase 9 attendee event services (event-scoped) ——

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/services')
  async eventServicesHub(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.attendeeServices.hub(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/services/vendors')
  async eventServiceVendors(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
    @Query('q') q?: string,
    @Query('category') category?: string,
  ) {
    return this.attendeeServices.listEventVendors(actor!, eventId, { q, category });
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/services/rentals')
  async eventServiceRentals(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
    @Query('category') category?: string,
  ) {
    return this.attendeeServices.listEventRentalCatalog(actor!, eventId, category);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/services/rentals/bookings')
  async attendeeBookRental(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
    @Body() body: Record<string, unknown>,
  ) {
    return this.attendeeServices.bookRental(actor!, eventId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('me/service-bookings')
  async myServiceBookings(
    @CommerceActorParam() actor: CommerceActor,
    @Query('eventId') eventId?: string,
  ) {
    return this.attendeeServices.listMyBookings(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('me/service-bookings/:bookingId/cancel')
  async cancelServiceBooking(
    @Param('bookingId') bookingId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.attendeeServices.cancelBooking(actor!, bookingId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('me/service-notifications')
  async serviceNotifications(@CommerceActorParam() actor: CommerceActor) {
    return this.attendeeServices.listNotifications(actor!);
  }
}
