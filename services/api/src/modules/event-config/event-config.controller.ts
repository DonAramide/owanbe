import { Controller, Get, Post, Body, Param, Query } from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { Roles } from '../../common/decorators/roles.decorator';
import { ADMIN_TIERS, VENDOR_CATEGORY_ADMIN_ROLES } from '../../common/permission-matrix';
import { RequirePermissions } from '../../permissions/permissions.decorator';
import { UseGuards } from '@nestjs/common';
import { CommerceAuthGuard } from '../commerce/commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from '../commerce/commerce-auth.service';
import { EventConfigService } from './event-config.service';
import { VendorNegotiationsService } from './vendor-negotiations.service';
import { VendorTaxonomyService } from './vendor-taxonomy.service';
import { parseOfferingKind } from './vendor-taxonomy.util';

@Controller()
export class EventConfigController {
  constructor(
    private readonly config: EventConfigService,
    private readonly negotiations: VendorNegotiationsService,
    private readonly taxonomy: VendorTaxonomyService,
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
  @Get('event-config/vendor-business-capabilities')
  async publicBusinessCapabilities(@TenantId() tenantId: string) {
    return this.taxonomy.listActiveBusinessCapabilities(tenantId);
  }

  @Public()
  @Get('event-config/vendor-offering-categories')
  async publicOfferingCategories(@TenantId() tenantId: string, @Query('kind') kind?: string) {
    await this.config.seedVendorCategoriesIfEmpty(tenantId);
    await this.config.ensureCoreVendorCategories(tenantId);
    await this.config.ensureFashionAttireCategories(tenantId);
    await this.config.ensureRentalCategories(tenantId);
    const parsed = kind ? parseOfferingKind(kind) : null;
    return this.taxonomy.listActiveOfferingCategories(tenantId, parsed);
  }

  @Public()
  @Get('event-config/vendor-resource-catalog')
  async publicResourceCatalog(@TenantId() tenantId: string) {
    return this.taxonomy.listActiveResources(tenantId);
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
  constructor(
    private readonly config: EventConfigService,
    private readonly taxonomy: VendorTaxonomyService,
  ) {}

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

  @Roles(...VENDOR_CATEGORY_ADMIN_ROLES)
  @Get('vendor-categories')
  async listVendorCategories(@TenantId() tenantId: string) {
    return this.config.adminListVendorCategories(tenantId);
  }

  @Roles(...VENDOR_CATEGORY_ADMIN_ROLES)
  @Post('vendor-categories')
  async patchVendorCategoryCapabilities(
    @TenantId() tenantId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.config.adminPatchVendorCategoryCapabilities(tenantId, body);
  }

  @Roles(...VENDOR_CATEGORY_ADMIN_ROLES)
  @Get('vendor-business-capabilities')
  async listBusinessCapabilities(@TenantId() tenantId: string) {
    return this.taxonomy.listBusinessCapabilities(tenantId);
  }

  @Roles(...VENDOR_CATEGORY_ADMIN_ROLES)
  @Post('vendor-business-capabilities')
  async patchBusinessCapability(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Body() body: Record<string, unknown>,
  ) {
    return this.taxonomy.patchBusinessCapability(tenantId, user.userId, body);
  }

  @Roles(...VENDOR_CATEGORY_ADMIN_ROLES)
  @Get('vendor-offering-categories')
  async listOfferingCategories(@TenantId() tenantId: string, @Query('kind') kind?: string) {
    await this.config.seedVendorCategoriesIfEmpty(tenantId);
    await this.config.ensureCoreVendorCategories(tenantId);
    await this.config.ensureFashionAttireCategories(tenantId);
    await this.config.ensureRentalCategories(tenantId);
    const parsed = kind ? parseOfferingKind(kind) : null;
    return this.taxonomy.listOfferingCategories(tenantId, parsed);
  }

  @Roles(...VENDOR_CATEGORY_ADMIN_ROLES)
  @Post('vendor-offering-categories')
  async upsertOfferingCategory(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Body() body: Record<string, unknown>,
  ) {
    return this.taxonomy.upsertOfferingCategory(tenantId, user.userId, body);
  }

  @Roles(...VENDOR_CATEGORY_ADMIN_ROLES)
  @Get('vendor-resource-catalog')
  async listResources(@TenantId() tenantId: string) {
    return this.taxonomy.listResources(tenantId);
  }

  @Roles(...VENDOR_CATEGORY_ADMIN_ROLES)
  @Post('vendor-resource-catalog')
  async upsertResource(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Body() body: Record<string, unknown>,
  ) {
    return this.taxonomy.upsertResource(tenantId, user.userId, body);
  }

  @Roles(...ADMIN_TIERS)
  @Get('budget-templates')
  async listBudgetTemplates(@TenantId() tenantId: string) {
    return this.config.listBudgetTemplates(tenantId);
  }
}
