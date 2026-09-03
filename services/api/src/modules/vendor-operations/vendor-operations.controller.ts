import { Body, Controller, Delete, Get, Param, Patch, Post, Put, Query, UseGuards } from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CommerceAuthGuard } from '../commerce/commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from '../commerce/commerce-auth.service';
import { VendorCrmService } from './vendor-crm.service';
import { VendorCalendarService } from './vendor-calendar.service';
import { EventVendorFundsService } from './vendor-pricing-funds.service';
import { VendorChangeRequestService } from './vendor-change-request.service';
import { VendorOfferingsService } from './vendor-offerings.service';

@Controller()
export class VendorOperationsController {
  constructor(
    private readonly crm: VendorCrmService,
    private readonly calendar: VendorCalendarService,
    private readonly eventFunds: EventVendorFundsService,
    private readonly changeRequests: VendorChangeRequestService,
    private readonly offerings: VendorOfferingsService,
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
  @Post('events/:eventId/vendor-requests/vendor-buyer')
  async createVendorBuyerRequest(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.crm.createVendorBuyerRequest(actor!, eventId, body);
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
  @Post('vendor-requests/:requestId/counter')
  async counterVendorRequest(
    @Param('requestId') requestId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.crm.counterOffer(actor!, requestId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendor-requests/:requestId/messages')
  async postVendorRequestMessage(
    @Param('requestId') requestId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.crm.postMessage(actor!, requestId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendor-requests/:requestId/confirm-agreement')
  async confirmAgreement(
    @Param('requestId') requestId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.crm.confirmAgreement(actor!, requestId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendor-requests/:requestId/fund')
  async fundVendorRequest(
    @Param('requestId') requestId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.eventFunds.reserveForRequest(actor!, requestId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendor-requests/:requestId/mark-complete')
  async markVendorRequestComplete(
    @Param('requestId') requestId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.crm.markServiceComplete(actor!, requestId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendor-requests/:requestId/confirm-completion')
  async confirmVendorRequestCompletion(
    @Param('requestId') requestId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.crm.confirmServiceCompletion(actor!, requestId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendor-requests/:requestId/report-issue')
  async reportVendorRequestIssue(
    @Param('requestId') requestId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.crm.reportServiceIssue(actor!, requestId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/vendor-funds')
  async getEventVendorFunds(
    @Param('eventId') eventId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.eventFunds.getSummary(actor!, eventId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('events/:eventId/vendor-funds')
  async fundEventVendorPool(
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.eventFunds.fundEvent(actor!, eventId, Number(body.amountMinor ?? 0));
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('vendor-requests/:requestId/timeline')
  async vendorRequestTimeline(
    @Param('requestId') requestId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.crm.getTimeline(actor!, requestId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('vendor-requests/:requestId/change-requests')
  async listChangeRequests(
    @Param('requestId') requestId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.changeRequests.listForRequest(actor!, requestId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendor-requests/:requestId/change-requests')
  async createChangeRequest(
    @Param('requestId') requestId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.changeRequests.create(actor!, requestId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('change-requests/:id/accept')
  async acceptChangeRequest(
    @Param('id') id: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.changeRequests.accept(actor!, id);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('change-requests/:id/decline')
  async declineChangeRequest(
    @Param('id') id: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.changeRequests.decline(actor!, id, body ?? {});
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('change-requests/:id/cancel')
  async cancelChangeRequest(
    @Param('id') id: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.changeRequests.cancel(actor!, id);
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
  @Get('vendors/:vendorId/outgoing-vendor-requests')
  async listOutgoingVendorRequests(
    @Param('vendorId') vendorId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.crm.listOutgoingForVendor(actor!, vendorId);
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
  @Patch('vendors/:vendorId/calendar/blocks/:blockId')
  async updateCalendarBlock(
    @Param('vendorId') vendorId: string,
    @Param('blockId') blockId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.calendar.updateBlock(actor!, vendorId, blockId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Delete('vendors/:vendorId/calendar/blocks/:blockId')
  async deleteCalendarBlock(
    @Param('vendorId') vendorId: string,
    @Param('blockId') blockId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.calendar.deleteBlock(actor!, vendorId, blockId);
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

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('vendors/:vendorId/offerings-config')
  async getOfferingsConfig(@Param('vendorId') vendorId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.offerings.getConfig(actor!, vendorId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Put('vendors/:vendorId/business-capabilities')
  async putBusinessCapabilities(
    @Param('vendorId') vendorId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    const keys = Array.isArray(body.capabilityKeys) ? body.capabilityKeys : [];
    return this.offerings.putCapabilities(actor!, vendorId, keys);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Put('vendors/:vendorId/offering-categories')
  async putOfferingCategories(
    @Param('vendorId') vendorId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    const ids = Array.isArray(body.categoryIds) ? body.categoryIds.map((id) => String(id)) : [];
    return this.offerings.putCategorySelections(actor!, vendorId, ids);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('vendors/:vendorId/offering-services')
  async listOfferingServices(@Param('vendorId') vendorId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.offerings.listServices(actor!, vendorId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendors/:vendorId/services')
  async createVendorService(
    @Param('vendorId') vendorId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.offerings.createService(actor!, vendorId, body);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('vendors/:vendorId/services/:serviceId/blueprint')
  async getBlueprint(
    @Param('vendorId') vendorId: string,
    @Param('serviceId') serviceId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.offerings.getServiceDetail(actor!, vendorId, serviceId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Put('vendors/:vendorId/services/:serviceId/blueprint')
  async putBlueprint(
    @Param('vendorId') vendorId: string,
    @Param('serviceId') serviceId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    const resources = Array.isArray(body.resources) ? (body.resources as Array<{ resourceId: string; required?: boolean }>) : [];
    return this.offerings.putBlueprint(actor!, vendorId, serviceId, resources);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('vendors/:vendorId/rental-packages')
  async listRentalPackages(@Param('vendorId') vendorId: string, @CommerceActorParam() actor: CommerceActor) {
    return this.offerings.listPackages(actor!, vendorId);
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('vendors/:vendorId/rental-packages')
  async upsertRentalPackage(
    @Param('vendorId') vendorId: string,
    @Body() body: Record<string, unknown>,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    return this.offerings.upsertPackage(actor!, vendorId, body);
  }
}
