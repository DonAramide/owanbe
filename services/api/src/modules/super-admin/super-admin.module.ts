import { Module } from '@nestjs/common';
import { AuditModule } from '../../audit/audit.module';
import { SuperAdminController } from './super-admin.controller';
import { SuperAdminOverviewService } from './super-admin-overview.service';
import { SuperAdminTenantsService } from './super-admin-tenants.service';
import { SuperAdminFinanceService } from './super-admin-finance.service';
import { SuperAdminSystemHealthService } from './super-admin-system-health.service';
import { SuperAdminFeatureFlagsService } from './super-admin-feature-flags.service';
import { SuperAdminAuditService } from './super-admin-audit.service';
import { SuperAdminAnalyticsService } from './super-admin-analytics.service';
import { SuperAdminSecurityService } from './super-admin-security.service';

@Module({
  imports: [AuditModule],
  controllers: [SuperAdminController],
  providers: [
    SuperAdminOverviewService,
    SuperAdminTenantsService,
    SuperAdminFinanceService,
    SuperAdminSystemHealthService,
    SuperAdminFeatureFlagsService,
    SuperAdminAuditService,
    SuperAdminAnalyticsService,
    SuperAdminSecurityService,
  ],
})
export class SuperAdminModule {}
