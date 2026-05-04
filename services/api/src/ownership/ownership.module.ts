import { Module } from '@nestjs/common';
import { VendorAccessService } from './vendor-access.service';
import { BookingAccessService } from './booking-access.service';

@Module({
  providers: [VendorAccessService, BookingAccessService],
  exports: [VendorAccessService, BookingAccessService],
})
export class OwnershipModule {}
