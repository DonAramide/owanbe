import { Module } from '@nestjs/common';
import { AuditModule } from '../../audit/audit.module';
import { ControlPlaneController } from './control-plane.controller';
import { ControlPlaneService } from './control-plane.service';

@Module({
  imports: [AuditModule],
  controllers: [ControlPlaneController],
  providers: [ControlPlaneService],
  exports: [ControlPlaneService],
})
export class ControlPlaneModule {}
