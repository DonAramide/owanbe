import { Module } from '@nestjs/common';
import { AuthModule } from '../../auth/auth.module';
import { OwnershipModule } from '../../ownership/ownership.module';
import { VendorsController } from './vendors.controller';
import { VendorPackagesController } from './vendor-packages.controller';
import { VendorsService } from './vendors.service';
import { VendorPackagesService } from './vendor-packages.service';

@Module({
  imports: [AuthModule, OwnershipModule],
  controllers: [VendorsController, VendorPackagesController],
  providers: [VendorsService, VendorPackagesService],
})
export class VendorsModule {}
