import { Module } from '@nestjs/common';
import { AuthModule } from '../../auth/auth.module';
import { AuthMeController } from './auth-me.controller';
import { UsersService } from './users.service';

@Module({
  imports: [AuthModule],
  controllers: [AuthMeController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
