import { Module } from '@nestjs/common';
import { AuthModule } from '../../auth/auth.module';
import { OwnershipModule } from '../../ownership/ownership.module';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';

@Module({
  imports: [AuthModule, OwnershipModule],
  controllers: [BookingsController],
  providers: [BookingsService],
})
export class BookingsModule {}
