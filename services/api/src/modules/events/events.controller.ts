import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { RequirePermissions } from '../../permissions/permissions.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CommerceAuthGuard } from '../commerce/commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from '../commerce/commerce-auth.service';
import { EventsService } from './events.service';
import { EventTiersService } from './event-tiers.service';
import { OrganizerPortalService } from './organizer-portal.service';
import { VendorParticipationService } from './vendor-participation.service';
import { EventOperationsService } from './event-operations.service';
import { EventWebsiteService } from './event-website.service';
import { CelebrationWallService } from './celebration-wall.service';
import { AsoEbiService } from './aso-ebi.service';
import { SeatingService } from './seating.service';
import { ProgramService } from './program.service';
import { EventGuestsService } from './event-guests.service';
import { EventInvitationsService } from './event-invitations.service';

@Controller()
export class EventsController {
  constructor(
    private readonly events: EventsService,
    private readonly tiers: EventTiersService,
    private readonly organizer: OrganizerPortalService,
    private readonly vendor: VendorParticipationService,
    private readonly ops: EventOperationsService,
    private readonly website: EventWebsiteService,
    private readonly wall: CelebrationWallService,
    private readonly asoEbi: AsoEbiService,
    private readonly seating: SeatingService,
    private readonly program: ProgramService,
    private readonly eventGuests: EventGuestsService,
    private readonly invitations: EventInvitationsService,
  ) {}

  @Public()
  @Throttle({ public: { limit: 300, ttl: 60_000 } })
  @Get('events')
  async listPublic(
    @TenantId() tenantId: string,
    @Query('q') q?: string,
    @Query('category') category?: string,
  ) {
    return this.events.listPublic(tenantId, q, category);
  }

  @Public()
  @Throttle({ public: { limit: 300, ttl: 60_000 } })
  @Get('events/:eventId')
  async getPublic(@TenantId() tenantId: string, @Param('eventId') eventId: string) {
    return this.events.getPublic(tenantId, eventId);
  }

