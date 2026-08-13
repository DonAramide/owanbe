import { Module, forwardRef } from '@nestjs/common';
import { AuthModule } from '../../auth/auth.module';
import { OwnershipModule } from '../../ownership/ownership.module';
import { VendorOperationsModule } from '../vendor-operations/vendor-operations.module';
import { VendorsController } from './vendors.controller';
import { VendorPackagesController } from './vendor-packages.controller';
import { VendorsService } from './vendors.service';
import { VendorPackagesService } from './vendor-packages.service';
import { VendorServicesService } from './vendor-services.service';

@Module({
  imports: [AuthModule, OwnershipModule, forwardRef(() => VendorOperationsModule)],
  controllers: [VendorsController, VendorPackagesController],
  providers: [VendorsService, VendorPackagesService, VendorServicesService],
  exports: [VendorsService, VendorPackagesService, VendorServicesService],
})
export class VendorsModule {}
