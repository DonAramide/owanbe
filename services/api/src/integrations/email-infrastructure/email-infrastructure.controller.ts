import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { Roles } from '../../common/decorators/roles.decorator';
import { SkipTenant } from '../../common/decorators/skip-tenant.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { SUPER_ADMIN_ROLES } from '../../common/permission-matrix';
import { EmailProviderAdminService } from './email-provider-admin.service';
import { EmailService } from './email.service';
import { SupabaseSmtpSyncService } from './supabase-smtp-sync.service';
import {
  CreateEmailProviderDto,
  SendTestEmailDto,
  UpdateEmailProviderDto,
} from './dto/email-provider.dto';

@Controller('super-admin/email-infrastructure')
@SkipTenant()
@Roles(...SUPER_ADMIN_ROLES)
export class EmailInfrastructureController {
  constructor(
    private readonly admin: EmailProviderAdminService,
    private readonly email: EmailService,
    private readonly supabaseSync: SupabaseSmtpSyncService,
  ) {}

  @Get('providers')
  listProviders() {
    return this.admin.list();
  }

  @Get('providers/:id')
  getProvider(@Param('id') id: string) {
    return this.admin.get(id);
  }

  @Post('providers')
  createProvider(@CurrentUser() user: JwtUser, @Body() dto: CreateEmailProviderDto) {
    return this.admin.create(user.userId, dto);
  }

  @Patch('providers/:id')
  updateProvider(
    @CurrentUser() user: JwtUser,
    @Param('id') id: string,
    @Body() dto: UpdateEmailProviderDto,
  ) {
    return this.admin.update(id, user.userId, dto);
  }

  @Delete('providers/:id')
  deleteProvider(@CurrentUser() user: JwtUser, @Param('id') id: string) {
    return this.admin.remove(id, user.userId);
  }

  @Post('providers/:id/set-default')
  setDefault(@CurrentUser() user: JwtUser, @Param('id') id: string) {
    return this.admin.setDefault(id, user.userId);
  }

  @Post('providers/:id/test-connection')
  async testConnection(@CurrentUser() user: JwtUser, @Param('id') id: string) {
    const result = await this.email.testConnection(id);
    await this.admin.recordAudit(id, user.userId, 'test_connection', result);
    return result;
  }

  @Post('providers/:id/test-email')
  async sendTestEmail(
    @CurrentUser() user: JwtUser,
    @Param('id') id: string,
    @Body() dto: SendTestEmailDto,
  ) {
    const result = await this.email.sendTestEmail(id, dto.to.trim());
    await this.admin.recordAudit(id, user.userId, 'test_email', {
      to: dto.to.trim(),
      ok: result.ok,
    });
    return result;
  }

  @Get('readiness')
  readiness() {
    return this.email.getReadiness();
  }

  @Get('audit')
  listAudit(@Query('providerId') providerId?: string, @Query('limit') limit?: string) {
    return this.admin.listAudit(providerId, limit ? Number(limit) : 50);
  }

  @Get('supabase-sync/status')
  async supabaseSyncStatus() {
    const configured = this.supabaseSync.isConfigured();
    const readiness = await this.email.getReadiness();
    return {
      managementApiConfigured: configured,
      syncEnabled: configured && readiness.ready,
      syncDisabledReason: !configured
        ? 'SUPABASE_ACCESS_TOKEN is not configured. Set an Owner/Administrator PAT and restart the API, or configure Auth SMTP in the Supabase Dashboard.'
        : !readiness.ready
          ? readiness.blockers.join('; ')
          : null,
      limitation: this.supabaseSync.describeLimitation(),
      canSyncProgrammatically: true,
      requires: ['SUPABASE_ACCESS_TOKEN', 'SUPABASE_PROJECT_REF (or SUPABASE_URL)'],
      requiresRole: 'Owner or Administrator personal access token',
      emailReadiness: readiness,
    };
  }

  @Post('supabase-sync')
  async syncToSupabase(@CurrentUser() user: JwtUser, @Body() body: { providerId?: string }) {
    const result = await this.supabaseSync.syncDefaultProvider(body?.providerId);
    await this.admin.recordAudit(
      result.syncedProviderId ?? null,
      user.userId,
      'supabase_sync',
      { ...result },
    );
    return result;
  }

  @Get('provider-types')
  providerTypes() {
    return {
      types: [
        { code: 'generic_smtp', label: 'Generic SMTP' },
        { code: 'zoho_smtp', label: 'Zoho SMTP' },
        { code: 'microsoft_365', label: 'Microsoft 365' },
        { code: 'google_workspace', label: 'Google Workspace' },
        { code: 'amazon_ses', label: 'Amazon SES' },
        { code: 'sendgrid', label: 'SendGrid' },
        { code: 'mailgun', label: 'Mailgun' },
        { code: 'postmark', label: 'Postmark' },
        { code: 'custom_smtp', label: 'Custom SMTP' },
        { code: 'resend', label: 'Resend' },
      ],
    };
  }
}
