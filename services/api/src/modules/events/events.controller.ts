import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CommerceAuthGuard } from '../commerce/commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from '../commerce/commerce-auth.service';
import { EventsService } from './events.service';
import { EventTiersService } from './event-tiers.service';
import { OrganizerPortalService } from './organizer-portal.service';
import { VendorParticipationService } from './vendor-participation.service';
import { EventOperationsService } from './event-operations.service';

@Controller()
export class EventsController {
  constructor(
    private readonly events: EventsService,
    private readonly tiers: EventTiersService,
    private readonly organizer: OrganizerPortalService,
    private readonly vendor: VendorParticipationService,
    private readonly ops: EventOperationsService,
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
  @Post('events/:eventId/publish')
  async publish(@Param('eventId') eventId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.events.publish(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
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
}
