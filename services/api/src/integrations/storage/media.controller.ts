import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
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

  @Get('status')
  status() {
    return { provider: this.storage.isSupabaseConfigured() ? 'supabase' : 'local_fallback' };
  }
}
