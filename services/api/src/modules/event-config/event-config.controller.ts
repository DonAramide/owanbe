import { Controller, Get, Post, Body, Param } from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { ADMIN_TIERS } from '../../common/permission-matrix';
import { RequirePermissions } from '../../permissions/permissions.decorator';
import { UseGuards } from '@nestjs/common';
import { CommerceAuthGuard } from '../commerce/commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from '../commerce/commerce-auth.service';
import { EventConfigService } from './event-config.service';
import { VendorNegotiationsService } from './vendor-negotiations.service';

@Controller()
export class EventConfigController {
  constructor(
    private readonly config: EventConfigService,
    private readonly negotiations: VendorNegotiationsService,
  ) {}

  @Public()
  @Get('event-config/categories')
  async categories(@TenantId() tenantId: string) {
    await this.config.seedDefaultsIfEmpty(tenantId);
    return this.config.listCategories(tenantId);
  }

  @Public()
  @Get('event-config/tags')
  async tags(@TenantId() tenantId: string) {
    await this.config.seedDefaultsIfEmpty(tenantId);
    return this.config.listTags(tenantId);
  }

  @Public()
  @Get('event-config/templates')
  async templates(@TenantId() tenantId: string) {
    await this.config.seedDefaultsIfEmpty(tenantId);
    return this.config.listTemplates(tenantId);
  }

  @Public()
  @Get('event-config/vendor-categories')
  async vendorCategories(@TenantId() tenantId: string) {
    return this.config.listVendorCategories(tenantId);
  }

  @Public()
  @Get('event-config/budget-templates')
  async budgetTemplates(@TenantId() tenantId: string) {
    return this.config.listBudgetTemplates(tenantId);
  }

  @UseGuards(CommerceAuthGuard)
  @RequirePermissions('event.create')
  @Get('events/:eventId/negotiations')
  async listNegotiations(@CommerceActorParam() actor: CommerceActor, @Param('eventId') eventId: string) {
    return this.negotiations.listForEvent(actor, eventId);
  }

  @UseGuards(CommerceAuthGuard)
  @RequirePermissions('event.create')
  @Post('events/:eventId/negotiations')
  async createNegotiation(
    @CommerceActorParam() actor: CommerceActor,
    @Param('eventId') eventId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.negotiations.createRequest(actor, eventId, body);
  }

  @UseGuards(CommerceAuthGuard)
  @RequirePermissions('event.create')
  @Post('negotiations/:negotiationId/offers')
  async counterOffer(
    @CommerceActorParam() actor: CommerceActor,
    @Param('negotiationId') negotiationId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.negotiations.counterOffer(actor, negotiationId, body, 'organizer');
  }

  @UseGuards(CommerceAuthGuard)
  @RequirePermissions('event.create')
  @Post('negotiations/:negotiationId/offers/:offerId/respond')
  async respondOffer(
    @CommerceActorParam() actor: CommerceActor,
    @Param('negotiationId') negotiationId: string,
    @Param('offerId') offerId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.negotiations.respondToOffer(actor, negotiationId, offerId, body);
  }
}

@Controller('admin/settings')
export class AdminEventConfigController {
  constructor(private readonly config: EventConfigService) {}

  @Roles(...ADMIN_TIERS)
  @Get('event-categories')
  async listCategories(@TenantId() tenantId: string) {
    await this.config.seedDefaultsIfEmpty(tenantId);
    return this.config.adminListCategories(tenantId);
  }

  @Roles(...ADMIN_TIERS)
  @Post('event-categories')
  async upsertCategory(@TenantId() tenantId: string, @Body() body: Record<string, unknown>) {
    return this.config.adminUpsertCategory(tenantId, body);
  }

  @Roles(...ADMIN_TIERS)
  @Get('event-tags')
  async listTags(@TenantId() tenantId: string) {
    await this.config.seedDefaultsIfEmpty(tenantId);
    const result = await this.config.listTags(tenantId);
    return result;
  }

  @Roles(...ADMIN_TIERS)
  @Post('event-tags')
  async upsertTag(@TenantId() tenantId: string, @Body() body: Record<string, unknown>) {
    return this.config.adminUpsertTag(tenantId, body);
  }

  @Roles(...ADMIN_TIERS)
  @Get('event-templates')
  async listTemplates(@TenantId() tenantId: string) {
    return this.config.listTemplates(tenantId);
  }

  @Roles(...ADMIN_TIERS)
  @Get('vendor-categories')
  async listVendorCategories(@TenantId() tenantId: string) {
    return this.config.listVendorCategories(tenantId);
  }

  @Roles(...ADMIN_TIERS)
  @Get('budget-templates')
  async listBudgetTemplates(@TenantId() tenantId: string) {
    return this.config.listBudgetTemplates(tenantId);
  }
}
