import { Body, Controller, Get, Post, Put, Req, UseGuards, Param, Headers } from '@nestjs/common';
import type { Request } from 'express';
import { Public } from '../../common/decorators/public.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import { CommerceAuthGuard } from '../../modules/commerce/commerce-auth.guard';
import { StorageService } from '../storage/storage.service';

@Controller('media')
export class MediaController {
  constructor(private readonly storage: StorageService) {}

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Post('presign')
  async presign(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Body() body: { filename: string; contentType: string; purpose?: string },
  ) {
    return this.storage.createPresignedUpload({
      tenantId,
      uploadedBy: user.userId,
      filename: body.filename,
      contentType: body.contentType,
      purpose: body.purpose,
    });
  }

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Put('upload/:encodedKey')
  async upload(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('encodedKey') encodedKey: string,
    @Headers('content-type') contentType: string,
    @Req() req: Request & { body: Buffer },
  ) {
    const body = Buffer.isBuffer(req.body) ? req.body : Buffer.from(req.body ?? []);
    return this.storage.proxyUpload({
      tenantId,
      userId: user.userId,
      encodedKey,
      contentType: contentType || 'application/octet-stream',
      body,
    });
  }

  @Get('status')
  status() {
    return { provider: this.storage.isSupabaseConfigured() ? 'supabase' : 'local_fallback' };
  }
}
