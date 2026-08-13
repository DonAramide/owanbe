import { Module } from '@nestjs/common';
import { AuditModule } from '../../audit/audit.module';
import { IntegrationsModule } from '../../integrations/integrations.module';
import { IdentitySecurityController } from './identity-security.controller';
import { IdentitySecurityService } from './identity-security.service';

@Module({
  imports: [AuditModule, IntegrationsModule],
  controllers: [IdentitySecurityController],
  providers: [IdentitySecurityService],
  exports: [IdentitySecurityService],
})
export class IdentitySecurityModule {}
