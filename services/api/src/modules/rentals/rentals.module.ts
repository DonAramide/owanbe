import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { CommerceModule } from '../commerce/commerce.module';
import { EventsModule } from '../events/events.module';
import { RentalsController } from './rentals.controller';
import { RentalsService } from './rentals.service';

@Module({
  imports: [DatabaseModule, CommerceModule, EventsModule],
  controllers: [RentalsController],
  providers: [RentalsService],
  exports: [RentalsService],
})
export class RentalsModule {}
