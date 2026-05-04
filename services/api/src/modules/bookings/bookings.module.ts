import { Module } from '@nestjs/common';
import { AuthModule } from '../../auth/auth.module';
import { OwnershipModule } from '../../ownership/ownership.module';
import { BookingsController } from './bookings.controller';

@Module({
  imports: [AuthModule, OwnershipModule],
  controllers: [BookingsController],
})
export class BookingsModule {}
