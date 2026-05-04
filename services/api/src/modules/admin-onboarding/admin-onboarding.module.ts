import { Module } from '@nestjs/common';
import { AuthModule } from '../../auth/auth.module';
import { AdminOnboardingController } from './admin-onboarding.controller';
import { AdminOnboardingService } from './admin-onboarding.service';

@Module({
  imports: [AuthModule],
  controllers: [AdminOnboardingController],
  providers: [AdminOnboardingService],
})
export class AdminOnboardingModule {}
