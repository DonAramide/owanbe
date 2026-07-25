import {
  Body,
  Controller,
  Get,
  Post,
  Put,
  Req,
  Res,
  UseGuards,
  Param,
  Headers,
  StreamableFile,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { Public } from '../../common/decorators/public.decorator';
import { SkipTenant } from '../../common/decorators/skip-tenant.decorator';
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

  /**
   * Public GET for NetworkImage / <img> — must skip tenant header because
   * browser image loads cannot send X-Tenant-Id.
   */
  @Public()
  @SkipTenant()
  @Get('object/:encodedKey')
  async getObject(
    @Param('encodedKey') encodedKey: string,
    @Res({ passthrough: true }) res: Response,
  ): Promise<StreamableFile> {
    const file = await this.storage.readObject(encodedKey);
    res.setHeader('Content-Type', file.contentType);
    res.setHeader('Cache-Control', 'public, max-age=86400');
    return new StreamableFile(file.body);
  }

  /**
   * Back-compat GET for avatar URLs previously saved as `/v1/media/upload/...`
   */
  @Public()
  @SkipTenant()
  @Get('upload/:encodedKey')
  async getUploadAlias(
    @Param('encodedKey') encodedKey: string,
    @Res({ passthrough: true }) res: Response,
  ): Promise<StreamableFile> {
    const file = await this.storage.readObject(encodedKey);
    res.setHeader('Content-Type', file.contentType);
    res.setHeader('Cache-Control', 'public, max-age=86400');
    return new StreamableFile(file.body);
  }

  @Public()
  @SkipTenant()
  @Get('status')
  status() {
    return { provider: this.storage.isSupabaseConfigured() ? 'supabase' : 'local_fallback' };
  }
}
