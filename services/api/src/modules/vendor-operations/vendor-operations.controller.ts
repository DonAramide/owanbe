import { Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CommerceAuthGuard } from '../commerce/commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from '../commerce/commerce-auth.service';
import { VendorCrmService } from './vendor-crm.service';
import { VendorCalendarService } from './vendor-calendar.service';

@Controller()
export class VendorOperationsController {
  constructor(
    private readonly crm: VendorCrmService,
    private readonly calendar: VendorCalendarService,
  ) {}

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/vendor-requests')
  async listEventVendorRequests(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.crm.listForEvent(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/vendor-requests')
  async createVendorRequest(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.crm.createRequest(actor!, eventId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Patch('vendor-requests/:requestId')
  async patchVendorRequest(
    @Param('requestId') requestId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.crm.patchRequest(actor!, requestId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendor-requests/:requestId/stage')
  async transitionVendorRequest(
    @Param('requestId') requestId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.crm.transitionStage(actor!, requestId, String(body.stage ?? ''), body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('vendors/:vendorId/requests')
  async listVendorRequests(
    @Param('vendorId') vendorId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.crm.listForVendor(actor!, vendorId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('vendors/:vendorId/calendar')
  async getVendorCalendar(
    @TenantId() tenantId: string,
    @Param('vendorId') vendorId: string,
    @Query('from') from: string,
    @Query('to') to: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    if (actor) {
      return this.calendar.getCalendarForActor(actor, vendorId, from, to);
    }
    return this.calendar.getCalendar(tenantId, vendorId, from, to);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendors/:vendorId/calendar/blocks')
  async addCalendarBlock(
    @Param('vendorId') vendorId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.calendar.addBlock(actor!, vendorId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Patch('vendors/:vendorId/calendar/settings')
  async patchCalendarSettings(
    @Param('vendorId') vendorId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.calendar.patchSettings(actor!, vendorId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('vendors/:vendorId/calendar/conflicts')
  async checkCalendarConflicts(
    @Param('vendorId') vendorId: string,
    @Query('startsAt') startsAt: string,
    @Query('endsAt') endsAt: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.calendar.checkConflicts(actor!, vendorId, startsAt, endsAt);
  }
}