  @Public()
  @Get('events/:eventId/tiers')
  async listPublicTiers(@TenantId() tenantId: string, @Param('eventId') eventId: string) {
    return this.tiers.list(null, tenantId, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @RequirePermissions('event.create')
  @Post('events')
  async create(@CommerceActorParam() actor: CommerceActor, @Body() body: Record<string, unknown>) {
    return this.events.create(actor!, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Patch('events/:eventId')
  async patch(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.events.patch(actor!, eventId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @RequirePermissions('event.publish')
  @Post('events/:eventId/publish')
  async publish(@Param('eventId') eventId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.events.publish(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @RequirePermissions('event.close')
  @Post('events/:eventId/go-live')
  async goLive(@Param('eventId') eventId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.events.goLive(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('organizers/me')
  async organizerMe(@CommerceActorParam() actor: CommerceActor) {
    return this.organizer.getMe(actor!);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('organizers/me/events')
  async organizerEvents(@CommerceActorParam() actor: CommerceActor) {
    return this.events.listForOrganizer(actor!);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/manage')
  async getEventManage(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.events.getForOrganizer(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('organizers/me/dashboard')
  async organizerDashboard(@CommerceActorParam() actor: CommerceActor) {
    return this.organizer.getDashboard(actor!);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/tiers/manage')
  async listOrganizerTiers(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.tiers.list(actor!, actor!.tenantId, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/tiers')
  async createTier(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.tiers.create(actor!, eventId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Patch('tiers/:tierId')
  async patchTier(
    @Param('tierId') tierId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.tiers.patch(actor!, tierId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Delete('tiers/:tierId')
  async deleteTier(@Param('tierId') tierId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.tiers.remove(actor!, tierId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('vendor/events')
  async vendorEvents(@CommerceActorParam() actor: CommerceActor) {
    return this.vendor.listForVendor(actor!);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @RequirePermissions('vendor.apply')
  @Post('vendor/events/:eventId/apply')
  async vendorApply(@Param('eventId') eventId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.vendor.apply(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendor/events/:eventId/accept')
  async vendorAccept(@Param('eventId') eventId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.vendor.accept(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendor/events/:eventId/reject')
  async vendorReject(@Param('eventId') eventId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.vendor.reject(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/check-ins')
  async listCheckIns(@Param('eventId') eventId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.ops.listCheckIns(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/check-ins')
  async checkIn(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.ops.checkIn(actor!, eventId, {
      ticketCode: body.ticketCode as string | undefined,
      entitlementId: body.entitlementId as string | undefined,
      source: body.source as string | undefined,
    });
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/incidents')
  async listIncidents(@Param('eventId') eventId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.ops.listIncidents(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/incidents')
  async createIncident(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.ops.createIncident(actor!, eventId, {
      title: String(body.title ?? ''),
      category: body.category as string | undefined,
      priority: body.priority as string | undefined,
      reporter: body.reporter as string | undefined,
      description: body.description as string | undefined,
    });
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/feed')
  async listFeed(@Param('eventId') eventId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.ops.listFeed(actor!, eventId);
  }

  @Public()
  @Throttle({ public: { limit: 300, ttl: 60_000 } })
  @Get('e/:slug')
  async getPublicWebsite(@TenantId() tenantId: string, @Param('slug') slug: string) {
    return this.website.getPublic(tenantId, slug);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/website')
  async getEventWebsite(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.website.getForOrganizer(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Patch('events/:eventId/website')
  async patchEventWebsite(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.website.patch(actor!, eventId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/website/publish')
  async publishEventWebsite(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.website.publish(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/website/unpublish')
  async unpublishEventWebsite(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.website.unpublish(actor!, eventId);
  }

  @Public()
  @Throttle({ public: { limit: 300, ttl: 60_000 } })
  @Get('events/:eventId/wall')
  async listWall(@TenantId() tenantId: string, @Param('eventId') eventId: string) {
    return this.wall.listPublic(tenantId, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/wall/manage')
  async manageWall(@Param('eventId') eventId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.wall.listForOrganizer(actor!, eventId);
  }

  @Public()
  @Throttle({ public: { limit: 30, ttl: 60_000 } })
  @Post('events/:eventId/wall/posts')
  async createWallPost(
    @TenantId() tenantId: string,
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.wall.createPost(tenantId, eventId, {
      guestName: body.guestName as string | undefined,
      message: body.message as string | undefined,
      photoUrl: body.photoUrl as string | undefined,
    });
  }

  @Public()
  @Throttle({ public: { limit: 120, ttl: 60_000 } })
  @Post('events/:eventId/wall/posts/:postId/reactions')
  async reactWallPost(
    @TenantId() tenantId: string,
    @Param('eventId') eventId: string,
    @Param('postId') postId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.wall.addReaction(tenantId, eventId, postId, String(body.reaction ?? ''));
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/wall/posts/:postId/moderate')
  async moderateWallPost(
    @Param('eventId') eventId: string,
    @Param('postId') postId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    const action = String(body.action ?? '') as 'hide' | 'delete' | 'pin' | 'unpin' | 'show';
    return this.wall.moderate(actor!, eventId, postId, action);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Patch('events/:eventId/wall/settings')
  async patchWallSettings(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.wall.patchSettings(actor!, eventId, Boolean(body.liveMode));
  }

  @Public()
  @Throttle({ public: { limit: 300, ttl: 60_000 } })
  @Get('events/:eventId/aso-ebi')
  async listAsoEbi(@TenantId() tenantId: string, @Param('eventId') eventId: string) {
    return this.asoEbi.listPublic(tenantId, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/aso-ebi/manage')
  async manageAsoEbi(@Param('eventId') eventId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.asoEbi.listForOrganizer(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/aso-ebi/fabrics')
  async createAsoEbiFabric(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.asoEbi.createFabric(actor!, eventId, {
      name: body.name as string | undefined,
      photoUrl: body.photoUrl as string | undefined,
      description: body.description as string | undefined,
    });
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Patch('events/:eventId/aso-ebi/fabrics/:fabricId')
  async patchAsoEbiFabric(
    @Param('eventId') eventId: string,
    @Param('fabricId') fabricId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.asoEbi.patchFabric(actor!, eventId, fabricId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Put('events/:eventId/aso-ebi/fabrics/:fabricId/packages')
  async upsertAsoEbiPackages(
    @Param('eventId') eventId: string,
    @Param('fabricId') fabricId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    const packages = (body.packages as Array<{ packageType: string; priceMinor: number }>) ?? [];
    return this.asoEbi.upsertPackages(actor!, eventId, fabricId, packages);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Put('events/:eventId/aso-ebi/fabrics/:fabricId/inventory')
  async upsertAsoEbiInventory(
    @Param('eventId') eventId: string,
    @Param('fabricId') fabricId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    const items = (body.items as Array<{ packageType: string; size: string; available: number }>) ?? [];
    return this.asoEbi.upsertInventory(actor!, eventId, fabricId, items);
  }

  @Public()
  @Throttle({ public: { limit: 30, ttl: 60_000 } })
  @Post('events/:eventId/aso-ebi/reservations')
  async createAsoEbiReservation(
    @TenantId() tenantId: string,
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor | null,
  ) {
    return this.asoEbi.createReservation(
      tenantId,
      eventId,
      {
        fabricId: body.fabricId as string | undefined,
        packageType: body.packageType as string | undefined,
        size: body.size as string | undefined,
        guestName: body.guestName as string | undefined,
        guestEmail: body.guestEmail as string | undefined,
      },
      actor?.userId,
    );
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Throttle({ public: { limit: 60, ttl: 60_000 } })
  @Post('events/:eventId/aso-ebi/reservations/:reservationId/pay')
  async payAsoEbiReservation(
    @Param('eventId') eventId: string,
    @Param('reservationId') reservationId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.asoEbi.markPaid(actor!, eventId, reservationId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/aso-ebi/reservations/:reservationId/collect')
  async collectAsoEbiReservation(
    @Param('eventId') eventId: string,
    @Param('reservationId') reservationId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.asoEbi.markCollected(actor!, eventId, reservationId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/aso-ebi/reservations/:reservationId/cancel')
  async cancelAsoEbiReservation(
    @Param('eventId') eventId: string,
    @Param('reservationId') reservationId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.asoEbi.cancelReservation(actor!, eventId, reservationId);
  }

  @Public()
  @Throttle({ public: { limit: 300, ttl: 60_000 } })
  @Get('events/:eventId/seating')
  async getSeating(@TenantId() tenantId: string, @Param('eventId') eventId: string) {
    return this.seating.getLayout(tenantId, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/seating/manage')
  async manageSeating(@Param('eventId') eventId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.seating.getLayoutForOrganizer(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Patch('events/:eventId/seating/layout')
  async patchSeatingLayout(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.seating.patchLayout(actor!, eventId, {
      name: body.name as string | undefined,
      canvasWidth: body.canvasWidth != null ? Number(body.canvasWidth) : undefined,
      canvasHeight: body.canvasHeight != null ? Number(body.canvasHeight) : undefined,
    });
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/seating/tables')
  async createSeatingTable(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.seating.createTable(actor!, eventId, {
      label: body.label as string | undefined,
      tableKind: body.tableKind as string | undefined,
      capacity: body.capacity != null ? Number(body.capacity) : undefined,
      isVip: body.isVip != null ? Boolean(body.isVip) : undefined,
      positionX: body.positionX != null ? Number(body.positionX) : undefined,
      positionY: body.positionY != null ? Number(body.positionY) : undefined,
      rotationDeg: body.rotationDeg != null ? Number(body.rotationDeg) : undefined,
    });
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Patch('events/:eventId/seating/tables/:tableId')
  async patchSeatingTable(
    @Param('eventId') eventId: string,
    @Param('tableId') tableId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.seating.patchTable(actor!, eventId, tableId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Delete('events/:eventId/seating/tables/:tableId')
  async deleteSeatingTable(
    @Param('eventId') eventId: string,
    @Param('tableId') tableId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.seating.deleteTable(actor!, eventId, tableId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Put('events/:eventId/seating/tables/positions')
  async syncSeatingPositions(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    const tables =
      (body.tables as Array<{ id: string; positionX: number; positionY: number; rotationDeg?: number }>) ?? [];
    return this.seating.syncTablePositions(actor!, eventId, tables);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/seating/assignments')
  async assignSeatingGuest(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.seating.assignGuest(actor!, eventId, {
      tableId: body.tableId as string | undefined,
      guestRef: body.guestRef as string | undefined,
      guestName: body.guestName as string | undefined,
      seatIndex: body.seatIndex != null ? Number(body.seatIndex) : undefined,
    });
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Delete('events/:eventId/seating/assignments/:assignmentId')
  async unassignSeatingGuest(
    @Param('eventId') eventId: string,
    @Param('assignmentId') assignmentId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.seating.unassignGuest(actor!, eventId, assignmentId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/seating/initialize')
  async initializeSeating(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.seating.initializeFromGuestCount(
      actor!,
      eventId,
      Number(body.guestCount ?? 150),
      body.vipTableCount != null ? Number(body.vipTableCount) : 1,
    );
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/seating/export')
  async exportSeating(@Param('eventId') eventId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.seating.exportLayout(actor!, eventId);
  }

  @Public()
  @Throttle({ public: { limit: 300, ttl: 60_000 } })
  @Get('events/:eventId/program')
  async getProgram(@TenantId() tenantId: string, @Param('eventId') eventId: string) {
    return this.program.getProgram(tenantId, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/program/items')
  async createProgramItem(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.program.createItem(actor!, eventId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Patch('events/:eventId/program/items/:itemId')
  async patchProgramItem(
    @Param('eventId') eventId: string,
    @Param('itemId') itemId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.program.patchItem(actor!, eventId, itemId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Delete('events/:eventId/program/items/:itemId')
  async deleteProgramItem(
    @Param('eventId') eventId: string,
    @Param('itemId') itemId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.program.deleteItem(actor!, eventId, itemId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/program/items/:itemId/status')
  async setProgramItemStatus(
    @Param('eventId') eventId: string,
    @Param('itemId') itemId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.program.setItemStatus(
      actor!,
      eventId,
      itemId,
      String(body.status ?? ''),
      body.delayMinutes != null ? Number(body.delayMinutes) : undefined,
    );
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/program/reorder')
  async reorderProgram(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    const itemIds = (body.itemIds as string[]) ?? [];
    return this.program.reorder(actor!, eventId, itemIds);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/program/auto-shift')
  async autoShiftProgram(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.program.autoShift(
      actor!,
      eventId,
      String(body.fromItemId ?? ''),
      Number(body.delayMinutes ?? 0),
    );
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/program/apply-template')
  async applyProgramTemplate(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.program.applyTemplate(actor!, eventId, String(body.template ?? ''));
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/guests')
  async listEventGuests(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.eventGuests.list(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/guests')
  async createEventGuest(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.eventGuests.create(actor!, eventId, {
      name: body.name as string | undefined,
      email: body.email as string | undefined,
      phoneE164: body.phoneE164 as string | undefined,
      groupLabel: body.groupLabel as string | undefined,
      notes: body.notes as string | undefined,
    });
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/guests/bulk')
  async bulkCreateEventGuests(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    const guests = (body.guests as Array<Record<string, unknown>>) ?? [];
    return this.eventGuests.bulkCreate(
      actor!,
      eventId,
      guests.map((g) => ({
        name: String(g.name ?? ''),
        email: g.email as string | undefined,
        phoneE164: g.phoneE164 as string | undefined,
        groupLabel: g.groupLabel as string | undefined,
      })),
    );
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/invitations')
  async listEventInvitations(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.invitations.listHub(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/invitations/send')
  async sendEventInvitations(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.invitations.sendBatch(actor!, eventId, {
      guestIds: body.guestIds as string[] | undefined,
      channel: body.channel as string | undefined,
      templateId: body.templateId as string | undefined,
    });
  }

  @Public()
  @Throttle({ public: { limit: 120, ttl: 60_000 } })
  @Get('invitations/validate')
  async validateInvitation(
    @TenantId() tenantId: string,
    @Query('token') token: string,
  ) {
    return this.invitations.validateToken(tenantId, token ?? '');
  }

  @Public()
  @Throttle({ public: { limit: 60, ttl: 60_000 } })
  @Post('invitations/rsvp')
  async rsvpInvitation(
    @TenantId() tenantId: string,
    @Body() body: Record<string, unknown>,
  ) {
    const status = String(body.status ?? '') === 'declined' ? 'declined' : 'confirmed';
    return this.invitations.rsvpByToken(tenantId, String(body.token ?? ''), status);
  }
}
