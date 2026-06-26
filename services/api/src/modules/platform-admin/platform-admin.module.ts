import { Module } from '@nestjs/common';
import { AuditModule } from '../../audit/audit.module';
import { PlatformAdminController } from './platform-admin.controller';
import { PlatformDashboardService } from './platform-dashboard.service';
import { AdminOrganizersService } from './admin-organizers.service';
import { AdminEventsService } from './admin-events.service';
import { AdminVendorsService } from './admin-vendors.service';
import { AdminOperationsCenterService } from './admin-operations-center.service';
import { AdminFinanceSupervisionService } from './admin-finance-supervision.service';
import { AdminAuditService } from './admin-audit.service';
import { LaunchOpsDashboardService } from './launch-ops-dashboard.service';

@Module({
  imports: [AuditModule],
  controllers: [PlatformAdminController],
  providers: [
    PlatformDashboardService,
    AdminOrganizersService,
    AdminEventsService,
    AdminVendorsService,
    AdminOperationsCenterService,
    AdminFinanceSupervisionService,
    AdminAuditService,
    LaunchOpsDashboardService,
  ],
})
export class PlatformAdminModule {}
