import { Controller, Get, Param, Post, Query } from '@nestjs/common';
import { Roles } from '../../common/decorators/roles.decorator';
import { TenantId } from '../../common/decorators/tenant-id.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUser } from '../../common/types/jwt-user';
import {
  ADMIN_DISPUTE_ROLES,
  DISPUTE_CREATE_ROLES,
  DISPUTE_PARTICIPANT_ROLES,
} from '../../common/permission-matrix';
import { DisputesService } from './disputes.service';

@Controller()
export class DisputesController {
  constructor(private readonly disputes: DisputesService) {}

  @Roles(...DISPUTE_CREATE_ROLES)
  @Post('disputes')
  async create(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Query('bookingId') bookingId: string,
    @Query('reason') reason: string,
    @Query('description') description: string,
    @Query('amountClaimedMinor') amountClaimedMinor?: string,
    @Query('idempotencyKey') idempotencyKey?: string,
  ) {
    return this.disputes.createDispute({
      tenantId,
      actorUserId: user.userId,
      bookingId,
      reason,
      description,
      amountClaimedMinor,
      idempotencyKey,
    });
  }

  @Roles(...DISPUTE_PARTICIPANT_ROLES)
  @Get('disputes')
  async myDisputes(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Query('limit') limit?: string,
  ) {
    const n = Math.min(100, Math.max(1, parseInt(limit ?? '50', 10) || 50));
    return this.disputes.listMyDisputes(tenantId, user.userId, user.roles, n);
  }

  @Roles(...DISPUTE_PARTICIPANT_ROLES)
  @Get('disputes/:id')
  async one(@TenantId() tenantId: string, @CurrentUser() user: JwtUser, @Param('id') id: string) {
    await this.disputes.ensureParticipantAccess({
      tenantId,
      disputeId: id,
      actorUserId: user.userId,
      actorRoles: user.roles,
    });
    return this.disputes.getDisputeDetails(tenantId, id);
  }

  @Roles(...DISPUTE_PARTICIPANT_ROLES)
  @Post('disputes/:id/messages')
  async addMessage(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('id') id: string,
    @Query('message') message: string,
    @Query('idempotencyKey') idempotencyKey?: string,
  ) {
    return this.disputes.addMessage({
      tenantId,
      disputeId: id,
      actorUserId: user.userId,
      actorRoles: user.roles,
      message,
      idempotencyKey,
    });
  }

  @Roles(...DISPUTE_PARTICIPANT_ROLES)
  @Post('disputes/:id/evidence')
  async addEvidence(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('id') id: string,
    @Query('type') type: 'image' | 'video' | 'document',
    @Query('url') url: string,
    @Query('idempotencyKey') idempotencyKey?: string,
  ) {
    return this.disputes.uploadEvidence({
      tenantId,
      disputeId: id,
      actorUserId: user.userId,
      actorRoles: user.roles,
      type,
      url,
      idempotencyKey,
    });
  }

  @Roles(...ADMIN_DISPUTE_ROLES)
  @Get('admin/disputes')
  async listAdmin(
    @TenantId() tenantId: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const p = Math.max(1, parseInt(page ?? '1', 10) || 1);
    const n = Math.min(100, Math.max(1, parseInt(limit ?? '50', 10) || 50));
    return this.disputes.listAdminDisputes(tenantId, p, n);
  }

  @Roles(...ADMIN_DISPUTE_ROLES)
  @Get('admin/disputes/:id')
  async adminOne(@TenantId() tenantId: string, @Param('id') id: string) {
    return this.disputes.getDisputeDetails(tenantId, id);
  }

  @Roles(...ADMIN_DISPUTE_ROLES)
  @Post('admin/disputes/:id/resolve')
  async resolve(
    @TenantId() tenantId: string,
    @CurrentUser() user: JwtUser,
    @Param('id') id: string,
    @Query('resolution') resolution: 'client_win' | 'vendor_win' | 'partial',
    @Query('refundAmountMinor') refundAmountMinor?: string,
    @Query('note') note?: string,
    @Query('releaseVendorPayout') releaseVendorPayout?: string,
  ) {
    return this.disputes.resolveDispute({
      tenantId,
      disputeId: id,
      actorUserId: user.userId,
      resolution,
      refundAmountMinor,
      note,
      releaseVendorPayout: releaseVendorPayout === 'true',
    });
  }
}
