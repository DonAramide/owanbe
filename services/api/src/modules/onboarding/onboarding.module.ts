import { Module } from '@nestjs/common';
import { AuthModule } from '../../auth/auth.module';
import { OwnershipModule } from '../../ownership/ownership.module';
import { OnboardingController } from './onboarding.controller';
import { OnboardingService } from './onboarding.service';

@Module({
  imports: [AuthModule, OwnershipModule],
  controllers: [OnboardingController],
  providers: [OnboardingService],
})
export class OnboardingModule {}
